-- ==============================================================================
-- ARCHIVO GENERADO - NO EDITAR
-- ==============================================================================
-- Este archivo es una COPIA exacta del original: 00_INSTALAR_post_restauracion_SIGESAPOL.sql
-- Creado para la ejecucion autocontenida en la edicion consola.
-- El prefijo indica el ORDEN ESTRICTO de ejecucion.
-- ==============================================================================
-- ============================================================================
-- 00_INSTALAR_post_restauracion_SIGESAPOL.sql
-- Deja un backup recién restaurado de la BD SIGESAPOL (sigesapol_junio)
-- operativo en una sola corrida. IDEMPOTENTE.
--
-- REGLA OPERATIVA: tras restaurar cualquier backup de esta BD, correr este
-- script ANTES de todo (antes de 02_MAESTRO_paso1_SIGESAPOL.sql o cualquier
-- paso de FASE MENSUAL del lado SIGESAPOL).
--
-- Qué instala:
--   1. Parche A [SIGESAPOL] — sp_sigesapol_diagnostico_en_prestacion_emergencia
--   2. Verificación final ✓/✗
-- ============================================================================


-- ============================================================================
-- PARCHE A [SIGESAPOL] — sp_sigesapol_diagnostico_en_prestacion_emergencia
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
	AND dx.estado = 1
	AND dx.deleted_at IS NULL;
END; $$

language 'plpgsql';


-- ============================================================================
-- cfg_ipress_alcance — alcance nivel III (Parte 3): este generador cubre
-- EXCLUSIVAMENTE el Hospital Luis N. Sáenz. Duplicada de la BD CPT (mismo
-- valor) porque las dos BD no pueden leerse entre sí sin dblink/fdw — mismo
-- patrón que cfg_periodo, ver justificación completa en
-- 00_INSTALAR_post_restauracion_CPT.sql.
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
-- log_alcance_depurado — constancia de filas removidas por IPRESS fuera de
-- alcance (ver 00_INSTALAR_post_restauracion_CPT.sql para la versión CPT,
-- que además guarda monto_removido).
-- ============================================================================
CREATE TABLE IF NOT EXISTS log_alcance_depurado (
	periodo_ini date NOT NULL,
	periodo_fin date NOT NULL,
	tabla text NOT NULL,
	codigo_ipress varchar(10),
	nombre_ipress text,
	filas_removidas bigint NOT NULL,
	registrado_en timestamptz NOT NULL DEFAULT now()
);


-- ============================================================================
-- VERIFICACIÓN FINAL
-- ============================================================================
DO $$
DECLARE
	v_check text;
BEGIN
	RAISE NOTICE '=== VERIFICACION INSTALADOR SIGESAPOL ===';

	v_check := CASE WHEN to_regprocedure('sp_sigesapol_diagnostico_en_prestacion_emergencia(integer)') IS NOT NULL
		THEN '✓' ELSE '✗ (Parche A no aplico)' END;
	RAISE NOTICE 'sp_sigesapol_diagnostico_en_prestacion_emergencia (Parche A): %', v_check;

	v_check := CASE WHEN EXISTS (SELECT 1 FROM cfg_ipress_alcance WHERE codigo_ipress = '00013591')
		THEN '✓' ELSE '✗ (tabla no se creo o falta la fila LNS)' END;
	RAISE NOTICE 'cfg_ipress_alcance (LNS 00013591): %', v_check;

	v_check := CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'log_alcance_depurado')
		THEN '✓' ELSE '✗ (tabla no se creo)' END;
	RAISE NOTICE 'Tabla log_alcance_depurado: %', v_check;

	RAISE NOTICE '=== FIN VERIFICACION ===';
END $$;

