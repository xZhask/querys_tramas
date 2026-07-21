-- ============================================================================
-- 09_ARMADO_consulta_externa.sql
-- Copia del armado original '06_CONSULTA_EXTERNA_1_2_3_TODO.sql' con UNA sola correcciÃ³n:
-- UNION -> UNION ALL (las ramas tienen literales 'base' distintos, el
-- duplicado entre ramas es imposible y el UNION solo costaba deduplicaciÃ³n
-- innecesaria sobre ~50 columnas). La estructura y columnas NO cambian.
-- Las tablas temp_* que lee ya vienen CONSOLIDADAS por el archivo 08
-- (canÃ³nico + complemento deduplicado); las filas de origen SIGESAPOL se
-- identifican por digitador = 'SIGESAPOL'.
-- ============================================================================
-- CONSULTA EXTERNA
-- ==================
(
SELECT 
'procedimientos en consulta externa'::text as base,

	bdt.tipo_documento_paciente as sp_tipo_documento_paciente,
	bdt.numero_documento_paciente as sp_numero_documento_paciente,
	bdt.apellido_paterno_paciente as sp_apellido_paterno_paciente,
	bdt.apellido_materno_paciente as sp_apellido_materno_paciente,
	bdt.nombres_paciente as sp_nombres_paciente,
	bdt.fecha_nacimiento as sp_fecha_nacimiento,
	bdt.genero_paciente as sp_genero_paciente,
	bdt.condicion_asegurado as sp_condicion_asegurado,
	bdt.tipo_atencion as sp_tipo_atencion,
	bdt.codigo_ipress as sp_codigo_ipress,
	bdt.nombre_ipress as sp_nombre_ipress,
	bdt.fecha_atencion as sp_fecha_atencion,
--	''::text as fecha_muestra,
	bdt.fecha_alta as sp_fecha_alta,
	bdt.tipo_documento_responsable as sp_tipo_documento_responsable,
	bdt.numero_documento_responsable as sp_numero_documento_responsable,
	bdt.apellido_paterno_responsable as sp_apellido_paterno_responsable,
	bdt.apellido_materno_responsable as sp_apellido_materno_responsable,
	bdt.nombres_responsable as sp_nombres_responsable,
	bdt.profesion_responsable as sp_profesion_responsable,
	bdt.especialidad_responsable as sp_especialidad_responsable,
	bdt.circunstancia_alta::text as sp_circunstancia_alta,
	bdt.upss_servicio as sp_upss_servicio,
	bdt.upss_descripcion as sp_upss_descripcion,
	'2' AS sp_hospitalizacion,

	-- DiagnÃ³sticos
	bdt.tipo_diagnostico as sp_tipo_diagnostico,
	bdt.codigo_diagnostico as sp_codigo_diagnostico,
	bdt.descripcion_diagnostico as sp_descripcion_diagnostico,
	
	-- Procedimientos
	bdt.codigo_procedimiento as sp_codigo_procedimiento, 
	bdt.descripcion_procedimiento as sp_descripcion_procedimiento, 
	bdt.suma_cantidad_registro as sp_suma_cantidad, 
	bdt.valorizacion as sp_valorizacion_total,
  
	-- DigitaciÃ³n procedimientos
	bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
	bdt.id_prestacion_cpt::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio

FROM temp_bdt_consulta_local bdt --FROM sp_procedimientos_segun_tipo_atencion('20230501', '20230531', 1) bdt; --15234
WHERE bdt.fecha_atencion::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
ORDER BY sp_fecha_atencion desc, sp_suma_cantidad desc
)
UNION ALL
(
SELECT 
'laboratorio en consulta externa'::text as base,
	laboratorio.tipo_documento_paciente as sp_tipo_documento_paciente,
	laboratorio.numero_documento_paciente as sp_numero_documento_paciente,
	laboratorio.apellido_paterno_paciente as sp_apellido_paterno_paciente,
	laboratorio.apellido_materno_paciente as sp_apellido_materno_paciente,
	laboratorio.nombres_paciente as sp_nombres_paciente,
	laboratorio.fecha_nacimiento as sp_fecha_nacimiento,
	laboratorio.genero_paciente as sp_genero_paciente,
	laboratorio.condicion_asegurado as sp_condicion_asegurado,
	laboratorio.tipo_atencion::integer as sp_tipo_atencion,
	laboratorio.codigo_ipress as sp_codigo_ipress,
	laboratorio.nombre_ipress as sp_nombre_ipress,
--	laboratorio.fecha_atencion as sp_fecha_atencion,
	-- laboratorio.fecha_muestra::text  as sp_fecha_atencion, 
	laboratorio.fecha_muestra as sp_fecha_atencion, 
	laboratorio.fecha_egreso as sp_fecha_alta,
	laboratorio.tipo_documento_responsable as sp_tipo_documento_responsable,
	laboratorio.numero_documento_responsable as sp_numero_documento_responsable,
	laboratorio.apellido_paterno_responsable as sp_apellido_paterno_responsable,
	laboratorio.apellido_materno_responsable as sp_apellido_materno_responsable,
	laboratorio.nombres_responsable as sp_nombres_responsable,
	laboratorio.profesion_responsable as sp_profesion_responsable,
	laboratorio.especialidad_responsable as sp_especialidad_responsable,
	laboratorio.circunstancia_alta::text as sp_circunstancia_alta,
	laboratorio.upss_codigo as sp_upss_servicio,
	laboratorio.upss_descripcion as sp_upss_descripcion,
	'2' AS sp_hospitalizacion,
	
	-- DiagnÃ³sticos
	laboratorio.tipo_diagnostico as sp_tipo_diagnostico,
	laboratorio.codigo_diagnostico as sp_codigo_diagnostico,
	laboratorio.descripcion_diagnostico as sp_descripcion_diagnostico,
	
	-- Procedimientos
	laboratorio.codigo_procedimiento as sp_codigo_procedimiento, 
	laboratorio.descripcion_procedimiento as sp_descripcion_procedimiento, 
	laboratorio.suma_cantidad_registro as sp_suma_cantidad, 
	laboratorio.valorizacion_total as sp_valorizacion_total,

	-- DigitaciÃ³n procedimientos
	laboratorio.digitador as digitador_laboratorio, 
	laboratorio.fecha_registro as fecha_registro_laboratorio, 
	laboratorio.hora_registro as hora_registro_laboratorio,
	''::text as id_prestacion_cpt,
	laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio

FROM temp_laboratorio_consulta_local laboratorio
WHERE laboratorio.fecha_muestra::date BETWEEN (SELECT p_ini FROM cfg_periodo) AND (SELECT p_fin FROM cfg_periodo)
ORDER BY sp_fecha_atencion desc, sp_suma_cantidad desc
)