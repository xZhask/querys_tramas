-- EMERGENCIA
-- ======================

/*
(SELECT 
'estancia en emergencia'::text as base,
	prioridad, 
	sp_tipo_documento_paciente, sp_numero_documento_paciente, 
	sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente, 
	sp_fecha_nacimiento, sp_genero_paciente, sp_condicion_asegurado, sp_tipo_atencion, 
	sp_codigo_ipress, sp_nombre_ipress, sp_fecha_atencion, sp_fecha_alta, 
	sp_tipo_documento_responsable, sp_numero_documento_responsable, 
	sp_apellido_paterno_responsable, sp_apellido_materno_responsable, sp_nombres_responsable, 
	sp_profesion_responsable, sp_especialidad_responsable, 
	sp_circunstancia_alta, 
	sp_upss_codigo, 
	--sp_upss_descripcion,
	regexp_replace(sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,
	'1' AS hospitalizacion,

	-- Diagnósticos 
	sp_tipo_dx_01, sp_codigo_dx_01, sp_descripcion_dx_01, 
	sp_tipo_dx_02, sp_codigo_dx_02, sp_descripcion_dx_02,
	sp_tipo_dx_03, sp_codigo_dx_03, sp_descripcion_dx_03,

	-- Digitación atención emergencia
	digitador_egreso as digitador_prestacion, 
	fecha_registro_ingreso as fecha_registro_prestacion, 
	hora_registro_ingreso as hora_registro_prestacion,
	id_atencion_emergencia,

	-- Procedimientos
	codigo_cpms as sp_codigo_procedimiento, 
	descripcion_cpms as sp_descripcion_procedimiento, 
	cantidad_cpms as sp_suma_cantidad, 
	valorizacion_cpms as sp_valorizacion_total,

	-- Auditoria
	sp_numero_documento_responsable as documento_responsable_cpt, 
	concat(sp_apellido_paterno_responsable,' ',sp_apellido_materno_responsable,', ',sp_nombres_responsable) as nombre_responsable_cpt,
	sp_upss_codigo as upss_codigo_cpt, 
	--sp_upss_descripcion as upss_descripcion_cpt,
	regexp_replace(sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,

	-- datos de procedimientos
	sp_fecha_atencion as fecha_procedimiento,
	sp_upss_codigo as upss_codigo_procedimiento,
	sp_upss_descripcion as upss_descripcion_procedimiento,
	sp_numero_documento_responsable as numero_documento_responsable_procedimiento,
	sp_apellido_paterno_responsable as apellido_paterno_responsable_procedimiento,
	sp_apellido_materno_responsable as apellido_materno_responsable_procedimiento,
	sp_nombres_responsable as nombres_responsable_procedimiento,
 
	-- Digitación procedimientos
	''::text as digitador_cpt, fecha_registro_ingreso as fecha_registro_cpt, hora_registro_ingreso as hora_registro_cpt,
	''::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio
	-- secuencia, 
  FROM temp_emergencia_local
  ORDER BY sp_fecha_alta, sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente

)

UNION

(SELECT 
'procedimientos en emergencia'::text as base,
	'' as prioridad,
	e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
	e.sp_fecha_nacimiento, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
	e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta,
	e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
	e.sp_profesion_responsable, e.sp_especialidad_responsable, 
	e.sp_circunstancia_alta, 
	e.sp_upss_codigo, 
	--e.sp_upss_descripcion,  
	regexp_replace(e.sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,
	'2' AS hospitalizacion,

	-- Diagnósticos
	e.sp_tipo_dx_01, e.sp_codigo_dx_01, e.sp_descripcion_dx_01,
	e.sp_tipo_dx_02, e.sp_codigo_dx_02, e.sp_descripcion_dx_02,
	e.sp_tipo_dx_03, e.sp_codigo_dx_03, e.sp_descripcion_dx_03,

	-- Digitación atención emergencia
	e.digitador_egreso as digitador_prestacion,
	e.fecha_registro_ingreso as fecha_registro_prestacion,
	e.hora_registro_ingreso as hora_registro_prestacion,
	e.id_atencion_emergencia as id_atencion_emergencia,
	
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

	-- Digitación procedimientos
	bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
	bdt.id_prestacion_cpt::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio
       
FROM temp_emergencia_local e -- 7,818
LEFT JOIN temp_bdt_emergencia_local bdt
	ON bdt.tipo_documento_paciente = e.sp_tipo_documento_paciente
	AND bdt.numero_documento_paciente = e.sp_numero_documento_paciente
	AND bdt.fecha_atencion between e.sp_fecha_atencion AND e.sp_fecha_alta
WHERE codigo_procedimiento is not null

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, suma_cantidad_registro desc) -- 17,223

UNION

(
SELECT 
'laboratorio en emergencia'::text as base,
	'' as prioridad,
	e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
	e.sp_fecha_nacimiento, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
	e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta,
	e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
	e.sp_profesion_responsable, e.sp_especialidad_responsable, 
	e.sp_circunstancia_alta, 
	e.sp_upss_codigo, 
	--e.sp_upss_descripcion,  
	regexp_replace(e.sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,
	'2' AS hospitalizacion,

	-- Diagnósticos
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
	e.digitador_egreso as digitador_prestacion,
	e.fecha_registro_ingreso as fecha_registro_prestacion,
	e.hora_registro_ingreso as hora_registro_prestacion,
	e.id_atencion_emergencia as id_atencion_emergencia,
	
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

	-- Digitación procedimientos
	laboratorio.digitador as digitador_cpt, laboratorio.fecha_registro as fecha_registro_cpt, laboratorio.hora_registro as hora_registro_cpt,
	''::text as id_prestacion_cpt,
	laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio
       
FROM temp_emergencia_local e -- 7,818
LEFT JOIN temp_laboratorio_emergencia_local laboratorio
	ON laboratorio.tipo_documento_paciente = e.sp_tipo_documento_paciente
	AND laboratorio.numero_documento_paciente = e.sp_numero_documento_paciente
	AND laboratorio.fecha_atencion between e.sp_fecha_atencion AND e.sp_fecha_alta
WHERE laboratorio.codigo_procedimiento is not null

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, sp_suma_cantidad desc -- 17,223
)
*/
/* CON SIGESAPOL */

--UNION

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

	-- Diagnósticos
	e.sp_tipo_dx_01, e.sp_codigo_dx_01, e.sp_descripcion_dx_01,
	e.sp_tipo_dx_02, e.sp_codigo_dx_02, e.sp_descripcion_dx_02,
	e.sp_tipo_dx_03, e.sp_codigo_dx_03, e.sp_descripcion_dx_03,

	-- Digitación atención emergencia
	--e.digitador_cpt as digitador_prestacion,
	--e.fecha_registro_cpt as fecha_registro_prestacion,
	--e.hora_registro_cpt as hora_registro_prestacion,
	e.id_emergencia_sigesapol as id_emergencia_sigesapol,
	
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

	-- Digitación procedimientos
	bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
	bdt.id_prestacion_cpt::text as id_prestacion_cpt,
	''::text as id_prestacion_laboratorio
       
FROM temp_emergencia_sigesapol_estancia e -- 7,818
LEFT JOIN temp_bdt_emergencia_sigesapol bdt
	ON bdt.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente::character varying
	AND bdt.numero_documento_paciente = e.sp_numero_documento_paciente
	AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
WHERE codigo_procedimiento is not null

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, suma_cantidad_registro desc
)

UNION

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

	-- Diagnósticos
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
	--e.digitador_egreso as digitador_prestacion,
	--e.fecha_registro_ingreso as fecha_registro_prestacion,
	--e.hora_registro_ingreso as hora_registro_prestacion,
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

	-- Digitación procedimientos
	laboratorio.digitador as digitador_cpt, laboratorio.fecha_registro as fecha_registro_cpt, laboratorio.hora_registro as hora_registro_cpt,
	''::text as id_prestacion_cpt,
	laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio
       
FROM temp_emergencia_sigesapol_estancia e -- 7,818
LEFT JOIN temp_laboratorio_emergencia_sigesapol laboratorio
	ON laboratorio.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente
	AND laboratorio.numero_documento_paciente = e.sp_numero_documento_paciente
	AND laboratorio.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
WHERE laboratorio.codigo_procedimiento is not null

ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, sp_suma_cantidad desc -- 17,223

)
