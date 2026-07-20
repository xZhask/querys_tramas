-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 11_ARMADO_hospitalizacion.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================
-- ============================================================================
-- 11_ARMADO_hospitalizacion.sql
-- Copia del armado original '08_HOSPITALIZACION_1_2_3_TODO.sql' con UNA sola correcciÃ³n:
-- UNION -> UNION ALL (las ramas tienen literales 'base' distintos, el
-- duplicado entre ramas es imposible y el UNION solo costaba deduplicaciÃ³n
-- innecesaria sobre ~50 columnas). La estructura y columnas NO cambian.
-- Las tablas temp_* que lee ya vienen CONSOLIDADAS por el archivo 08
-- (canÃ³nico + complemento deduplicado); las filas de origen SIGESAPOL se
-- identifican por digitador = 'SIGESAPOL'.
-- ============================================================================
-- HOSPITALIZACION - SOLO
-- ======================

(SELECT 
'estancia hospitalaria'::text as base,	
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
	regexp_replace(e.sp_upss_descripcion, '\r|\n|\t', '', 'g') as sp_upss_descripcion,
	'1' AS hospitalizacion,
-- DiagnÃ³sticos
e.sp_tipo_dx_01,
e.sp_codigo_dx_01,
--e.sp_descripcion_dx_01,
regexp_replace(e.sp_descripcion_dx_01, '\r|\n|\t', '', 'g') as sp_descripcion_dx_01,
e.sp_tipo_dx_02,
e.sp_codigo_dx_02,
--e.sp_descripcion_dx_02,
regexp_replace(e.sp_descripcion_dx_02, '\r|\n|\t', '', 'g') as sp_descripcion_dx_02,
e.sp_tipo_dx_03,
e.sp_codigo_dx_03,
--e.sp_descripcion_dx_03,
regexp_replace(e.sp_descripcion_dx_03, '\r|\n|\t', '', 'g') as sp_descripcion_dx_03,

e.digitador as digitador_prestacion,
e.fecha_registro as fecha_registro_prestacion,
e.hora_registro as hora_registro_prestacion,
e.id_prestacion_cpt as id_prestacion_cpt,

-- Procedimientos
e.sp_codigo_procedimiento, 
e.sp_descripcion_procedimiento, 
e.sp_dias_estancia as sp_suma_cantidad,
e.sp_valorizacion_total,

-- Auditoria
e.sp_numero_documento_responsable as documento_responsable_cpt, 
concat(e.sp_apellido_paterno_responsable,' ',e.sp_apellido_materno_responsable,', ',e.sp_nombres_responsable) as nombre_responsable_cpt,
e.sp_upss_codigo as upss_codigo_cpt, e.sp_upss_descripcion as upss_descripcion_cpt,
	
e.digitador as digitador_cpt, 
e.sp_fecha_atencion as fecha_atencion_procedimiento,
e.fecha_registro as fecha_registro_cpt, e.hora_registro as hora_registro_cpt,
e.id_prestacion_cpt::text as id_prestacion_cpt,
''::text as id_prestacion_laboratorio

FROM temp_hospitalizacion_local e  -- 981
ORDER BY e.sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente
)

UNION ALL

(
SELECT 
'procedimientos en hospitalizaciÃ³n'::text as base,
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
       '1' AS hospitalizacion,
-- DiagnÃ³sticos
e.sp_tipo_dx_01,
e.sp_codigo_dx_01,
--e.sp_descripcion_dx_01,
regexp_replace(e.sp_descripcion_dx_01, '\r|\n|\t', '', 'g') as sp_descripcion_dx_01,
e.sp_tipo_dx_02,
e.sp_codigo_dx_02,
--e.sp_descripcion_dx_02,
regexp_replace(e.sp_descripcion_dx_02, '\r|\n|\t', '', 'g') as sp_descripcion_dx_02,
e.sp_tipo_dx_03,
e.sp_codigo_dx_03,
--e.sp_descripcion_dx_03,
regexp_replace(e.sp_descripcion_dx_03, '\r|\n|\t', '', 'g') as sp_descripcion_dx_03,

e.digitador as digitador_prestacion,
e.fecha_registro as fecha_registro_prestacion,
e.hora_registro as hora_registro_prestacion,
e.id_prestacion_cpt as id_prestacion_cpt,

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

--e.upss_codigo, e.upss_descripcion, '' as prioridad
bdt.digitador as digitador_cpt, 
bdt.fecha_atencion as fecha_atencion_procedimiento,
bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
bdt.id_prestacion_cpt::text as id_prestacion_cpt,
''::text as id_prestacion_laboratorio
	       
FROM temp_hospitalizacion_local e -- 66,569
	LEFT JOIN temp_bdt_hospitalizacion_local bdt
	ON bdt.tipo_documento_paciente = e.sp_tipo_documento_paciente
	AND bdt.numero_documento_paciente = e.sp_numero_documento_paciente
	AND bdt.fecha_atencion between e.sp_fecha_atencion AND e.sp_fecha_alta
	WHERE bdt.codigo_procedimiento is not null
	AND bdt.codigo_procedimiento not in ('99231', '99231.15', '99262', '99295')
	
ORDER BY sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, sp_suma_cantidad desc -- 67,674 -- 16-06-2023 -- 67706
)

UNION ALL

(
SELECT 
'laboratorio en hospitalizaciÃ³n'::text as base,	
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
	'1' AS hospitalizacion,
-- DiagnÃ³sticos
e.sp_tipo_dx_01,
e.sp_codigo_dx_01,
--e.sp_descripcion_dx_01,
regexp_replace(e.sp_descripcion_dx_01, '\r|\n|\t', '', 'g') as sp_descripcion_dx_01,
e.sp_tipo_dx_02,
e.sp_codigo_dx_02,
--e.sp_descripcion_dx_02,
regexp_replace(e.sp_descripcion_dx_02, '\r|\n|\t', '', 'g') as sp_descripcion_dx_02,
e.sp_tipo_dx_03,
e.sp_codigo_dx_03,
--e.sp_descripcion_dx_03,
regexp_replace(e.sp_descripcion_dx_03, '\r|\n|\t', '', 'g') as sp_descripcion_dx_03,

e.digitador as digitador_prestacion,
e.fecha_registro as fecha_registro_prestacion,
e.hora_registro as hora_registro_prestacion,
e.id_prestacion_cpt as id_prestacion_cpt,
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

laboratorio.digitador as digitador_cpt,
laboratorio.fecha_muestra as fecha_atencion_procedimiento,
laboratorio.fecha_registro as fecha_registro_cpt, laboratorio.hora_registro as hora_registro_cpt,
''::text as id_prestacion_cpt,
laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio

	       
	  FROM temp_hospitalizacion_local e -- 974
	  LEFT JOIN temp_laboratorio_hospitalizacion_local laboratorio
		ON laboratorio.tipo_documento_paciente = e.sp_tipo_documento_paciente
		AND laboratorio.numero_documento_paciente = e.sp_numero_documento_paciente
		AND laboratorio.fecha_atencion between e.sp_fecha_atencion AND e.sp_fecha_alta

	WHERE laboratorio.codigo_procedimiento is not null
	
	  ORDER BY sp_fecha_atencion, e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, sp_suma_cantidad desc
)

UNION ALL

(
SELECT 
'procedimientos en hospitalización RECLASIFICADOS'::text as base,
e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
       e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
       e.sp_fecha_nacimiento, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
       e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta, 
       e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
       e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
       e.sp_profesion_responsable, e.sp_especialidad_responsable, 
       e.sp_circunstancia_alta, 
       e.sp_upss_codigo, 
       regexp_replace(e.sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,
       '1' AS hospitalizacion,
-- Diagnósticos
e.sp_tipo_dx_01,
e.sp_codigo_dx_01,
regexp_replace(e.sp_descripcion_dx_01, '\r|\n|\t', '', 'g') as sp_descripcion_dx_01,
e.sp_tipo_dx_02,
e.sp_codigo_dx_02,
regexp_replace(e.sp_descripcion_dx_02, '\r|\n|\t', '', 'g') as sp_descripcion_dx_02,
e.sp_tipo_dx_03,
e.sp_codigo_dx_03,
regexp_replace(e.sp_descripcion_dx_03, '\r|\n|\t', '', 'g') as sp_descripcion_dx_03,

e.digitador as digitador_prestacion,
e.fecha_registro as fecha_registro_prestacion,
e.hora_registro as hora_registro_prestacion,
e.id_prestacion_cpt as id_prestacion_cpt,

-- Procedimientos
bdt.codigo_procedimiento as sp_codigo_procedimiento, 
bdt.descripcion_procedimiento as sp_descripcion_procedimiento, 
bdt.suma_cantidad_registro as sp_suma_cantidad, 
bdt.valorizacion as sp_valorizacion_total,

-- Auditoria
bdt.numero_documento_responsable as documento_responsable_cpt, 
concat(bdt.apellido_paterno_responsable,' ',bdt.apellido_materno_responsable,', ',bdt.nombres_responsable) as nombre_responsable_cpt,
bdt.upss_servicio as upss_codigo_cpt, 
regexp_replace(bdt.upss_descripcion, '\r|\n', '', 'g') as upss_descripcion_cpt,

bdt.digitador as digitador_cpt, 
bdt.fecha_atencion as fecha_atencion_procedimiento,
bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt,
bdt.id_prestacion_cpt::text as id_prestacion_cpt,
''::text as id_prestacion_laboratorio
       
FROM temp_hospitalizacion_local e
	LEFT JOIN temp_bdt_emergencia_sigesapol bdt
	ON bdt.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente::character varying
	AND bdt.numero_documento_paciente = e.sp_numero_documento_paciente
	AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE bdt.codigo_procedimiento is not null
	AND e.origen_reclasificacion IS NOT NULL
)

UNION ALL

(
SELECT 
'laboratorio en hospitalización RECLASIFICADOS'::text as base,	
	e.sp_tipo_documento_paciente, e.sp_numero_documento_paciente, 
	e.sp_apellido_paterno_paciente, e.sp_apellido_materno_paciente, e.sp_nombres_paciente, 
	e.sp_fecha_nacimiento, e.sp_genero_paciente, e.sp_condicion_asegurado, e.sp_tipo_atencion, 
	e.sp_codigo_ipress, e.sp_nombre_ipress, e.sp_fecha_atencion, e.sp_fecha_alta, 
	e.sp_tipo_documento_responsable, e.sp_numero_documento_responsable, 
	e.sp_apellido_paterno_responsable, e.sp_apellido_materno_responsable, e.sp_nombres_responsable, 
	e.sp_profesion_responsable, e.sp_especialidad_responsable, 
	e.sp_circunstancia_alta, 
	e.sp_upss_codigo, 
	regexp_replace(e.sp_upss_descripcion, '\r|\n', '', 'g') as sp_upss_descripcion,
	'1' AS hospitalizacion,
-- Diagnósticos
e.sp_tipo_dx_01,
e.sp_codigo_dx_01,
regexp_replace(e.sp_descripcion_dx_01, '\r|\n|\t', '', 'g') as sp_descripcion_dx_01,
e.sp_tipo_dx_02,
e.sp_codigo_dx_02,
regexp_replace(e.sp_descripcion_dx_02, '\r|\n|\t', '', 'g') as sp_descripcion_dx_02,
e.sp_tipo_dx_03,
e.sp_codigo_dx_03,
regexp_replace(e.sp_descripcion_dx_03, '\r|\n|\t', '', 'g') as sp_descripcion_dx_03,

e.digitador as digitador_prestacion,
e.fecha_registro as fecha_registro_prestacion,
e.hora_registro as hora_registro_prestacion,
e.id_prestacion_cpt as id_prestacion_cpt,

laboratorio.codigo_procedimiento as sp_codigo_procedimiento,
laboratorio.descripcion_procedimiento as sp_descripcion_procedimiento, 
laboratorio.suma_cantidad_registro as sp_suma_cantidad, 
laboratorio.valorizacion_total,

-- Auditoria
laboratorio.numero_documento_responsable as documento_responsable_cpt, 
concat(laboratorio.apellido_paterno_responsable,' ',laboratorio.apellido_materno_responsable,', ',laboratorio.nombres_responsable) as nombre_responsable_cpt,
laboratorio.upss_codigo as upss_codigo_cpt, 
regexp_replace(laboratorio.upss_descripcion, '\r|\n', '', 'g') as upss_descripcion_cpt,

laboratorio.digitador as digitador_cpt,
laboratorio.fecha_muestra as fecha_atencion_procedimiento,
laboratorio.fecha_registro as fecha_registro_cpt, laboratorio.hora_registro as hora_registro_cpt,
''::text as id_prestacion_cpt,
laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio
	       
	  FROM temp_hospitalizacion_local e
	  LEFT JOIN temp_laboratorio_emergencia_sigesapol laboratorio
		ON laboratorio.tipo_documento_paciente::character varying = e.sp_tipo_documento_paciente::character varying
		AND laboratorio.numero_documento_paciente = e.sp_numero_documento_paciente
		AND laboratorio.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date

	WHERE laboratorio.codigo_procedimiento is not null
	AND e.origen_reclasificacion IS NOT NULL
)
