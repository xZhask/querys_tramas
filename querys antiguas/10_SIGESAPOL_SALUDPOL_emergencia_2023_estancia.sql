create table temp_emergencia_sigesapol_estancia as
SELECT
	'SIGESAPOL emergencia estancia'::text AS base,
	CASE 
		WHEN a.tipo_doc_ident = 'DNI' THEN '1'::varchar
		WHEN a.tipo_doc_ident = 'CE' THEN '2'::varchar
	END AS sp_tipo_documento_paciente,
	a.nro_doc_ident AS sp_numero_documento_paciente, 
	a.paterno AS sp_apellido_paterno_paciente, 
	a.materno AS sp_apellido_materno_paciente, 
	a.nombre AS sp_nombres_paciente, 
	a.fecha_nac AS sp_fecha_nacimiento_paciente,
	--DATE_PART('year', age(pre.fecha_atencion::date, a.fecha_nac::date)) as edad,
	CASE 
		WHEN a.sexo = 'M' THEN '1'::varchar
		WHEN a.sexo = 'F' THEN '2'::varchar
	END AS sp_genero_paciente,
	CASE
		WHEN e.id_tipo_parentesco = 8 THEN '1'::varchar -- titular
		ELSE '2'::varchar
	END AS sp_condicion_asegurado,
	'2'::text AS sp_tipo_atencion,
	es.codigo AS sp_codigo_ipress,
	es.nombre AS sp_nombre_ipress,
	--pre.ipress AS condicion_ipress,
	--e.fecha_atencion as sp_fecha_atencion,
	COALESCE(e.fecha_atencion, e.created_at) sp_fecha_atencion,
	--''::text as fecha_muestra,
	--em.fecha_alta_medica as sp_fecha_alta,
	e.fecha_alta_medica as sp_fecha_alta_emergencia,

	(CASE WHEN m.tipo_documento IS NULL then '1' else m.tipo_documento end)::varchar sp_tipo_documento_responsable, -- campo llamado DNI => código 1
	m.dni AS sp_numero_documento_responsable,
	m.paterno AS sp_apellido_paterno_responsable,
	m.materno AS sp_apellido_materno_responsable,
	m.nombre AS sp_nombres_responsable,

	prof.nombre AS sigesapol_nombre_profesion_responsable,
	(CASE 	WHEN prof.nombre = 'MEDICO GENERAL' THEN 'MÉDICO'
		WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN 'MÉDICO'
		WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN 'QUÍMICO'
		WHEN prof.nombre = 'ODONTOLOGIA' THEN 'ODONTÓLOGO'
		WHEN prof.nombre = 'OBSTETRICIA' THEN 'OBSTETRA'
		WHEN prof.nombre = 'ENFERMERIA' THEN 'ENFERMERÍA'
		WHEN prof.nombre = 'PSICOLOGIA' THEN 'PSICÓLOGOS'
		WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN 'TECNÓLOGOS MÉDICOS'
		WHEN prof.nombre = 'NUTRICIONISTA' THEN 'NUTRICIONISTA'
		WHEN prof.nombre = 'MEDICO CIRUJANO' THEN 'MÉDICO'
		WHEN prof.nombre = 'MEDICO' THEN 'MÉDICO'
		WHEN prof.nombre = 'OFTALMOLOGIA' THEN 'MÉDICO'
		WHEN prof.nombre = 'GINECOLOGIA' THEN 'MÉDICO'
		WHEN prof.nombre = 'BIOLOGO' THEN 'BIÓLOGO'
	ELSE 'OTRO PROFESIONAL DE LA SALUD'
	END
	) AS sp_nombre_profesion_responsable,
	(CASE 	WHEN prof.nombre = 'MEDICO GENERAL' THEN '01'
		WHEN prof.nombre = 'MEDICO ESPECIALISTA' THEN '01'
		WHEN prof.nombre = 'QUIMICO FARMACEUTICO' THEN '02'
		WHEN prof.nombre = 'ODONTOLOGIA' THEN '03'
		WHEN prof.nombre = 'OBSTETRICIA' THEN '05'
		WHEN prof.nombre = 'ENFERMERIA' THEN '06'
		WHEN prof.nombre = 'PSICOLOGIA' THEN '07'
		WHEN prof.nombre = 'TECNOLOGÍA MEDICA' THEN '09'
		WHEN prof.nombre = 'NUTRICIONISTA' THEN '10'
		WHEN prof.nombre = 'MEDICO CIRUJANO' THEN '01'
		WHEN prof.nombre = 'MEDICO' THEN '01'
		WHEN prof.nombre = 'OFTALMOLOGIA' THEN '01'
		WHEN prof.nombre = 'GINECOLOGIA' THEN '01'
		WHEN prof.nombre = 'BIOLOGO' THEN '04'
		WHEN prof.nombre = 'MEDICO CIRUJANO' THEN '01'
	ELSE '00'
	END
	) AS sp_codigo_profesion_responsable,

	(CASE WHEN esp.nombre = 'OBSTETRICIA' then '00' else '01' end)::varchar sp_codigo_especialidad,
	--es.nombre AS nombre_especialidad,
	regexp_replace(esp.nombre, '\r|\n|\t', '', 'g') as nombre_especialidad,
	--''::text AS sp_circunstancia_alta,
	e.id_condi_egres_med AS sp_circunstancia_alta_sigesapol_sp,
	cond.codigo_salupol AS condicion_alta,
	e.id_prioridad prioridad,
	e.estado,

	'230000'::varchar as sp_upss_codigo, -- pre.codigo_upss AS sp_upss_codigo,
	'EMERGENCIA'::varchar as sp_upss_nombre,
	--regexp_replace(cons.nombre, '\r|\n|\t', '', 'g') as upss_nombre_consultorio,
	--regexp_replace(upss.descripcion_upss, '\r|\n|\t', '', 'g') AS sp_upss_nombre,
	'2'::varchar AS hospitalizacion, 

	/*
	max(CASE WHEN d1.orden = 1 THEN d1.tipo_diagnostico END) as sp_tipo_dx_01, -- sp
	max(CASE WHEN d1.orden = 1 THEN d1.codigo_diagnostico END) as sp_codigo_dx_01, -- sp
	max(CASE WHEN d1.orden = 1 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_01, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.tipo_diagnostico END) as sp_tipo_dx_02, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.codigo_diagnostico END) as sp_codigo_dx_02, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_02, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.tipo_diagnostico END) as sp_tipo_dx_03, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.codigo_diagnostico END) as sp_codigo_dx_03, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_03, -- sp
	*/
	'2'::varchar AS sp_tipo_dx_01,
	d1.codigo AS sp_codigo_dx_01, 
	d1.nombre AS sp_descripcion_dx_01,
	'2'::varchar AS sp_tipo_dx_02,
	d2.codigo AS sp_codigo_dx_02, 
	d2.nombre AS sp_descripcion_dx_02,
	'2'::varchar AS sp_tipo_dx_03,
	d3.codigo AS sp_codigo_dx_03, 
	d3.nombre AS sp_descripcion_dx_03,

	e.id as id_emergencia_sigesapol, --116
	--pre.id id_prestacion, 
	
	e.cpms_alta as cpms_alta,
	(date(e.fecha_alta_medica) - date(e.fecha_atencion) + 1) as cantidad_cpms_estancia
	--,((date(e.fecha_alta_medica) - date(e.fecha_atencion) + 1) * pro.t_nivel3) as valorizacion_estancia

	--,m.dni dni_emergencia, m.paterno AS paterno_emergencia, m.materno AS materno_emergencia--,
	--me.dni dni_prestacion, me.paterno AS paterno_prestacion, me.materno AS materno_prestacion--,
	--pre.id, m.paterno, me.paterno, e.id id_emergencia,
	--case 
	--when m.dni::varchar = me.dni::varchar then 'QUEDA'
	--when pre.id_medico = m.id then 'QUEDA'
	--ELSE 'NO QUEDA'
	--END AS ESTANCIA
	
  FROM emergencias e
  LEFT JOIN asegurados a ON a.id = e.id_asegurado

	inner join users u on u.id = e.id_medico_egreso and u.status = 1
	--inner join medicos m on m.dni = u.dni and m.id_establecimiento = '76' 
	left join 
	(select * from (
		select *, row_number() over (
			partition by dni
			order by id desc
			) as row_num
		from medicos
		) as medicos_ordenados
		where medicos_ordenados.row_num = 1
	) as m
	on m.dni = u.dni

  INNER JOIN establecimientos es ON es.id = e.id_establecimiento
  --INNER JOIN medicos m ON m.id = e.id_medico_egreso
  INNER JOIN profesiones prof on prof.id = m.id_profesion
  INNER JOIN especializaciones esp on esp.id = m.id_especializacion
  left join condiciones cond on cond.id = e.id_condi_egres_med
  --left join prestaciones pre on pre.id_ext = e.id -- AND em.estado 
  --JOIN procedimientos pro ON pro.codigo = e.cpms_alta -- Para filtrar sólo los que tienen CPMS de estancia
  --INNER JOIN sp_sigesapol_diagnostico_en_prestacion_emergencia(pre.id) d1 ON d1.id_prestacion = pre.id --AND d1.orden = 1

  LEFT JOIN diagnosticos d1 ON d1.id = e.id_diag_cab
  LEFT JOIN diagnosticos d2 ON d2.id = e.id_diag_cuer1
  LEFT JOIN diagnosticos d3 ON d3.id = e.id_diag_cuer2
  
  where e.fecha_alta_medica is not null
  and e.fecha_alta_medica::date between '20241201' and '20241231'

Group by 
a.tipo_doc_ident, a.nro_doc_ident, a.paterno, a.materno, a.nombre, 
a.fecha_nac, a.sexo, e.id_tipo_parentesco, 
es.codigo, es.nombre, e.id_prioridad,
m.tipo_documento, m.dni, m.paterno, m.materno, m.nombre,
prof.nombre, esp.nombre,
cond.codigo_salupol, e.estado, e.id_condi_egres_med,
e.fecha_atencion, e.fecha_alta_medica,
--pre.fecha_atencion, pre.id, 
e.id
,a.id--,  me.paterno, me.dni, me.materno, m.id

, d1.codigo, d1.nombre, d2.codigo, d2.nombre, d3.codigo, d3.nombre--, pro.t_nivel3

order by a.id