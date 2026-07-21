import sys
with open('c:/laragon/www/querys_tramas/02_MAESTRO_paso1_SIGESAPOL.sql', 'r', encoding='utf-8') as f:
    lines = f.readlines()

idx = -1
for i, l in enumerate(lines):
    if 'Verificación rápida post-creación:' in l:
        idx = i
        break

if idx != -1:
    final = lines[:idx] + [
        '-- Verificación rápida post-creación:\n',
        'SELECT COUNT(*) AS estancias_emergencia,\n',
        '       MIN(sp_fecha_atencion) AS primera_atencion,\n',
        '       MAX(sp_fecha_alta_emergencia) AS ultima_alta,\n',
        '       COUNT(*) FILTER (WHERE sp_numero_documento_paciente IS NULL) AS sin_documento\n',
        'FROM temp_emergencia_sigesapol_estancia;\n',
        '-- "sin_documento" > 0 => emergencias sin asegurado vinculado (LEFT JOIN):\n',
        '-- revisar antes de continuar, porque no cruzarán con los procedimientos CPT.\n\n',
        '-- ============================================================================\n',
        '-- 0. GUARDIÁN DEL PERIODO (SELLO PARA TRANSFERENCIA)\n',
        '-- ============================================================================\n',
        'DROP TABLE IF EXISTS temp_sigesapol_cfg_periodo;\n',
        'CREATE TABLE temp_sigesapol_cfg_periodo AS\n',
        'SELECT p_ini, p_fin FROM cfg_periodo;\n',
        '-- ============================================================================\n'
    ]
    with open('c:/laragon/www/querys_tramas/02_MAESTRO_paso1_SIGESAPOL.sql', 'w', encoding='utf-8') as f:
        f.writelines(final)
