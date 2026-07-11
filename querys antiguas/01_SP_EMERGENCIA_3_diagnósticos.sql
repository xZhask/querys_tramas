/* =======================================
Procedimiento almacenado para obtener la cantidad de atenciones realizados en un determinado período por emergencia
Parámetros a enviar: 	
	p_inicio_periodo: Fecha de inicio de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230501
	p_fin_periodo: Fecha de fin de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230531

   =======================================
*/

-- CREAR LA FUNCIÓN "sp_diagnostico_en_prestacion_emergencia"

-- DROP FUNCTION sp_emergencia_en_periodo(p_inicio_periodo DATE, p_fin_periodo DATE);

CREATE OR REPLACE FUNCTION sp_emergencia_en_periodo(
	p_inicio_periodo 	DATE, 		-- '20230501'
	p_fin_periodo 		DATE 		-- '20230531'	
)
RETURNS TABLE (
	historia text,
	prioridad character varying(100),
	sp_tipo_documento_paciente integer,
	sp_numero_documento_paciente text,
	sp_apellido_paterno_paciente character varying(45),
	sp_apellido_materno_paciente character varying(45),
	sp_nombres_paciente character varying(45),
	sp_fecha_nacimiento date,
	edad double precision,
	mes double precision,
	dias double precision,
	sp_genero_paciente integer,
	sp_condicion_asegurado integer,
	sp_tipo_atencion text,
	sp_codigo_ipress text,
	sp_nombre_ipress text,
	sp_upss_codigo text,
	sp_upss_descripcion text,
	sp_fecha_atencion date,
	sp_fecha_alta date,
	sp_tipo_documento_responsable integer,
	sp_numero_documento_responsable text,
	sp_apellido_paterno_responsable character varying(45),
	sp_apellido_materno_responsable character varying(45),
	sp_nombres_responsable character varying(45),
	sp_profesion_responsable text,
	sp_especialidad_responsable text,
	descripcion_especialidad character varying(255),
	sp_circunstancia_alta character varying(100),
	descrip_circunstancia_alta character varying(100),
	sp_tipo_dx_01 character varying,
	sp_codigo_dx_01 character varying,
	sp_descripcion_dx_01 text,
	sp_tipo_dx_02 character varying,
	sp_codigo_dx_02 character varying,
	sp_descripcion_dx_02 text,
	sp_tipo_dx_03 character varying,
	sp_codigo_dx_03 character varying,
	sp_descripcion_dx_03 text,
	codigo_cpms text,
	descripcion_cpms text,
	cantidad_cpms integer,
	valorizacion_cpms numeric,
	digitador_egreso text,
	fecha_registro_ingreso date,
	hora_registro_ingreso time with time zone,
	secuencia integer,
	id_atencion_emergencia integer
)
AS $$ 
BEGIN
RETURN QUERY 

SELECT
	SUBSTRING(hc.numero_historia_clinica , 3, 6) as historia, 
	ate.prioridad AS prioridad,
	per.codigo_tipo_documento as sp_tipo_documento_paciente, -- sp tipo_documento
	CASE 
		WHEN per.codigo_tipo_documento = 1 THEN SUBSTRING(per.numero_documento, 3, 8)
		WHEN per.codigo_tipo_documento = 2 THEN SUBSTRING(per.numero_documento, 2, 9)
		ELSE SUBSTRING(per.numero_documento, 2, 9) 
	END as sp_numero_documento_paciente, -- sp numero_documento
	per.apellido_paterno as sp_apellido_paterno_paciente, -- sp 
	per.apellido_materno as sp_apellido_materno_paciente, -- sp
	per.nombres as sp_nombres_paciente, -- sp
	per.fecha_nacimiento AS sp_fecha_nacimiento, -- sp
	DATE_PART('year', age(ate.fecha_ingreso, per.fecha_nacimiento)) as edad,
	DATE_PART('month', age(ate.fecha_ingreso, per.fecha_nacimiento)) as mes,
	DATE_PART('day', age(ate.fecha_ingreso, per.fecha_nacimiento)) as dias,
	per.codigo_genero AS sp_genero_paciente, -- sp
	CASE 
		WHEN per.id_parentesco IN ('8','7','6','5','4','3','2') THEN 2 -- derechohabiente
		WHEN per.id_parentesco = 9 THEN 3 -- civil
		ELSE per.id_parentesco -- titulares / otros para revisar
	END AS sp_condicion_asegurado, -- sp
	'2'::text AS sp_tipo_atencion, -- sp tipo_atencion
	TRIM('00013591') AS sp_codigo_ipress, -- sp
	TRIM('HOSPITAL NACIONAL PNP LUIS N SAENZ') AS sp_nombre_ipress, -- sp 
	'230000'::text AS sp_upss_codigo, -- sp
	'EMERGENCIA'::text AS sp_upss_descripcion, -- sp
	ate.fecha_ingreso AS sp_fecha_atencion, -- sp
	ate.fecha_egreso AS sp_fecha_alta, -- sp

	pm.codigo_tipo_documento as sp_tipo_documento_responsable, -- sp
	CASE 
		WHEN pm.codigo_tipo_documento = 1 THEN SUBSTRING(pm.numero_documento, 3, 8)
		WHEN pm.codigo_tipo_documento = 2 THEN SUBSTRING(pm.numero_documento, 2, 9)
		ELSE SUBSTRING(pm.numero_documento, 2, 9) 
	END as sp_numero_documento_responsable, -- sp
	pm.apellido_paterno as sp_apellido_paterno_responsable, -- sp
	pm.apellido_materno as sp_apellido_materno_responsable, -- sp
	pm.nombres as sp_nombres_responsable, -- sp
	
  	(CASE WHEN m.id_profesion='92' THEN '01' 
		WHEN m.id_profesion='30' THEN '02' 
		WHEN m.id_profesion='28' THEN '03' 
		WHEN m.id_profesion='18' THEN '04' 
		WHEN m.id_profesion='189' THEN '05' 
		WHEN m.id_profesion='434' THEN '06' 
		WHEN m.id_profesion='29' THEN '07' 
		WHEN m.id_profesion='438' THEN '09' 
		WHEN m.id_profesion='77' THEN '10' 	
		WHEN m.id_profesion <> ALL (ARRAY[92, 30, 28, 18, 189, 434, 29, 438, 77]) THEN '00'
		ELSE NULL
	END) AS sp_profesion_responsable, -- sp

	CASE 
		WHEN m.especialidad_medico = 'OBSTETRA' OR m.id_especialidad_med IN (105, 362) THEN '00' -- Se reemplazó 391 
		ELSE '01'
	END AS sp_especialidad_responsable, -- sp
	m.especialidad_medico AS descripcion_especialidad,
	des.descripcion AS sp_circunstancia_alta, -- sp
	des.descripcion AS descrip_circunstancia_alta,
	-- Diagnósticos
 	d1.tipo_diagnostico as sp_tipo_dx_01, -- sp
	d1.codigo_diagnostico as sp_codigo_dx_01, -- sp
	d1.descripcion_diagnostico AS sp_descripcion_dx_01, -- sp
	d2.tipo_diagnostico as sp_tipo_dx_02, -- sp
	d2.codigo_diagnostico as sp_codigo_dx_02, -- sp
	d2.descripcion_diagnostico AS sp_descripcion_dx_02, -- sp
	d3.tipo_diagnostico as sp_tipo_dx_03, -- sp
	d3.codigo_diagnostico as sp_codigo_dx_03, -- sp
	d3.descripcion_diagnostico AS sp_descripcion_dx_03, -- sp
	-- Generar procedimientos temporalmente, según indicación, UNITIC regulalizará esta información desde el sistema
  	(case 
  	when ate.prioridad = 'I - GRAVEDAD SÚBITA EXTREMA' then '99295'
  	when ate.prioridad IN ('II - URGENCIA MAYOR', 'III - URGENCIA MENOR') then '99231.15'
  	else ''
  	end) AS codigo_cpms,
	
	(case 
	when ate.prioridad = 'I - GRAVEDAD SÚBITA EXTREMA' 
		then 'ATENCIÓN EN UNIDAD DE CUIDADOS INTENSIVOS, DÍA PACIENTE'
  	when ate.prioridad IN ('II - URGENCIA MAYOR', 'III - URGENCIA MENOR') 
		then 'ATENCIÓN PACIENTE-DÍA HOSPITALIZACIÓN ESPECIALIZADA CONTINUADA QUE NO ESTÁ ESPECIFICADA'
  	else ''
	end) AS descripcion_cpms,

	(ate.fecha_egreso - ate.fecha_ingreso + 1) as cantidad_cpms,
	
	(case 
	when ate.prioridad = 'I - GRAVEDAD SÚBITA EXTREMA' 
		then ((ate.fecha_egreso - ate.fecha_ingreso + 1) * 1664.44)
  	when ate.prioridad IN ('II - URGENCIA MAYOR', 'III - URGENCIA MENOR') 
		then ((ate.fecha_egreso - ate.fecha_ingreso + 1) * 392.99)
  	else 0.0
	end) AS valorizacion_cpms,
	
 	pue.apellido_paterno || ' '||  pue.apellido_materno || ' '||  pue.nombres as digitador_egreso,
 	ate.fecha_registro_ingreso,
	ate.hora_registro_ingreso,
 	ate.secuencia,
	ate.id_atencion_emergencia

FROM atencion_emergencia ate
	INNER JOIN persona per ON ate.id_persona=per.id_persona
	LEFT JOIN historia_clinica hc ON per.id_persona = hc.id_persona
	INNER JOIN usuario ue on ue.codigo_usuario=ate.codigo_usuario_egreso
  	INNER JOIN persona pue on ue.id_persona=pue.id_persona
	INNER JOIN medico m on m.codigo_medico = ate.codigo_medico	
	INNER JOIN persona pm ON m.id_persona = pm.id_persona	
	INNER JOIN diagnostico dx ON dx.id_atencion_emergencia=ate.id_atencion_emergencia
	INNER JOIN cie10 c1 ON c1.id_cie10=dx.id_cie10
	INNER JOIN destino des ON des.id_destino=ate.id_destino

	INNER JOIN sp_diagnostico_en_prestacion_emergencia(ate.id_atencion_emergencia) d1 ON d1.id_atencion_emergencia = ate.id_atencion_emergencia AND d1.orden = 1

	LEFT JOIN sp_diagnostico_en_prestacion_emergencia(ate.id_atencion_emergencia) d2 ON d2.id_atencion_emergencia = ate.id_atencion_emergencia AND d2.orden = 2

	LEFT JOIN sp_diagnostico_en_prestacion_emergencia(ate.id_atencion_emergencia) d3 ON d3.id_atencion_emergencia = ate.id_atencion_emergencia AND d3.orden = 3

WHERE ate.fecha_egreso::DATE between p_inicio_periodo::DATE AND p_fin_periodo::DATE

GROUP BY 
	 ate.secuencia,
	 ate.prioridad,
	 hc.numero_historia_clinica,
	 per.codigo_tipo_documento,
	 per.numero_documento,
	 per.apellido_paterno,
	 per.apellido_materno,
	 per.nombres,
	 per.fecha_nacimiento,
	 per.codigo_genero,
	 --condicion_asegurado,
	 per.id_parentesco,
	 ate.fecha_ingreso,
	 ate.fecha_egreso,
	 pm.codigo_tipo_documento,
	 pm.apellido_paterno,
	 pm.apellido_materno,
	 pm.nombres,
	 pm.codigo_tipo_documento,
	 pm.numero_documento,
 	 pm.apellido_paterno,
 	 pm.apellido_materno,
	 pm.nombres,
	 --profesion_responsable,
	 m.id_profesion,
	 m.especialidad_medico,
	 m.id_especialidad_med,
	 des.descripcion,
	 --dx.tipo,
	 --c1.codigo,
	 --c1.descripcion,
	 d1.tipo_diagnostico, d1.codigo_diagnostico, d1.descripcion_diagnostico,
	 d2.tipo_diagnostico, d2.codigo_diagnostico, d2.descripcion_diagnostico,
	 d3.tipo_diagnostico, d3.codigo_diagnostico, d3.descripcion_diagnostico,
	 digitador_egreso,
	 ate.fecha_registro_ingreso,
	 ate.hora_registro_ingreso,
	 ate.id_atencion_emergencia

ORDER BY ate.fecha_ingreso, per.numero_documento;

END; $$ 

LANGUAGE 'plpgsql';

--SELECT * FROM sp_emergencia_en_periodo('20230801', '20230831');

/*
FORMATO EN EXCEL
Números de documentos: 8 y 9
Código ipress: 8
UPSS: 6
Profesión: 2
Especialidad: 2
*/