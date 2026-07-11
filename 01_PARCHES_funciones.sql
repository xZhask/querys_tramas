-- ============================================================================
-- 01_PARCHES_funciones.sql
-- Correcciones a las funciones del pipeline de tramas Nivel 3 (LNS)
-- Basadas en los hallazgos verificados con datos (rondas 1-3 de checks).
--
-- PARCHE A -> correr en BD SIGESAPOL
-- PARCHE B -> correr en BD CPT
-- PARCHE C -> correr en BD CPT (preventivo, función legado)
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
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') FROM temp_emergencia_local et)
			)
		WHEN p_tipo_atencion = 22 THEN -- 'EMERGENCIA' con padrón SIGESAPOL       -- FIX 3
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') FROM temp_emergencia_sigesapol_estancia et)
			)
		WHEN p_tipo_atencion = 3 THEN -- 'HOSPITALIZACION'
			(
			t.origen = 'HOSPITALIZACION'
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(ht.sp_numero_documento_paciente, 10, '0') FROM temp_hospitalizacion_local ht)
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
