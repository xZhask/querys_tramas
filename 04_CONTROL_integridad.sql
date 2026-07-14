-- ============================================================================
-- 04_CONTROL_integridad.sql
-- Controles de calidad ANTES de exportar las tramas a Excel.
-- Correr en la BD CPT después del paso 2.
--
-- Regla de oro de las tramas: ninguna fila de las tramas 2/3/4 puede quedar
-- sin su referencia en la trama 1. Estos controles detectan violaciones
-- ANTES de que SALUDPOL las observe. Lo ideal: todos los controles en cero.
-- El resultado de estos controles sirve además como insumo de auditoría.
-- ============================================================================


-- ============================================================
-- CONTROL 1: Procedimientos de emergencia HUÉRFANOS
-- Filas de temp_bdt_emergencia_sigesapol que NO cruzan con ninguna
-- estancia de emergencia por (documento + fecha dentro de la estadía).
-- Estas filas quedarían fuera de la trama 3 o sin cabecera en la trama 1.
-- ============================================================
SELECT COUNT(*) AS procedimientos_emergencia_huerfanos
FROM temp_bdt_emergencia_sigesapol bdt
WHERE NOT EXISTS (
	SELECT 1
	FROM temp_emergencia_sigesapol_estancia e
	WHERE e.sp_numero_documento_paciente = bdt.numero_documento_paciente
	  AND bdt.fecha_atencion::date BETWEEN e.sp_fecha_atencion::date
	                                   AND e.sp_fecha_alta_emergencia::date
);

-- Detalle de los huérfanos (si el conteo fue > 0):
SELECT bdt.numero_documento_paciente, bdt.fecha_atencion,
       bdt.codigo_procedimiento, bdt.descripcion_procedimiento
FROM temp_bdt_emergencia_sigesapol bdt
WHERE NOT EXISTS (
	SELECT 1
	FROM temp_emergencia_sigesapol_estancia e
	WHERE e.sp_numero_documento_paciente = bdt.numero_documento_paciente
	  AND bdt.fecha_atencion::date BETWEEN e.sp_fecha_atencion::date
	                                   AND e.sp_fecha_alta_emergencia::date
)
ORDER BY bdt.numero_documento_paciente, bdt.fecha_atencion
LIMIT 50;


-- ============================================================
-- CONTROL 2: Procedimientos de hospitalización HUÉRFANOS
-- (misma lógica contra las estancias hospitalarias)
-- ============================================================
SELECT COUNT(*) AS procedimientos_hospitalizacion_huerfanos
FROM temp_bdt_hospitalizacion_local bdt
WHERE NOT EXISTS (
	SELECT 1
	FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = bdt.numero_documento_paciente
	  AND bdt.fecha_atencion::date BETWEEN h.sp_fecha_atencion::date
	                                   AND h.sp_fecha_alta::date
);


-- ============================================================
-- CONTROL 3: Exámenes de laboratorio HUÉRFANOS (emergencia y hosp.)
-- Tras el PARCHE B, los documentos de laboratorio ya se normalizan
-- por tipo; este control confirma que el cruce funciona.
-- ============================================================
SELECT COUNT(*) AS laboratorio_emergencia_huerfanos
FROM temp_laboratorio_emergencia_sigesapol lab
WHERE NOT EXISTS (
	SELECT 1
	FROM temp_emergencia_sigesapol_estancia e
	WHERE e.sp_numero_documento_paciente = lab.numero_documento_paciente
	  AND lab.fecha_atencion::date BETWEEN e.sp_fecha_atencion::date
	                                   AND e.sp_fecha_alta_emergencia::date
);

SELECT COUNT(*) AS laboratorio_hospitalizacion_huerfanos
FROM temp_laboratorio_hospitalizacion_local lab
WHERE NOT EXISTS (
	SELECT 1
	FROM temp_hospitalizacion_local h
	WHERE h.sp_numero_documento_paciente = lab.numero_documento_paciente
	  AND lab.fecha_atencion::date BETWEEN h.sp_fecha_atencion::date
	                                   AND h.sp_fecha_alta::date
);


-- ============================================================
-- CONTROL 4: Estancias sin documento de paciente
-- El LEFT JOIN a asegurados en el paso 1 puede producir documento NULL;
-- esas estancias no cruzarán con nada.
-- ============================================================
SELECT COUNT(*) AS estancias_emergencia_sin_documento
FROM temp_emergencia_sigesapol_estancia
WHERE sp_numero_documento_paciente IS NULL
   OR TRIM(sp_numero_documento_paciente) = '';

SELECT COUNT(*) AS estancias_hospitalizacion_sin_documento
FROM temp_hospitalizacion_local
WHERE sp_numero_documento_paciente IS NULL
   OR TRIM(sp_numero_documento_paciente) = '';


-- ============================================================
-- CONTROL 5: Transiciones emergencia -> hospitalización
-- Pacientes con emergencia y hospitalización cuyas fechas se tocan
-- o solapan en el período. NO es un error: es la hoja "OBSERVACIONES"
-- para el Excel. Los casos SOLAPAMIENTO son los que pueden duplicar
-- procedimientos en ambas tramas (el join es por documento + rango).
-- ============================================================
SELECT
	e.sp_numero_documento_paciente AS documento,
	e.sp_apellido_paterno_paciente, e.sp_nombres_paciente,
	e.sp_fecha_atencion::date        AS emerg_ingreso,
	e.sp_fecha_alta_emergencia::date AS emerg_alta,
	h.sp_fecha_atencion::date        AS hosp_ingreso,
	h.sp_fecha_alta::date            AS hosp_alta,
	CASE
		WHEN h.sp_fecha_atencion::date = e.sp_fecha_alta_emergencia::date THEN 'TRANSICIÓN MISMO DÍA'
		WHEN h.sp_fecha_atencion::date <  e.sp_fecha_alta_emergencia::date THEN 'SOLAPAMIENTO'
		ELSE 'CONTIGUO'
	END AS observacion
FROM temp_emergencia_sigesapol_estancia e
JOIN temp_hospitalizacion_local h
  ON h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
 AND h.sp_fecha_atencion::date <= e.sp_fecha_alta_emergencia::date + 1
 AND h.sp_fecha_alta::date     >= e.sp_fecha_atencion::date
ORDER BY documento, emerg_ingreso;


-- ============================================================
-- CONTROL 6: Procedimientos duplicados entre tramas
-- El mismo procedimiento (documento + fecha + código) presente tanto
-- en la BDT de emergencia como en la de hospitalización. Derivado
-- directo de los SOLAPAMIENTOS del control 5.
-- ============================================================
SELECT be.numero_documento_paciente, be.fecha_atencion,
       be.codigo_procedimiento,
       be.suma_cantidad_registro AS cant_en_emergencia,
       bh.suma_cantidad_registro AS cant_en_hospitalizacion
FROM temp_bdt_emergencia_sigesapol be
JOIN temp_bdt_hospitalizacion_local bh
  ON bh.numero_documento_paciente = be.numero_documento_paciente
 AND bh.fecha_atencion = be.fecha_atencion
 AND bh.codigo_procedimiento = be.codigo_procedimiento
ORDER BY be.numero_documento_paciente, be.fecha_atencion;


-- ============================================================
-- CONTROL 7: Códigos de procedimiento vacíos o nulos
-- No deben llegar a la trama 3 (ni '' ni NULL).
-- ============================================================
SELECT 'bdt_consulta' AS tabla, COUNT(*) AS codigos_vacios
FROM temp_bdt_consulta_local WHERE codigo_procedimiento IS NULL OR TRIM(codigo_procedimiento) = ''
UNION ALL
SELECT 'bdt_emergencia_sigesapol', COUNT(*)
FROM temp_bdt_emergencia_sigesapol WHERE codigo_procedimiento IS NULL OR TRIM(codigo_procedimiento) = ''
UNION ALL
SELECT 'bdt_hospitalizacion', COUNT(*)
FROM temp_bdt_hospitalizacion_local WHERE codigo_procedimiento IS NULL OR TRIM(codigo_procedimiento) = '';


-- ============================================================
-- CONTROL 8: Valorizaciones nulas o en cero
-- Montos que llegarían vacíos a la trama (tarifa no encontrada, etc.)
-- ============================================================
SELECT 'bdt_consulta' AS tabla, COUNT(*) AS valorizacion_cero_o_nula
FROM temp_bdt_consulta_local WHERE COALESCE(valorizacion, 0) = 0
UNION ALL
SELECT 'bdt_emergencia_sigesapol', COUNT(*)
FROM temp_bdt_emergencia_sigesapol WHERE COALESCE(valorizacion, 0) = 0
UNION ALL
SELECT 'bdt_hospitalizacion', COUNT(*)
FROM temp_bdt_hospitalizacion_local WHERE COALESCE(valorizacion, 0) = 0
UNION ALL
SELECT 'estancia_hospitalizacion', COUNT(*)
FROM temp_hospitalizacion_local WHERE COALESCE(sp_valorizacion_total, 0) = 0;


-- ============================================================
-- CONTROL 9: Estancias CPT contiguas o solapadas del mismo paciente
-- Nota de auditoría: "regla del equipo: conservar cama general 99231.15".
-- Clasifica los solapamientos como Transferencia de cama o Solapamiento Real.
-- ============================================================
SELECT
	h1.sp_numero_documento_paciente AS documento,
	h1.id_prestacion_cpt AS id_1,
	h1.sp_fecha_atencion AS ingreso_1,
	h1.sp_fecha_alta AS alta_1,
	h1.sp_codigo_procedimiento AS cpms_1,
	h2.id_prestacion_cpt AS id_2,
	h2.sp_fecha_atencion AS ingreso_2,
	h2.sp_fecha_alta AS alta_2,
	h2.sp_codigo_procedimiento AS cpms_2,
	CASE
		WHEN h1.sp_fecha_alta = h2.sp_fecha_atencion OR h2.sp_fecha_alta = h1.sp_fecha_atencion
			THEN 'TRANSFERENCIA DE CAMA (día de traslado facturado doble)'
		ELSE 'SOLAPAMIENTO REAL'
	END AS motivo
FROM temp_hospitalizacion_local h1
INNER JOIN temp_hospitalizacion_local h2
   ON h1.sp_numero_documento_paciente = h2.sp_numero_documento_paciente
  AND h1.id_prestacion_cpt < h2.id_prestacion_cpt
  AND h1.sp_fecha_atencion <= h2.sp_fecha_alta
  AND h1.sp_fecha_alta >= h2.sp_fecha_atencion
ORDER BY documento, ingreso_1;


-- ============================================================
-- CONTROL 10: Control de No Doble Reporte
-- Ningún par (documento + fecha + código) puede aparecer simultáneamente
-- en la trama de emergencia y en la de hospitalización. Debe dar CERO.
-- ============================================================
WITH emergency_reported AS (
	-- Estancias en emergencia
	SELECT sp_numero_documento_paciente AS DNI, sp_fecha_atencion::date AS fecha, 
		CASE 
			WHEN e.prioridad = 1 THEN '99285'
			WHEN e.prioridad = 2 THEN '99284'
			WHEN e.prioridad = 3 THEN '99282'
			WHEN e.prioridad = 4 THEN '99281'
			ELSE '99281'
		END AS codigo
	FROM temp_emergencia_sigesapol_estancia e
	WHERE e.excluir_tipo2 = false
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
		  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
	  )
	UNION ALL
	-- Procedimientos en emergencia
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_emergencia_sigesapol bdt
	JOIN temp_emergencia_sigesapol_estancia e 
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
	WHERE e.excluir_tipo2 = false AND bdt.codigo_procedimiento IS NOT NULL
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND bdt.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
	  )
	UNION ALL
	-- Laboratorios en emergencia
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_emergencia_sigesapol lab
	JOIN temp_emergencia_sigesapol_estancia e 
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta_emergencia::date
	WHERE e.excluir_tipo2 = false AND lab.codigo_procedimiento IS NOT NULL
	  AND NOT EXISTS (
		SELECT 1 FROM temp_hospitalizacion_local h
		WHERE h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
		  AND lab.fecha_atencion::date between h.sp_fecha_atencion::date AND h.sp_fecha_alta::date
	  )
),
hospitalization_reported AS (
	-- Estancias en hospitalización
	SELECT sp_numero_documento_paciente AS DNI, sp_fecha_atencion::date AS fecha, sp_codigo_procedimiento AS codigo
	FROM temp_hospitalizacion_local
	UNION ALL
	-- Procedimientos hospitalización (normales)
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_hospitalizacion_local bdt
	JOIN temp_hospitalizacion_local e 
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE bdt.codigo_procedimiento IS NOT NULL
	UNION ALL
	-- Procedimientos hospitalización (reclasificados de emergencia)
	SELECT e.sp_numero_documento_paciente, bdt.fecha_atencion::date, bdt.codigo_procedimiento
	FROM temp_bdt_emergencia_sigesapol bdt
	JOIN temp_hospitalizacion_local e 
	  ON e.sp_numero_documento_paciente = bdt.numero_documento_paciente 
	 AND bdt.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE e.origen_reclasificacion IS NOT NULL AND bdt.codigo_procedimiento IS NOT NULL
	UNION ALL
	-- Laboratorios hospitalización (normales)
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_hospitalizacion_local lab
	JOIN temp_hospitalizacion_local e 
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE lab.codigo_procedimiento IS NOT NULL
	UNION ALL
	-- Laboratorios hospitalización (reclasificados de emergencia)
	SELECT e.sp_numero_documento_paciente, lab.fecha_atencion::date, lab.codigo_procedimiento
	FROM temp_laboratorio_emergencia_sigesapol lab
	JOIN temp_hospitalizacion_local e 
	  ON e.sp_numero_documento_paciente = lab.numero_documento_paciente 
	 AND lab.fecha_atencion::date between e.sp_fecha_atencion::date AND e.sp_fecha_alta::date
	WHERE e.origen_reclasificacion IS NOT NULL AND lab.codigo_procedimiento IS NOT NULL
)
SELECT COUNT(*) AS total_duplicados_emergencia_hosp
FROM emergency_reported er
JOIN hospitalization_reported hr 
  ON er.DNI = hr.DNI 
 AND er.fecha = hr.fecha 
 AND er.codigo = hr.codigo;


