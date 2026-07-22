<?php
declare(strict_types=1);

/**
 * Aplica 01_PARCHES_funciones.sql (idempotente: CREATE OR REPLACE) contra la
 * BD CPT, reutilizando el mismo helper que cli_run_period.php usa para
 * "instaladores" (PipelineRunner::dividirSentencias + PDO::exec).
 * Uso: php cli_aplicar_parches.php
 */

require_once __DIR__ . '/app/bootstrap.php';

function ejecutarSqlCrudo(PDO $pdo, string $rutaArchivo): void
{
    $sql = file_get_contents($rutaArchivo);
    if ($sql === false) {
        throw new RuntimeException("No se pudo leer {$rutaArchivo}");
    }
    $runner = new PipelineRunner(2000, 1);
    $ref = new ReflectionClass($runner);
    $metodo = $ref->getMethod('dividirSentencias');
    $metodo->setAccessible(true);
    $sentencias = $metodo->invoke($runner, $sql);
    foreach ($sentencias as $sentencia) {
        $pdo->exec($sentencia);
    }
}

echo "== Aplicando 01_PARCHES_funciones.sql contra CPT ({$GLOBALS['argv'][0]}) ==\n";
ejecutarSqlCrudo(getCptPdo(), REPO_ROOT . '/01_PARCHES_funciones.sql');
echo "OK\n";
