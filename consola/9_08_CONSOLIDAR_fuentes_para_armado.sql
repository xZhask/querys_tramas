-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 08_CONSOLIDAR_fuentes_para_armado.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================

-- ============================================================================
-- 08_CONSOLIDAR_fuentes_para_armado.sql
-- Consolida canónico + complemento DENTRO de las tablas que el armado ya lee
-- (temp_bdt_*, temp_laboratorio_*, temp_hospitalizacion_local), aplicando las
-- reglas de deduplicación finales. Así las queries de armado corren SIN
-- modificaciones estructurales y las tramas salen completas y sin dobles.
--
-- Correr en la BD CPT, DESPUÉS del 07 (los reportes B.1/B.2/B.3 del 07 deben
-- revisarse ANTES: una vez consolidado, el cruce ya no muestra los pares).
--
-- Reglas aplicadas (checks 24-25):
--   Tipo 1 (médicos):        duplicado = paciente+fecha+código+mismo médico
--   Tipo 2 y 3 (lab/imag.):  duplicado = paciente+fecha+código+misma cantidad
--   Estancias:               duplicado = documento + solapamiento de fechas
--
-- Mecánica según la fuente canónica del mes:
--   CPT (jul-sep 2025):       las tablas CPT quedan intactas y se INSERTAN
--                             solo las filas SIGESAPOL sin par (anti-join).
--   SIGESAPOL (oct-dic 2025): se BORRAN de las tablas CPT las filas duplicadas
--                             (gana la versión SIGESAPOL) y se INSERTAN TODAS
--                             las filas SIGESAPOL. Lo que sobrevive de CPT es,
--                             por construcción, el complemento.
-- Las filas provenientes de SIGESAPOL llevan digitador = 'SIGESAPOL' para
-- trazabilidad en el Excel.
-- ============================================================================

-- =========== FUENTE CANÓNICA: derivada de cfg_fuente_canonica ==============
-- Ya NO se edita a mano. Se deriva del período activo en cfg_periodo contra
-- las vigencias registradas en cfg_fuente_canonica (ver CONTEXTO_CANONICO.md,
-- regla inmutable #1, y Parte 2 de 00_RUTA_jul_dic_2025.md). Si la tabla no
-- existe o el período no tiene vigencia definida, esto falla con RAISE
-- EXCEPTION en vez de asumir un valor por defecto.
DROP TABLE IF EXISTS cfg_canonico;
CREATE TABLE cfg_canonico AS
SELECT fuente::text AS fuente
FROM cfg_fuente_canonica
WHERE (SELECT p_ini FROM cfg_periodo) BETWEEN periodo_desde AND COALESCE(periodo_hasta, DATE '9999-12-31');
-- ============================================================================

DO $$
DECLARE
	v_matches integer;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='cfg_fuente_canonica') THEN
		RAISE EXCEPTION 'Falta cfg_fuente_canonica. Correr 00_INSTALAR_post_restauracion_CPT.sql primero.';
	END IF;
	SELECT COUNT(*) INTO v_matches FROM cfg_fuente_canonica
	WHERE (SELECT p_ini FROM cfg_periodo) BETWEEN periodo_desde AND COALESCE(periodo_hasta, DATE '9999-12-31');
	IF v_matches = 0 THEN
		RAISE EXCEPTION 'El período de cfg_periodo (p_ini=%) no tiene vigencia definida en cfg_fuente_canonica.', (SELECT p_ini FROM cfg_periodo);
	ELSIF v_matches > 1 THEN
		RAISE EXCEPTION 'El período de cfg_periodo (p_ini=%) matchea % vigencias en cfg_fuente_canonica (deben ser disjuntas).', (SELECT p_ini FROM cfg_periodo), v_matches;
	END IF;
	IF (SELECT fuente FROM cfg_canonico) NOT IN ('CPT','SIGESAPOL') THEN
		RAISE EXCEPTION 'cfg_canonico.fuente debe ser CPT o SIGESAPOL';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='temp_sigesapol_procedimientos') THEN
		RAISE EXCEPTION 'Falta temp_sigesapol_procedimientos (correr archivo 06 en SIGESAPOL y trasladar)';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name='temp_sigesapol_cfg_periodo') THEN
		RAISE EXCEPTION 'Falta temp_sigesapol_cfg_periodo. Reinicia la ejecución desde el Paso 1.';
	END IF;
    
    DECLARE
        v_ini DATE;
        v_fin DATE;
        s_ini DATE;
        s_fin DATE;
    BEGIN
        SELECT p_ini, p_fin INTO v_ini, v_fin FROM cfg_periodo LIMIT 1;
        SELECT p_ini, p_fin INTO s_ini, s_fin FROM temp_sigesapol_cfg_periodo LIMIT 1;

        IF (v_ini <> s_ini OR v_fin <> s_fin) THEN
            RAISE EXCEPTION 'Desfase de periodo: CPT solicita % - % pero SIGESAPOL entregó % - %. Reinicie desde el Paso 1.', v_ini, v_fin, s_ini, s_fin;
        END IF;
    END;
END $$;


-- ============================================================
-- 1. ESTANCIAS HOSPITALARIAS -> temp_hospitalizacion_local
-- ============================================================

-- 1a. (solo canónico SIGESAPOL) borrar de CPT las estancias duplicadas
DELETE FROM temp_hospitalizacion_local c
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_hospitalizacion_sigesapol_estancia s
	WHERE s.sp_numero_documento_paciente = c.sp_numero_documento_paciente
	  AND s.sp_fecha_atencion <= c.sp_fecha_alta::date
	  AND s.sp_fecha_alta     >= c.sp_fecha_atencion::date
);

-- 1b. insertar estancias SIGESAPOL (todas si es canónico; solo sin par si no)
INSERT INTO temp_hospitalizacion_local (
	historia, sp_tipo_documento_paciente, sp_numero_documento_paciente,
	sp_apellido_paterno_paciente, sp_apellido_materno_paciente, sp_nombres_paciente,
	sp_fecha_nacimiento, sp_genero_paciente, sp_condicion_asegurado, sp_tipo_atencion,
	sp_codigo_ipress, sp_nombre_ipress, sp_upss_codigo, sp_upss_descripcion,
	sp_fecha_atencion, sp_fecha_alta,
	sp_tipo_documento_responsable, sp_numero_documento_responsable,
	sp_apellido_paterno_responsable, sp_apellido_materno_responsable, sp_nombres_responsable,
	sp_profesion_responsable, sp_especialidad_responsable, sp_circunstancia_alta,
	sp_tipo_dx_01, sp_codigo_dx_01, sp_descripcion_dx_01,
	sp_tipo_dx_02, sp_codigo_dx_02, sp_descripcion_dx_02,
	sp_tipo_dx_03, sp_codigo_dx_03, sp_descripcion_dx_03,
	sp_codigo_procedimiento, sp_descripcion_procedimiento,
	sp_dias_estancia, sp_valorizacion_total,
	digitador, fecha_registro, id_prestacion_cpt
)
SELECT
	NULL, s.sp_tipo_documento_paciente::int, s.sp_numero_documento_paciente,
	s.sp_apellido_paterno_paciente, s.sp_apellido_materno_paciente, s.sp_nombres_paciente,
	s.sp_fecha_nacimiento_paciente::date, s.sp_genero_paciente::int, s.sp_condicion_asegurado::int, s.sp_tipo_atencion,
	s.sp_codigo_ipress, s.sp_nombre_ipress, s.sp_upss_codigo, s.sp_upss_nombre,
	s.sp_fecha_atencion, s.sp_fecha_alta,
	s.sp_tipo_documento_responsable::int, s.sp_numero_documento_responsable,
	s.sp_apellido_paterno_responsable, s.sp_apellido_materno_responsable, s.sp_nombres_responsable,
	s.sp_codigo_profesion_responsable, s.sp_codigo_especialidad, s.sp_circunstancia_alta_sigesapol::varchar,
	s.sp_tipo_dx_01, s.sp_codigo_dx_01, s.sp_descripcion_dx_01,
	s.sp_tipo_dx_02, s.sp_codigo_dx_02, s.sp_descripcion_dx_02,
	s.sp_tipo_dx_03, s.sp_codigo_dx_03, s.sp_descripcion_dx_03,
	s.cpms_alta, UPPER(k.descripcioncpt),
	s.cantidad_cpms_estancia, s.sp_valorizacion_estancia,
	'SIGESAPOL', s.sp_fecha_alta, s.id_hospitalizacion_sigesapol
FROM temp_hospitalizacion_sigesapol_estancia s
LEFT JOIN cpt k ON k.cod_cpt = s.cpms_alta
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
   OR NOT EXISTS (
	SELECT 1 FROM temp_hospitalizacion_local c
	WHERE c.sp_numero_documento_paciente = s.sp_numero_documento_paciente
	  AND c.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND s.sp_fecha_atencion <= c.sp_fecha_alta::date
	  AND s.sp_fecha_alta     >= c.sp_fecha_atencion::date
);


-- ============================================================
-- 2. PROCEDIMIENTOS MÉDICOS E IMÁGENES (tipos 1 y 3) -> temp_bdt_*
--    consulta='1', emergencia='2', hospitalización='3'
-- ============================================================

-- 2a. (solo canónico SIGESAPOL) borrar duplicados de las BDT según regla
DELETE FROM temp_bdt_consulta_local cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '1' AND sig.tipo_procedimiento IN (1,3)
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
);
DELETE FROM temp_bdt_emergencia_sigesapol cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '2' AND sig.tipo_procedimiento IN (1,3)
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
);
DELETE FROM temp_bdt_hospitalizacion_local cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '3' AND sig.tipo_procedimiento IN (1,3)
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) )
);

-- 2b. insertar filas SIGESAPOL tipos 1 y 3 (todas si canónico; sin par si no)
--     Una sentencia por tabla destino; misma lógica, cambia el filtro de trama.
INSERT INTO temp_bdt_consulta_local (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_servicio, upss_descripcion,
	fecha_atencion, fecha_alta,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion,
	digitador, fecha_registro, id_prestacion_cpt
)
SELECT
	sig.tipo_atencion_trama::int, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_alta::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '1' AND sig.tipo_procedimiento IN (1,3)
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_bdt_consulta_local cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND cpt.numero_documento_responsable = sig.sp_numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad) ) ) );

INSERT INTO temp_bdt_emergencia_sigesapol (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_servicio, upss_descripcion,
	fecha_atencion, fecha_alta,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion,
	digitador, fecha_registro, id_prestacion_cpt
)
SELECT
	sig.tipo_atencion_trama::int, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_alta::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '2' AND sig.tipo_procedimiento IN (1,3)
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_bdt_emergencia_sigesapol cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND cpt.numero_documento_responsable = sig.sp_numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad) ) ) );

INSERT INTO temp_bdt_hospitalizacion_local (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_servicio, upss_descripcion,
	fecha_atencion, fecha_alta,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion,
	digitador, fecha_registro, id_prestacion_cpt
)
SELECT
	sig.tipo_atencion_trama::int, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_alta::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '3' AND sig.tipo_procedimiento IN (1,3)
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_bdt_hospitalizacion_local cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND ( (sig.tipo_procedimiento = 1 AND cpt.numero_documento_responsable = sig.sp_numero_documento_responsable)
	     OR (sig.tipo_procedimiento = 3 AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad) ) ) );


-- ============================================================
-- 3. LABORATORIO (tipo 2) -> temp_laboratorio_*
--    Regla: paciente + fecha + código + misma cantidad
-- ============================================================

DELETE FROM temp_laboratorio_consulta_local cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '1' AND sig.tipo_procedimiento = 2
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro
);
DELETE FROM temp_laboratorio_emergencia_sigesapol cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '2' AND sig.tipo_procedimiento = 2
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro
);
DELETE FROM temp_laboratorio_hospitalizacion_local cpt
WHERE (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
  AND EXISTS (
	SELECT 1 FROM temp_sigesapol_procedimientos sig
	WHERE sig.tipo_atencion_trama = '3' AND sig.tipo_procedimiento = 2
	  AND sig.sp_numero_documento_paciente = cpt.numero_documento_paciente
	  AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date
	  AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento
	  AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro
);

-- Inserciones tipo 2 (una por tabla destino; solo cambia el filtro de trama)
INSERT INTO temp_laboratorio_consulta_local (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_codigo, upss_descripcion,
	fecha_atencion, fecha_muestra,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion_total,
	digitador, fecha_registro, id_prestacion_laboratorio
)
SELECT
	sig.tipo_atencion_trama, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_atencion::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '1' AND sig.tipo_procedimiento = 2
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_laboratorio_consulta_local cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad ) );

INSERT INTO temp_laboratorio_emergencia_sigesapol (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_codigo, upss_descripcion,
	fecha_atencion, fecha_muestra,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion_total,
	digitador, fecha_registro, id_prestacion_laboratorio
)
SELECT
	sig.tipo_atencion_trama, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_atencion::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '2' AND sig.tipo_procedimiento = 2
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_laboratorio_emergencia_sigesapol cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad ) );

INSERT INTO temp_laboratorio_hospitalizacion_local (
	tipo_atencion, historia, tipo_documento_paciente, numero_documento_paciente,
	apellido_paterno_paciente, apellido_materno_paciente, nombres_paciente,
	fecha_nacimiento, genero_paciente, condicion_asegurado,
	codigo_ipress, nombre_ipress, upss_codigo, upss_descripcion,
	fecha_atencion, fecha_muestra,
	tipo_documento_responsable, numero_documento_responsable,
	apellido_paterno_responsable, apellido_materno_responsable, nombres_responsable,
	profesion_responsable, especialidad_responsable,
	tipo_diagnostico, codigo_diagnostico, descripcion_diagnostico,
	codigo_procedimiento, descripcion_procedimiento,
	suma_cantidad_registro, valorizacion_total,
	digitador, fecha_registro, id_prestacion_laboratorio
)
SELECT
	sig.tipo_atencion_trama, sig.historia, sig.sp_tipo_documento_paciente::int, sig.sp_numero_documento_paciente,
	sig.sp_apellido_paterno_paciente, sig.sp_apellido_materno_paciente, sig.sp_nombres_paciente,
	sig.sp_fecha_nacimiento_paciente::date, sig.sp_genero_paciente::int, sig.sp_condicion_asegurado::int,
	sig.sp_codigo_ipress, sig.sp_nombre_ipress, sig.sp_upss_codigo, sig.sp_upss_nombre,
	sig.sp_fecha_atencion::date, sig.sp_fecha_atencion::date,
	sig.sp_tipo_documento_responsable::int, sig.sp_numero_documento_responsable,
	sig.sp_apellido_paterno_responsable, sig.sp_apellido_materno_responsable, sig.sp_nombres_responsable,
	sig.sp_codigo_profesion_responsable, sig.sp_codigo_especialidad,
	sig.sp_tipo_dx_01, sig.sp_codigo_dx_01, sig.sp_descripcion_dx_01,
	sig.sp_codigo_procedimiento, sig.sp_descripcion_procedimiento,
	sig.sp_suma_cantidad, sig.sp_valorizacion_calculada,
	'SIGESAPOL', sig.sp_fecha_atencion::date, sig.id_prestacion_sigesapol
FROM temp_sigesapol_procedimientos sig
WHERE sig.tipo_atencion_trama = '3' AND sig.tipo_procedimiento = 2
  AND ( (SELECT fuente FROM cfg_canonico) = 'SIGESAPOL'
     OR NOT EXISTS (
	SELECT 1 FROM temp_laboratorio_hospitalizacion_local cpt
	WHERE cpt.digitador IS DISTINCT FROM 'SIGESAPOL'
	  AND cpt.numero_documento_paciente = sig.sp_numero_documento_paciente
	  AND cpt.fecha_atencion::date = sig.sp_fecha_atencion::date
	  AND cpt.codigo_procedimiento = sig.sp_codigo_procedimiento
	  AND cpt.suma_cantidad_registro = sig.sp_suma_cantidad ) );


-- ============================================================
-- 4. RESUMEN POST-CONSOLIDACIÓN (filas por tabla y por origen)
-- ============================================================
SELECT 'hospitalizacion estancias' AS tabla, digitador = 'SIGESAPOL' AS origen_sigesapol, COUNT(*)
FROM temp_hospitalizacion_local GROUP BY 2
UNION ALL SELECT 'bdt consulta', digitador = 'SIGESAPOL', COUNT(*) FROM temp_bdt_consulta_local GROUP BY 2
UNION ALL SELECT 'bdt emergencia', digitador = 'SIGESAPOL', COUNT(*) FROM temp_bdt_emergencia_sigesapol GROUP BY 2
UNION ALL SELECT 'bdt hospitalizacion', digitador = 'SIGESAPOL', COUNT(*) FROM temp_bdt_hospitalizacion_local GROUP BY 2
UNION ALL SELECT 'lab consulta', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_consulta_local GROUP BY 2
UNION ALL SELECT 'lab emergencia', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_emergencia_sigesapol GROUP BY 2
UNION ALL SELECT 'lab hospitalizacion', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_hospitalizacion_local GROUP BY 2
ORDER BY 1, 2;

-- IMPORTANTE: este script es de una sola pasada por período. Si necesitas
-- re-correrlo, primero regenera las tablas con el paso 2 (03_MAESTRO), porque
-- la consolidación modifica las tablas en el lugar.
