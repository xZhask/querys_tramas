/* =======================================
Procedimiento almacenado para obtener la cantidad de atenciones realizados en un determinado período por hospitalización
Parámetros a enviar: 	
  p_inicio_periodo: Fecha de inicio de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230501
  p_fin_periodo: Fecha de fin de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230531

 =======================================
*/

-- CREAR LA FUNCIÓN "sp_diagnostico_en_prestacion_cpt"


--DROP FUNCTION sp_hospitalizacion_en_periodo(p_inicio_periodo DATE, p_fin_periodo DATE);

CREATE OR REPLACE FUNCTION sp_hospitalizacion_en_periodo(
	p_inicio_periodo DATE,  -- '20230501'
	p_fin_periodo DATE 	-- '20230531'
)
RETURNS TABLE (
	historia text,
	sp_tipo_documento_paciente integer,
	sp_numero_documento_paciente text,
	sp_apellido_paterno_paciente character varying(45),
	sp_apellido_materno_paciente character varying(45),
	sp_nombres_paciente character varying(45),
	sp_fecha_nacimiento date,
	edad double precision,
	meses double precision,
	dias double precision,
	sp_genero_paciente integer,
	sp_condicion_asegurado integer,
	sp_tipo_atencion text,
	sp_codigo_ipress text,
	sp_nombre_ipress text,
	sp_upss_codigo character varying,
	sp_upss_descripcion character varying,
	sp_fecha_atencion date,
	sp_fecha_alta date,
	sp_tipo_documento_responsable integer,
	sp_numero_documento_responsable text,
	sp_apellido_paterno_responsable character varying(45),
	sp_apellido_materno_responsable character varying(45),
	sp_nombres_responsable character varying(45),
	numero_colegio_medico character varying(13),
	rne character varying(30),
	sp_profesion_responsable text,
	sp_especialidad_responsable text,
	sp_circunstancia_alta character varying(100),
	sp_tipo_dx_01 character varying,
	sp_codigo_dx_01 character varying,
	sp_descripcion_dx_01 text,
	sp_tipo_dx_02 character varying,
	sp_codigo_dx_02 character varying,
	sp_descripcion_dx_02 text,
	sp_tipo_dx_03 character varying,
	sp_codigo_dx_03 character varying,
	sp_descripcion_dx_03 text,
	sp_codigo_procedimiento character varying(10),
	sp_descripcion_procedimiento text,
	sp_dias_estancia integer,
	sp_valorizacion_total numeric,
	estado_cpt character varying(1),
	ubicacion_ipress character varying(10),
	digitador text,
	fecha_registro date,
	hora_registro time with time zone,
	id_prestacion_cpt integer
) 
AS $$ 
BEGIN
RETURN QUERY 

SELECT
	-- ========== DATOS PACIENTE ==========
	SUBSTRING(hc.numero_historia_clinica , 3, 6)as historia,
	p.codigo_tipo_documento as sp_tipo_documento_paciente, -- sp
	CASE 
		WHEN p.codigo_tipo_documento = 1 THEN SUBSTRING(p.numero_documento, 3, 8)
		WHEN p.codigo_tipo_documento = 2 THEN SUBSTRING(p.numero_documento, 2, 9)
		ELSE SUBSTRING(p.numero_documento, 2, 9) 
	END AS sp_numero_documento_paciente, -- sp
	p.apellido_paterno as sp_apellido_paterno_paciente, -- sp
	p.apellido_materno as sp_apellido_materno_paciente, -- sp
	p.nombres as sp_nombres_paciente, -- sp
	p.fecha_nacimiento AS sp_fecha_nacimiento, -- sp
	DATE_PART('year', age(r.fecha_ingreso, p.fecha_nacimiento)) as edad,
	DATE_PART('month', age(r.fecha_ingreso, p.fecha_nacimiento)) as meses,
	DATE_PART('day', age(r.fecha_ingreso, p.fecha_nacimiento)) as dias,
	p.codigo_genero as sp_genero_paciente, -- sp
	CASE 	
		WHEN p.id_parentesco = 1 THEN 1
		WHEN p.id_parentesco = 9 THEN 3
		ELSE 2
	END AS sp_condicion_asegurado, -- sp
	CASE 
		WHEN t.origen = 'CONSULTA' THEN 1::text
		WHEN t.origen = 'ATENCION EN EMERGENCIA' THEN 2::text
		WHEN t.origen = 'HOSPITALIZACION' THEN 3::text
	END AS sp_tipo_atencion, -- sp -- debe resultar 3

	-- ========== ==========
		
	-- ========== DATOS IPRESS ========== 
		
	TRIM('00013591') AS sp_codigo_ipress, -- sp
	TRIM('HOSPITAL NACIONAL PNP LUIS N SAENZ') AS sp_nombre_ipress, -- sp

	-- ========== ==========
		
	-- ========== DATOS SERVICIO ========== 
	
	COALESCE(s.upss, '') as sp_upss_codigo, -- sp
	COALESCE(s.descripcion, '') as sp_upss_descripcion, -- sp
	r.fecha_ingreso as sp_fecha_atencion, -- sp -- En bdt se utiliza la fecha de la prestación pcpt.fecha_consulta as fecha_atencion,
	r.fecha_egreso as sp_fecha_alta, -- sp

	-- ========== ==========
		
	-- ========== DATOS MEDICO ========== 

	pm.codigo_tipo_documento as sp_tipo_documento_responsable, -- sp
	CASE 
		WHEN pm.codigo_tipo_documento = 1 THEN SUBSTRING(pm.numero_documento, 3, 8)
		WHEN pm.codigo_tipo_documento = 2 THEN SUBSTRING(pm.numero_documento, 2, 9)
		ELSE SUBSTRING(pm.numero_documento, 2, 9) 
	END as sp_numero_documento_responsable, -- sp
	pm.apellido_paterno as sp_apellido_paterno_responsable, -- sp
	pm.apellido_materno as sp_apellido_materno_responsable, -- sp
	pm.nombres as sp_nombres_responsable, -- sp
	m.numero_colegio_medico,
	m.rne,
	(CASE 
		WHEN m.id_profesion='92' THEN '01' 
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
	END) as sp_profesion_responsable, -- sp

	CASE 
		WHEN t.origen IN ('ATENCION EN EMERGENCIA','HOSPITALIZACION') THEN
			CASE 
				WHEN m.especialidad_medico = 'OBSTETRA' OR m.id_especialidad_med IN (105, 362) THEN '00'
				ELSE '01'
			END
		ELSE ''
	END AS sp_especialidad_responsable, -- sp
	r.codigo_alta::character varying(100) AS sp_circunstancia_alta, -- sp

	-- ========== DATOS DIAGNÓSTICOS ==========

	d1.tipo_diagnostico as sp_tipo_dx_01, -- sp
	d1.codigo_diagnostico as sp_codigo_dx_01, -- sp
	d1.descripcion_diagnostico AS sp_descripcion_dx_01, -- sp
	d2.tipo_diagnostico as sp_tipo_dx_02, -- sp
	d2.codigo_diagnostico as sp_codigo_dx_02, -- sp
	d2.descripcion_diagnostico AS sp_descripcion_dx_02, -- sp
	d3.tipo_diagnostico as sp_tipo_dx_03, -- sp
	d3.codigo_diagnostico as sp_codigo_dx_03, -- sp
	d3.descripcion_diagnostico AS sp_descripcion_dx_03, -- sp

	-- ========== DATOS PROCEDIMIENTOS ==========
	
	x.cod_cpt AS sp_codigo_procedimiento, -- sp
	x.descripcioncpt AS sp_descripcion_procedimiento, -- sp

	(date(r.fecha_egreso) - date(r.fecha_ingreso) + 1) as sp_dias_estancia, -- sp
	((date(r.fecha_egreso) - date(r.fecha_ingreso) + 1) * x.nivel_3) as sp_valorizacion_total, -- sp
	
	x.estado as estado_cpt, 
	t.ubicacion_ipress as ubicacion_ipress, 
	
	pu.apellido_paterno || ' '||  pu.apellido_materno || ' '||  pu.nombres as digitador,
	t.fecha_registro,
	t.hora_registro,
	t.id_prestacion_cpt as id_prestacion_cpt

FROM prestacion_cpt t
		
	INNER JOIN persona p on t.id_persona = p.id_persona
	INNER JOIN medico m on m.codigo_medico = t.codigo_medico
	INNER JOIN persona pm ON m.id_persona = pm.id_persona
	LEFT JOIN historia_clinica hc ON p.id_persona = hc.id_persona
	INNER JOIN usuario u on u.codigo_usuario=t.codigo_usuario
	INNER JOIN persona pu on u.id_persona=pu.id_persona
	INNER JOIN diagnostico_cpt d ON t.id_prestacion_cpt = D.id_prestacion_cpt AND D.estado = 'N'
	INNER JOIN cie10 c ON c.id_cie10 = d.id_cie10
	
	INNER JOIN sp_diagnostico_en_prestacion_cpt(t.id_prestacion_cpt) d1 ON d1.id_prestacion_cpt = t.id_prestacion_cpt AND d1.orden = 1

	LEFT JOIN sp_diagnostico_en_prestacion_cpt(t.id_prestacion_cpt) d2 ON d2.id_prestacion_cpt = t.id_prestacion_cpt AND d2.orden = 2

	LEFT JOIN sp_diagnostico_en_prestacion_cpt(t.id_prestacion_cpt) d3 ON d3.id_prestacion_cpt = t.id_prestacion_cpt AND d3.orden = 3
	
	INNER join procedimiento_cpt r on d.id_diagnostico_cpt=r.id_diagnostico_cpt
	INNER join cpt x on x.id_cpt=r.id_cpt
	INNER JOIN servicio_hcentral s ON t.id_servicio_hcentral = s.id_servicio

WHERE r.fecha_egreso::DATE BETWEEN p_inicio_periodo AND p_fin_periodo
	AND t.origen = 'HOSPITALIZACION'
	AND t.estado = 'N'

GROUP BY
	t.origen,
	hc.numero_historia_clinica, p.codigo_tipo_documento, p.numero_documento, 
	p.apellido_paterno, p.apellido_materno, p.nombres, p.fecha_nacimiento, p.id_parentesco, p.codigo_genero,
	r.fecha_ingreso, r.fecha_egreso, 
	t.condicion_cpt_ipress,
	d1.tipo_diagnostico, d1.codigo_diagnostico, d1.descripcion_diagnostico,
	d2.tipo_diagnostico, d2.codigo_diagnostico, d2.descripcion_diagnostico,
	d3.tipo_diagnostico, d3.codigo_diagnostico, d3.descripcion_diagnostico,
	x.cod_cpt, x.descripcioncpt,
	x.nivel_3, x.estado,
	s.upss, s.descripcion,
	pm.codigo_tipo_documento, pm.numero_documento, pm.apellido_paterno, pm.apellido_materno, pm.nombres,
	m.numero_colegio_medico, m.id_profesion, m.rne, m.id_especialidad_med, m.especialidad_medico,
	r.codigo_alta,
	pu.apellido_paterno, pu.apellido_materno, pu.nombres,
	t.id_prestacion_cpt

ORDER BY r.fecha_egreso, p.numero_documento;

END; $$ 

LANGUAGE 'plpgsql';

--SELECT * FROM sp_hospitalizacion_en_periodo('20230801', '20230831');
--SELECT * FROM sp_hospitalizacion_en_periodo('20230101', '20230430') WHERE sp_numero_documento_paciente = '00167120'

/*
FORMATO EN EXCEL
Números de documentos y código ipress: 8
UPSS: 6
Profesión: 2
Especialidad: 2
*/