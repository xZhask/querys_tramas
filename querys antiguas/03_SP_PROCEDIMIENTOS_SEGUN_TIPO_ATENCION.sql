/* =======================================
Procedimiento almacenado para obtener la cantidad de procedimientos médicos realizados en un determinado período y/o según el tipo de atención
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

-- VALIDAR LA EXISTENCIA DE LAS TABLAS: temp_emergencia_local y temp_hospitalizacion_local
-- Funciones sp_emergencia_en_periodo y sp_hospitalizacion_en_periodo


--DROP FUNCTION sp_procedimientos_segun_tipo_atencion(p_inicio_periodo DATE, p_fin_periodo DATE, p_tipo_atencion INTEGER);

CREATE OR REPLACE FUNCTION sp_procedimientos_segun_tipo_atencion(
	p_inicio_periodo DATE,  -- '20230601'
	p_fin_periodo DATE, 	-- '20230630'
	p_tipo_atencion INTEGER	-- 1, 2, 3, 4* 'CONSULTA', 'ATENCION EN EMERGENCIA',  'HOSPITALIZACION', 4* COMODÍN: 'TODO'
	--p_tabla_referencial CHARACTER VARYING(255)
) 
RETURNS TABLE (
        tipo_atencion integer,
	historia text,
	grado_paciente character varying(255),
	situacion_paciente character varying(40),
	tipo_documento_paciente integer,
	numero_documento_paciente text,
	apellido_paterno_paciente character varying(45),
	apellido_materno_paciente character varying(45),
	nombres_paciente character varying(45),
	fecha_nacimiento date,
	edad double precision,
	meses double precision,
	dias double precision,
	ubigeo_departamento text,
	departamento_paciente character varying,
	ubigeo_provincia text,
	provincia_paciente character varying,
	ubigeo_distrito text,
	distrito_paciente character varying,
	genero_paciente integer,
	condicion_asegurado integer,
	id_parentesco integer,
	parentesco_paciente character varying(15),
	codigo_ipress text,
	nombre_ipress text,
	condicion_ipress text,
	division_hcentral character varying,
	upss_servicio character varying,
	upss_descripcion character varying,
	condicion_servicio text,
	fecha_atencion date,
	fecha_alta date,
	tipo_documento_responsable integer,
	numero_documento_responsable text,
	apellido_paterno_responsable character varying(45),
	apellido_materno_responsable character varying(45),
	nombres_responsable character varying(45),
	numero_colegio_medico character varying(13),
	rne character varying(30),
	profesion_responsable text,
	especialidad_responsable text,
	circunstancia_alta smallint,
	tipo_diagnostico text,
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	codigo_procedimiento character varying,
	descripcion_procedimiento text,
	suma_cantidad_registro bigint,
	valorizacion numeric,
	estado_cpt character varying(1),
	ubicacion_ipress character varying(10),
	digitador text,
	fecha_registro date,
	hora_registro time with time zone,
	id_prestacion_cpt integer
) 
AS $$ 
-- DECLARE
--	v_fecha_inicial DATE := (SELECT tel.fecha_atencion FROM temp_emergencia_local tel order by tel.fecha_atencion limit 1);
BEGIN
RETURN QUERY 

SELECT 
	-- ========== DATOS PACIENTE ==========
	CASE 
		WHEN pcpt.origen = 'CONSULTA' THEN 1
		WHEN pcpt.origen = 'ATENCION EN EMERGENCIA' THEN 2
		WHEN pcpt.origen = 'HOSPITALIZACION' THEN 3 
	END AS tipo_atencion,
	SUBSTRING(hc.numero_historia_clinica , 3, 6)as historia,
	gr.descripcion_corta as grado_paciente,
	tper.descripcion as situacion_paciente,
	p.codigo_tipo_documento as tipo_documento_paciente, --LLAVE
	CASE 
		WHEN p.codigo_tipo_documento = 1 THEN SUBSTRING(p.numero_documento, 3, 8)
		WHEN p.codigo_tipo_documento = 2 THEN SUBSTRING(p.numero_documento, 2, 9)
		ELSE SUBSTRING(p.numero_documento, 2, 9) 
	END as numero_documento_paciente, --LLAVE 
	p.apellido_paterno as apellido_paterno_paciente,
	p.apellido_materno as apellido_materno_paciente,
	p.nombres as nombres_paciente,
	p.fecha_nacimiento AS fecha_nacimiento,
	DATE_PART('year', age(pcpt.fecha_consulta, p.fecha_nacimiento)) as edad,
	DATE_PART('month', age(pcpt.fecha_consulta, p.fecha_nacimiento)) as meses,
	DATE_PART('day', age(pcpt.fecha_consulta, p.fecha_nacimiento)) as dias

	-- == UBIGEO PACIENTE ==
	, (case when p.id_distrito is not null then SUBSTRING(dis.codigo, 1, 2) else SUBSTRING(disr.codigo, 1, 2) end ) as ubigeo_departamento	
	, (case when p.id_distrito is not null then dep.descripcion else depa.descripcion end ) as departamento	
	, (case when p.id_distrito is not null then SUBSTRING(dis.codigo, 3, 2) else SUBSTRING(disr.codigo, 3, 2) end ) as ubigeo_provincia
	, (case when p.id_distrito is not null then prov.descripcion else provi.descripcion end ) as provincia		
	, (case when p.id_distrito is not null then SUBSTRING(dis.codigo, 5, 2) else SUBSTRING(disr.codigo, 5, 2) end ) as ubigeo_distrito
	, (case when p.id_distrito is not null then dis.descripcion else disr.descripcion end ) as distrito,
	-- == FIN UBIGEO PACIENTE ==
	p.codigo_genero as genero_paciente,
	CASE 
		WHEN p.id_parentesco = 1 THEN 1 
		WHEN p.id_parentesco = 9 THEN 3 
		ELSE 2 
	END AS condicion_asegurado,	
	p.id_parentesco,
	par.descripcion as parentesco_paciente,

	-- ========== ==========
		
	-- ========== DATOS IPRESS ========== 
		
	TRIM('00013591') AS codigo_ipress, -- LLAVE
	TRIM('HOSPITAL NACIONAL PNP LUIS N SAENZ') AS nombre_ipress, --LLAVE.
	CASE
		when pcpt.condicion_cpt_ipress='N' then 'NUEVO' 
		when pcpt.condicion_cpt_ipress='C' then 'CONTINUADOR'
		when pcpt.condicion_cpt_ipress='R' then 'REINGRESO' 
	END as condicion_ipress,

	-- ========== ==========
		
	-- ========== DATOS SERVICIO ========== 
	
	COALESCE(div.descripcion, '') as division_hcentral,
	COALESCE(shc.upss, '') as upss_servicio,
	COALESCE(shc.descripcion, '') as upss_descripcion,
	CASE
		when pcpt.condicion_cpt_upss='N' then 'NUEVO' 
		when pcpt.condicion_cpt_upss='C' then 'CONTINUADOR'
		when pcpt.condicion_cpt_upss='R' then 'REINGRESO' 
	END as condicion_servicio,
	pcpt.fecha_consulta as fecha_atencion, --LLAVE
	CAST(null AS DATE) as fecha_alta, -- LLAVE

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
	m.rne,
	--PROFESION_GENERAL
	CASE 
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
	END as profesion_responsable, -- LLAVE

	CASE 
		WHEN pcpt.origen IN ('ATENCION EN EMERGENCIA','HOSPITALIZACION') THEN
			CASE 
				WHEN m.especialidad_medico = 'OBSTETRA' OR m.id_especialidad_med IN (105, 362) THEN '00'
				ELSE '01'
			END
		ELSE ''
	END AS especialidad_responsable, -- LLAVE
	prcpt.codigo_alta  AS circunstancia_alta,

	-- ========== ==========
		
	-- ========== DATOS DIAGNÓSTICOS ========== 
	
	(CASE 
		when dcpt.tipo_diagnostico_cpt = 'P - PRESUNTIVO' then '1' 
		when dcpt.tipo_diagnostico_cpt = 'D - DEFINITIVO' then '2'
		when dcpt.tipo_diagnostico_cpt = 'R - REPETITIVO' then '3' 
	END) as tipo_diagnostico,
	c.codigo as codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,

	-- ========== ==========
		
	-- ========== DATOS PROCEDIMIENTOS ========== 

	c2.cod_cpt as codigo_procedimiento,
	UPPER(c2.descripcioncpt) as descripcion_procedimiento,
	SUM(COALESCE(prcpt.cantidad_registro, 1)) as suma_cantidad_registro,
	--c2.nivel_3 as valorizacion,
	(SUM(COALESCE(prcpt.cantidad_registro, 1)) * c2.nivel_3) as valorizacion_total,
	C2.estado as estado_cpt,
	pcpt.ubicacion_ipress as ubicacion_ipress,

	-- ========== ==========
	
	-- ========== DATOS DIGITACIÓN ========== 
	
	pu.apellido_paterno || ' '||  pu.apellido_materno || ' '||  pu.nombres as digitador,
	pcpt.fecha_registro,
	pcpt.hora_registro,
	pcpt.id_prestacion_cpt
		
	FROM prestacion_cpt pcpt
		INNER JOIN persona p on pcpt.id_persona = p.id_persona		
		INNER JOIN medico m on m.codigo_medico = pcpt.codigo_medico	
		INNER JOIN persona pm ON m.id_persona = pm.id_persona
		LEFT JOIN historia_clinica hc ON p.id_persona = hc.id_persona
		LEFT JOIN parentesco parm on parm.id_parentesco=pm.id_parentesco	
		LEFT JOIN medico mrx on mrx.codigo_medico = pcpt.codigo_medico_rayosx
		LEFT JOIN persona pmrx ON mrx.id_persona = pmrx.id_persona
		INNER JOIN usuario u on u.codigo_usuario=pcpt.codigo_usuario
		INNER JOIN persona pu on u.id_persona=pu.id_persona	
		INNER JOIN diagnostico_cpt dcpt ON pcpt.id_prestacion_cpt = dcpt.id_prestacion_cpt AND dcpt.estado = 'N'
		INNER JOIN cie10 c ON c.id_cie10 = dcpt.id_cie10
		LEFT JOIN procedimiento_cpt prcpt ON dcpt.id_diagnostico_cpt = prcpt.id_diagnostico_cpt
		INNER JOIN cpt c2 ON prcpt.id_cpt = c2.id_cpt
		LEFT JOIN servicio_hcentral shc ON pcpt.id_servicio_hcentral = shc.id_servicio
		LEFT JOIN departamento_hcentral deph on deph.id_dep_hcentral=shc.id_dep_hcentral
		LEFT JOIN division_hcentral div on div.id_div_hcentral=deph.id_div_hcentral
		LEFT JOIN parentesco par on par.id_parentesco=p.id_parentesco	
		LEFT JOIN titular titu on titu.id_titular=p.id_titular
		LEFT JOIN tipo_persona tper on tper.id_tipo_persona=titu.id_tipo_persona
		LEFT JOIN grado gr on gr.id_grado=titu.id_grado

		LEFT JOIN distrito dis on dis.id_distrito = p.id_distrito
			LEFT JOIN provincia prov on prov.id_provincia = dis.id_provincia
			LEFT JOIN departamento dep on dep.id_departamento = prov.id_departamento
		LEFT JOIN distrito disr on disr.id_distrito = p.id_distrito_referencial
			LEFT JOIN provincia provi on provi.id_provincia = disr.id_provincia
			LEFT JOIN departamento depa on depa.id_departamento = provi.id_departamento

	WHERE
		pcpt.estado = 'N' -- PREGUNTAR N: activo, I: inactivo
		-- and pcpt.fecha_registro <= '20230304' -- SUGERIR
		AND
		CASE
			WHEN p_tipo_atencion = 1 THEN -- 'CONSULTA'
				( 
				pcpt.origen = 'CONSULTA'
				AND
				pcpt.fecha_consulta::date between p_inicio_periodo and p_fin_periodo
				)
			
			WHEN p_tipo_atencion = 2 THEN -- 'ATENCION EN EMERGENCIA'
				(
				pcpt.origen = 'ATENCION EN EMERGENCIA'
				AND
				pcpt.fecha_consulta::date <= p_fin_periodo
				AND 
				p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_emergencia_local et)
				)
			
			WHEN p_tipo_atencion = 22 THEN -- 'ATENCION EN EMERGENCIA'
				(
				pcpt.origen = 'ATENCION EN EMERGENCIA'
				AND
				pcpt.fecha_consulta::date <= p_fin_periodo
				AND
				p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_emergencia_sigesapol_estancia et)
				)
			WHEN p_tipo_atencion = 3 THEN -- 'HOSPITALIZACION'
				(
				pcpt.origen = 'HOSPITALIZACION'
				AND
				pcpt.fecha_consulta::date <= p_fin_periodo
				AND 
				p.numero_documento IN (SELECT DISTINCT LPAD(ht.sp_numero_documento_paciente, 10, '0') as numero_documento_paciente FROM temp_hospitalizacion_local ht)
				)
			WHEN p_tipo_atencion = 4 THEN -- Comodín 'TODO'
				(
				pcpt.fecha_consulta::date between p_inicio_periodo and p_fin_periodo
				--AND 
				--c2.cod_cpt not in('99231','99231.15','99295','99263') -- desde abril -- No se aplica para poder hallar inconsistencias, de darse el caso
				)
		END
	GROUP BY
		pcpt.origen,
		hc.numero_historia_clinica, gr.descripcion_corta, tper.descripcion,
		p.codigo_tipo_documento, p.numero_documento, p.apellido_paterno, p.apellido_materno, p.nombres, 
		p.fecha_nacimiento, p.codigo_genero, 
		p.id_parentesco, par.descripcion, --parm.id_parentesco, p.numero_hijo,
		shc.upss, shc.descripcion, div.descripcion, pcpt.fecha_consulta,
		pm.codigo_tipo_documento, pm.numero_documento, pm.apellido_paterno, pm.apellido_materno, pm.nombres, 
		m.id_profesion, m.id_especialidad_med, m.especialidad_medico, m.numero_colegio_medico, m.rne, prcpt.codigo_alta,
		dcpt.tipo_diagnostico_cpt, c.codigo, c.descripcion, 
		c2.cod_cpt, c2.descripcioncpt, prcpt.cantidad_registro, c2.nivel_3, C2.estado, pcpt.ubicacion_ipress,
		pu.apellido_paterno, pu.apellido_materno, pu.nombres,
		pcpt.fecha_registro, pcpt.hora_registro, pcpt.id_prestacion_cpt,

		p.id_distrito, dis.codigo, disr.codigo,
		dep.descripcion, depa.descripcion,
		prov.descripcion, provi.descripcion, dis.descripcion, disr.descripcion

	ORDER BY 
	pcpt.fecha_consulta, pcpt.origen, p.numero_documento;

END; $$

LANGUAGE 'plpgsql';

-- SELECT * FROM sp_procedimientos_segun_tipo_atencion('20240101', '20240131', 22) limit 5;

-- SELECT * FROM sp_procedimientos_segun_tipo_atencion('20190101', '20231031', 4) where numero_documento_paciente = '72950598'

/*
FORMATO EN EXCEL
Números de documentos y código ipress: 8
UPSS: 6
Profesión: 2
Especialidad: 2
*/
