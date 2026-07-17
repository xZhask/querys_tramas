<?php
declare(strict_types=1);

/**
 * Mapeo paso -> archivo, en el mismo orden que run_month.ps1. Cada paso es
 * o un .sql del repo (ejecutado vía PDO::exec) o uno de los 3 scripts .py
 * (ejecutado vía proc_open), o el traslado (servicio PHP). El aplicativo
 * NUNCA reimplementa lo que hacen estos archivos: solo los invoca y valida
 * que hayan corrido.
 *
 * tipo:
 *   'sql'      -> PDO::exec() del archivo completo en la BD indicada, con
 *                 sustitución de período si edita_periodo=true.
 *   'traslado' -> TrasladoService::ejecutar() (paso 4, no es un .sql).
 *   'python'   -> proc_open del script con --year --month, cwd=REPO_ROOT.
 *
 * validacion:
 *   ['tipo' => 'conteo', 'bd' => 'cpt'|'sigesapol', 'tabla' => '...']
 *       -> paso ok si SELECT COUNT(*) FROM tabla no lanza error (el conteo
 *          se muestra igual, aunque sea 0, no bloquea salvo error SQL).
 *   ['tipo' => 'sin_error']
 *       -> paso ok si no lanzó excepción.
 *   ['tipo' => 'archivo_existe', 'ruta' => callable($periodo): string]
 *       -> paso ok si exit code 0 Y el archivo existe.
 *   ['tipo' => 'exit_0']
 *       -> paso ok solo si el proceso devolvió código 0.
 */

return [
    [
        'numero' => 1,
        'nombre' => 'Estancias de emergencia (SIGESAPOL)',
        'archivo' => '02_MAESTRO_paso1_SIGESAPOL.sql',
        'bd' => 'sigesapol',
        'tipo' => 'sql',
        'edita_periodo' => true,
        'una_pasada' => false,
        'validacion' => ['tipo' => 'conteo', 'bd' => 'sigesapol', 'tabla' => 'temp_emergencia_sigesapol_estancia'],
    ],
    [
        'numero' => 2,
        'nombre' => 'Estancias de hospitalización (SIGESAPOL)',
        'archivo' => '05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql',
        'bd' => 'sigesapol',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => false,
        'validacion' => ['tipo' => 'conteo', 'bd' => 'sigesapol', 'tabla' => 'temp_hospitalizacion_sigesapol_estancia'],
    ],
    [
        'numero' => 3,
        'nombre' => 'Procedimientos SIGESAPOL',
        'archivo' => '06_FASE2_SIGESAPOL_procedimientos.sql',
        'bd' => 'sigesapol',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => false,
        'validacion' => ['tipo' => 'conteo', 'bd' => 'sigesapol', 'tabla' => 'temp_sigesapol_procedimientos'],
    ],
    [
        'numero' => 4,
        'nombre' => 'Traslado SIGESAPOL -> CPT',
        'archivo' => null,
        'bd' => 'ambas',
        'tipo' => 'traslado',
        'edita_periodo' => false,
        'una_pasada' => false,
        'tablas' => [
            'temp_emergencia_sigesapol_estancia',
            'temp_hospitalizacion_sigesapol_estancia',
            'temp_sigesapol_procedimientos',
        ],
        'validacion' => ['tipo' => 'sin_error'],
    ],
    [
        'numero' => 5,
        'nombre' => 'Materialización de tablas temp_* (CPT)',
        'archivo' => '03_MAESTRO_paso2_CPT.sql',
        'bd' => 'cpt',
        'tipo' => 'sql',
        'edita_periodo' => true,
        'una_pasada' => false,
        // Índices compuestos que run_month.ps1 crea justo después de este
        // paso: sin ellos, la consolidación (paso 7) pasa de segundos a
        // decenas de minutos (ver CONTEXTO_CANONICO.md, "Automatización").
        'crear_indices_despues' => true,
        // El propio 03_MAESTRO_paso2_CPT.sql crea estos 6 índices con
        // CREATE INDEX simple (sin IF NOT EXISTS) sobre tablas que este
        // paso NO recrea (p.ej. temp_emergencia_sigesapol_estancia, que
        // pertenece al traslado). Si "Reiniciar desde paso 5" se usa sin
        // volver a correr el traslado, el paso falla con "ya existe". Se
        // limpian antes de ejecutar el archivo para que sea repetible.
        'limpiar_indices_antes' => [
            'idx_tmp_emer_sig_doc', 'idx_tmp_hosp_doc', 'idx_tmp_bdt_emer_doc',
            'idx_tmp_bdt_hosp_doc', 'idx_tmp_lab_emer_doc', 'idx_tmp_lab_hosp_doc',
        ],
        'validacion' => ['tipo' => 'conteo', 'bd' => 'cpt', 'tabla' => 'temp_bdt_consulta_local'],
    ],
    [
        'numero' => 6,
        'nombre' => 'Deduplicación CPT / SIGESAPOL',
        'archivo' => '07_FASE2_deduplicacion_CPT_SIGESAPOL.sql',
        'bd' => 'cpt',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => true,
        'validacion' => ['tipo' => 'sin_error'],
    ],
    [
        'numero' => 7,
        'nombre' => 'Consolidación de fuentes para armado',
        'archivo' => '08_CONSOLIDAR_fuentes_para_armado.sql',
        'bd' => 'cpt',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => true,
        'validacion' => ['tipo' => 'sin_error'],
    ],
    [
        'numero' => 8,
        'nombre' => 'Reclasificación de emergencias > 24h',
        'archivo' => '12_RECLASIFICAR_emergencias_24h.sql',
        'bd' => 'cpt',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => true,
        'validacion' => ['tipo' => 'sin_error'],
    ],
    [
        'numero' => 9,
        'nombre' => 'Control de integridad',
        'archivo' => '04_CONTROL_integridad.sql',
        'bd' => 'cpt',
        'tipo' => 'sql',
        'edita_periodo' => false,
        'una_pasada' => false,
        'guarda_salida_en' => '03_INFORMATIVOS/controles_integridad_raw.txt',
        'validacion' => ['tipo' => 'sin_error'],
    ],
    [
        'numero' => 10,
        'nombre' => 'Generación de tramas + libro de auditoría (v2)',
        'archivo' => 'generate_outputs_v2.py',
        'bd' => 'ambas',
        'tipo' => 'python',
        'edita_periodo' => false,
        'una_pasada' => false,
        'validacion' => ['tipo' => 'archivo_existe', 'ruta' => 'metricas'],
    ],
    [
        'numero' => 11,
        'nombre' => 'Verificación de aserciones A1/A2/A3/A4',
        'archivo' => '14_VERIFICAR_ASERTOS.py',
        'bd' => 'cpt',
        'tipo' => 'python',
        'edita_periodo' => false,
        'una_pasada' => false,
        'validacion' => ['tipo' => 'exit_0'],
    ],
];
