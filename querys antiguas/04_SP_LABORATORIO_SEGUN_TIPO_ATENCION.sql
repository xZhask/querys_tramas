/* =======================================
Procedimiento almacenado para obtener la cantidad de exámenes de laboratorio realizados en un determinado período y/o según el tipo de atención
Parámetros a enviar: 
  p_inicio_periodo: Fecha de inicio de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230501
  p_fin_periodo: Fecha de fin de la consulta: año (4 dígitos) + mes (2 dígitos) + día (2 dígitos) según el siguiente formato 20230531
  p_tipo_atencion INTEGER
	Valores esperados:
		1 => 'CONSULTA'
		2 => 'ATENCION EN EMERGENCIA'
		3 => 'HOSPITALIZACION'
		4 => COMODÍN QUE REPRESENTA 'TODO'

 =======================================
*/

--DROP FUNCTION sp_laboratorio_segun_tipo_atencion(p_inicio_periodo DATE, p_fin_periodo DATE, p_tipo_atencion INTEGER);

CREATE OR REPLACE FUNCTION sp_laboratorio_segun_tipo_atencion(
	p_inicio_periodo DATE,  -- '20230501'
	p_fin_periodo DATE, 	-- '20230531'
	p_tipo_atencion INTEGER 	-- 1, 2, 3, 4* 'CONSULTA', 'ATENCION EN EMERGENCIA',  'HOSPITALIZACION', 4* COMODÍN: 'TODO'
) 
RETURNS TABLE (
	tipo_atencion text,
	historia text,
	tipo_documento_paciente integer,
	numero_documento_paciente text,
	apellido_paterno_paciente character varying(45),
	apellido_materno_paciente character varying(45),
	nombres_paciente character varying(45),
	fecha_nacimiento date,
	edad double precision,
	meses double precision,
	dias double precision,
	genero_paciente integer,
	condicion_asegurado integer,
	codigo_ipress character varying(10),
	nombre_ipress character varying(255),
	descripcion_division character varying,
	upss_codigo character varying(6),
	upss_descripcion character varying(150),
	fecha_atencion date,
	fecha_muestra date,
	fecha_egreso date,
	tipo_documento_responsable integer,
	numero_documento_responsable text,
	apellido_paterno_responsable character varying(45),
	apellido_materno_responsable character varying(45),
	nombres_responsable character varying(45),
	numero_colegio_medico character varying(13),
	profesion_responsable text,
	especialidad_responsable text,
	circunstancia_alta character varying,
	tipo_diagnostico text,
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	codigo_procedimiento character varying(10),
	descripcion_procedimiento text,
	suma_cantidad_registro bigint,
	valorizacion_total numeric,
	estado_cpt character varying(1),
	digitador text,
	fecha_registro date,
	hora_registro time with time zone,
	id_prestacion_laboratorio integer,
	correlativo integer
) 
AS $$ 
-- DECLARE
--	v_fecha_inicial DATE := (SELECT tel.fecha_atencion FROM temp_emergencia_local tel order by tel.fecha_atencion limit 1);	
BEGIN
RETURN QUERY 

SELECT 
	-- ========== DATOS PACIENTE ==========
	CASE
	    WHEN t.origen::text = 'CONSULTA'::text THEN '1'::text
	    WHEN t.origen::text = 'ATENCION EN EMERGENCIA'::text THEN '2'::text
	    WHEN t.origen::text = 'HOSPITALIZACION'::text THEN '3'::text
	    ELSE NULL::text
	END AS tipo_atencion,
	SUBSTRING(hc.numero_historia_clinica , 3, 6) as historia,
	td.codigo_tipo_documento AS tipo_documento_paciente,
	"substring"(p.numero_documento::text, 3, 8) AS numero_documento_paciente,
	p.apellido_paterno AS apellido_paterno_paciente,
	p.apellido_materno AS apellido_materno_paciente,
	p.nombres AS nombres_paciente,
	p.fecha_nacimiento,
	DATE_PART('year', age(t.fecha_muestra, p.fecha_nacimiento)) as edad,
	DATE_PART('month', age(t.fecha_muestra, p.fecha_nacimiento)) as meses,
	DATE_PART('day', age(t.fecha_muestra, p.fecha_nacimiento)) as dias,
	p.codigo_genero AS genero_paciente,
	CASE
	    WHEN p.id_parentesco <> 1 THEN 2
	    ELSE p.id_parentesco
	END AS condicion_asegurado,

	-- ========== ==========
	
	-- ========== DATOS IPRESS - SERVICIO ==========
	
	o.codigo_ipress,
	o.nombre AS nombre_ipress,
	COALESCE(div.descripcion, ''::character varying) AS descripcion_division,
	-- COALESCE(deph.descripcion, ''::character varying) AS descripcion_departamento,
	w.upss AS upss_codigo,
	w.descripcion AS upss_descripcion,	
	t.fecha_muestra AS fecha_atencion, -- según vista recibida
	t.fecha_registro AS fecha_muestra, -- según vista recibida
	CAST(null AS DATE) as fecha_egreso,

	-- ========== ==========
	
	-- ========== DATOS MEDICO ========== 
	
	pm.codigo_tipo_documento as tipo_documento_responsable, --LLAVE
	CASE 
		WHEN pm.codigo_tipo_documento = 1 THEN SUBSTRING(pm.numero_documento, 3, 8)
		WHEN pm.codigo_tipo_documento = 2 THEN SUBSTRING(pm.numero_documento, 2, 9)
		ELSE SUBSTRING(pm.numero_documento, 2, 9) 
	END as numero_documento_responsable, --LLAVE
	pm.apellido_paterno as apellido_paterno_responsable,
	pm.apellido_materno as apellido_materno_responsable,
	pm.nombres as nombres_responsable,
	m.numero_colegio_medico,
	--m.rne,
	CASE
	    WHEN m.id_profesion = 92 THEN '01'::text
	    WHEN m.id_profesion = 30 THEN '02'::text
	    WHEN m.id_profesion = 28 THEN '03'::text
	    WHEN m.id_profesion = 18 THEN '04'::text
	    WHEN m.id_profesion = 189 THEN '05'::text
	    WHEN m.id_profesion = 434 THEN '06'::text
	    WHEN m.id_profesion = 29 THEN '07'::text
	    WHEN m.id_profesion = 438 THEN '09'::text
	    WHEN m.id_profesion = 77 THEN '10'::text
	    WHEN m.id_profesion <> ALL (ARRAY[92, 30, 28, 18, 189, 434, 29, 438, 77]) THEN '00'::text
	    ELSE NULL::text
	END AS profesion_responsable,
	CASE
	    WHEN t.origen IN ('ATENCION EN EMERGENCIA','HOSPITALIZACION') THEN
	    CASE
		WHEN m.especialidad_medico = 'OBSTETRA' OR m.id_especialidad_med IN (105, 362) THEN '00'
		ELSE '01'
	    END
	    ELSE ''
	END AS especialidad_responsable,
	''::character varying AS circunstancia_alta, -- en hospitalización se utilizará la condición de la tabla de hospitalización relacionada

	-- ========== ==========
	
	-- ========== DATOS DIAGNÓSTICOS ==========
	
	CASE
	    WHEN d.tipo_diagnostico::text = 'P - PRESUNTIVO'::text THEN '1'
	    WHEN d.tipo_diagnostico::text = 'D - DEFINITIVO'::text THEN '2'
	    WHEN d.tipo_diagnostico::text = 'R - REPETITIVO'::text THEN '3'
	END AS tipo_diagnostico,
	e.codigo AS codigo_diagnostico,
	UPPER(e.descripcion) AS descripcion_diagnostico,

	-- ========== ==========
	
	-- ========== DATOS PROCEDIMIENTOS ========== 

	x.cod_cpt AS codigo_procedimiento,
	UPPER(x.descripcioncpt) AS descripcion_procedimiento,
	SUM(COALESCE(r.cantidad::integer, 1)) AS suma_cantidad_registro,
	(SUM(COALESCE(r.cantidad::integer, 1)) * x.nivel_3) AS valorizacion_total,
	x.estado AS estado_cpt,

	-- ========== ==========
	
	-- ========== DATOS DIGITACIÓN ==========
	
	(((pu.apellido_paterno::text || ' '::text) || pu.apellido_materno::text) || ' '::text) || pu.nombres::text AS digitador,
	t.fecha_registro,
	t.hora_registro,
	--t.estado,
	t.id_prestacion_laboratorio,	
	t.secuencia AS correlativo
	
FROM persona p

	JOIN prestacion_laboratorio t ON t.id_persona = p.id_persona
	JOIN tipo_documento td ON p.codigo_tipo_documento = td.codigo_tipo_documento
	JOIN medico m ON m.codigo_medico = t.codigo_medico
	JOIN persona pm ON m.id_persona = pm.id_persona
	JOIN usuario u ON u.codigo_usuario = t.codigo_usuario
	JOIN persona pu ON u.id_persona = pu.id_persona
	JOIN establecimiento_medico z ON z.id_establecimiento_medico = t.id_establecimiento_medico
	RIGHT JOIN diagnostico_laboratorio d ON d.id_prestacion_laboratorio = t.id_prestacion_laboratorio
	JOIN cie10 e ON d.id_cie10 = e.id_cie10
	RIGHT JOIN procedimiento_laboratorio r ON d.id_diagnostico_laboratorio = r.id_diagnostico_laboratorio
	JOIN cpt x ON x.id_cpt = r.id_cpt
	JOIN departamento_hcentral h ON h.id_dep_hcentral = t.id_dep_hcentral
	JOIN servicio_hcentral w ON w.id_servicio = t.id_servicio_hcentral
	LEFT JOIN departamento_hcentral deph ON deph.id_dep_hcentral = w.id_dep_hcentral
	LEFT JOIN division_hcentral div ON div.id_div_hcentral = deph.id_div_hcentral
	JOIN establecimiento_medico o ON o.id_establecimiento_medico = t.id_establecimiento_medico
	LEFT JOIN historia_clinica hc ON p.id_persona = hc.id_persona

WHERE t.estado::text = 'N'::text AND d.estado::text = 'N'::text 
	AND
	CASE
		WHEN p_tipo_atencion = 1 THEN -- 'CONSULTA'
			( 
			t.origen = 'CONSULTA'
			AND t.estado = 'N'
			AND
			t.fecha_registro::DATE between p_inicio_periodo and p_fin_periodo
			)
		WHEN p_tipo_atencion = 2 THEN -- 'ATENCION EN EMERGENCIA'
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND t.estado = 'N'
			-- AND t.fecha_fecha_muestra >= '20210405' -- inicio de convenio
			AND t.fecha_muestra <= p_fin_periodo
			AND 
			--p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_emergencia_local et)
			--SIGESAPOL
			p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_emergencia_sigesapol_estancia et)
			)
		WHEN p_tipo_atencion = 3 THEN -- 'HOSPITALIZACION'
			(
			t.origen = 'HOSPITALIZACION'
			AND t.estado = 'N'
			-- AND t.fecha_muestra >= '20210405' -- inicio de convenio
			AND t.fecha_muestra <= p_fin_periodo
			AND 
			p.numero_documento IN (SELECT DISTINCT LPAD(ht.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_hospitalizacion_local ht)
			)
		WHEN p_tipo_atencion = 4 THEN -- Comodín 'TODO'
			(
			t.fecha_registro::DATE between p_inicio_periodo and p_fin_periodo -- muestras realizadas
			)
	END

GROUP BY 
	t.origen, hc.numero_historia_clinica,
	td.codigo_tipo_documento, p.numero_documento, p.apellido_paterno, p.apellido_materno, p.nombres, 
	p.fecha_nacimiento, p.codigo_genero, p.id_parentesco, --p.numero_hijo, 
	o.codigo_ipress, o.nombre, div.descripcion, --deph.descripcion, 
	w.upss, w.descripcion, 
	t.fecha_muestra, t.fecha_registro, 
	pm.numero_documento, pm.apellido_paterno, pm.apellido_materno, pm.nombres, 
	m.id_profesion, m.numero_colegio_medico, m.especialidad_medico, m.id_especialidad_med, 
	d.tipo_diagnostico, e.codigo, e.descripcion, 
	x.cod_cpt, x.descripcioncpt, r.cantidad, x.nivel_3, x.estado,
	pm.codigo_tipo_documento,
	pu.apellido_paterno, pu.apellido_materno, pu.nombres, 
	t.id_prestacion_laboratorio

ORDER BY t.fecha_registro, p.numero_documento;

END; $$ 

LANGUAGE 'plpgsql';


--SELECT * FROM sp_laboratorio_segun_tipo_atencion('20230901', '20230930', 4);

/*
FORMATO EN EXCEL
Números de documentos y código ipress: 8
UPSS: 6
Profesión: 2
Especialidad: 2
*/