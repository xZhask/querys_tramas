-- ============================================================================
-- 05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql
-- Estancias HOSPITALARIAS desde SIGESAPOL ("query 10-bis").
-- Correr en la BD SIGESAPOL, después del paso 1 (usa la misma cfg_periodo).
-- Necesaria para períodos OCTUBRE 2025 en adelante, donde SIGESAPOL supera
-- a CPT como fuente de hospitalización (checks 13b/16/23).
--
-- Diseño espejo de la query 10 (emergencias), con la receta del CHECK 17:
--   - Válidas: fecha_alta_medica IS NOT NULL AND estado IN (6, 7)
--   - Dx cabecera: id_diag_cab/cuer1/cuer2 (85% de cobertura) con fallback
--     a receta_diagnosticos vía la función parcheada (15% restante)
--   - Tipo de dx: '2' fijo (regla SALUDPOL: todo definitivo)
--   - Valorización de estancia: días × t_nivel3 del CPMS de alta
-- ============================================================================

-- Verifica que cfg_periodo exista (se crea en 02_MAESTRO_paso1)
DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cfg_periodo') THEN
		RAISE EXCEPTION 'Falta cfg_periodo: corre primero el bloque CONFIGURAR PERÍODO de 02_MAESTRO_paso1_SIGESAPOL.sql';
	END IF;
END $$;


DROP TABLE IF EXISTS temp_hospitalizacion_sigesapol_estancia;

CREATE TABLE temp_hospitalizacion_sigesapol_estancia AS
SELECT
	'SIGESAPOL hospitalizacion estancia'::text AS base,
	CASE
		WHEN a.tipo_doc_ident = 'DNI' THEN '1'::varchar
		WHEN a.tipo_doc_ident = 'CE' THEN '2'::varchar
	END AS sp_tipo_documento_paciente,
	a.nro_doc_ident AS sp_numero_documento_paciente,
	a.paterno AS sp_apellido_paterno_paciente,
	a.materno AS sp_apellido_materno_paciente,
	a.nombre AS sp_nombres_paciente,
	a.fecha_nac AS sp_fecha_nacimiento_paciente,
	CASE
		WHEN a.sexo = 'M' THEN '1'::varchar
		WHEN a.sexo = 'F' THEN '2'::varchar
	END AS sp_genero_paciente,
	CASE
		WHEN a.id_tipo_parentesco = 8 THEN '1'::varchar -- titular (mismo código que emergencias)
		ELSE '2'::varchar
	END AS sp_condicion_asegurado,
	'3'::text AS sp_tipo_atencion, -- hospitalización
	es.codigo AS sp_codigo_ipress,
	es.nombre AS sp_nombre_ipress,
	COALESCE(h.fecha_ingreso, h.fecha_atencion, h.created_at)::date AS sp_fecha_atencion,
	h.fecha_alta_medica::date AS sp_fecha_alta,

	(CASE WHEN m.tipo_documento IS NULL THEN '1' ELSE m.tipo_documento END)::varchar AS sp_tipo_documento_responsable,
	m.dni AS sp_numero_documento_responsable,
	m.paterno AS sp_apellido_paterno_responsable,
	m.materno AS sp_apellido_materno_responsable,
	m.nombre AS sp_nombres_responsable,

	prof.nombre AS sigesapol_nombre_profesion_responsable,
	(CASE 	WHEN prof.nombre IN ('MEDICO GENERAL','MEDICO ESPECIALISTA','MEDICO CIRUJANO','MEDICO','OFTALMOLOGIA','GINECOLOGIA') THEN '01'
		WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN '02'
		WHEN prof.nombre = 'ODONTOLOGIA' THEN '03'
		WHEN prof.nombre = 'BIOLOGO' THEN '04'
		WHEN prof.nombre = 'OBSTETRICIA' THEN '05'
		WHEN prof.nombre = 'ENFERMERIA' THEN '06'
		WHEN prof.nombre = 'PSICOLOGIA' THEN '07'
		WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN '09'
		WHEN prof.nombre = 'NUTRICIONISTA' THEN '10'
	ELSE '00'
	END) AS sp_codigo_profesion_responsable,
	(CASE WHEN esp.nombre = 'OBSTETRICIA' THEN '00' ELSE '01' END)::varchar AS sp_codigo_especialidad,
	regexp_replace(esp.nombre, '\r|\n|\t', '', 'g') AS nombre_especialidad,

	h.id_condicion_alta AS sp_circunstancia_alta_sigesapol,
	h.estado,

	-- UPSS de hospitalización (código SALUDPOL de internamiento)
	'930000'::varchar AS sp_upss_codigo,
	'HOSPITALIZACION'::varchar AS sp_upss_nombre,
	'1'::varchar AS hospitalizacion,

	-- ===== DIAGNÓSTICOS: cabecera con fallback a receta_diagnosticos =====
	-- Regla SALUDPOL vigente: TODO tipo de dx = '2' (definitivo)
	'2'::varchar AS sp_tipo_dx_01,
	COALESCE(d1.codigo,  fdx.codigo_dx_01)  AS sp_codigo_dx_01,
	COALESCE(d1.nombre,  fdx.descripcion_dx_01) AS sp_descripcion_dx_01,
	'2'::varchar AS sp_tipo_dx_02,
	COALESCE(d2.codigo,  fdx.codigo_dx_02)  AS sp_codigo_dx_02,
	COALESCE(d2.nombre,  fdx.descripcion_dx_02) AS sp_descripcion_dx_02,
	'2'::varchar AS sp_tipo_dx_03,
	COALESCE(d3.codigo,  fdx.codigo_dx_03)  AS sp_codigo_dx_03,
	COALESCE(d3.nombre,  fdx.descripcion_dx_03) AS sp_descripcion_dx_03,

	h.id AS id_hospitalizacion_sigesapol,
	-- CPMS de estancia: cpms_alta viene VACÍO en el 100% de hospitalizaciones
	-- (hallazgo del piloto). Fallback por clase de cama, con tarifas
	-- verificadas en procedimientos.t_nivel3:
	--   UCI/intensivos -> 99295 | intermedios -> 99305 | resto -> 99231
	COALESCE(NULLIF(h.cpms_alta, ''),
		CASE
			WHEN cc.descripcion ILIKE '%UCI%' OR cc.descripcion ILIKE '%INTENSIV%' THEN '99295'
			WHEN cc.descripcion ILIKE '%INTERMEDI%' THEN '99305'
			ELSE '99231'
		END) AS cpms_alta,
	(COALESCE(h.cpms_alta, '') = '') AS es_cpms_derivado, -- true = código derivado por clase de cama
	cc.descripcion AS clase_cama, -- trazabilidad del fallback aplicado
	(h.fecha_alta_medica::date - COALESCE(h.fecha_atencion, h.fecha_ingreso, h.created_at)::date + 1) AS cantidad_cpms_estancia,
	((h.fecha_alta_medica::date - COALESCE(h.fecha_atencion, h.fecha_ingreso, h.created_at)::date + 1) * pro.t_nivel3) AS sp_valorizacion_estancia

FROM hospitalizaciones h
LEFT JOIN asegurados a ON a.id = h.id_asegurado
INNER JOIN establecimientos es ON es.id = h.id_establecimiento

-- Cama activa para derivar la clase (id_cama_egreso viene NULL, piloto):
LEFT JOIN camas cam ON cam.id = h.id_cama
LEFT JOIN clase_camas cc ON cc.id = cam.id_clase_cama

-- Médico de alta: hospitalizaciones tiene id_medico_alta (medicos.id) e
-- id_user_alta (users.id). Se prioriza el vínculo directo a medicos;
-- si en la validación salieran muchos NULL, cambiar al patrón users->medicos
-- de la query 10 usando id_user_alta.
LEFT JOIN medicos m   ON m.id = h.id_medico_alta
LEFT JOIN profesiones prof ON prof.id = m.id_profesion
LEFT JOIN especializaciones esp ON esp.id = m.id_especializacion

-- Dx de cabecera (85% de cobertura, CHECK 17)
LEFT JOIN diagnosticos d1 ON d1.id = h.id_diag_cab
LEFT JOIN diagnosticos d2 ON d2.id = h.id_diag_cuer1
LEFT JOIN diagnosticos d3 ON d3.id = h.id_diag_cuer2

-- Fallback para el 15% sin dx de cabecera: receta_diagnosticos por
-- id_hospitalizacion (usa el mismo filtrado del PARCHE A: activos, no borrados)
LEFT JOIN LATERAL (
	SELECT
		MAX(CASE WHEN rn = 1 THEN codigo END) AS codigo_dx_01,
		MAX(CASE WHEN rn = 1 THEN nombre END) AS descripcion_dx_01,
		MAX(CASE WHEN rn = 2 THEN codigo END) AS codigo_dx_02,
		MAX(CASE WHEN rn = 2 THEN nombre END) AS descripcion_dx_02,
		MAX(CASE WHEN rn = 3 THEN codigo END) AS codigo_dx_03,
		MAX(CASE WHEN rn = 3 THEN nombre END) AS descripcion_dx_03
	FROM (
		SELECT cie.codigo,
		       UPPER(regexp_replace(cie.nombre, '\r|\n|\t', '', 'g')) AS nombre,
		       ROW_NUMBER() OVER (ORDER BY rd.id) AS rn
		FROM receta_diagnosticos rd
		JOIN diagnosticos cie ON cie.id = rd.id_diagnostico
		WHERE rd.id_hospitalizacion = h.id
		  AND rd.estado = 1
		  AND rd.deleted_at IS NULL
	) sub
	WHERE rn <= 3
) fdx ON h.id_diag_cab IS NULL

-- Tarifa del CPMS de estancia EFECTIVO (con el mismo fallback de arriba)
LEFT JOIN procedimientos pro ON pro.codigo =
	COALESCE(NULLIF(h.cpms_alta, ''),
		CASE
			WHEN cc.descripcion ILIKE '%UCI%' OR cc.descripcion ILIKE '%INTENSIV%' THEN '99295'
			WHEN cc.descripcion ILIKE '%INTERMEDI%' THEN '99305'
			ELSE '99231'
		END)

WHERE h.fecha_alta_medica IS NOT NULL
  AND h.estado IN (6, 7)  -- válidas según CHECK 17
  AND h.fecha_alta_medica::date BETWEEN (SELECT p_ini FROM cfg_periodo)
                                    AND (SELECT p_fin FROM cfg_periodo)
  -- ALCANCE: solo Hospital Luis N. Sáenz (ver CONTEXTO_CANONICO.md §1).
  -- Filtro por ID de establecimiento, nunca por nombre (dos grafías legítimas).
  AND es.id = (SELECT id_establecimiento_sigesapol FROM cfg_ipress_alcance);


-- ============================================================================
-- ALCANCE: constancia de lo depurado por IPRESS (ver CONTEXTO_CANONICO.md §3)
-- ============================================================================
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo)
   AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_hospitalizacion_sigesapol_estancia';

INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo),
       'temp_hospitalizacion_sigesapol_estancia', es.codigo, es.nombre, COUNT(*)
FROM hospitalizaciones h
INNER JOIN establecimientos es ON es.id = h.id_establecimiento
WHERE h.fecha_alta_medica IS NOT NULL
  AND h.estado IN (6, 7)
  AND h.fecha_alta_medica::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
  AND es.id <> (SELECT id_establecimiento_sigesapol FROM cfg_ipress_alcance)
GROUP BY es.codigo, es.nombre;


-- ============================================================
-- Verificación post-creación
-- ============================================================
SELECT COUNT(*) AS estancias_hosp,
       COUNT(*) FILTER (WHERE sp_numero_documento_paciente IS NULL) AS sin_documento,
       COUNT(*) FILTER (WHERE sp_codigo_dx_01 IS NULL) AS sin_dx_principal,
       COUNT(*) FILTER (WHERE sp_numero_documento_responsable IS NULL) AS sin_medico,
       COUNT(*) FILTER (WHERE cpms_alta IS NULL) AS sin_cpms_alta,
       COUNT(*) FILTER (WHERE sp_valorizacion_estancia IS NULL) AS sin_valorizacion
FROM temp_hospitalizacion_sigesapol_estancia;
-- sin_medico alto  => cambiar el join de medicos al patrón users (ver comentario)
-- sin_dx_principal => hospitalizaciones sin dx ni en cabecera ni en receta: reportar
-- sin_cpms_alta / sin_valorizacion => revisar con el equipo cómo valorizar esas estancias

-- NOTA: esta tabla también debe trasladarse a la BD CPT (mismo procedimiento
-- pg_dump que el padrón de emergencia) para el armado y la deduplicación.
