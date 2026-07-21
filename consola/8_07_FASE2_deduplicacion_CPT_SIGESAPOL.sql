-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 07_FASE2_deduplicacion_CPT_SIGESAPOL.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================

-- ============================================================================
-- 07_FASE2_deduplicacion_CPT_SIGESAPOL.sql  (VERSIÓN FINAL post-piloto julio 2025)
-- Deduplicación y consolidación entre fuentes (todo julio-diciembre 2025).
-- Correr en la BD CPT, después del paso 2 y del traslado de las tablas
-- SIGESAPOL (padrón emergencia, estancias hosp. y procedimientos).
--
-- FUENTE CANÓNICA POR MES (checks 13b/15a/16/23):
--   JUL-SEP 2025: CPT canónico, SIGESAPOL complementa (usar B.4a y A.2)
--   OCT-DIC 2025: SIGESAPOL canónico, CPT complementa (usar B.4b y A.3)
--   La fuente complementaria SIEMPRE entra por anti-join; nunca se suman
--   ambas fuentes completas.
--
-- REGLAS DE DUPLICADO (cerradas con checks 24-25 del piloto):
--   Tipo 1 (proc. médicos):   paciente + fecha + código + MISMO MÉDICO
--   Tipo 2 y 3 (lab/imágenes): paciente + fecha + código + MISMA CANTIDAD
--     (el médico se ignora: CPT firma el validador del servicio y
--      SIGESAPOL el médico tratante — confirmado con muestra)
--   Los pares que coinciden en paciente+fecha+código pero NO cumplen su
--   regla NO se descartan: van a la hoja "OBSERVACIONES DUPLICADOS" con
--   su motivo, para decisión de auditoría.
--
-- Incluye las tablas de LABORATORIO de CPT en el cruce (ausentes en la
-- versión anterior; por eso el piloto no mostró pares de tipo 2).
-- ============================================================================


-- ============================================================
-- 0. FUENTE CPT UNIFICADA (BDT + LABORATORIO) como tabla de trabajo
-- ============================================================
DROP TABLE IF EXISTS temp_cpt_procedimientos_unificado;
CREATE TABLE temp_cpt_procedimientos_unificado AS
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion, 'BDT consulta' AS fuente_cpt
FROM temp_bdt_consulta_local
UNION ALL
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion, 'BDT emergencia'
FROM temp_bdt_emergencia_sigesapol
UNION ALL
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion, 'BDT hospitalizacion'
FROM temp_bdt_hospitalizacion_local
UNION ALL
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion_total, 'LAB consulta'
FROM temp_laboratorio_consulta_local
UNION ALL
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion_total, 'LAB emergencia'
FROM temp_laboratorio_emergencia_sigesapol
UNION ALL
SELECT numero_documento_paciente, fecha_atencion, codigo_procedimiento,
       descripcion_procedimiento, numero_documento_responsable,
       suma_cantidad_registro, valorizacion_total, 'LAB hospitalizacion'
FROM temp_laboratorio_hospitalizacion_local;

CREATE INDEX idx_cpt_unif_llave ON temp_cpt_procedimientos_unificado
	(numero_documento_paciente, fecha_atencion, codigo_procedimiento);
ANALYZE temp_cpt_procedimientos_unificado;


-- ============================================================
-- A. ESTANCIAS HOSPITALARIAS
-- ============================================================

-- A.1 Reporte de estancias duplicadas entre fuentes (auditoría)
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

-- A.2 JUL-SEP 2025 (CPT canónico): complemento = estancias SOLO en SIGESAPOL
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

-- A.3 OCT-DIC 2025 (SIGESAPOL canónico): complemento = estancias SOLO en CPT
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


-- ============================================================
-- B. PROCEDIMIENTOS Y LABORATORIO
-- ============================================================

-- B.1 DUPLICADOS CIERTOS (se descartan automáticamente de la fuente
--     complementaria). Cumplen la regla de su tipo.
SELECT
	cpt.numero_documento_paciente AS documento,
	cpt.fecha_atencion::date AS fecha,
	cpt.codigo_procedimiento,
	sig.tipo_procedimiento,
	cpt.fuente_cpt,
	sig.base AS fuente_sigesapol,
	cpt.suma_cantidad_registro AS cantidad_cpt,
	sig.sp_suma_cantidad       AS cantidad_sigesapol,
	cpt.valorizacion           AS valorizacion_cpt,
	sig.sp_valorizacion_calculada AS valorizacion_sigesapol
FROM temp_cpt_procedimientos_unificado cpt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
 AND (   (sig.tipo_procedimiento = 1
          AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
      OR (sig.tipo_procedimiento IN (2, 3)
          AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
ORDER BY documento, fecha;

-- B.2 HOJA "OBSERVACIONES DUPLICADOS" (NO se descartan; decisión de
--     auditoría). Coinciden en paciente+fecha+código pero no cumplen la
--     regla automática de su tipo. Exportar como hoja aparte del Excel.
SELECT
	cpt.numero_documento_paciente AS documento,
	cpt.fecha_atencion::date AS fecha,
	cpt.codigo_procedimiento,
	cpt.descripcion_procedimiento,
	sig.tipo_procedimiento,
	cpt.fuente_cpt,
	sig.base AS fuente_sigesapol,
	cpt.numero_documento_responsable    AS medico_cpt,
	sig.sp_numero_documento_responsable AS medico_sigesapol,
	cpt.suma_cantidad_registro AS cantidad_cpt,
	sig.sp_suma_cantidad       AS cantidad_sigesapol,
	cpt.valorizacion           AS valorizacion_cpt,
	sig.sp_valorizacion_calculada AS valorizacion_sigesapol,
	CASE
		WHEN sig.tipo_procedimiento = 1
			THEN 'MEDICO DISTINTO ENTRE FUENTES - VALIDAR POSIBLE DOBLE REGISTRO'
		ELSE 'CANTIDAD DISTINTA ENTRE FUENTES - VALIDAR CONSOLIDACION DE CANTIDADES'
	END AS motivo_observacion
FROM temp_cpt_procedimientos_unificado cpt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
WHERE NOT (   (sig.tipo_procedimiento = 1
               AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
           OR (sig.tipo_procedimiento IN (2, 3)
               AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
ORDER BY motivo_observacion, documento, fecha;

-- B.3 RESUMEN EJECUTIVO del doble registro (para informe a jefatura)
SELECT sig.base,
       sig.tipo_procedimiento,
       COUNT(*) AS duplicados_ciertos,
       SUM(sig.sp_valorizacion_calculada) AS monto_evitado_doble_cobro
FROM temp_cpt_procedimientos_unificado cpt
JOIN temp_sigesapol_procedimientos sig
  ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
 AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
 AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
 AND (   (sig.tipo_procedimiento = 1
          AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
      OR (sig.tipo_procedimiento IN (2, 3)
          AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
GROUP BY sig.base, sig.tipo_procedimiento
ORDER BY sig.base, sig.tipo_procedimiento;

-- B.4a JUL-SEP 2025 (CPT canónico): complemento SIGESAPOL por anti-join
DROP TABLE IF EXISTS temp_proc_complemento_sigesapol;
CREATE TABLE temp_proc_complemento_sigesapol AS
SELECT sig.*
FROM temp_sigesapol_procedimientos sig
WHERE NOT EXISTS (
	SELECT 1 FROM temp_cpt_procedimientos_unificado cpt
	WHERE cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND (   (sig.tipo_procedimiento = 1
	           AND cpt.numero_documento_responsable = sig.sp_numero_documento_responsable)
	       OR (sig.tipo_procedimiento IN (2, 3)
	           AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad) )
);

-- B.4b OCT-DIC 2025 (SIGESAPOL canónico): complemento CPT por anti-join
DROP TABLE IF EXISTS temp_proc_complemento_cpt;
CREATE TABLE temp_proc_complemento_cpt AS
SELECT cpt.*
FROM temp_cpt_procedimientos_unificado cpt
WHERE NOT EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND (   (sig.tipo_procedimiento = 1
	           AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
	       OR (sig.tipo_procedimiento IN (2, 3)
	           AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
);


-- ============================================================
-- C. RESUMEN DE CONSOLIDACIÓN DEL PERÍODO
-- ============================================================
SELECT 'CPT unificado (BDT + LAB)' AS fuente, COUNT(*) AS filas FROM temp_cpt_procedimientos_unificado
UNION ALL SELECT 'SIGESAPOL procedimientos', COUNT(*) FROM temp_sigesapol_procedimientos
UNION ALL SELECT 'Complemento SIGESAPOL (jul-sep: sumar a CPT)', COUNT(*) FROM temp_proc_complemento_sigesapol
UNION ALL SELECT 'Complemento CPT (oct-dic: sumar a SIGESAPOL)', COUNT(*) FROM temp_proc_complemento_cpt
UNION ALL SELECT 'Hosp: complemento SIGESAPOL (jul-sep)', COUNT(*) FROM temp_hosp_complemento_sigesapol
UNION ALL SELECT 'Hosp: complemento CPT (oct-dic)', COUNT(*) FROM temp_hosp_complemento_cpt;

-- Nota: los documentos de paciente y médico cruzan a 8 dígitos homogéneos
-- entre fuentes (verificado en piloto). Los ~267 médicos con documento de
-- 9 caracteres en SIGESAPOL (CE) no cruzarán con CPT por diseño de la
-- normalización; su volumen es marginal y quedan del lado canónico.
