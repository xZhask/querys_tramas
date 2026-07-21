import sys
with open('c:/laragon/www/querys_tramas/03_MAESTRO_paso2_CPT.sql', 'r', encoding='utf-8') as f:
    text = f.read()

import re

# We see that it deleted DO $$ ... END $$; entirely and we need to put it back.
text = re.sub(
    r"-- ============================================================================\s+-- 1\. ESTANCIAS",
    """-- ============================================================================

-- ============================================================
-- 0. VALIDACIÓN PREVIA: el padrón SIGESAPOL debe existir aquí
-- ============================================================
DO $$
DECLARE
    v_ini DATE;
    v_fin DATE;
    s_ini DATE;
    s_fin DATE;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables
	               WHERE table_name = 'temp_emergencia_sigesapol_estancia') THEN
		RAISE EXCEPTION 'Falta temp_emergencia_sigesapol_estancia. Corre el paso 1 en SIGESAPOL y trasládala a esta BD (ver instrucciones al final del paso 1).';
	END IF;
	IF NOT EXISTS (SELECT 1 FROM information_schema.tables
	               WHERE table_name = 'temp_sigesapol_cfg_periodo') THEN
		RAISE EXCEPTION 'Falta temp_sigesapol_cfg_periodo. Reinicia la ejecución desde el Paso 1.';
	END IF;

    SELECT p_ini, p_fin INTO v_ini, v_fin FROM cfg_periodo LIMIT 1;
    SELECT p_ini, p_fin INTO s_ini, s_fin FROM temp_sigesapol_cfg_periodo LIMIT 1;

    IF (v_ini <> s_ini OR v_fin <> s_fin) THEN
        RAISE EXCEPTION 'Desfase de periodo: CPT solicita % - % pero SIGESAPOL entregó % - %. Reinicie desde el Paso 1.', v_ini, v_fin, s_ini, s_fin;
    END IF;
END $$;


-- ============================================================
-- 1. ESTANCIAS""",
    text
)

with open('c:/laragon/www/querys_tramas/03_MAESTRO_paso2_CPT.sql', 'w', encoding='utf-8') as f:
    f.write(text)
