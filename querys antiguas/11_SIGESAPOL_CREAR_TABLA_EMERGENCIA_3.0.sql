-- ================================================================
-- CONSULTA PARA GENERAR LAS PRESTACIONES DEL TIPO EMERGENCIA 
-- (HASTA EL NIVEL DE PROCEDIMIENTOS MÉDICOS) -- SALUDPOL
-- ================================================================

CREATE TABLE temp_emergencia_procedimientos_sigesapol AS
SELECT  
	'SIGESAPOL emergencia'::text AS base,
	--h.nro_historia AS historia,
	--regexp_replace(h.nro_historia, '\r|\n|\t', '', 'g') as historia,
	c.grado AS grado_paciente,
	--'¿?' AS situacion_paciente,
	CASE 
		WHEN a.tipo_doc_ident = 'DNI' THEN '1'::varchar
		WHEN a.tipo_doc_ident = 'CE' THEN '2'::varchar
	END AS sp_tipo_documento_paciente,
	a.nro_doc_ident AS sp_numero_documento_paciente, 
	a.paterno AS sp_apellido_paterno_paciente, 
	a.materno AS sp_apellido_materno_paciente, 
	a.nombre AS sp_nombres_paciente, 
	a.fecha_nac AS sp_fecha_nacimiento_paciente, 
	--'' as edad,
	--DATE_PART('year', age(pre.fecha_atencion::date, a.fecha_nac::date)) as edad,
	--DATE_PART('month', age(pre.fecha_atencion::date, a.fecha_nac::date)) as meses,
	--DATE_PART('day', age(pre.fecha_atencion::date, a.fecha_nac::date)) as dias,
	CASE 
		WHEN a.sexo = 'M' THEN '1'::varchar
		WHEN a.sexo = 'F' THEN '2'::varchar
	END AS sp_genero_paciente,
	CASE
		WHEN c.parentesco = 'TITULAR' THEN '1'::varchar
		ELSE '2'::varchar
	END AS sp_condicion_asegurado,
	pre.id_tipo_atencion AS sp_tipo_atencion,
	e.codigo AS sp_codigo_ipress,
	e.nombre AS sp_nombre_ipress,
	--pre.ipress AS condicion_ipress,
	pre.fecha_atencion as sp_fecha_atencion_preocedimiento,
	--em.fecha_ingreso as sp_fecha_atencion,
	em.fecha_atencion as sp_fecha_atencion_emergencia,
	--em.fecha_alta_medica as sp_fecha_alta,
	em.fecha_alta_medica as sp_fecha_alta_emergencia,
	(CASE WHEN m.tipo_documento IS NULL then '1' else m.tipo_documento end)::varchar sp_tipo_documento_responsable, -- campo llamado DNI => código 1
	m.dni AS sp_numero_documento_responsable,
	m.paterno AS sp_apellido_paterno_responsable,
	m.materno AS sp_apellido_materno_responsable,
	m.nombre AS sp_nombres_responsable,
	--m.colegiatura AS numero_colegio_medico,
	--m.rne AS rne,
	--m.id_profesion AS sp_codigo_profesion_responsable,
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
	ELSE '00'
	END
	) AS sp_codigo_profesion_responsable,
	(CASE WHEN es.nombre = 'OBSTETRICIA' then '00' else '01' end)::varchar sp_codigo_especialidad,
	--es.nombre AS nombre_especialidad,
	regexp_replace(es.nombre, '\r|\n|\t', '', 'g') as nombre_especialidad,
	--''::text AS sp_circunstancia_alta,
	em.id_condi_egres_med AS id_circunstancia_alta_sigesapol,
	cond.codigo_salupol AS sp_circunstancia_alta_sp,
	em.id_prioridad prioridad,
	em.estado,
	--div.nombre AS division_hcentral,
	pre.codigo_upss AS sp_upss_codigo,
	--cons.nombre AS sp_upss_nombre,
	regexp_replace(cons.nombre, '\r|\n|\t', '', 'g') as upss_nombre_consultorio,
	regexp_replace(upss.descripcion_upss, '\r|\n|\t', '', 'g') AS sp_upss_nombre,
	tr.descripcion AS servicio_de_triaje,
	
	--pre.upss AS condicion_servicio,
	'2'::varchar AS hospitalizacion, 
	-- ====== DIAGNÓSTICOS
	--(CASE WHEN rd.id_tipo_diagnostico IS NULL THEN '1' else rd.id_tipo_diagnostico end)::varchar id_tipo_diagnostico,
	--rd.id_tipo_diagnostico AS sp_tipo_diagnostico,
	--d.codigo AS sp_codigo_diagnostico, 
	--d.nombre AS sp_descripcion_diagnostico,

	max(CASE WHEN d1.orden = 1 THEN d1.tipo_diagnostico END) as sp_tipo_dx_01, -- sp
	max(CASE WHEN d1.orden = 1 THEN d1.codigo_diagnostico END) as sp_codigo_dx_01, -- sp
	max(CASE WHEN d1.orden = 1 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_01, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.tipo_diagnostico END) as sp_tipo_dx_02, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.codigo_diagnostico END) as sp_codigo_dx_02, -- sp
	max(CASE WHEN d1.orden = 2 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_02, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.tipo_diagnostico END) as sp_tipo_dx_03, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.codigo_diagnostico END) as sp_codigo_dx_03, -- sp
	max(CASE WHEN d1.orden = 3 THEN d1.descripcion_diagnostico END) AS sp_descripcion_dx_03, -- sp
	-- ======
	-- ===== PROCEDIMIENTOS
	
	p2.codigo::varchar AS sp_codigo_procedimiento,
	p2.descripcion::varchar AS sp_descripcion_procedimiento,
	pp.cantidad AS sp_suma_cantidad,
	--CASE WHEN e.nivel='1' THEN p2.t_nivel1 
	--	WHEN e.nivel='2' THEN p2.t_nivel2 
	--	WHEN e.nivel='3' THEN p2.t_nivel3 
	--END::float precio_tarifario_procedimiento
	(pp.cantidad * p2.t_nivel3) AS sp_valorizacion_calculada

	-- Digitación procedimientos
	--,'' as digitador_cpt, '' as fecha_registro_cpt, '' as hora_registro_cpt
	, pre.id_ext as is_emergencia_sigesapol
	, pre.id as id_prestacion_sigesapol
	--, ''::text as id_prestacion_laboratorio
	
	,em.cpms_alta as cpms_alta,
	--(extract(days from (em.fecha_alta_medica - em.fecha_atencion)) + 1) cantidad_cpms_estancia,
	pre.id as id_prestacion_cpt
	
FROM prestaciones pre 
	LEFT JOIN asegurados a ON a.id = pre.id_asegurado
	INNER JOIN asegurado_historias h ON h.id_asegurado = a.id AND h.id_establecimiento = '76' -- "Hospital Nacional PNP Luis N. Saenz"
	INNER JOIN establecimientos e ON e.id = pre.id_establecimiento 
	LEFT JOIN citas c ON c.id = pre.id_cita
	INNER JOIN sub_consultorios subc ON subc.id = c.id_sub_consultorio
	INNER JOIN consultorios cons ON cons.id = subc.id_consultorio
	INNER JOIN tipo_consultorio_divisiones div ON div.id = cons.id_consultorio_division
	INNER JOIN medicos m ON m.id = pre.id_medico
	INNER JOIN especializaciones es on es.id = m.id_especializacion
	INNER JOIN profesiones prof on prof.id = m.id_profesion
	--LEFT JOIN receta_diagnosticos rd on rd.id_prestacion = pre.id
	--LEFT JOIN diagnosticos d on d.id= rd.id_diagnostico	
	--LEFT JOIN tipo_diagnosticos td on td.id = rd.id_tipo_diagnostico
	left join prestacion_procedimientos pp on pp.id_prestacion = pre.id
	left join procedimientos p2 on p2.id = pp.id_procedimiento
	
	left join emergencias em on em.id = pre.id_ext-- AND em.estado 
	--left join condiciones cond on cond.id::character varying = em.id_condicion_alta 
	left join condiciones cond on cond.id = em.id_condi_egres_med
	left join upsses upss on upss.codigo = pre.codigo_upss

	INNER JOIN sp_sigesapol_diagnostico_en_prestacion_emergencia(pre.id) d1 ON d1.id_prestacion = pre.id --AND d1.orden = 1

	LEFT JOIN triajes tr ON tr.id = em.id_triaje

--WHERE pre.id_tipo_atencion IN (1, 5, 7) -- ('AMBULATORIO', 'SERVICIO NUTRICIONAL - AMBULATORIO', 'URGENCIA')
WHERE pre.id_tipo_atencion IN (2) -- ('EMERGENCIA')
AND pre.id_establecimiento = 76  -- "Hospital Nacional PNP Luis N. Saenz"
--AND pre.fecha_atencion between '20230801' AND '20230831'

--and pre.id = '1266673'

AND
--pre.fecha_alta between '20230801' AND '20230831'
--AND em.fecha_egreso between '20230801' AND '20230831'
  --fecha_egreso between '20230801' and '20230831'
  --fecha_egreso_medico between '20230801' and '20230831'
  em.fecha_alta_medica::date between '20241201' and '20241231'
AND p2.tipo_procedimiento = 1 -- 1: médicos, 2: laboratorio, 3: imágenes
  
AND pre.id_estado_reg = 1 -- Activo, Anulado 0
AND em.estado = '5'
--AND em.id not in ('34075', '34074', '34040')
-- AND p2.codigo IS NOT NULL -- 169,395
--AND 
Group by 
pre.id_tipo_atencion, h.nro_historia, c.grado, a.tipo_doc_ident, a.nro_doc_ident, a.paterno, a.materno, a.nombre, 
a.fecha_nac, a.sexo, c.parentesco, 
e.codigo, e.nombre, 
pre.ipress, div.nombre, pre.codigo_upss, cons.nombre, pre.upss,
--pre.fecha_atencion, pre.fecha_alta,
m.tipo_documento, m.dni, m.paterno, m.materno, m.nombre,
m.colegiatura, m.rne, m.id_profesion, prof.nombre, es.nombre
	-- ====== DIAGNÓSTICOS
--rd.id_tipo_diagnostico--,	--d.codigo, d.nombre--,
	-- ===== PROCEDIMIENTOS
,p2.codigo, p2.descripcion, pp.cantidad, e.nivel, p2.t_nivel1, p2.t_nivel2, p2.t_nivel3
,pre.id, em.id_prioridad
,cond.codigo_salupol, em.estado, em.id_condi_egres_med
,em.fecha_atencion, em.fecha_alta_medica, em.cpms_alta
,upss.descripcion_upss
--,d1.tipo_diagnostico, d1.codigo_diagnostico, d1.descripcion_diagnostico
--,d2.tipo_diagnostico, d2.codigo_diagnostico, d2.descripcion_diagnostico
--,d3.tipo_diagnostico, d3.codigo_diagnostico, d3.descripcion_diagnostico
, tr.descripcion

order by pre.fecha_atencion