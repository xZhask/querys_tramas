<?php
declare(strict_types=1);

require_once __DIR__ . '/../app/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonSalida(['ok' => false, 'mensaje' => 'Método no permitido.'], 405);
}

$periodo = (string) ($_POST['periodo'] ?? '');
if (!ArchivoService::periodoValido($periodo)) {
    jsonSalida(['ok' => false, 'errores' => ['Período inválido.']]);
}

if (!isset($_FILES['archivo']) || $_FILES['archivo']['error'] !== UPLOAD_ERR_OK) {
    jsonSalida(['ok' => false, 'errores' => ['No se recibió el archivo o hubo un error al subirlo.']]);
}

$nombreSubido = $_FILES['archivo']['name'];
if (strtolower(pathinfo($nombreSubido, PATHINFO_EXTENSION)) !== 'xlsx') {
    jsonSalida(['ok' => false, 'errores' => ['El archivo debe ser un libro de Excel (.xlsx).']]);
}

$repoEjecuciones = new EjecucionRepository(getCptPdo());
$enCurso = $repoEjecuciones->hayEnCurso();
if ($enCurso !== null) {
    jsonSalida(['ok' => false, 'errores' => ["Ya hay una ejecución en curso (período {$enCurso['periodo']}). Espere a que termine."]]);
}

$servicio = new ReincorporarService();
$validacion = $servicio->validar($periodo, $_FILES['archivo']['tmp_name']);
if (!$validacion['ok']) {
    jsonSalida(['ok' => false, 'errores' => $validacion['errores']]);
}

$ejecucionId = $repoEjecuciones->crear($periodo, 'reincorporacion', usuarioLocal());

try {
    $respaldo = $servicio->reemplazarLibroAuditoria($periodo, $_FILES['archivo']['tmp_name']);

    [$anio, $mes] = array_map('intval', explode('-', $periodo));
    $runner = new PipelineRunner($anio, $mes);

    $inicio = microtime(true);
    $resultado13 = $runner->ejecutarScriptCrudo('13_REINCORPORAR_decisiones.py');
    $duracion13 = (microtime(true) - $inicio) * 1000;

    $ok13 = $resultado13['codigo'] === 0;
    $repoEjecuciones->registrarPaso(
        $ejecucionId,
        1,
        'Reincorporación de decisiones (script 13)',
        $ok13 ? 'completado' : 'fallido',
        $ok13 ? 'Decisiones aplicadas a las tramas TXT.' : 'El script de reincorporación devolvió un error.',
        null,
        trim($resultado13['stdout'] . "\n" . $resultado13['stderr']),
        $duracion13
    );

    if (!$ok13) {
        $repoEjecuciones->finalizar($ejecucionId, 'fallido');
        jsonSalida([
            'ok' => false,
            'errores' => ['El script de reincorporación falló. Revise el detalle técnico.'],
            'detalle_tecnico' => trim($resultado13['stdout'] . "\n" . $resultado13['stderr']),
            'respaldo' => basename($respaldo),
        ]);
    }

    // El log de 13 se lee AHORA, antes de correr 14: la propia
    // verificación A3-ciclo de 14_VERIFICAR_ASERTOS.py vuelve a invocar
    // 13_REINCORPORAR_decisiones.py internamente (con un libro de
    // decisiones en blanco, para probar idempotencia) y restaura las tramas
    // y el xlsx al terminar, pero NO restaura reincorporacion.log — leerlo
    // después de correr 14 devolvería el log de esa prueba interna, no el
    // de la reincorporación real que acaba de pedir el usuario.
    $rutaLog = ArchivoService::carpetaExpediente($periodo) . '/03_INFORMATIVOS/reincorporacion.log';
    $logTexto = is_file($rutaLog) ? file_get_contents($rutaLog) : null;

    $inicio2 = microtime(true);
    $resultado14 = $runner->ejecutarScriptCrudo('14_VERIFICAR_ASERTOS.py');
    $duracion14 = (microtime(true) - $inicio2) * 1000;
    $ok14 = $resultado14['codigo'] === 0;

    $repoEjecuciones->registrarPaso(
        $ejecucionId,
        2,
        'Re-verificación de aserciones (CONTROL 10 incluido)',
        $ok14 ? 'completado' : 'fallido',
        $ok14 ? 'Aserciones A1/A2/A3/A4 en PASS tras la reincorporación.' : 'Alguna aserción falló tras reincorporar.',
        null,
        trim($resultado14['stdout'] . "\n" . $resultado14['stderr']),
        $duracion14
    );

    $repoEjecuciones->finalizar($ejecucionId, $ok14 ? 'completado' : 'fallido');

    jsonSalida([
        'ok' => $ok14,
        'ejecucion_id' => $ejecucionId,
        'respaldo' => basename($respaldo),
        'log' => $logTexto,
        'aserciones' => parsearAserciones(trim($resultado14['stdout'] . "\n" . $resultado14['stderr'])),
    ]);
} catch (Throwable $e) {
    $repoEjecuciones->registrarPaso($ejecucionId, 0, 'Error inesperado', 'fallido', 'Error inesperado durante la reincorporación.', null, $e->getMessage(), null);
    $repoEjecuciones->finalizar($ejecucionId, 'fallido');
    jsonSalida(['ok' => false, 'errores' => ['Error inesperado. Revise el detalle técnico.'], 'detalle_tecnico' => $e->getMessage()]);
}
