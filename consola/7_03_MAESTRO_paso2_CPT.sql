-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 03_MAESTRO_paso2_CPT.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================

-- ============================================================================
-- 03_MAESTRO_paso2_CPT.sql
-- PASO 2 del armado mensual: materialización de todas las tablas temp_* en CPT.
-- Correr en la BD CPT, DESPUÉS de:
--   (a) haber corrido el paso 1 en SIGESAPOL, y
--   (b) haber trasladado temp_emergencia_sigesapol_estancia a esta BD.
--
-- Reemplaza al archivo original "05_CREAR_TABLAS_EN_BASE_A_LOS_PROCEDIMIENTOS"
-- corrigiendo:
--   1. Período declarado UNA sola vez (antes: 8 fechas dispersas e
--      inconsistentes entre sí: 20231201, 20241001, 20241201, 20240501).
--   2. DROP TABLE IF EXISTS en todo: re-ejecutable sin limpieza manual.
--   3. Orden de dependencias explícito (estancias primero, luego
--      procedimientos y laboratorio que consultan los padrones).
--   4. Eliminados los dos bloques rotos (CREATE comentado con SELECT vivo
--      que ejecutaba consultas pesadas sin crear nada).
--   5. Eliminada la edición manual de la función de laboratorio: se usa el
--      nuevo modo 22 del PARCHE B.
--   6. Índices + ANALYZE sobre las tablas grandes para acelerar los joins
--      del armado (06/07/08).
--
-- NOTA DE ALCANCE (verificado con CHECKS 13a/15a):
--   - temp_emergencia_local (emergencia CPT, query 01) NO se genera: no hay
--     emergencias CPT desde antes de 2024. Su función queda como legado.
--   - Para períodos >= octubre 2025, los procedimientos migraron masivamente
--     de CPT a SIGESAPOL (prestaciones). Estas tablas saldrán casi vacías
--     para esos meses: PENDIENTE confirmar con el equipo la fuente SIGESAPOL
--     (¿query 09?) antes de armar esos períodos.
-- ============================================================================

-- ========================= CONFIGURAR PERÍODO AQUÍ =========================
DROP TABLE IF EXISTS cfg_periodo;
CREATE TABLE cfg_periodo AS
SELECT DATE '2025-08-01' AS p_ini,   -- <== inicio del periodo
       DATE '2025-08-31' AS p_fin;   -- <== fin del período   (igual al paso 1)
-- ============================================================================


-- ============================================================
-- 0. VALIDACIÓN PREVIA: el padrón SIGESAPOL debe existir aquí
-- ============================================================
DO $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables
	               WHERE table_name = 'temp_emergencia_sigesapol_estancia') THEN
		RAISE EXCEPTION 'Falta temp_emergencia_sigesapol_estancia. Corre el paso 1 en SIGESAPOL y trasládala a esta BD (ver instrucciones al final del paso 1).';
	END IF;
END $$;


-- ============================================================
-- 1. ESTANCIAS (padrones) - deben crearse ANTES que el resto

-- 1.1 Hospitalización CPT (estancias con dx 1-3)
DROP TABLE IF EXISTS temp_hospitalizacion_local;
CREATE TABLE temp_hospitalizacion_local AS
	SELECT * FROM sp_hospitalizacion_en_periodo(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo));

-- ALCANCE: filtra el resultado ya materializado (la función original no se
-- toca). Constancia de lo depurado en log_alcance_depurado antes de borrar.
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_hospitalizacion_local';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_hospitalizacion_local',
       sp_codigo_ipress, sp_nombre_ipress, COUNT(*), SUM(sp_valorizacion_total)
FROM temp_hospitalizacion_local
WHERE sp_codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY sp_codigo_ipress, sp_nombre_ipress;
DELETE FROM temp_hospitalizacion_local WHERE sp_codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- (temp_emergencia_local NO se crea: emergencia CPT sin datos 2024+, CHECK 13a)


-- 1.2 Estructura vacía de temp_emergencia_local (REQUERIDA aunque no se use):
-- las funciones 03/04 la referencian dentro del mismo statement del CASE y
-- PostgreSQL exige que exista físicamente aunque la rama nunca se ejecute
-- (hallazgo del piloto julio 2025). Emergencia CPT no tiene datos 2024+,
-- así que se crea vacía con la estructura del padrón SIGESAPOL.
DROP TABLE IF EXISTS temp_emergencia_local;
CREATE TABLE temp_emergencia_local AS
	SELECT * FROM temp_emergencia_sigesapol_estancia LIMIT 0;


-- ============================================================
-- 2. PROCEDIMIENTOS MÉDICOS (BDT) - función 03
-- ============================================================

-- 2.1 Consulta externa (dentro del período)
DROP TABLE IF EXISTS temp_bdt_consulta_local;
CREATE TABLE temp_bdt_consulta_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 1);

-- ALCANCE: ver nota en temp_hospitalizacion_local más arriba. En la práctica
-- esta función siempre devuelve LNS (prestacion_cpt no tiene otras IPRESS),
-- pero se filtra igual por consistencia y como red de seguridad para A4.
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_bdt_consulta_local';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_bdt_consulta_local',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion)
FROM temp_bdt_consulta_local
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_bdt_consulta_local WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 2.2 Emergencia con padrón SIGESAPOL (histórico hasta fin de período)
DROP TABLE IF EXISTS temp_bdt_emergencia_sigesapol;
CREATE TABLE temp_bdt_emergencia_sigesapol AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 22);

-- ALCANCE: ver nota arriba.
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_bdt_emergencia_sigesapol';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_bdt_emergencia_sigesapol',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion)
FROM temp_bdt_emergencia_sigesapol
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_bdt_emergencia_sigesapol WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 2.3 Hospitalización (histórico hasta fin de período, con padrón local)
DROP TABLE IF EXISTS temp_bdt_hospitalizacion_local;
CREATE TABLE temp_bdt_hospitalizacion_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 3);

-- ALCANCE: ver nota arriba.
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_bdt_hospitalizacion_local';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_bdt_hospitalizacion_local',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion)
FROM temp_bdt_hospitalizacion_local
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_bdt_hospitalizacion_local WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 2.4 (OPCIONAL - solo para reporte DIRSAPOL) Todos los tipos del mes
DROP TABLE IF EXISTS temp_bdt_mes_local;
CREATE TABLE temp_bdt_mes_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 4);


-- ============================================================
-- 3. EXÁMENES DE LABORATORIO - función 04 (PARCHE B aplicado)
-- ============================================================

-- 3.1 Consulta externa (dentro del período)
DROP TABLE IF EXISTS temp_laboratorio_consulta_local;
CREATE TABLE temp_laboratorio_consulta_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 1);

-- ALCANCE: sp_laboratorio_segun_tipo_atencion SÍ deriva codigo_ipress con un
-- join real a establecimiento_medico (prestacion_laboratorio cubre toda la
-- red PNP, a diferencia de prestacion_cpt) — este filtro tiene efecto real,
-- no es solo red de seguridad. Constancia en log_alcance_depurado.
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_laboratorio_consulta_local';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_laboratorio_consulta_local',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion_total)
FROM temp_laboratorio_consulta_local
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_laboratorio_consulta_local WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 3.2 Emergencia con padrón SIGESAPOL - modo 22 nuevo, SIN editar la función
DROP TABLE IF EXISTS temp_laboratorio_emergencia_sigesapol;
CREATE TABLE temp_laboratorio_emergencia_sigesapol AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 22);

-- ALCANCE: ver nota arriba (efecto real, no red de seguridad).
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_laboratorio_emergencia_sigesapol';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_laboratorio_emergencia_sigesapol',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion_total)
FROM temp_laboratorio_emergencia_sigesapol
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_laboratorio_emergencia_sigesapol WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 3.3 Hospitalización
DROP TABLE IF EXISTS temp_laboratorio_hospitalizacion_local;
CREATE TABLE temp_laboratorio_hospitalizacion_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 3);

-- ALCANCE: ver nota arriba (efecto real, no red de seguridad).
DELETE FROM log_alcance_depurado
 WHERE periodo_ini = (SELECT p_ini FROM cfg_periodo) AND periodo_fin = (SELECT p_fin FROM cfg_periodo)
   AND tabla = 'temp_laboratorio_hospitalizacion_local';
INSERT INTO log_alcance_depurado (periodo_ini, periodo_fin, tabla, codigo_ipress, nombre_ipress, filas_removidas, monto_removido)
SELECT (SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 'temp_laboratorio_hospitalizacion_local',
       codigo_ipress, nombre_ipress, COUNT(*), SUM(valorizacion_total)
FROM temp_laboratorio_hospitalizacion_local
WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance)
GROUP BY codigo_ipress, nombre_ipress;
DELETE FROM temp_laboratorio_hospitalizacion_local WHERE codigo_ipress <> (SELECT codigo_ipress FROM cfg_ipress_alcance);

-- 3.4 (OPCIONAL - solo para reporte DIRSAPOL) Todos los tipos del mes
DROP TABLE IF EXISTS temp_laboratorio_mes_local;
CREATE TABLE temp_laboratorio_mes_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion(
		(SELECT p_ini FROM cfg_periodo), (SELECT p_fin FROM cfg_periodo), 4);


-- ============================================================
-- 4. ÍNDICES + ESTADÍSTICAS para acelerar el armado (06/07/08)
--    Los joins de las tramas cruzan por (documento, fecha).
-- ============================================================
CREATE INDEX idx_tmp_emer_sig_doc ON temp_emergencia_sigesapol_estancia (sp_numero_documento_paciente);
CREATE INDEX idx_tmp_hosp_doc     ON temp_hospitalizacion_local (sp_numero_documento_paciente);
CREATE INDEX idx_tmp_bdt_emer_doc ON temp_bdt_emergencia_sigesapol (numero_documento_paciente, fecha_atencion);
CREATE INDEX idx_tmp_bdt_hosp_doc ON temp_bdt_hospitalizacion_local (numero_documento_paciente, fecha_atencion);
CREATE INDEX idx_tmp_lab_emer_doc ON temp_laboratorio_emergencia_sigesapol (numero_documento_paciente, fecha_atencion);
CREATE INDEX idx_tmp_lab_hosp_doc ON temp_laboratorio_hospitalizacion_local (numero_documento_paciente, fecha_atencion);

ANALYZE temp_emergencia_sigesapol_estancia;
ANALYZE temp_hospitalizacion_local;
ANALYZE temp_bdt_consulta_local;
ANALYZE temp_bdt_emergencia_sigesapol;
ANALYZE temp_bdt_hospitalizacion_local;
ANALYZE temp_laboratorio_consulta_local;
ANALYZE temp_laboratorio_emergencia_sigesapol;
ANALYZE temp_laboratorio_hospitalizacion_local;


-- ============================================================
-- 5. RESUMEN DE LO GENERADO
-- ============================================================
SELECT 'temp_emergencia_sigesapol_estancia' AS tabla, COUNT(*) AS filas FROM temp_emergencia_sigesapol_estancia
UNION ALL SELECT 'temp_hospitalizacion_local', COUNT(*) FROM temp_hospitalizacion_local
UNION ALL SELECT 'temp_bdt_consulta_local', COUNT(*) FROM temp_bdt_consulta_local
UNION ALL SELECT 'temp_bdt_emergencia_sigesapol', COUNT(*) FROM temp_bdt_emergencia_sigesapol
UNION ALL SELECT 'temp_bdt_hospitalizacion_local', COUNT(*) FROM temp_bdt_hospitalizacion_local
UNION ALL SELECT 'temp_laboratorio_consulta_local', COUNT(*) FROM temp_laboratorio_consulta_local
UNION ALL SELECT 'temp_laboratorio_emergencia_sigesapol', COUNT(*) FROM temp_laboratorio_emergencia_sigesapol
UNION ALL SELECT 'temp_laboratorio_hospitalizacion_local', COUNT(*) FROM temp_laboratorio_hospitalizacion_local
ORDER BY tabla;

-- Después de este paso: correr 04_CONTROL_integridad.sql, y si pasa,
-- las queries de armado 06 / 07 / 08 (+ 11 farmacia en SIGESAPOL).
