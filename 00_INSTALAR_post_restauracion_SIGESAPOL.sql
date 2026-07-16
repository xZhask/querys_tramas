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

	RAISE NOTICE '=== FIN VERIFICACION ===';
END $$;
