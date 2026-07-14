-- ============================================================================
-- 12_RECLASIFICAR_emergencias_24h.sql
-- Reclasificación de estancias de emergencia > 24 horas y unión de estancias.
-- Correr en la BD CPT (db_cpt_junio26), después del paso 8 (CONSOLIDAR).
-- ============================================================================

-- 1. Agregar columnas de trazabilidad si no existen
ALTER TABLE temp_hospitalizacion_local 
ADD COLUMN IF NOT EXISTS origen_reclasificacion varchar(50) DEFAULT NULL;

ALTER TABLE temp_emergencia_sigesapol_estancia 
ADD COLUMN IF NOT EXISTS excluir_tipo2 boolean DEFAULT false;

-- 2. Marcar excluir_tipo2 = true para todas las emergencias > 24 horas (duración > 1 día)
-- Esto incluye tanto las reclasificables como las de CIERRE ADMINISTRATIVO.
UPDATE temp_emergencia_sigesapol_estancia
SET excluir_tipo2 = true
WHERE (sp_fecha_alta_emergencia - sp_fecha_atencion) > INTERVAL '24 hours';

-- 3. CASO A: Unión de Estancias Solapadas / Contiguas
-- Expandir la estancia de hospitalización existente en temp_hospitalizacion_local
-- que se toca o solapa con la emergencia > 24h (excluyendo CIERRE ADMINISTRATIVO).
-- Primero actualizamos las fechas de ingreso y egreso, digitador y origen
UPDATE temp_hospitalizacion_local h
SET 
	sp_fecha_atencion = LEAST(h.sp_fecha_atencion, e.sp_fecha_atencion),
	sp_fecha_alta = GREATEST(h.sp_fecha_alta, e.sp_fecha_alta_emergencia),
	digitador = 'RECLASIF_EMERGENCIA',
	origen_reclasificacion = 'UNION_EMERGENCIA_HOSP'
FROM temp_emergencia_sigesapol_estancia e
WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
  -- Excluir CIERRE ADMINISTRATIVO (>15 días y cambio de mes)
  AND NOT (TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15)
  -- Solo emergencias > 24h
  AND (e.sp_fecha_alta_emergencia - e.sp_fecha_atencion) > INTERVAL '24 hours';

-- Recalcular días de estancia y valorización para las estancias unidas
UPDATE temp_hospitalizacion_local h
SET 
	sp_dias_estancia = (date(sp_fecha_alta) - date(sp_fecha_atencion) + 1),
	sp_valorizacion_total = (date(sp_fecha_alta) - date(sp_fecha_atencion) + 1) * COALESCE((SELECT nivel_3 FROM cpt WHERE cod_cpt = h.sp_codigo_procedimiento LIMIT 1), 392.99)
WHERE h.origen_reclasificacion = 'UNION_EMERGENCIA_HOSP';


-- 4. CASO B: Nueva Estancia por Permanencia en Emergencia > 24h
-- Insertar una nueva estancia tipo 3 (99231.15) para emergencias > 24h
-- que no se solapan con ninguna hospitalización existente (excluyendo CIERRE ADMINISTRATIVO).
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
  -- No debe solaparse con ninguna hospitalización en temp_hospitalizacion_local
  AND NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
	  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
	  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
  );

-- 5. Crear indices sobre las columnas agregadas para optimizar
CREATE INDEX IF NOT EXISTS idx_tmp_hosp_origen_rec ON temp_hospitalizacion_local (origen_reclasificacion);
CREATE INDEX IF NOT EXISTS idx_tmp_emerg_excluir ON temp_emergencia_sigesapol_estancia (excluir_tipo2);
