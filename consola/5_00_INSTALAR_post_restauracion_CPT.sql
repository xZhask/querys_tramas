-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 00_INSTALAR_post_restauracion_CPT.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================

-- ============================================================================
-- 00_INSTALAR_post_restauracion_CPT.sql
-- Deja un backup recién restaurado de la BD CPT (db_cpt_junio26) operativo en
-- una sola corrida. IDEMPOTENTE: se puede correr las veces que sea necesario
-- sin romper nada ni duplicar datos.
--
-- REGLA OPERATIVA: tras restaurar cualquier backup de esta BD, correr este
-- script ANTES de todo (antes de 02/03/08 o cualquier paso de FASE MENSUAL).
--
-- Qué instala:
--   1. Parche B [CPT] — sp_laboratorio_segun_tipo_atencion (corregida)
--   2. Parche C [CPT] — sp_diagnostico_en_prestacion_emergencia (preventivo)
--   3. cfg_fuente_canonica con sus dos vigencias (jul-sep CPT / oct-dic~ SIGESAPOL)
--   4. Verificación final ✓/✗ de funciones y tablas esperadas
--
-- Qué NO instala (debe venir del backup restaurado, no se recrea aquí porque
-- su DDL vive en el paquete original de funciones, fuera de este repo):
--   - 00_sp_diagnostico_en_prestacion_cpt
--   - 02_SP_HOSPITALIZACION_3_diagnosticos
--   - 03_SP_PROCEDIMIENTOS_SEGUN_TIPO_ATENCION
-- Si la verificación final marca ✗ en alguna de estas, el backup restaurado
-- está incompleto y hay que re-obtenerlo o correr su script original a mano.
-- ============================================================================


-- ============================================================================
-- PARCHE B [CPT] — sp_laboratorio_segun_tipo_atencion
-- (ver justificación completa de cada FIX en 01_PARCHES_funciones.sql)
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
	CASE
	    WHEN t.origen::text = 'CONSULTA'::text THEN '1'::text
	    WHEN t.origen::text = 'ATENCION EN EMERGENCIA'::text THEN '2'::text
	    WHEN t.origen::text = 'HOSPITALIZACION'::text THEN '3'::text
	    ELSE NULL::text
	END AS tipo_atencion,
	SUBSTRING(hc.numero_historia_clinica , 3, 6) as historia,
	td.codigo_tipo_documento AS tipo_documento_paciente,
	CASE
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
	CASE
	    WHEN p.id_parentesco = 1 THEN 1
	    WHEN p.id_parentesco = 9 THEN 3
	    ELSE 2
	END AS condicion_asegurado,

	o.codigo_ipress,
	o.nombre AS nombre_ipress,
	COALESCE(div.descripcion, ''::character varying) AS descripcion_division,
	w.upss AS upss_codigo,
	w.descripcion AS upss_descripcion,
	t.fecha_muestra AS fecha_atencion,
	t.fecha_registro AS fecha_muestra,
	CAST(null AS DATE) as fecha_egreso,

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

	CASE
	    WHEN d.tipo_diagnostico::text = 'P - PRESUNTIVO'::text THEN '1'
	    WHEN d.tipo_diagnostico::text = 'D - DEFINITIVO'::text THEN '2'
	    WHEN d.tipo_diagnostico::text = 'R - REPETITIVO'::text THEN '3'
	END AS tipo_diagnostico,
	e.codigo AS codigo_diagnostico,
	UPPER(e.descripcion) AS descripcion_diagnostico,

	x.cod_cpt AS codigo_procedimiento,
	UPPER(x.descripcioncpt) AS descripcion_procedimiento,
	SUM(COALESCE(r.cantidad::integer, 1)) AS suma_cantidad_registro,
	(SUM(COALESCE(r.cantidad::integer, 1)) * x.nivel_3) AS valorizacion_total,
	x.estado AS estado_cpt,

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
	INNER JOIN diagnostico_laboratorio d ON d.id_prestacion_laboratorio = t.id_prestacion_laboratorio
	JOIN cie10 e ON d.id_cie10 = e.id_cie10
	INNER JOIN procedimiento_laboratorio r ON d.id_diagnostico_laboratorio = r.id_diagnostico_laboratorio
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
		WHEN p_tipo_atencion = 1 THEN
			(
			t.origen = 'CONSULTA'
			AND
			t.fecha_registro::DATE between p_inicio_periodo and p_fin_periodo
			)
		WHEN p_tipo_atencion = 2 THEN
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') FROM temp_emergencia_local et)
			)
		WHEN p_tipo_atencion = 22 THEN
			(
			t.origen = 'ATENCION EN EMERGENCIA'
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(et.sp_numero_documento_paciente, 10, '0') FROM temp_emergencia_sigesapol_estancia et)
			)
		WHEN p_tipo_atencion = 3 THEN
			(
			t.origen = 'HOSPITALIZACION'
			AND t.fecha_muestra <= p_fin_periodo
			AND
			p.numero_documento IN (SELECT DISTINCT LPAD(ht.sp_numero_documento_paciente, 10, '0') FROM temp_hospitalizacion_local ht)
			)
		WHEN p_tipo_atencion = 4 THEN
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
	x.cod_cpt, x.descripcioncpt, x.nivel_3, x.estado,
	pm.codigo_tipo_documento,
	pu.apellido_paterno, pu.apellido_materno, pu.nombres,
	t.id_prestacion_laboratorio, t.hora_registro, t.secuencia

ORDER BY t.fecha_registro, p.numero_documento;

END; $$

LANGUAGE 'plpgsql';


-- ============================================================================
-- PARCHE C [CPT] (preventivo) — sp_diagnostico_en_prestacion_emergencia
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
	(CASE dx.tipo
		WHEN 'P' THEN '1'
		WHEN 'D' THEN '2'
		WHEN 'R' THEN '3'
		ELSE '2'
	END)::character varying(1) as tipo_diagnostico,
	c.codigo AS codigo_diagnostico,
	UPPER(c.descripcion) as descripcion_diagnostico,
	ROW_NUMBER() OVER(
		PARTITION BY dx.id_atencion_emergencia
		ORDER BY dx.id_diagnostico
	)::integer AS orden
FROM diagnostico dx
INNER JOIN cie10 c ON dx.id_cie10 = c.id_cie10
WHERE dx.id_atencion_emergencia = p_id_prestacion_emergencia;
END; $$

language 'plpgsql';


-- ============================================================================
-- cfg_fuente_canonica — dato permanente con vigencias (Parte 2 de 00_RUTA)
-- ============================================================================
CREATE TABLE IF NOT EXISTS cfg_fuente_canonica (
	id serial PRIMARY KEY,
	periodo_desde date NOT NULL,
	periodo_hasta date,               -- NULL = vigente
	fuente text NOT NULL CHECK (fuente IN ('CPT','SIGESAPOL')),
	sustento text NOT NULL,
	registrado_en timestamptz NOT NULL DEFAULT now(),
	UNIQUE (periodo_desde, fuente)
);

INSERT INTO cfg_fuente_canonica (periodo_desde, periodo_hasta, fuente, sustento)
SELECT v.periodo_desde, v.periodo_hasta, v.fuente, v.sustento
FROM (VALUES
	(DATE '2024-01-01', DATE '2025-09-30', 'CPT',
	 'check 23: 99.3% de solapamiento de prestaciones entre CPT y SIGESAPOL en el mismo periodo'),
	(DATE '2025-10-01', NULL::date, 'SIGESAPOL',
	 'crossover checks 15a/16: tras la migracion institucional, SIGESAPOL pasa a ser el sistema de registro predominante del hospital')
) AS v(periodo_desde, periodo_hasta, fuente, sustento)
WHERE NOT EXISTS (
	SELECT 1 FROM cfg_fuente_canonica c
	WHERE c.periodo_desde = v.periodo_desde AND c.fuente = v.fuente
);


-- ============================================================================
-- cfg_ipress_alcance — alcance nivel III (Parte 3): este generador cubre
-- EXCLUSIVAMENTE el Hospital Luis N. Sáenz. Las demás IPRESS (nivel I/II)
-- las trabaja otro equipo con otra base. El filtro es SIEMPRE por
-- código/ID de establecimiento, NUNCA por nombre (LNS tiene dos grafías
-- legítimas en origen: "LUIS N SAENZ" y "LUIS N. SAENZ", ambas válidas).
-- Duplicada en la BD SIGESAPOL (00_INSTALAR_post_restauracion_SIGESAPOL.sql)
-- porque las dos BD no pueden leerse entre sí sin dblink/fdw — mismo patrón
-- que cfg_periodo, que también vive por separado en cada BD.
-- ============================================================================
CREATE TABLE IF NOT EXISTS cfg_ipress_alcance (
	codigo_ipress varchar(10) PRIMARY KEY,
	id_establecimiento_sigesapol integer NOT NULL,
	descripcion text NOT NULL,
	registrado_en timestamptz NOT NULL DEFAULT now()
);

INSERT INTO cfg_ipress_alcance (codigo_ipress, id_establecimiento_sigesapol, descripcion)
SELECT '00013591', 76,
       'Hospital Nacional PNP Luis N. Saenz (nivel III) - unico alcance de este generador; las demas IPRESS (nivel I/II) las trabaja otro equipo con otra base.'
WHERE NOT EXISTS (SELECT 1 FROM cfg_ipress_alcance WHERE codigo_ipress = '00013591');


-- ============================================================================
-- log_alcance_depurado — constancia de filas/montos removidos por IPRESS
-- fuera de alcance en cada extracción (ver CONTEXTO_CANONICO.md §3).
-- Idempotente por (periodo_ini, periodo_fin, tabla): cada script borra su
-- propio período+tabla antes de reinsertar, igual que las temp_*.
-- ============================================================================
CREATE TABLE IF NOT EXISTS log_alcance_depurado (
	periodo_ini date NOT NULL,
	periodo_fin date NOT NULL,
	tabla text NOT NULL,
	codigo_ipress varchar(10),
	nombre_ipress text,
	filas_removidas bigint NOT NULL,
	monto_removido numeric,
	registrado_en timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================
DO $$
DECLARE
	v_check text;
BEGIN
	RAISE NOTICE '=== VERIFICACION INSTALADOR CPT ===';

	v_check := CASE WHEN to_regprocedure('sp_diagnostico_en_prestacion_cpt(integer)') IS NOT NULL
		THEN '✓' ELSE '✗ (falta -- restaurar del paquete original, funcion 00)' END;
	RAISE NOTICE 'sp_diagnostico_en_prestacion_cpt: %', v_check;

	v_check := CASE WHEN to_regprocedure('sp_hospitalizacion_en_periodo(date,date)') IS NOT NULL
		THEN '✓' ELSE '✗ (falta -- restaurar del paquete original, funcion 02)' END;
	RAISE NOTICE 'sp_hospitalizacion_en_periodo: %', v_check;

	v_check := CASE WHEN to_regprocedure('sp_procedimientos_segun_tipo_atencion(date,date,integer)') IS NOT NULL
		THEN '✓' ELSE '✗ (falta -- restaurar del paquete original, funcion 03)' END;
	RAISE NOTICE 'sp_procedimientos_segun_tipo_atencion: %', v_check;

	v_check := CASE WHEN to_regprocedure('sp_laboratorio_segun_tipo_atencion(date,date,integer)') IS NOT NULL
		THEN '✓' ELSE '✗ (Parche B no aplico)' END;
	RAISE NOTICE 'sp_laboratorio_segun_tipo_atencion (Parche B): %', v_check;

	v_check := CASE WHEN to_regprocedure('sp_diagnostico_en_prestacion_emergencia(integer)') IS NOT NULL
		THEN '✓' ELSE '✗ (Parche C no aplico)' END;
	RAISE NOTICE 'sp_diagnostico_en_prestacion_emergencia (Parche C): %', v_check;

	v_check := CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'cfg_fuente_canonica')
		THEN '✓' ELSE '✗ (tabla no se creo)' END;
	RAISE NOTICE 'Tabla cfg_fuente_canonica: %', v_check;

	v_check := CASE WHEN (SELECT COUNT(*) FROM cfg_fuente_canonica) >= 2
		THEN '✓ (' || (SELECT COUNT(*)::text FROM cfg_fuente_canonica) || ' vigencias)'
		ELSE '✗ (faltan vigencias, esperadas >= 2)' END;
	RAISE NOTICE 'Vigencias cargadas en cfg_fuente_canonica: %', v_check;

	v_check := CASE WHEN EXISTS (SELECT 1 FROM cfg_ipress_alcance WHERE codigo_ipress = '00013591')
		THEN '✓' ELSE '✗ (tabla no se creo o falta la fila LNS)' END;
	RAISE NOTICE 'cfg_ipress_alcance (LNS 00013591): %', v_check;

	v_check := CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'log_alcance_depurado')
		THEN '✓' ELSE '✗ (tabla no se creo)' END;
	RAISE NOTICE 'Tabla log_alcance_depurado: %', v_check;

	RAISE NOTICE '=== FIN VERIFICACION ===';
END $$;
