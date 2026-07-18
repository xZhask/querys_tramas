-- ============================================================================
-- 12_RECLASIFICAR_emergencias_24h.sql
-- Reclasificación de estancias de emergencia > 24 horas y unión de estancias.
-- Correr en la BD CPT (db_cpt_junio26), después del paso 8 (CONSOLIDAR).
-- ============================================================================

-- 1. Agregar columnas de trazabilidad si no existen
ALTER TABLE temp_hospitalizacion_local
ADD COLUMN IF NOT EXISTS origen_reclasificacion varchar(50) DEFAULT NULL;

-- id_emergencia_unida: fuente única de verdad de qué emergencia quedó unida
-- a cada hospitalización (ver sección 3). generate_outputs_v2.py consume
-- esta columna en vez de re-derivar la condición de fecha en Python.
ALTER TABLE temp_hospitalizacion_local
ADD COLUMN IF NOT EXISTS id_emergencia_unida integer DEFAULT NULL;

ALTER TABLE temp_emergencia_sigesapol_estancia
ADD COLUMN IF NOT EXISTS excluir_tipo2 boolean DEFAULT false;

-- 1b. Snapshot de valorización ANTES de reclasificar (para CONTROL 14 en
-- 04_CONTROL_integridad.sql: recuperación neta real, sin contar de nuevo el
-- valor de una estancia que ya se facturaba antes de unirla con Caso A).
-- row_uid es estable a través del UPDATE de Caso A (mismo row, solo cambian
-- fechas/valorización); las filas nuevas de Caso B no tienen fila "antes"
-- correspondiente, así que aportan 0 al "antes" correctamente.
ALTER TABLE temp_hospitalizacion_local ADD COLUMN IF NOT EXISTS row_uid serial;
DROP TABLE IF EXISTS temp_hospitalizacion_antes_reclasif;
CREATE TABLE temp_hospitalizacion_antes_reclasif AS
SELECT row_uid, sp_valorizacion_total AS valorizacion_antes, sp_dias_estancia AS dias_antes
FROM temp_hospitalizacion_local;

-- 2. Marcar excluir_tipo2 = true para todas las emergencias > 24 horas (duración > 1 día)
-- Esto incluye tanto las reclasificables como las de CIERRE ADMINISTRATIVO.
UPDATE temp_emergencia_sigesapol_estancia
SET excluir_tipo2 = true
WHERE (sp_fecha_alta_emergencia - sp_fecha_atencion) > INTERVAL '24 hours';

-- 3. CASO A: Unión de Estancias Solapadas / Contiguas
-- Regla inmutable 1.4: toda emergencia que SE SOLAPA O TOCA (margen de 1 día
-- calendario — transferencia física inmediata, sin solapamiento porque las
-- fechas son por día, no por hora) con una hospitalización existente se
-- unifica (excluyendo CIERRE ADMINISTRATIVO). Una hospitalización puede
-- tocar/solapar más de una emergencia candidata (dato real, verificado en
-- los 6 meses); DISTINCT ON elige una sola por hospitalización -brecha
-- mínima primero, luego id- para que la unión sea determinista y no genere
-- pares duplicados en el libro de auditoría (ver CONTEXTO_CANONICO.md §3,
-- hallazgo "o toca" / duplicados internos).
DROP TABLE IF EXISTS temp_union_ganadora;
CREATE TABLE temp_union_ganadora AS
SELECT DISTINCT ON (h.row_uid)
	h.row_uid,
	e.id_emergencia_sigesapol,
	e.sp_fecha_atencion AS e_ing,
	e.sp_fecha_alta_emergencia AS e_alt
FROM temp_hospitalizacion_local h
JOIN temp_emergencia_sigesapol_estancia e
  ON e.sp_numero_documento_paciente = h.sp_numero_documento_paciente
 AND h.sp_fecha_atencion::date <= e.sp_fecha_alta_emergencia::date + 1
 AND h.sp_fecha_alta::date     >= e.sp_fecha_atencion::date
 AND NOT (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15)
ORDER BY h.row_uid, (h.sp_fecha_atencion::date - e.sp_fecha_alta_emergencia::date) ASC, e.id_emergencia_sigesapol ASC;

UPDATE temp_hospitalizacion_local h
SET
	sp_fecha_atencion = LEAST(h.sp_fecha_atencion, g.e_ing),
	sp_fecha_alta = GREATEST(h.sp_fecha_alta, g.e_alt),
	digitador = 'RECLASIF_EMERGENCIA',
	origen_reclasificacion = 'UNION_EMERGENCIA_HOSP',
	id_emergencia_unida = g.id_emergencia_sigesapol
FROM temp_union_ganadora g
WHERE h.row_uid = g.row_uid;

-- Marcar excluir_tipo2 = true solo para las emergencias que ganaron el desempate
UPDATE temp_emergencia_sigesapol_estancia e
SET excluir_tipo2 = true
WHERE e.id_emergencia_sigesapol IN (SELECT id_emergencia_sigesapol FROM temp_union_ganadora);

-- Recalcular días de estancia y valorización para las estancias unidas
UPDATE temp_hospitalizacion_local h
SET 
	sp_dias_estancia = (date(sp_fecha_alta) - date(sp_fecha_atencion) + 1),
	sp_valorizacion_total = (date(sp_fecha_alta) - date(sp_fecha_atencion) + 1) * COALESCE((SELECT nivel_3 FROM cpt WHERE cod_cpt = h.sp_codigo_procedimiento LIMIT 1), 392.99)
WHERE h.origen_reclasificacion = 'UNION_EMERGENCIA_HOSP';


-- 4. CASO B: Nueva Estancia por Permanencia en Emergencia > 24h
-- Insertar una nueva estancia tipo 3 (99231.15) para emergencias > 24h que
-- NO ganaron el desempate de la sección 3 (excluyendo CIERRE ADMINISTRATIVO).
-- Se usa temp_union_ganadora (la misma fuente única de verdad) en vez de un
-- NOT EXISTS geométrico independiente: una emergencia >24h puede tocar una
-- hospitalización y aun así perder el desempate frente a otra emergencia
-- del mismo paciente (dato real — ver caveat de cadenas multi-episodio en
-- CONTEXTO_CANONICO.md §3). Antes de este cambio esa emergencia "perdedora"
-- quedaba con excluir_tipo2=true (regla de duración, sección 2) pero SIN
-- unión real y SIN estancia Caso B — desaparecía de las 4 tramas sin dejar
-- rastro (verificado: 2 casos en julio 2025, docs 00237288 y 08479060).
INSERT INTO temp_hospitalizacion_local (
	historia, sp_tipo_documento_paciente, sp_numero_documento_paciente,
	sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente,
	sp_fecha_nacimiento, sp_genero_paciente, sp_condicion_asegurado, sp_tipo_atencion,
	sp_codigo_ipress, sp_nombre_ipress, sp_upss_codigo, sp_upss_descripcion,
	sp_fecha_atencion, sp_fecha_alta,
	sp_tipo_documento_responsable, sp_numero_documento_responsable,
	sp_apellido_paterno_responsable, sp_apellido_materno_responsable, sp_nombres_responsable,
	sp_profesion_responsable, sp_especialidad_responsable, sp_circunstancia_alta,
	sp_tipo_dx_01, sp_codigo_dx_01, sp_descripcion_dx_01,
	sp_tipo_dx_02, sp_codigo_dx_02, sp_descripcion_dx_02,
	sp_tipo_dx_03, sp_codigo_dx_03, sp_descripcion_dx_03,
	sp_codigo_procedimiento, sp_descripcion_procedimiento,
	sp_dias_estancia, sp_valorizacion_total,
	digitador, origen_reclasificacion
)
SELECT
	NULL, e.sp_tipo_documento_paciente::int, e.sp_numero_documento_paciente,
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente,
	e.sp_fecha_nacimiento_paciente::date, e.sp_genero_paciente::int, e.sp_condicion_asegurado::int, 3, -- tipo 3 hosp
	e.sp_codigo_ipress, e.sp_nombre_ipress, '230000', 'EMERGENCIA',
	e.sp_fecha_atencion, e.sp_fecha_alta_emergencia,
	e.sp_tipo_documento_responsable::int, e.sp_numero_documento_responsable,
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable,
	e.sp_codigo_profesion_responsable, e.sp_codigo_especialidad, e.sp_circunstancia_alta_sigesapol_sp::int,
	e.sp_tipo_dx_01, e.sp_codigo_dx_01, e.sp_descripcion_dx_01,
	e.sp_tipo_dx_02, e.sp_codigo_dx_02, e.sp_descripcion_dx_02,
	e.sp_tipo_dx_03, e.sp_codigo_dx_03, e.sp_descripcion_dx_03,
	'99231.15', 'Atención paciente-día hospitalización especializada continuada que no está especificada',
	(date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1),
	(date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) * 392.99,
	'RECLASIF_EMERGENCIA', 'PERMANENCIA_EMERGENCIA_24H'
FROM temp_emergencia_sigesapol_estancia e
WHERE (e.sp_fecha_alta_emergencia - e.sp_fecha_atencion) > INTERVAL '24 hours'
  -- Excluir CIERRE ADMINISTRATIVO
  AND NOT (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15)
  -- No debe haber ganado el desempate de la sección 3 (si ganó, ya está
  -- físicamente unida a su hospitalización y no necesita estancia propia)
  AND e.id_emergencia_sigesapol NOT IN (SELECT id_emergencia_sigesapol FROM temp_union_ganadora);

-- 5. Crear indices sobre las columnas agregadas para optimizar
CREATE INDEX IF NOT EXISTS idx_tmp_hosp_origen_rec ON temp_hospitalizacion_local (origen_reclasificacion);
CREATE INDEX IF NOT EXISTS idx_tmp_emerg_excluir ON temp_emergencia_sigesapol_estancia (excluir_tipo2);
