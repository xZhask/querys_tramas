-- ============================================================================
-- 06_FASE2_SIGESAPOL_procedimientos.sql
-- Procedimientos desde SIGESAPOL (prestaciones + prestacion_procedimientos),
-- generalización de la query 09 a TODOS los tipos de atención del convenio.
-- Correr en la BD SIGESAPOL después del paso 1 (usa la misma cfg_periodo).
--
-- Cambios respecto a la 09 original:
--   1. Período desde cfg_periodo (antes: fecha quemada).
--   2. Tres universos según el catálogo verificado (CHECK 19/20):
--        - Ambulatorio:      id_tipo_atencion IN (1, 5, 7)   [como la 09]
--        - Emergencia:       id_tipo_atencion = 2            [242 mil en alcance]
--        - Hospitalización:  id_tipo_atencion IN (3, 6, 8)   [hosp + nutricional + oncológico]
--   3. Incluye tipo_procedimiento 1 (médicos), 2 (laboratorio) y 3 (imágenes);
--      antes solo 1. La columna tipo_procedimiento sale en el resultado para
--      poder separarlos en el armado/Excel.
--   4. Joins de citas/consultorios pasados a LEFT: emergencia y hospitalización
--      no siempre tienen cita, el INNER los eliminaba.
--   5. Tipo de dx fijo en '2' (regla SALUDPOL: todo definitivo). Los códigos y
--      descripciones sí salen de la función de diagnósticos (PARCHE A aplicado:
--      sin anulados ni eliminados).
--   6. DROP IF EXISTS y verificación final.
-- ============================================================================

DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cfg_periodo') THEN
		RAISE EXCEPTION 'Falta cfg_periodo: corre primero el bloque CONFIGURAR PERÍODO de 02_MAESTRO_paso1_SIGESAPOL.sql';
	END IF;
END $$;


DROP TABLE IF EXISTS temp_sigesapol_procedimientos;

CREATE TABLE temp_sigesapol_procedimientos AS
SELECT
	CASE
		WHEN pre.id_tipo_atencion IN (1, 5, 7) THEN 'SIGESAPOL ambulatorio'
		WHEN pre.id_tipo_atencion = 2          THEN 'SIGESAPOL emergencia'
		WHEN pre.id_tipo_atencion IN (3, 6, 8) THEN 'SIGESAPOL hospitalizacion'
	END::text AS base,
	CASE
		WHEN pre.id_tipo_atencion IN (1, 5, 7) THEN '1'
		WHEN pre.id_tipo_atencion = 2          THEN '2'
		WHEN pre.id_tipo_atencion IN (3, 6, 8) THEN '3'
	END::varchar AS tipo_atencion_trama,
	pre.id_tipo_atencion AS id_tipo_atencion_sigesapol,
	p2.tipo_procedimiento, -- 1: médicos, 2: laboratorio, 3: imágenes

	regexp_replace(h.nro_historia, '\r|\n|\t', '', 'g') AS historia,
	c.grado AS grado_paciente,
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
		WHEN c.parentesco = 'TITULAR' THEN '1'::varchar
		ELSE '2'::varchar
	END AS sp_condicion_asegurado,

	e.codigo AS sp_codigo_ipress,
	e.nombre AS sp_nombre_ipress,
	pre.fecha_atencion AS sp_fecha_atencion,
	pre.fecha_alta AS sp_fecha_alta,

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
	(CASE WHEN es.nombre = 'OBSTETRICIA' THEN '00' ELSE '01' END)::varchar AS sp_codigo_especialidad,
	regexp_replace(es.nombre, '\r|\n|\t', '', 'g') AS nombre_especialidad,
	''::text AS sp_circunstancia_alta,

	pre.codigo_upss AS sp_upss_codigo,
	regexp_replace(cons.nombre, '\r|\n|\t', '', 'g') AS upss_nombre_consultorio,
	regexp_replace(upss.descripcion_upss, '\r|\n|\t', '', 'g') AS sp_upss_nombre,
	pre.ipress AS condicion_ipress,
	pre.upss AS condicion_servicio,

	-- ===== DIAGNÓSTICOS (tipo fijo '2' por regla SALUDPOL) =====
	'2'::varchar AS sp_tipo_dx_01,
	max(CASE WHEN d1.orden = 1 THEN d1.codigo_diagnostico END) AS sp_codigo_dx_01,
	max(CASE WHEN d1.orden = 1 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_01,
	'2'::varchar AS sp_tipo_dx_02,
	max(CASE WHEN d1.orden = 2 THEN d1.codigo_diagnostico END) AS sp_codigo_dx_02,
	max(CASE WHEN d1.orden = 2 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_02,
	'2'::varchar AS sp_tipo_dx_03,
	max(CASE WHEN d1.orden = 3 THEN d1.codigo_diagnostico END) AS sp_codigo_dx_03,
	max(CASE WHEN d1.orden = 3 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_03,

	-- ===== PROCEDIMIENTOS =====
	p2.codigo::varchar AS sp_codigo_procedimiento,
	p2.descripcion::varchar AS sp_descripcion_procedimiento,
	pp.cantidad AS sp_suma_cantidad,
	(pp.cantidad * p2.t_nivel3) AS sp_valorizacion_calculada,

	pre.id AS id_prestacion_sigesapol

FROM prestaciones pre
	LEFT JOIN asegurados a ON a.id = pre.id_asegurado
	INNER JOIN asegurado_historias h ON h.id_asegurado = a.id AND h.id_establecimiento = '76' -- Hospital LNS
	INNER JOIN establecimientos e ON e.id = pre.id_establecimiento
	LEFT JOIN citas c ON c.id = pre.id_cita                                -- LEFT: emerg/hosp no siempre tienen cita
	LEFT JOIN sub_consultorios subc ON subc.id = c.id_sub_consultorio
	LEFT JOIN consultorios cons ON cons.id = subc.id_consultorio
	INNER JOIN medicos m ON m.id = pre.id_medico
	INNER JOIN especializaciones es ON es.id = m.id_especializacion
	INNER JOIN profesiones prof ON prof.id = m.id_profesion
	LEFT JOIN prestacion_procedimientos pp ON pp.id_prestacion = pre.id
	LEFT JOIN procedimientos p2 ON p2.id = pp.id_procedimiento
	LEFT JOIN upsses upss ON upss.codigo = pre.codigo_upss
	INNER JOIN (
		SELECT
			rd.id_prestacion,
			cie.codigo AS codigo_diagnostico,
			UPPER(regexp_replace(cie.nombre, '\r|\n|\t', '', 'g')) as descripcion_diagnostico,
			ROW_NUMBER() OVER(PARTITION BY rd.id_prestacion ORDER BY rd.id)::integer AS orden
		FROM receta_diagnosticos rd
		INNER JOIN diagnosticos cie ON cie.id = rd.id_diagnostico
		WHERE rd.estado = 1
		  AND rd.deleted_at IS NULL
	) d1 ON d1.id_prestacion = pre.id AND d1.orden <= 3

WHERE pre.id_tipo_atencion IN (1, 5, 7, 2, 3, 6, 8)
  AND p2.tipo_procedimiento IN (1, 2, 3)  -- médicos, laboratorio, imágenes
  AND pre.fecha_atencion >= (SELECT p_ini FROM cfg_periodo)
  AND pre.fecha_atencion <  (SELECT p_fin FROM cfg_periodo) + INTERVAL '1 day'

GROUP BY
	pre.id_tipo_atencion, p2.tipo_procedimiento,
	h.nro_historia, c.grado, a.tipo_doc_ident, a.nro_doc_ident,
	a.paterno, a.materno, a.nombre, a.fecha_nac, a.sexo, c.parentesco,
	e.codigo, e.nombre, pre.fecha_atencion, pre.fecha_alta,
	m.tipo_documento, m.dni, m.paterno, m.materno, m.nombre,
	prof.nombre, es.nombre,
	pre.codigo_upss, cons.nombre, upss.descripcion_upss, pre.ipress, pre.upss,
	p2.codigo, p2.descripcion, pp.cantidad, p2.t_nivel3,
	pre.id;


-- ============================================================
-- Verificación post-creación: volumen por universo y tipo
-- ============================================================
SELECT base, tipo_procedimiento,
       COUNT(*) AS filas,
       COUNT(DISTINCT sp_numero_documento_paciente) AS pacientes,
       SUM(sp_valorizacion_calculada) AS valorizacion_total,
       COUNT(*) FILTER (WHERE COALESCE(sp_valorizacion_calculada,0) = 0) AS sin_valorizacion
FROM temp_sigesapol_procedimientos
GROUP BY base, tipo_procedimiento
ORDER BY base, tipo_procedimiento;

-- NOTA 1: esta tabla también viaja a la BD CPT (mismo pg_dump) para la
--         deduplicación contra las BDT de CPT (archivo 07).
-- NOTA 2: la 09 original queda reemplazada por este script (su universo
--         ambulatorio está incluido con el mismo detalle).
