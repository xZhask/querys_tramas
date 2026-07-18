<?php
declare(strict_types=1);

/**
 * Driver headless para correr el pipeline mensual completo (o solo los
 * instaladores) sin pasar por la UI/login. Reutiliza el mismo código que usa
 * aplicativo/public/ejecutar_paso.php (PipelineRunner, EjecucionRepository,
 * pipelineConfig()) — no reimplementa nada de la lógica del pipeline.
 *
 * Uso:
 *   php cli_run_period.php instaladores
 *   php cli_run_period.php YYYY-MM [--desde=N] [--hasta=N]
 */

require_once __DIR__ . '/app/bootstrap.php';

function ejecutarSqlCrudo(PDO $pdo, string $rutaArchivo): void
{
    $sql = file_get_contents($rutaArchivo);
    if ($sql === false) {
        throw new RuntimeException("No se pudo leer {$rutaArchivo}");
    }
    $runner = new PipelineRunner(2000, 1); // año/mes irrelevantes para este uso
    $ref = new ReflectionClass($runner);
    $metodo = $ref->getMethod('dividirSentencias');
    $metodo->setAccessible(true);
    $sentencias = $metodo->invoke($runner, $sql);
    foreach ($sentencias as $sentencia) {
        $pdo->exec($sentencia);
    }
}

$args = $argv;
array_shift($args);
$modo = $args[0] ?? '';

if ($modo === 'instaladores') {
    echo "== Instalador CPT ==\n";
    ejecutarSqlCrudo(getCptPdo(), REPO_ROOT . '/00_INSTALAR_post_restauracion_CPT.sql');
    echo "OK\n";
    echo "== Instalador SIGESAPOL ==\n";
    ejecutarSqlCrudo(getSigesapolPdo(), REPO_ROOT . '/00_INSTALAR_post_restauracion_SIGESAPOL.sql');
    echo "OK\n";
    exit(0);
}

if (!preg_match('/^\d{4}-\d{2}$/', $modo)) {
    fwrite(STDERR, "Uso: php cli_run_period.php instaladores | YYYY-MM [--desde=N]\n");
    exit(1);
}

[$anioStr, $mesStr] = explode('-', $modo);
$anio = (int) $anioStr;
$mes = (int) $mesStr;
$periodo = $modo;

$desde = 1;
$hasta = null;
foreach ($args as $a) {
    if (preg_match('/^--desde=(\d+)$/', $a, $m)) {
        $desde = (int) $m[1];
    }
    if (preg_match('/^--hasta=(\d+)$/', $a, $m)) {
        $hasta = (int) $m[1];
    }
}

$repo = new EjecucionRepository(getCptPdo());
$pasos = pipelineConfig();

$enCurso = $repo->hayEnCurso();
if ($enCurso !== null) {
    $inactivo = time() - strtotime($enCurso['actualizado_en']);
    if ($inactivo > 900) {
        $repo->finalizar((int) $enCurso['id'], 'fallido');
    } else {
        fwrite(STDERR, "Ya hay una ejecucion en curso (periodo {$enCurso['periodo']}).\n");
        exit(1);
    }
}

$pasoInicial = $desde > 1 ? $desde - 1 : 0;
$id = $repo->crear($periodo, 'generacion', 'cli', $pasoInicial);
echo "Ejecucion #{$id} iniciada para {$periodo} (desde paso {$desde})\n";

$runner = new PipelineRunner($anio, $mes);
$ok = true;
foreach ($pasos as $paso) {
    if ($paso['numero'] < $desde || ($hasta !== null && $paso['numero'] > $hasta)) {
        continue;
    }
    $t0 = microtime(true);
    echo "-> Paso {$paso['numero']}: {$paso['nombre']} ... ";
    $resultado = $runner->ejecutar($paso);
    $dur = (microtime(true) - $t0) * 1000;
    $repo->registrarPaso(
        $id,
        $paso['numero'],
        $paso['nombre'],
        $resultado['ok'] ? 'completado' : 'fallido',
        $resultado['mensaje'],
        $resultado['conteo'],
        $resultado['detalle_tecnico'],
        $dur
    );
    if ($resultado['ok']) {
        echo "OK";
        if ($resultado['conteo'] !== null) {
            echo " (conteo={$resultado['conteo']})";
        }
        echo sprintf(" [%.0fms]\n", $dur);
    } else {
        echo "FALLO\n";
        echo "   mensaje: {$resultado['mensaje']}\n";
        echo "   detalle: " . ($resultado['detalle_tecnico'] ?? '') . "\n";
        $ok = false;
        break;
    }
    if ($paso['numero'] === 11) {
        $aserciones = parsearAserciones((string) $resultado['detalle_tecnico']);
        foreach ($aserciones as $a) {
            echo "     {$a['nombre']}: {$a['estado']} {$a['detalle']}\n";
        }
    }
}

$repo->finalizar($id, $ok ? 'completado' : 'fallido');
echo $ok ? "=== {$periodo}: PIPELINE COMPLETO ===\n" : "=== {$periodo}: PIPELINE DETENIDO POR FALLO ===\n";
exit($ok ? 0 : 1);
