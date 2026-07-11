-- ============================================================================
-- 07_FASE2_deduplicacion_CPT_SIGESAPOL.sql
-- Deduplicación y consolidación entre fuentes para los períodos de
-- convivencia (aplica a TODO julio-diciembre 2025).
-- Correr en la BD CPT, después del paso 2 y de trasladar las tablas
-- SIGESAPOL (padrón de emergencia, estancias de hospitalización y
-- procedimientos).
--
-- REGLA DE FUENTE CANÓNICA (basada en checks 13b/15a/16/23):
--   JULIO-SEPTIEMBRE 2025: CPT canónico (es superconjunto: 99.3% de
--     SIGESAPOL ⊂ CPT en la muestra de marzo). SIGESAPOL solo complementa.
--   OCTUBRE-DICIEMBRE 2025: SIGESAPOL canónico (CPT en caída libre).
--     CPT solo complementa (obstetricia, imágenes, laboratorio no migrados).
--   La fuente complementaria SIEMPRE entra por anti-join: solo lo que la
--   canónica no tiene. NUNCA se suman ambas fuentes completas.
--
-- Llave de deduplicación:
--   Estancias:      documento + solapamiento de rango de fechas
--   Procedimientos (ESTRICTA, dedup automática):
--       documento paciente + fecha + código + documento del MÉDICO responsable
--   Procedimientos (LAXA, solo reporte de revisión):
--       documento paciente + fecha + código con médico DISTINTO
--       => posible atención legítima en dos consultorios el mismo día;
--          NO se descarta automáticamente, la decide auditoría.
-- ============================================================================


-- ============================================================
-- A. ESTANCIAS HOSPITALARIAS
-- ============================================================

-- A.1 Reporte de duplicados (siempre correr primero, para auditoría)
SELECT
	c.sp_numero_documento_paciente AS documento,
	c.sp_fecha_atencion::date  AS cpt_ingreso,
	c.sp_fecha_alta::date      AS cpt_alta,
	s.sp_fecha_atencion        AS sig_ingreso,
	s.sp_fecha_alta            AS sig_alta,
	c.sp_valorizacion_total    AS cpt_valorizacion,
	s.sp_valorizacion_estancia AS sig_valorizacion
FROM temp_hospitalizacion_local c
JOIN temp_hospitalizacion_sigesapol_estancia s
  ON s.sp_numero_documento_paciente = c.sp_numero_documento_paciente
 AND s.sp_fecha_atencion <= c.sp_fecha_alta::date
 AND s.sp_fecha_alta     >= c.sp_fecha_atencion::date
ORDER BY documento;

-- A.2 PERÍODOS JUL-SEP 2025 (CPT canónico):
--     complemento = estancias SOLO en SIGESAPOL
DROP TABLE IF EXISTS temp_hosp_complemento_sigesapol;
CREATE TABLE temp_hosp_complemento_sigesapol AS
SELECT s.*
FROM temp_hospitalizacion_sigesapol_estancia s
WHERE NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local c
	WHERE c.sp_numero_documento_paciente = s.sp_numero_documento_paciente
	  AND s.sp_fecha_atencion <= c.sp_fecha_alta::date
	  AND s.sp_fecha_alta     >= c.sp_fecha_atencion::date
);
-- Trama 1 de hospitalización = temp_hospitalizacion_local (todo)
--                            + temp_hosp_complemento_sigesapol

-- A.3 PERÍODOS OCT-DIC 2025 (SIGESAPOL canónico):
--     complemento = estancias SOLO en CPT
DROP TABLE IF EXISTS temp_hosp_complemento_cpt;
CREATE TABLE temp_hosp_complemento_cpt AS
SELECT c.*
FROM temp_hospitalizacion_local c
WHERE NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_sigesapol_estancia s
	WHERE s.sp_numero_documento_paciente = c.sp_numero_documento_paciente
	  AND s.sp_fecha_atencion <= c.sp_fecha_alta::date
	  AND s.sp_fecha_alta     >= c.sp_fecha_atencion::date
);
-- Trama 1 de hospitalización = temp_hospitalizacion_sigesapol_estancia (todo)
--                            + temp_hosp_complemento_cpt

-- (Usar A.2 **o** A.3 según el mes; el otro sirve de contraste)


-- ============================================================
-- B. PROCEDIMIENTOS (todas las atenciones)
-- ============================================================

-- B.1 Reporte de duplicados CIERTOS entre fuentes (llave ESTRICTA:
--     mismo paciente + fecha + código + MISMO MÉDICO responsable)
SELECT
	bdt.numero_documento_paciente AS documento,
	bdt.fecha_atencion,
	bdt.codigo_procedimiento,
	bdt.numero_documento_responsable AS medico,
	bdt.suma_cantidad_registro AS cantidad_cpt,
	sig.sp_suma_cantidad       AS cantidad_sigesapol,
	bdt.valorizacion           AS valorizacion_cpt,
	sig.sp_valorizacion_calculada AS valorizacion_sigesapol,
	sig.base
FROM (
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro, valorizacion FROM temp_bdt_consulta_local
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro, valorizacion FROM temp_bdt_emergencia_sigesapol
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro, valorizacion FROM temp_bdt_hospitalizacion_local
) bdt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = bdt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = bdt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = bdt.codigo_procedimiento
 AND sig.sp_numero_documento_responsable = bdt.numero_documento_responsable
ORDER BY documento, fecha_atencion;

-- B.1b Reporte de POSIBLES duplicados a revisar (llave LAXA: mismo
--      paciente + fecha + código, pero MÉDICO DISTINTO). Caso típico:
--      paciente atendido en dos consultorios el mismo día con el mismo
--      código. NO se deduplica automáticamente: exportar como hoja
--      "POSIBLES DUPLICADOS" para decisión de auditoría.
SELECT
	bdt.numero_documento_paciente AS documento,
	bdt.fecha_atencion,
	bdt.codigo_procedimiento,
	bdt.numero_documento_responsable AS medico_cpt,
	sig.sp_numero_documento_responsable AS medico_sigesapol,
	bdt.suma_cantidad_registro AS cantidad_cpt,
	sig.sp_suma_cantidad       AS cantidad_sigesapol,
	sig.sp_upss_nombre         AS servicio_sigesapol,
	sig.base
FROM (
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro FROM temp_bdt_consulta_local
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro FROM temp_bdt_emergencia_sigesapol
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
	       numero_documento_responsable, suma_cantidad_registro FROM temp_bdt_hospitalizacion_local
) bdt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = bdt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = bdt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = bdt.codigo_procedimiento
 AND sig.sp_numero_documento_responsable IS DISTINCT FROM bdt.numero_documento_responsable
ORDER BY documento, fecha_atencion;

-- B.2 Resumen ejecutivo del doble registro (para el informe a jefatura)
SELECT sig.base,
       COUNT(*) AS procedimientos_duplicados,
       SUM(sig.sp_valorizacion_calculada) AS monto_en_riesgo_de_doble_cobro
FROM (
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento FROM temp_bdt_consulta_local
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento FROM temp_bdt_emergencia_sigesapol
	UNION ALL
	SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento FROM temp_bdt_hospitalizacion_local
) bdt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = bdt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = bdt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = bdt.codigo_procedimiento
GROUP BY sig.base;

-- B.3 PERÍODOS JUL-SEP 2025 (CPT canónico):
--     complemento SIGESAPOL = procedimientos que CPT no tiene
DROP TABLE IF EXISTS temp_proc_complemento_sigesapol;
CREATE TABLE temp_proc_complemento_sigesapol AS
SELECT sig.*
FROM temp_sigesapol_procedimientos sig
WHERE NOT EXISTS (
	SELECT 1 FROM (
		SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento, numero_documento_responsable FROM temp_bdt_consulta_local
		UNION ALL
		SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento, numero_documento_responsable FROM temp_bdt_emergencia_sigesapol
		UNION ALL
		SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento, numero_documento_responsable FROM temp_bdt_hospitalizacion_local
	) bdt
	WHERE bdt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND bdt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND bdt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND bdt.numero_documento_responsable = sig.sp_numero_documento_responsable  -- llave estricta
);

-- B.4 PERÍODOS OCT-DIC 2025 (SIGESAPOL canónico):
--     complemento CPT = procedimientos que SIGESAPOL no tiene
DROP TABLE IF EXISTS temp_proc_complemento_cpt;
CREATE TABLE temp_proc_complemento_cpt AS
SELECT bdt.*
FROM (
	SELECT * FROM temp_bdt_consulta_local
	UNION ALL
	SELECT * FROM temp_bdt_emergencia_sigesapol
	UNION ALL
	SELECT * FROM temp_bdt_hospitalizacion_local
) bdt
WHERE NOT EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.sp_numero_documento_paciente = bdt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = bdt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = bdt.codigo_procedimiento
	  AND sig.sp_numero_documento_responsable = bdt.numero_documento_responsable  -- llave estricta
);


-- ============================================================
-- C. RESUMEN DE CONSOLIDACIÓN DEL PERÍODO
-- ============================================================
SELECT 'CPT: bdt consulta' AS fuente, COUNT(*) AS filas FROM temp_bdt_consulta_local
UNION ALL SELECT 'CPT: bdt emergencia', COUNT(*) FROM temp_bdt_emergencia_sigesapol
UNION ALL SELECT 'CPT: bdt hospitalizacion', COUNT(*) FROM temp_bdt_hospitalizacion_local
UNION ALL SELECT 'SIGESAPOL: procedimientos', COUNT(*) FROM temp_sigesapol_procedimientos
UNION ALL SELECT 'Complemento SIGESAPOL (si CPT canónico)', COUNT(*) FROM temp_proc_complemento_sigesapol
UNION ALL SELECT 'Complemento CPT (si SIGESAPOL canónico)', COUNT(*) FROM temp_proc_complemento_cpt
UNION ALL SELECT 'Hosp: complemento SIGESAPOL', COUNT(*) FROM temp_hosp_complemento_sigesapol
UNION ALL SELECT 'Hosp: complemento CPT', COUNT(*) FROM temp_hosp_complemento_cpt;

-- IMPORTANTE - nota sobre formatos de documento en el cruce:
-- Las tablas CPT (bdt) llevan el documento ya normalizado (8 dígitos DNI /
-- 9 con letra CE); las SIGESAPOL llevan nro_doc_ident tal cual. Si el
-- reporte B.1 sale sospechosamente en CERO, correr esta comprobación:
--   SELECT DISTINCT LENGTH(sp_numero_documento_paciente)
--   FROM temp_sigesapol_procedimientos LIMIT 10;
-- Si SIGESAPOL guarda el DNI con ceros a la izquierda u otro largo,
-- ajustar las condiciones de cruce a:
--   LPAD(bdt.numero_documento_paciente, 10, '0') = LPAD(sig.sp_numero_documento_paciente, 10, '0')
