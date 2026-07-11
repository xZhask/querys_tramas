
-- ======== ATENCIONES DE EMERGENCIA ==========
CREATE TABLE temp_emergencia_local AS
	SELECT * FROM sp_emergencia_en_periodo('20231201', '20231231');

-- ======== ATENCIONES DE HOSPITALIZACIÓN ==========
CREATE TABLE temp_hospitalizacion_local AS
	SELECT * FROM sp_hospitalizacion_en_periodo('20231201', '20231231');



-- ======== BDT - PROCEDIMIENTOS MÉDICOS ==========

-- Todos los procedimientos del mes (con todos los tipos de atención)
-- Utilizado para la DIRSAPOL
-- PARA DIRSAPOL
 CREATE TABLE temp_bdt_mes_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion('20241201', '20241231', 4);

-- ===
/*
CREATE TABLE temp_bdt_enfermedades_raras_enero2019_junio2023 AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion_y_diagnosticos('20190101', '20230630', 4, 1); -- 2019-2023
*/

-- Todos los procedimientos con tipo de atención de consulta externa dentro del mes de producción
CREATE TABLE temp_bdt_consulta_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion('20241001', '20241031', 1);

-- Todos los procedimientos con tipo de atención de emergencia, desde el inicio del convenio
-- guardar inicial y luego buscar reducir la cantidad pasando parámetros
--CREATE TABLE temp_bdt_emergencia_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion('20240501', '20240531', 2);

CREATE TABLE temp_bdt_emergencia_sigesapol AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion('20240501', '20240531', 22);

-- Todos los procedimientos con tipo de atención de hospitalización, desde el inicio del convenio
-- guardar inicial y luego buscar reducir la cantidad pasando parámetros
CREATE TABLE temp_bdt_hospitalizacion_local AS
	SELECT * FROM sp_procedimientos_segun_tipo_atencion('20240501', '20240531', 3);

-- select tipo_atencion, count(tipo_atencion) from temp_bdt_mes_local group by tipo_atencion

-- SELECT * FROM sp_procedimientos_segun_tipo_atencion('20230701', '20230731', 4) WHERE tipo_atencion=2
-- ======== ============================ ==========

-- ======== EXÁMENES DE LABORATORIO ==========

-- Todos los exámenes de laboratorio del mes (con todos los tipos de atención)
-- PARA DIRSAPOL
CREATE TABLE temp_laboratorio_mes_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion('20241201', '20241231', 4); 
-- ===

-- Todos los exámenes de laboratorio con tipo de atención de consulta externa dentro del mes de producción
CREATE TABLE temp_laboratorio_consulta_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion('20240501', '20240531', 1); 

-- Todos los exámenes de laboratorio con tipo de atención de emergencia, desde el inicio del convenio
-- guardar inicial y luego buscar reducir la cantidad pasando parámetros
--CREATE TABLE temp_laboratorio_emergencia_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion('20240501', '20240531', 2); 

-- SIGESAPOL
-- Después de crear la tabla temp_emergencia_sigesapol
-- Actualizamos el procedimiento sp_laboratorio_segun_tipo_atencion
CREATE TABLE temp_laboratorio_emergencia_sigesapol AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion('20240501', '20240531', 2); 

-- Todos los exámenes de laboratorio con tipo de atención de hospitalización, desde el inicio del convenio
-- guardar inicial y luego buscar reducir la cantidad pasando parámetros
CREATE TABLE temp_laboratorio_hospitalizacion_local AS
	SELECT * FROM sp_laboratorio_segun_tipo_atencion('20240501', '20240531', 3); 

-- select tipo_atencion, count(tipo_atencion) from temp_bdt_mes_local group by tipo_atencion
