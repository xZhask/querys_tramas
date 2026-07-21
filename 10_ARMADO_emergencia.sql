-- ============================================================================
-- 10_ARMADO_emergencia.sql
-- Copia del armado original '07_EMERGENCIA_1_2_3_TODO.sql' con UNA sola correcciÃ³n:
-- UNION -> UNION ALL (las ramas tienen literales 'base' distintos, el
-- duplicado entre ramas es imposible y el UNION solo costaba deduplicaciÃ³n
-- innecesaria sobre ~50 columnas). La estructura y columnas NO cambian.
-- Las tablas temp_* que lee ya vienen CONSOLIDADAS por el archivo 08
-- (canÃ³nico + complemento deduplicado); las filas de origen SIGESAPOL se
-- identifican por digitador = 'SIGESAPOL'.
-- ============================================================================
-- EMERGENCIA
-- ============================================================================
(SELECT 
'estancia en emergencia'::text as base,
	prioridad, 
	sp_tipo_documento_paciente, sp_numero_documento_paciente, 
	sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente, 
	sp_fecha_nacimiento_paciente AS sp_fecha_nacimiento, sp_genero_paciente, sp_condicion_asegurado, sp_tipo_atencion, 
	sp_codigo_ipress, sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta_emergencia AS sp_fecha_alta, 
	sp_tipo_documento_responsable, sp_numero_documento_responsable, 
	sp_apellido_paterno_responsable, sp_apellido_materno_responsable, sp_nombres_responsable, 
	sp_codigo_profesion_responsable AS sp_profesion_responsable, sp_codigo_especialidad AS sp_especialidad_responsable, 
	sp_circunstancia_alta_sigesapol_sp::int AS sp_circunstancia_alta, 
	sp_upss_codigo, 
	regexp_replace(sp_upss_nombre, '\r|\n', '', 'g') as sp_upss_descripcion,
	'2' AS hospitalizacion,

	-- Diagnósticos 
	sp_tipo_dx_01, sp_codigo_dx_01, sp_descripcion_dx_01, 
	sp_tipo_dx_02, sp_codigo_dx_02, sp_descripcion_dx_02,
	sp_tipo_dx_03, sp_codigo_dx_03, sp_descripcion_dx_03,

	-- Digitación
	'SIGESAPOL' AS digitador_prestacion, 
	e.sp_fecha_atencion::date AS fecha_registro_prestacion, 
	NULL::time AS hora_registro_prestacion,
	id_emergencia_sigesapol AS id_atencion_emergencia,

	-- Código CPMS por prioridad y tarifa (forzado por prioridad)
	CASE 
		WHEN e.prioridad = 1 THEN '99285'
		WHEN e.prioridad = 2 THEN '99284'
		WHEN e.prioridad = 3 THEN '99282'
		WHEN e.prioridad = 4 THEN '99281'
		ELSE '99281'
	END as sp_codigo_procedimiento, 
	CASE 
		WHEN e.prioridad = 1 THEN 'Consulta en emergencia para evaluación y manejo de un paciente (Prioridad I)'
		WHEN e.prioridad = 2 THEN 'Consulta en emergencia para evaluación y manejo de un paciente (Prioridad II)'
		WHEN e.prioridad = 3 THEN 'Consulta en emergencia para evaluación y manejo de un paciente (Prioridad III)'
		WHEN e.prioridad = 4 THEN 'Consulta en emergencia para evaluación y manejo de un paciente (Prioridad IV)'
		ELSE 'Consulta en emergencia'
	END as sp_descripcion_procedimiento, 
	1 AS sp_suma_cantidad, 
	COALESCE((SELECT nivel_3 FROM cpt WHERE cod_cpt = (
		CASE 
			WHEN e.prioridad = 1 THEN '99285'
			WHEN e.prioridad = 2 THEN '99284'
			WHEN e.prioridad = 3 THEN '99282'
			WHEN e.prioridad = 4 THEN '99281'
			ELSE '99281'
		END
	) LIMIT 1), 15.31) as sp_valorizacion_total,

	-- Auditoria
	sp_numero_documento_responsable as documento_responsable_cpt, 
	concat(sp_apellido_paterno_responsable,' ',sp_apellido_materno_responsable,', ',sp_nombres_responsable) as nombre_responsable_cpt,
	sp_upss_codigo as upss_codigo_cpt, 
	regexp_replace(sp_upss_nombre, '\r|\n', '', 'g') as upss_descripcion_cpt,

	-- datos de procedimientos
	e.sp_fecha_atencion as fecha_procedimiento,
	sp_upss_codigo as upss_codigo_procedimiento,
	regexp_replace(sp_upss_nombre, '\r|\n', '', 'g') as upss_descripcion_procedimiento,
	sp_numero_documento_responsable as numero_documento_responsable_procedimiento,
	sp_apellido_paterno_responsable as apellido_paterno_responsable_procedimiento,
	sp_apellido_materno_responsable as apellido_materno_responsable_procedimiento,
	sp_nombres_responsable as nombres_responsable_procedimiento,
 
	-- Digitación procedimientos
	'SIGESAPOL' as digitador_cpt, e.sp_fecha_atencion::date as fecha_registro_cpt, NULL::time as hora_registro_cpt,
	''::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio
  FROM temp_emergencia_sigesapol_estancia e
  WHERE e.sp_fecha_alta_emergencia::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
    AND e.excluir_tipo2 = false
    AND NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
	  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
	  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
    )
  ORDER BY sp_fecha_alta, sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente
)

UNION ALL

(SELECT
'procedimientos en emergencia CPT-SIGESAPOL'::text as base,
	e.prioridad,
	e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
	e.sp_fecha_nacimiento_paciente, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
	e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta_emergencia,
	e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
	e.sp_codigo_profesion_responsable, e.sp_codigo_especialidad, 
	e.sp_circunstancia_alta_sigesapol_sp,
	-- e.sp_circunstancia_alta_sp, 
	e.sp_upss_codigo, 
	--e.sp_upss_descripcion,  
	regexp_replace(e.sp_upss_nombre, '\r|\n', '', 'g') as sp_upss_descripcion,
	'2' AS hospitalizacion,

	-- DiagnÃ³sticos
	e.sp_tipo_dx_01, e.sp_codigo_dx_01, e.sp_descripcion_dx_01,
	e.sp_tipo_dx_02, e.sp_codigo_dx_02, e.sp_descripcion_dx_02,
	e.sp_tipo_dx_03, e.sp_codigo_dx_03, e.sp_descripcion_dx_03,

	-- Digitación atención emergencia
	'SIGESAPOL' as digitador_prestacion,
	e.sp_fecha_atencion::date as fecha_registro_prestacion,
	NULL::time as hora_registro_prestacion,
	e.id_emergencia_sigesapol as id_atencion_emergencia,
	
	-- Procedimientos
	bdt.codigo_procedimiento as sp_codigo_procedimiento, 
	bdt.descripcion_procedimiento as sp_descripcion_procedimiento, 
	bdt.suma_cantidad_registro as sp_suma_cantidad, 
	bdt.valorizacion as sp_valorizacion_total,

	-- Auditoria
	bdt.numero_documento_responsable as documento_responsable_cpt, 
	concat(bdt.apellido_paterno_responsable,' ',bdt.apellido_materno_responsable,', ',bdt.nombres_responsable) as nombre_responsable_cpt,
	bdt.upss_servicio as upss_codigo_cpt, 
	--bdt.upss_descripcion as upss_descripcion_cpt,
	regexp_replace(bdt.upss_descripcion, '\r|\n', '', 'g') as upss_descripcion_cpt,

	-- datos de procedimientos
	bdt.fecha_atencion as fecha_procedimiento,
	bdt.upss_servicio as upss_codigo_procedimiento,
	bdt.upss_descripcion as upss_descripcion_procedimiento,
	bdt.numero_documento_responsable as numero_documento_responsable_procedimiento,
	bdt.apellido_paterno_responsable as apellido_paterno_responsable_procedimiento,
	bdt.apellido_materno_responsable as apellido_materno_responsable_procedimiento,
	bdt.nombres_responsable as nombres_responsable_procedimiento,

	-- DigitaciÃ³n procedimientos
	bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
	bdt.id_prestacion_cpt::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio
       
FROM temp_emergencia_sigesapol_estancia e -- 7,818
LEFT JOIN temp_bdt_emergencia_sigesapol bdt
	ON bdt.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente::character varying
	AND bdt.numero_documento_paciente = e.sp_numero_documento_paciente
	AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
WHERE e.sp_fecha_alta_emergencia::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
  AND codigo_procedimiento is not null
  AND e.excluir_tipo2 = false
  AND NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
	  AND bdt.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
  )

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, suma_cantidad_registro desc
)

UNION ALL

(
SELECT 
'laboratorio en emergencia CPT-SIGESAPOL'::text as base,
	e.prioridad,
	e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
	e.sp_fecha_nacimiento_paciente, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
	e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta_emergencia,
	e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
	e.sp_codigo_profesion_responsable, e.sp_codigo_especialidad, 
	e.sp_circunstancia_alta_sigesapol_sp,
	--e.sp_circunstancia_alta_sp,
	e.sp_upss_codigo, 
	--e.sp_upss_descripcion,  
	regexp_replace(e.sp_upss_nombre, '\r|\n', '', 'g') as sp_upss_descripcion,
	'2' AS hospitalizacion,

	-- DiagnÃ³sticos
	e.sp_tipo_dx_01,
	e.sp_codigo_dx_01,
	e.sp_descripcion_dx_01,
	e.sp_tipo_dx_02,
	e.sp_codigo_dx_02,
	e.sp_descripcion_dx_02,
	e.sp_tipo_dx_03,
	e.sp_codigo_dx_03,
	e.sp_descripcion_dx_03,

	-- Digitación atención emergencia
	'SIGESAPOL' as digitador_prestacion,
	e.sp_fecha_atencion::date as fecha_registro_prestacion,
	NULL::time as hora_registro_prestacion,
	e.id_emergencia_sigesapol as id_atencion_emergencia,
	
	-- Procedimientos
	laboratorio.codigo_procedimiento as sp_codigo_procedimiento,
	laboratorio.descripcion_procedimiento as sp_descripcion_procedimiento, 
	laboratorio.suma_cantidad_registro as sp_suma_cantidad, 
	laboratorio.valorizacion_total,

	-- Auditoria
	laboratorio.numero_documento_responsable as documento_responsable_cpt, 
	concat(laboratorio.apellido_paterno_responsable,' ',laboratorio.apellido_materno_responsable,', ',laboratorio.nombres_responsable) as nombre_responsable_cpt,
	laboratorio.upss_codigo as upss_codigo_cpt, 
	--laboratorio.upss_descripcion as upss_descripcion_cpt,
	regexp_replace(laboratorio.upss_descripcion, '\r|\n', '', 'g') as upss_descripcion_cpt,

	-- datos de procedimientos
	laboratorio.fecha_muestra as fecha_procedimiento,
	laboratorio.upss_codigo as upss_codigo_procedimiento,
	laboratorio.upss_descripcion as upss_descripcion_procedimiento,
	laboratorio.numero_documento_responsable as numero_documento_responsable_procedimiento,
	laboratorio.apellido_paterno_responsable as apellido_paterno_responsable_procedimiento,
	laboratorio.apellido_materno_responsable as apellido_materno_responsable_procedimiento,
	laboratorio.nombres_responsable as nombres_responsable_procedimiento,

	-- DigitaciÃ³n procedimientos
	laboratorio.digitador as digitador_cpt, laboratorio.fecha_registro as fecha_registro_cpt, laboratorio.hora_registro as hora_registro_cpt,
	''::text as id_prestacion_cpt,
	laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio
       
FROM temp_emergencia_sigesapol_estancia e -- 7,818
LEFT JOIN temp_laboratorio_emergencia_sigesapol laboratorio
	ON laboratorio.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente
	AND laboratorio.numero_documento_paciente = e.sp_numero_documento_paciente
	AND laboratorio.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
WHERE e.sp_fecha_alta_emergencia::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
  AND laboratorio.codigo_procedimiento is not null
  AND e.excluir_tipo2 = false
  AND NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
	  AND laboratorio.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
  )

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, sp_suma_cantidad desc -- 17,223

)
