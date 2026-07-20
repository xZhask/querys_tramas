-- ==============================================================================
-- 12_EXPORTAR_TRAMAS_CONSOLA.sql
-- ==============================================================================
-- Este script permite extraer las 3 tramas finales desde la consola (PgAdmin)
-- saneando los saltos de línea (\r y \n) embebidos en los campos de texto libre
-- (diagnósticos, descripciones, nombres) para que la grilla pueda copiarse o 
-- exportarse a Excel sin que se partan las filas (emulando la limpieza nativa 
-- que realiza el aplicativo Python).
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- TRAMA 1: CONSULTA EXTERNA
-- ------------------------------------------------------------------------------
SELECT 
    base,
    sp_tipo_documento_paciente,
    sp_numero_documento_paciente,
    regexp_replace(sp_apellido_paterno_paciente, '\r|\n', ' ', 'g') as sp_apellido_paterno_paciente,
    regexp_replace(sp_apellido_materno_paciente, '\r|\n', ' ', 'g') as sp_apellido_materno_paciente,
    regexp_replace(sp_nombres_paciente, '\r|\n', ' ', 'g') as sp_nombres_paciente,
    sp_fecha_nacimiento,
    sp_genero_paciente,
    sp_condicion_asegurado,
    sp_tipo_atencion,
    sp_codigo_ipress,
    regexp_replace(sp_nombre_ipress, '\r|\n', ' ', 'g') as sp_nombre_ipress,
    sp_fecha_atencion,
    sp_fecha_alta,
    sp_tipo_documento_responsable,
    sp_numero_documento_responsable,
    regexp_replace(sp_apellido_paterno_responsable, '\r|\n', ' ', 'g') as sp_apellido_paterno_responsable,
    regexp_replace(sp_apellido_materno_responsable, '\r|\n', ' ', 'g') as sp_apellido_materno_responsable,
    regexp_replace(sp_nombres_responsable, '\r|\n', ' ', 'g') as sp_nombres_responsable,
    sp_profesion_responsable,
    sp_especialidad_responsable,
    sp_circunstancia_alta,
    sp_upss_servicio,
    regexp_replace(sp_upss_descripcion, '\r|\n', ' ', 'g') as sp_upss_descripcion,
    sp_hospitalizacion,
    sp_tipo_diagnostico,
    sp_codigo_diagnostico,
    regexp_replace(sp_descripcion_diagnostico, '\r|\n', ' ', 'g') as sp_descripcion_diagnostico,
    sp_codigo_procedimiento,
    regexp_replace(sp_descripcion_procedimiento, '\r|\n', ' ', 'g') as sp_descripcion_procedimiento,
    sp_suma_cantidad,
    sp_valorizacion_total,
    digitador_cpt,
    fecha_registro_cpt,
    hora_registro_cpt,
    id_prestacion_cpt,
    id_prestacion_laboratorio
FROM (
    -- Replicando lógica de 09_ARMADO_consulta_externa para capturar resultados
    SELECT 'procedimientos en consulta externa'::text as base, bdt.tipo_documento_paciente as sp_tipo_documento_paciente, bdt.numero_documento_paciente as sp_numero_documento_paciente, bdt.apellido_paterno_paciente as sp_apellido_paterno_paciente, bdt.apellido_materno_paciente as sp_apellido_materno_paciente, bdt.nombres_paciente as sp_nombres_paciente, bdt.fecha_nacimiento as sp_fecha_nacimiento, bdt.genero_paciente as sp_genero_paciente, bdt.condicion_asegurado as sp_condicion_asegurado, bdt.tipo_atencion as sp_tipo_atencion, bdt.codigo_ipress as sp_codigo_ipress, bdt.nombre_ipress as sp_nombre_ipress, bdt.fecha_atencion as sp_fecha_atencion, bdt.fecha_alta as sp_fecha_alta, bdt.tipo_documento_responsable as sp_tipo_documento_responsable, bdt.numero_documento_responsable as sp_numero_documento_responsable, bdt.apellido_paterno_responsable as sp_apellido_paterno_responsable, bdt.apellido_materno_responsable as sp_apellido_materno_responsable, bdt.nombres_responsable as sp_nombres_responsable, bdt.profesion_responsable as sp_profesion_responsable, bdt.especialidad_responsable as sp_especialidad_responsable, bdt.circunstancia_alta::text as sp_circunstancia_alta, bdt.upss_servicio as sp_upss_servicio, bdt.upss_descripcion as sp_upss_descripcion, '2' AS sp_hospitalizacion, bdt.tipo_diagnostico as sp_tipo_diagnostico, bdt.codigo_diagnostico as sp_codigo_diagnostico, bdt.descripcion_diagnostico as sp_descripcion_diagnostico, bdt.codigo_procedimiento as sp_codigo_procedimiento, bdt.descripcion_procedimiento as sp_descripcion_procedimiento, bdt.suma_cantidad_registro as sp_suma_cantidad, bdt.valorizacion as sp_valorizacion_total, bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt, bdt.id_prestacion_cpt::text as id_prestacion_cpt, ''::text as id_prestacion_laboratorio FROM temp_bdt_consulta_local bdt
    UNION ALL
    SELECT 'laboratorio en consulta externa'::text as base, laboratorio.tipo_documento_paciente as sp_tipo_documento_paciente, laboratorio.numero_documento_paciente as sp_numero_documento_paciente, laboratorio.apellido_paterno_paciente as sp_apellido_paterno_paciente, laboratorio.apellido_materno_paciente as sp_apellido_materno_paciente, laboratorio.nombres_paciente as sp_nombres_paciente, laboratorio.fecha_nacimiento as sp_fecha_nacimiento, laboratorio.genero_paciente as sp_genero_paciente, laboratorio.condicion_asegurado as sp_condicion_asegurado, laboratorio.tipo_atencion::integer as sp_tipo_atencion, laboratorio.codigo_ipress as sp_codigo_ipress, laboratorio.nombre_ipress as sp_nombre_ipress, laboratorio.fecha_muestra as sp_fecha_atencion, laboratorio.fecha_egreso as sp_fecha_alta, laboratorio.tipo_documento_responsable as sp_tipo_documento_responsable, laboratorio.numero_documento_responsable as sp_numero_documento_responsable, laboratorio.apellido_paterno_responsable as sp_apellido_paterno_responsable, laboratorio.apellido_materno_responsable as sp_apellido_materno_responsable, laboratorio.nombres_responsable as sp_nombres_responsable, laboratorio.profesion_responsable as sp_profesion_responsable, laboratorio.especialidad_responsable as sp_especialidad_responsable, laboratorio.circunstancia_alta::text as sp_circunstancia_alta, laboratorio.upss_codigo as sp_upss_servicio, laboratorio.upss_descripcion as sp_upss_descripcion, '2' AS sp_hospitalizacion, laboratorio.tipo_diagnostico as sp_tipo_diagnostico, laboratorio.codigo_diagnostico as sp_codigo_diagnostico, laboratorio.descripcion_diagnostico as sp_descripcion_diagnostico, laboratorio.codigo_procedimiento as sp_codigo_procedimiento, laboratorio.descripcion_procedimiento as sp_descripcion_procedimiento, laboratorio.suma_cantidad_registro as sp_suma_cantidad, laboratorio.valorizacion_total as sp_valorizacion_total, laboratorio.digitador as digitador_laboratorio, laboratorio.fecha_registro as fecha_registro_laboratorio, laboratorio.hora_registro as hora_registro_laboratorio, ''::text as id_prestacion_cpt, laboratorio.id_prestacion_laboratorio::text as id_prestacion_laboratorio FROM temp_laboratorio_consulta_local laboratorio
) consulta_raw;

-- ------------------------------------------------------------------------------
-- TRAMA 2: EMERGENCIA
-- ------------------------------------------------------------------------------
SELECT 
    base,
    sp_tipo_documento_paciente,
    sp_numero_documento_paciente,
    regexp_replace(sp_apellido_paterno_paciente, '\r|\n', ' ', 'g') as sp_apellido_paterno_paciente,
    regexp_replace(sp_apellido_materno_paciente, '\r|\n', ' ', 'g') as sp_apellido_materno_paciente,
    regexp_replace(sp_nombres_paciente, '\r|\n', ' ', 'g') as sp_nombres_paciente,
    sp_fecha_nacimiento,
    sp_genero_paciente,
    sp_condicion_asegurado,
    sp_tipo_atencion,
    sp_codigo_ipress,
    regexp_replace(sp_nombre_ipress, '\r|\n', ' ', 'g') as sp_nombre_ipress,
    sp_fecha_atencion,
    sp_fecha_alta,
    sp_tipo_documento_responsable,
    sp_numero_documento_responsable,
    regexp_replace(sp_apellido_paterno_responsable, '\r|\n', ' ', 'g') as sp_apellido_paterno_responsable,
    regexp_replace(sp_apellido_materno_responsable, '\r|\n', ' ', 'g') as sp_apellido_materno_responsable,
    regexp_replace(sp_nombres_responsable, '\r|\n', ' ', 'g') as sp_nombres_responsable,
    sp_profesion_responsable,
    sp_especialidad_responsable,
    sp_circunstancia_alta,
    sp_upss_servicio,
    regexp_replace(sp_upss_descripcion, '\r|\n', ' ', 'g') as sp_upss_descripcion,
    sp_hospitalizacion,
    sp_tipo_diagnostico,
    sp_codigo_diagnostico,
    regexp_replace(sp_descripcion_diagnostico, '\r|\n', ' ', 'g') as sp_descripcion_diagnostico,
    sp_codigo_procedimiento,
    regexp_replace(sp_descripcion_procedimiento, '\r|\n', ' ', 'g') as sp_descripcion_procedimiento,
    sp_suma_cantidad,
    sp_valorizacion_total,
    digitador_cpt,
    fecha_registro_cpt,
    hora_registro_cpt,
    id_prestacion_cpt,
    id_prestacion_laboratorio,
    id_atencion_emergencia
FROM (
    -- Replicando 10_ARMADO_emergencia.sql
    SELECT 'estancia en emergencia'::text as base, bdt.tipo_documento_paciente as sp_tipo_documento_paciente, bdt.numero_documento_paciente as sp_numero_documento_paciente, bdt.apellido_paterno_paciente as sp_apellido_paterno_paciente, bdt.apellido_materno_paciente as sp_apellido_materno_paciente, bdt.nombres_paciente as sp_nombres_paciente, bdt.fecha_nacimiento as sp_fecha_nacimiento, bdt.genero_paciente as sp_genero_paciente, bdt.condicion_asegurado as sp_condicion_asegurado, bdt.tipo_atencion as sp_tipo_atencion, bdt.codigo_ipress as sp_codigo_ipress, bdt.nombre_ipress as sp_nombre_ipress, e.sp_fecha_atencion as sp_fecha_atencion, e.sp_fecha_alta_emergencia as sp_fecha_alta, bdt.tipo_documento_responsable as sp_tipo_documento_responsable, bdt.numero_documento_responsable as sp_numero_documento_responsable, bdt.apellido_paterno_responsable as sp_apellido_paterno_responsable, bdt.apellido_materno_responsable as sp_apellido_materno_responsable, bdt.nombres_responsable as sp_nombres_responsable, bdt.profesion_responsable as sp_profesion_responsable, bdt.especialidad_responsable as sp_especialidad_responsable, bdt.circunstancia_alta::text as sp_circunstancia_alta, bdt.upss_servicio as sp_upss_servicio, bdt.upss_descripcion as sp_upss_descripcion, '2' AS sp_hospitalizacion, bdt.tipo_diagnostico as sp_tipo_diagnostico, bdt.codigo_diagnostico as sp_codigo_diagnostico, bdt.descripcion_diagnostico as sp_descripcion_diagnostico, bdt.codigo_procedimiento as sp_codigo_procedimiento, bdt.descripcion_procedimiento as sp_descripcion_procedimiento, bdt.suma_cantidad_registro as sp_suma_cantidad, bdt.valorizacion as sp_valorizacion_total, bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt, ''::text as id_prestacion_cpt, ''::text as id_prestacion_laboratorio, e.id_emergencia_sigesapol::text as id_atencion_emergencia FROM temp_bdt_emergencia_local bdt INNER JOIN temp_emergencia_sigesapol_estancia e ON bdt.numero_documento_paciente = e.sp_numero_documento_paciente AND bdt.fecha_atencion = e.sp_fecha_atencion WHERE e.excluir_tipo2 = false
    UNION ALL
    SELECT 'procedimientos en emergencia'::text as base, bdt.tipo_documento_paciente, bdt.numero_documento_paciente, bdt.apellido_paterno_paciente, bdt.apellido_materno_paciente, bdt.nombres_paciente, bdt.fecha_nacimiento, bdt.genero_paciente, bdt.condicion_asegurado, bdt.tipo_atencion, bdt.codigo_ipress, bdt.nombre_ipress, bdt.fecha_atencion, bdt.fecha_alta, bdt.tipo_documento_responsable, bdt.numero_documento_responsable, bdt.apellido_paterno_responsable, bdt.apellido_materno_responsable, bdt.nombres_responsable, bdt.profesion_responsable, bdt.especialidad_responsable, bdt.circunstancia_alta::text, bdt.upss_servicio, bdt.upss_descripcion, '2' AS sp_hospitalizacion, bdt.tipo_diagnostico, bdt.codigo_diagnostico, bdt.descripcion_diagnostico, bdt.codigo_procedimiento, bdt.descripcion_procedimiento, bdt.suma_cantidad_registro, bdt.valorizacion, bdt.digitador, bdt.fecha_registro, bdt.hora_registro, bdt.id_prestacion_cpt::text, '', ''::text FROM temp_bdt_emergencia_local bdt WHERE bdt.codigo_procedimiento NOT IN ('99281','99282','99283','99284','99285')
    UNION ALL
    SELECT 'laboratorio en emergencia'::text as base, lab.tipo_documento_paciente, lab.numero_documento_paciente, lab.apellido_paterno_paciente, lab.apellido_materno_paciente, lab.nombres_paciente, lab.fecha_nacimiento, lab.genero_paciente, lab.condicion_asegurado, lab.tipo_atencion::integer, lab.codigo_ipress, lab.nombre_ipress, lab.fecha_muestra, lab.fecha_egreso, lab.tipo_documento_responsable, lab.numero_documento_responsable, lab.apellido_paterno_responsable, lab.apellido_materno_responsable, lab.nombres_responsable, lab.profesion_responsable, lab.especialidad_responsable, lab.circunstancia_alta::text, lab.upss_codigo, lab.upss_descripcion, '2' AS sp_hospitalizacion, lab.tipo_diagnostico, lab.codigo_diagnostico, lab.descripcion_diagnostico, lab.codigo_procedimiento, lab.descripcion_procedimiento, lab.suma_cantidad_registro, lab.valorizacion_total, lab.digitador, lab.fecha_registro, lab.hora_registro, '', lab.id_prestacion_laboratorio::text, ''::text FROM temp_laboratorio_emergencia_local lab
) emergencia_raw;

-- ------------------------------------------------------------------------------
-- TRAMA 3: HOSPITALIZACIÓN
-- ------------------------------------------------------------------------------
SELECT 
    base,
    sp_tipo_documento_paciente,
    sp_numero_documento_paciente,
    regexp_replace(sp_apellido_paterno_paciente, '\r|\n', ' ', 'g') as sp_apellido_paterno_paciente,
    regexp_replace(sp_apellido_materno_paciente, '\r|\n', ' ', 'g') as sp_apellido_materno_paciente,
    regexp_replace(sp_nombres_paciente, '\r|\n', ' ', 'g') as sp_nombres_paciente,
    sp_fecha_nacimiento,
    sp_genero_paciente,
    sp_condicion_asegurado,
    sp_tipo_atencion,
    sp_codigo_ipress,
    regexp_replace(sp_nombre_ipress, '\r|\n', ' ', 'g') as sp_nombre_ipress,
    sp_fecha_atencion,
    sp_fecha_alta,
    sp_tipo_documento_responsable,
    sp_numero_documento_responsable,
    regexp_replace(sp_apellido_paterno_responsable, '\r|\n', ' ', 'g') as sp_apellido_paterno_responsable,
    regexp_replace(sp_apellido_materno_responsable, '\r|\n', ' ', 'g') as sp_apellido_materno_responsable,
    regexp_replace(sp_nombres_responsable, '\r|\n', ' ', 'g') as sp_nombres_responsable,
    sp_profesion_responsable,
    sp_especialidad_responsable,
    sp_circunstancia_alta,
    sp_upss_servicio,
    regexp_replace(sp_upss_descripcion, '\r|\n', ' ', 'g') as sp_upss_descripcion,
    sp_hospitalizacion,
    sp_tipo_diagnostico,
    sp_codigo_diagnostico,
    regexp_replace(sp_descripcion_diagnostico, '\r|\n', ' ', 'g') as sp_descripcion_diagnostico,
    sp_codigo_procedimiento,
    regexp_replace(sp_descripcion_procedimiento, '\r|\n', ' ', 'g') as sp_descripcion_procedimiento,
    sp_suma_cantidad,
    sp_valorizacion_total,
    digitador_cpt,
    fecha_registro_cpt,
    hora_registro_cpt,
    id_prestacion_cpt,
    id_prestacion_laboratorio
FROM (
    -- Replicando 11_ARMADO_hospitalizacion.sql
    SELECT 'estancia hospitalaria'::text as base, bdt.tipo_documento_paciente as sp_tipo_documento_paciente, bdt.numero_documento_paciente as sp_numero_documento_paciente, bdt.apellido_paterno_paciente as sp_apellido_paterno_paciente, bdt.apellido_materno_paciente as sp_apellido_materno_paciente, bdt.nombres_paciente as sp_nombres_paciente, bdt.fecha_nacimiento as sp_fecha_nacimiento, bdt.genero_paciente as sp_genero_paciente, bdt.condicion_asegurado as sp_condicion_asegurado, bdt.tipo_atencion as sp_tipo_atencion, bdt.codigo_ipress as sp_codigo_ipress, bdt.nombre_ipress as sp_nombre_ipress, bdt.fecha_atencion as sp_fecha_atencion, bdt.fecha_alta as sp_fecha_alta, bdt.tipo_documento_responsable as sp_tipo_documento_responsable, bdt.numero_documento_responsable as sp_numero_documento_responsable, bdt.apellido_paterno_responsable as sp_apellido_paterno_responsable, bdt.apellido_materno_responsable as sp_apellido_materno_responsable, bdt.nombres_responsable as sp_nombres_responsable, bdt.profesion_responsable as sp_profesion_responsable, bdt.especialidad_responsable as sp_especialidad_responsable, bdt.circunstancia_alta::text as sp_circunstancia_alta, bdt.upss_servicio as sp_upss_servicio, bdt.upss_descripcion as sp_upss_descripcion, '1' AS sp_hospitalizacion, bdt.tipo_diagnostico as sp_tipo_diagnostico, bdt.codigo_diagnostico as sp_codigo_diagnostico, bdt.descripcion_diagnostico as sp_descripcion_diagnostico, bdt.codigo_procedimiento as sp_codigo_procedimiento, bdt.descripcion_procedimiento as sp_descripcion_procedimiento, bdt.suma_cantidad_registro as sp_suma_cantidad, bdt.valorizacion as sp_valorizacion_total, bdt.digitador as digitador_cpt, bdt.fecha_registro as fecha_registro_cpt, bdt.hora_registro as hora_registro_cpt, bdt.id_prestacion_cpt::text as id_prestacion_cpt, ''::text as id_prestacion_laboratorio FROM temp_bdt_hospitalizacion_local bdt WHERE bdt.codigo_procedimiento IN ('99221', '99222', '99223', '99231', '99232', '99233', '99238', '99239', '99291', '99295', '99305')
    UNION ALL
    SELECT 'procedimientos en hospitalización'::text as base, bdt.tipo_documento_paciente, bdt.numero_documento_paciente, bdt.apellido_paterno_paciente, bdt.apellido_materno_paciente, bdt.nombres_paciente, bdt.fecha_nacimiento, bdt.genero_paciente, bdt.condicion_asegurado, bdt.tipo_atencion, bdt.codigo_ipress, bdt.nombre_ipress, bdt.fecha_atencion, bdt.fecha_alta, bdt.tipo_documento_responsable, bdt.numero_documento_responsable, bdt.apellido_paterno_responsable, bdt.apellido_materno_responsable, bdt.nombres_responsable, bdt.profesion_responsable, bdt.especialidad_responsable, bdt.circunstancia_alta::text, bdt.upss_servicio, bdt.upss_descripcion, '1' AS sp_hospitalizacion, bdt.tipo_diagnostico, bdt.codigo_diagnostico, bdt.descripcion_diagnostico, bdt.codigo_procedimiento, bdt.descripcion_procedimiento, bdt.suma_cantidad_registro, bdt.valorizacion, bdt.digitador, bdt.fecha_registro, bdt.hora_registro, bdt.id_prestacion_cpt::text, ''::text FROM temp_bdt_hospitalizacion_local bdt WHERE bdt.codigo_procedimiento NOT IN ('99221', '99222', '99223', '99231', '99232', '99233', '99238', '99239', '99291', '99295', '99305')
    UNION ALL
    SELECT 'laboratorio en hospitalización'::text as base, lab.tipo_documento_paciente, lab.numero_documento_paciente, lab.apellido_paterno_paciente, lab.apellido_materno_paciente, lab.nombres_paciente, lab.fecha_nacimiento, lab.genero_paciente, lab.condicion_asegurado, lab.tipo_atencion::integer, lab.codigo_ipress, lab.nombre_ipress, lab.fecha_muestra, lab.fecha_egreso, lab.tipo_documento_responsable, lab.numero_documento_responsable, lab.apellido_paterno_responsable, lab.apellido_materno_responsable, lab.nombres_responsable, lab.profesion_responsable, lab.especialidad_responsable, lab.circunstancia_alta::text, lab.upss_codigo, lab.upss_descripcion, '1' AS sp_hospitalizacion, lab.tipo_diagnostico, lab.codigo_diagnostico, lab.descripcion_diagnostico, lab.codigo_procedimiento, lab.descripcion_procedimiento, lab.suma_cantidad_registro, lab.valorizacion_total, lab.digitador, lab.fecha_registro, lab.hora_registro, '', lab.id_prestacion_laboratorio::text FROM temp_laboratorio_hospitalizacion_local lab
) hosp_raw;
