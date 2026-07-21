-- ============================================================================
-- 01_PARCHES_funciones.sql
-- Correcciones a las funciones del pipeline de tramas Nivel 3 (LNS)
-- Basadas en los hallazgos verificados con datos (rondas 1-3 de checks).
--
-- PARCHE A -> correr en BD SIGESAPOL
-- PARCHE B -> correr en BD CPT
-- PARCHE C -> correr en BD CPT (preventivo, función legado)
-- PARCHE D -> correr en BD CPT (v3.3, crítico: fuga de período entre estancias)
--
-- Cada parche es un CREATE OR REPLACE completo: se puede correr las veces
-- que sea necesario sin romper nada.
-- ============================================================================


-- ============================================================================
-- PARCHE A [SIGESAPOL]
-- sp_sigesapol_diagnostico_en_prestacion_emergencia
--
-- FIX: excluir diagnósticos anulados (estado <> 1) y eliminados lógicamente
--      (deleted_at poblado). Verificado con CHECK 10: existen 943 eliminados
--      lógicos + 1,187 con estado 0 + 46 con estado 2 que hoy entrarían.
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_sigesapol_diagnostico_en_prestacion_emergencia(
	p_id_prestacion_emergencia integer
)
RETURNS TABLE (
	id_prestacion integer,
	tipo_diagnostico character varying(1),
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	orden integer
)
AS $$
BEGIN
RETURN QUERY

SELECT
	dx.id_prestacion,
	dx.id_tipo_diagnostico::character varying(1) as tipo_diagnostico,
	cie.codigo AS codigo_diagnostico,
	UPPER(regexp_replace(cie.nombre, '\r|\n|\t', '', 'g')) as descripcion_diagnostico,
	ROW_NUMBER() OVER(ORDER BY dx.id)::integer AS orden
FROM receta_diagnosticos dx
INNER JOIN diagnosticos cie ON cie.id = dx.id_diagnostico
WHERE dx.id_prestacion = p_id_prestacion_emergencia
	AND dx.estado = 1              -- FIX: solo diagnósticos activos (CHECK 10)
	AND dx.deleted_at IS NULL;     -- FIX: excluir eliminados lógicamente (CHECK 10)
END; $$

language 'plpgsql';


-- ============================================================================
-- PARCHE B [CPT]
-- sp_laboratorio_segun_tipo_atencion
--
-- FIX 1 (crítico): normalización del documento del PACIENTE según tipo de
--        documento, igual que las queries 01/02/03. Antes aplicaba
--        SUBSTRING(3,8) a todos y mutilaba los carnés de extranjería
--        (verificado con CHECK 07: CE guarda '0V18580183' y debe quedar
--        'V18580183', no '18580183'), generando exámenes huérfanos que no
--        cruzan con las otras tramas.
-- FIX 2: condicion_asegurado consistente con las queries 02/03
--        (1 -> 1 titular, 9 -> 3 civil, resto -> 2 familiar).
--        Antes el valor 3 nunca se generaba en laboratorio.
-- FIX 3: nuevo modo 22 (emergencia con padrón SIGESAPOL), igual que en la
--        función 03. ELIMINA la edición manual de la función entre corridas
--        que menciona el comentario del archivo 05. El modo 2 queda para el
--        padrón local histórico (temp_emergencia_local).
-- FIX 4: RIGHT JOINs reescritos como INNER JOIN. El comportamiento efectivo
--        era ya de INNER (los filtros del WHERE anulaban el lado derecho),
--        pero la redacción era confusa y propensa a error.
-- FIX 5: r.cantidad removido del GROUP BY. Antes, un mismo examen con
--        cantidades distintas (2 y 3) salía en DOS filas en lugar de una
--        consolidada con 5, contradiciendo la intención del SUM.
-- FIX 6 (v3.3, crítico): las ramas EMERGENCIA/HOSPITALIZACION (2/22/3) solo
--        exigían "t.fecha_muestra <= p_fin_periodo" (sin cota inferior) más
--        "documento con ALGUNA estancia en el período" — esto traía TODO el
--        historial de laboratorio de ese documento con esa fecha tope, sin
--        acotar a la estancia específica. Verificado con julio 2025: el
--        equivalente en sp_procedimientos_segun_tipo_atencion trajo filas con
--        fecha_atencion desde 2018 (77,350 de 101,467 filas, 76%, fuera de
--        julio) para pacientes con una hospitalización distinta y ya cerrada
--        años atrás. Regla de negocio confirmada: un examen de laboratorio
--        de hospitalización/emergencia factura en el período del ALTA de ESA
--        estancia, incluso si la fecha de la muestra es de un mes anterior
--        (estadía que cruza de mes) — pero NUNCA de una estancia distinta,
--        ya cerrada, del mismo paciente. Corregido acotando por EXISTS a la
--        ventana [ingreso, alta] de la estancia concreta (misma tabla que ya
--        se usaba para el join por documento), en vez de "IN (SELECT
--        documento de cualquier estancia del período)".
--
-- NOTA: la estructura de columnas de salida NO cambia (compatibilidad con
--       el armado en Excel). El intercambio fecha_muestra/fecha_registro
--       se mantiene tal cual ("según vista recibida").
-- VALIDACIÓN SUGERIDA: correr un mes con la versión anterior y esta, y
--       comparar conteos y sumas de valorización antes de adoptarla.
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_laboratorio_segun_tipo_atencion(
	p_inicio_periodo DATE,
	p_fin_periodo DATE,
	p_tipo_atencion INTEGER 	-- 1 CONSULTA | 2 EMERGENCIA (padrón local) | 22 EMERGENCIA (padrón SIGESAPOL) | 3 HOSPITALIZACION | 4 TODO
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
	CASE                                                          -- FIX 1
		WHEN p.codigo_tipo_documento = 1 THEN SUBSTRING(p.numero_documento, 3, 8)
		WHEN p.codigo_tipo_documento = 2 THEN SUBSTRING(p.numero_documento, 2, 9)
		ELSE SUBSTRING(p.numero_documento, 2, 9)
	END AS numero_documento_paciente,
	p.apellido_paterno AS apellido_paterno_paciente,
	p.apellido_materno AS apellido_materno_paciente,
	p.nombres AS nombres_paciente,
	p.fecha_nacimiento,
	DATE_PART('year', age(t.fecha_muestra, p.fecha_nacimiento)) as edad,
	DATE_PART('month', age(t.fecha_muestra, p.fecha_nacimiento)) as meses,
	DATE_PART('day', age(t.fecha_muestra, p.fecha_nacimiento)) as dias,
	p.codigo_genero AS genero_paciente,
	CASE                                                          -- FIX 2
	    WHEN p.id_parentesco = 1 THEN 1
	    WHEN p.id_parentesco = 9 THEN 3
	    ELSE 2
	END AS condicion_asegurado,

	-- ========== DATOS IPRESS - SERVICIO ==========
	o.codigo_ipress,
	o.nombre AS nombre_ipress,
	COALESCE(div.descripcion, ''::character varying) AS descripcion_division,
	w.upss AS upss_codigo,
	w.descripcion AS upss_descripcion,
	t.fecha_muestra AS fecha_atencion, -- según vista recibida
	t.fecha_registro AS fecha_muestra, -- según vista recibida
	CAST(null AS DATE) as fecha_egreso,

	-- ========== DATOS MEDICO ==========
	pm.codigo_tipo_documento as tipo_documento_responsable,
	CASE
		WHEN pm.codigo_tipo_documento = 1 THEN SUBSTRING(pm.numero_documento, 3, 8)
		WHEN pm.codigo_tipo_documento = 2 THEN SUBSTRING(pm.numero_documento, 2, 9)
		ELSE SUBSTRING(pm.numero_documento, 2, 9)
	END as numero_documento_responsable,
	pm.apellido_paterno as apellido_paterno_responsable,
	pm.apellido_materno as apellido_materno_responsable,
	pm.nombres as nombres_responsable,
	m.numero_colegio_medico,
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
	''::character varying AS circunstancia_alta,

	-- ========== DATOS DIAGNÓSTICOS ==========
	CASE
	    WHEN d.tipo_diagnostico::text = 'P - PRESUNTIVO'::text THEN '1'
	    WHEN d.tipo_diagnostico::text = 'D - DEFINITIVO'::text THEN '2'
	    WHEN d.tipo_diagnostico::text = 'R - REPETITIVO'::text THEN '3'
	END AS tipo_diagnostico,
	e.codigo AS codigo_diagnostico,
	UPPER(e.descripcion) AS descripcion_diagnostico,

	-- ========== DATOS PROCEDIMIENTOS ==========
	x.cod_cpt AS codigo_procedimiento,
	UPPER(x.descripcioncpt) AS descripcion_procedimiento,
	SUM(COALESCE(r.cantidad::integer, 1)) AS suma_cantidad_registro,
	(SUM(COALESCE(r.cantidad::integer, 1)) * x.nivel_3) AS valorizacion_total,
	x.estado AS estado_cpt,

	-- ========== DATOS DIGITACIÓN ==========
	(((pu.apellido_paterno::text || ' '::text) || pu.apellido_materno::text) || ' '::text) || pu.nombres::text AS digitador,
	t.fecha_registro,
	t.hora_registro,
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
	INNER JOIN diagnostico_laboratorio d ON d.id_prestacion_laboratorio = t.id_prestacion_laboratorio   -- FIX 4
	JOIN cie10 e ON d.id_cie10 = e.id_cie10
	INNER JOIN procedimiento_laboratorio r ON d.id_diagnostico_laboratorio = r.id_diagnostico_laboratorio  -- FIX 4
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
			AND
			t.fecha_registro::DATE between p_inicio_periodo and p_fin_periodo
			)
		WHEN p_tipo_atencion = 2 THEN -- 'EMERGENCIA' con padrón LOCAL (histórico)
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND EXISTS (                                                   -- FIX 6
				SELECT 1 FROM temp_emergencia_local et
				WHERE LPAD(et.sp_numero_documento_paciente, 10, '0') = p.numero_documento
				  AND t.fecha_muestra::date BETWEEN et.sp_fecha_atencion::date AND et.sp_fecha_alta_emergencia::date
			)
			)
		WHEN p_tipo_atencion = 22 THEN -- 'EMERGENCIA' con padrón SIGESAPOL       -- FIX 3
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND EXISTS (                                                   -- FIX 6
				SELECT 1 FROM temp_emergencia_sigesapol_estancia et
				WHERE LPAD(et.sp_numero_documento_paciente, 10, '0') = p.numero_documento
				  AND t.fecha_muestra::date BETWEEN et.sp_fecha_atencion::date AND et.sp_fecha_alta_emergencia::date
			)
			)
		WHEN p_tipo_atencion = 3 THEN -- 'HOSPITALIZACION'
			(
			t.origen = 'HOSPITALIZACION'
			AND EXISTS (                                                   -- FIX 6
				SELECT 1 FROM temp_hospitalizacion_local ht
				WHERE LPAD(ht.sp_numero_documento_paciente, 10, '0') = p.numero_documento
				  AND t.fecha_muestra::date BETWEEN ht.sp_fecha_atencion::date AND ht.sp_fecha_alta::date
			)
			)
		WHEN p_tipo_atencion = 4 THEN -- Comodín 'TODO'
			(
			t.fecha_registro::DATE between p_inicio_periodo and p_fin_periodo
			)
	END

GROUP BY
	t.origen, hc.numero_historia_clinica,
	td.codigo_tipo_documento, p.codigo_tipo_documento, p.numero_documento,
	p.apellido_paterno, p.apellido_materno, p.nombres,
	p.fecha_nacimiento, p.codigo_genero, p.id_parentesco,
	o.codigo_ipress, o.nombre, div.descripcion,
	w.upss, w.descripcion,
	t.fecha_muestra, t.fecha_registro,
	pm.numero_documento, pm.apellido_paterno, pm.apellido_materno, pm.nombres,
	m.id_profesion, m.numero_colegio_medico, m.especialidad_medico, m.id_especialidad_med,
	d.tipo_diagnostico, e.codigo, e.descripcion,
	x.cod_cpt, x.descripcioncpt, x.nivel_3, x.estado,      -- FIX 5: r.cantidad removido
	pm.codigo_tipo_documento,
	pu.apellido_paterno, pu.apellido_materno, pu.nombres,
	t.id_prestacion_laboratorio, t.hora_registro, t.secuencia

ORDER BY t.fecha_registro, p.numero_documento;

END; $$

LANGUAGE 'plpgsql';


-- ============================================================================
-- PARCHE C [CPT] - PREVENTIVO (función legado)
-- sp_diagnostico_en_prestacion_emergencia
--
-- La emergencia CPT no tiene registros desde antes de 2024 (CHECK 13a), así
-- que este parche NO afecta el alcance 2024-2026. Se aplica por higiene:
--
-- FIX 1: el CASE comparaba contra 'P - PRESUNTIVO' pero la columna tipo es
--        varchar(1) y guarda solo 'D' o vacío (CHECK 01). Se compara por letra.
-- FIX 2: el ROW_NUMBER ordenaba por id_atencion_emergencia (constante dentro
--        de la prestación => orden aleatorio entre corridas). Se ordena por
--        el PK id_diagnostico (orden de registro, determinístico).
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_diagnostico_en_prestacion_emergencia(
	p_id_prestacion_emergencia integer
)
RETURNS TABLE (
	id_prestacion integer,
	tipo_diagnostico character varying(1),
	codigo_diagnostico character varying(10),
	descripcion_diagnostico text,
	orden integer
)
AS $$
BEGIN
RETURN QUERY

SELECT
	dx.id_atencion_emergencia AS id_prestacion,
	(CASE dx.tipo                                              -- FIX 1
		WHEN 'P' THEN '1'
		WHEN 'D' THEN '2'
		WHEN 'R' THEN '3'
		ELSE '2' -- Se indica que se coloque definitivo
	END)::character varying(1) as tipo_diagnostico,
	c.codigo AS codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,
	ROW_NUMBER() OVER(
		PARTITION BY dx.id_atencion_emergencia
		ORDER BY dx.id_diagnostico                             -- FIX 2
	)::integer AS orden
FROM diagnostico dx
INNER JOIN cie10 c ON dx.id_cie10 = c.id_cie10
WHERE dx.id_atencion_emergencia = p_id_prestacion_emergencia;
END; $$

language 'plpgsql';


-- ============================================================================
-- PARCHE D [CPT]
-- sp_procedimientos_segun_tipo_atencion
--
-- Función legado sin PARCHE previo en este repo (su DDL vivía solo en la BD,
-- ver 00_RUTA_jul_dic_2025.md). Encontrada rota al implementar A7-cobertura
-- (v3.3, misión de corrección de período): mismo bug de FIX 6 de PARCHE B,
-- en la función hermana de procedimientos (no de laboratorio).
--
-- FIX 1 (crítico): las ramas EMERGENCIA/HOSPITALIZACION (2/22/3) solo exigían
--        "pcpt.fecha_consulta::date <= p_fin_periodo" (sin cota inferior) más
--        "documento con ALGUNA estancia en el período" — traía TODO el
--        historial de procedimientos de ese documento con esa fecha tope,
--        sin acotar a la estancia específica. Verificado con julio 2025:
--        temp_bdt_hospitalizacion_local trajo 101,467 filas con fecha_atencion
--        entre 2018-03-01 y 2025-07-31; solo 24,117 (24%) caían realmente en
--        julio — el resto eran procedimientos de hospitalizaciones DISTINTAS
--        y ya cerradas del mismo paciente. Coincide en forma y magnitud con
--        el síntoma original de la misión ("septiembre trae 666/2,081/3,612
--        filas de mayo/junio/julio"). Regla de negocio confirmada por el
--        equipo: un procedimiento de hospitalización/emergencia factura en
--        el período del ALTA de ESA estancia, incluso si su fecha propia es
--        de un mes anterior (estadía que cruza de mes) — pero NUNCA de una
--        estancia distinta, ya cerrada, del mismo paciente. Corregido
--        acotando por EXISTS a la ventana [ingreso, alta] de la estancia
--        concreta, igual que PARCHE B FIX 6.
--
-- NOTA: la estructura de columnas de salida NO cambia. Únicamente se
--       reescribe el WHERE CASE de las ramas 2/22/3; el resto de la función
--       (SELECT, JOINs, GROUP BY, ORDER BY) es una copia idéntica de la
--       versión previamente instalada (verificada con pg_get_functiondef).
-- ============================================================================
CREATE OR REPLACE FUNCTION sp_procedimientos_segun_tipo_atencion(p_inicio_periodo date, p_fin_periodo date, p_tipo_atencion integer)
 RETURNS TABLE(tipo_atencion integer, historia text, grado_paciente character varying, situacion_paciente character varying, tipo_documento_paciente integer, numero_documento_paciente text, apellido_paterno_paciente character varying, apellido_materno_paciente character varying, nombres_paciente character varying, fecha_nacimiento date, edad double precision, meses double precision, dias double precision, ubigeo_departamento text, departamento_paciente character varying, ubigeo_provincia text, provincia_paciente character varying, ubigeo_distrito text, distrito_paciente character varying, genero_paciente integer, condicion_asegurado integer, id_parentesco integer, parentesco_paciente character varying, codigo_ipress text, nombre_ipress text, condicion_ipress text, division_hcentral character varying, upss_servicio character varying, upss_descripcion character varying, condicion_servicio text, fecha_atencion date, fecha_alta date, tipo_documento_responsable integer, numero_documento_responsable text, apellido_paterno_responsable character varying, apellido_materno_responsable character varying, nombres_responsable character varying, numero_colegio_medico character varying, rne character varying, profesion_responsable text, especialidad_responsable text, circunstancia_alta smallint, tipo_diagnostico text, codigo_diagnostico character varying, descripcion_diagnostico text, codigo_procedimiento character varying, descripcion_procedimiento text, suma_cantidad_registro bigint, valorizacion numeric, estado_cpt character varying, ubicacion_ipress character varying, digitador text, fecha_registro date, hora_registro time with time zone, id_prestacion_cpt integer)
 LANGUAGE plpgsql
AS $function$
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

	-- ========== DATOS IPRESS ==========

	TRIM('00013591') AS codigo_ipress, -- LLAVE
	TRIM('HOSPITAL NACIONAL PNP LUIS N SAENZ') AS nombre_ipress, --LLAVE.
	CASE
		when pcpt.condicion_cpt_ipress='N' then 'NUEVO'
		when pcpt.condicion_cpt_ipress='C' then 'CONTINUADOR'
		when pcpt.condicion_cpt_ipress='R' then 'REINGRESO'
	END as condicion_ipress,

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

	-- ========== DATOS DIAGNÓSTICOS ==========

	(CASE
		when dcpt.tipo_diagnostico_cpt = 'P - PRESUNTIVO' then '1'
		when dcpt.tipo_diagnostico_cpt = 'D - DEFINITIVO' then '2'
		when dcpt.tipo_diagnostico_cpt = 'R - REPETITIVO' then '3'
	END) as tipo_diagnostico,
	c.codigo as codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,

	-- ========== DATOS PROCEDIMIENTOS ==========

	c2.cod_cpt as codigo_procedimiento,
	UPPER(c2.descripcioncpt) as descripcion_procedimiento,
	SUM(COALESCE(prcpt.cantidad_registro, 1)) as suma_cantidad_registro,
	(SUM(COALESCE(prcpt.cantidad_registro, 1)) * c2.nivel_3) as valorizacion_total,
	C2.estado as estado_cpt,
	pcpt.ubicacion_ipress as ubicacion_ipress,

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
				AND EXISTS (                                                   -- FIX 1
					SELECT 1 FROM temp_emergencia_local et
					WHERE LPAD(et.sp_numero_documento_paciente, 10, '0') = p.numero_documento
					  AND pcpt.fecha_consulta::date BETWEEN et.sp_fecha_atencion::date AND et.sp_fecha_alta_emergencia::date
				)
				)

			WHEN p_tipo_atencion = 22 THEN -- 'ATENCION EN EMERGENCIA'
				(
				pcpt.origen = 'ATENCION EN EMERGENCIA'
				AND EXISTS (                                                   -- FIX 1
					SELECT 1 FROM temp_emergencia_sigesapol_estancia et
					WHERE LPAD(et.sp_numero_documento_paciente, 10, '0') = p.numero_documento
					  AND pcpt.fecha_consulta::date BETWEEN et.sp_fecha_atencion::date AND et.sp_fecha_alta_emergencia::date
				)
				)
			WHEN p_tipo_atencion = 3 THEN -- 'HOSPITALIZACION'
				(
				pcpt.origen = 'HOSPITALIZACION'
				AND EXISTS (                                                   -- FIX 1
					SELECT 1 FROM temp_hospitalizacion_local ht
					WHERE LPAD(ht.sp_numero_documento_paciente, 10, '0') = p.numero_documento
					  AND pcpt.fecha_consulta::date BETWEEN ht.sp_fecha_atencion::date AND ht.sp_fecha_alta::date
				)
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

END; $function$;
