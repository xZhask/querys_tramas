<?php
declare(strict_types=1);

$cuerpo = json_decode(file_get_contents('php://input'), true) ?? [];
if (!empty($cuerpo['db_cpt'])) {
    putenv('LNS_DB_CPT=' . $cuerpo['db_cpt']);
}
if (!empty($cuerpo['db_sigesapol'])) {
    putenv('LNS_DB_SIGESAPOL=' . $cuerpo['db_sigesapol']);
}

require_once __DIR__ . '/../app/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonSalida(['ok' => false, 'mensaje' => 'Método no permitido.'], 405);
}

$accion = $cuerpo['accion'] ?? '';
$repo = new EjecucionRepository(getCptPdo());

switch ($accion) {
    case 'iniciar':
        manejarIniciar($cuerpo, $repo);
        break;
    case 'correr_paso':
        manejarCorrerPaso($cuerpo, $repo);
        break;
    case 'cancelar':
        manejarCancelar($cuerpo, $repo);
        break;
    default:
        jsonSalida(['ok' => false, 'mensaje' => 'Acción no reconocida.'], 400);
}

function manejarIniciar(array $cuerpo, EjecucionRepository $repo): void
{
    $periodo = (string) ($cuerpo['periodo'] ?? '');
    if (!ArchivoService::periodoValido($periodo)) {
        jsonSalida(['ok' => false, 'mensaje' => 'Período inválido.']);
    }

    // Libera candados de ejecuciones abandonadas (> 15 min sin avance).
    $enCurso = $repo->hayEnCurso();
    if ($enCurso !== null) {
        $inactivoSegundos = time() - strtotime($enCurso['actualizado_en']);
        if ($inactivoSegundos > 900) {
            $repo->finalizar((int) $enCurso['id'], 'fallido');
            $enCurso = null;
        }
    }
    if ($enCurso !== null) {
        jsonSalida(['ok' => false, 'mensaje' => "Ya hay una ejecución en curso (período {$enCurso['periodo']}). Espere a que termine antes de iniciar otra."]);
    }

    $forzarDesdePaso = isset($cuerpo['forzar_desde_paso']) ? (int) $cuerpo['forzar_desde_paso'] : null;

    if ($forzarDesdePaso === null && $repo->tieneAvanceDesde($periodo, 6)) {
        jsonSalida([
            'ok' => false,
            'requiere_confirmacion' => true,
            'mensaje' => "El período {$periodo} ya tiene pasos ejecutados. Por favor, use los botones 'Reiniciar ciclo completo' o 'Reiniciar desde paso 5' que aparecen arriba.",
        ]);
    }

    $pasoInicial = ($forzarDesdePaso === 5) ? 4 : 0;
    $id = $repo->crear($periodo, 'generacion', usuarioLocal(), $pasoInicial, $cuerpo['db_cpt'] ?? null, $cuerpo['db_sigesapol'] ?? null);

    jsonSalida(['ok' => true, 'ejecucion_id' => $id, 'primer_paso' => $pasoInicial + 1]);
}

function manejarCorrerPaso(array $cuerpo, EjecucionRepository $repo): void
{
    $ejecucionId = (int) ($cuerpo['ejecucion_id'] ?? 0);
    $numeroPaso = (int) ($cuerpo['paso'] ?? 0);

    $ejecucion = $repo->porId($ejecucionId);
    if ($ejecucion === null) {
        jsonSalida(['ok' => false, 'mensaje' => 'Ejecución no encontrada.'], 404);
    }

    $pasos = pipelineConfig();
    $paso = null;
    foreach ($pasos as $p) {
        if ($p['numero'] === $numeroPaso) {
            $paso = $p;
            break;
        }
    }
    if ($paso === null) {
        jsonSalida(['ok' => false, 'mensaje' => 'Paso no encontrado.'], 404);
    }

    [$anio, $mes] = array_map('intval', explode('-', $ejecucion['periodo']));
    $runner = new PipelineRunner($anio, $mes);

    $inicio = microtime(true);
    $resultado = $runner->ejecutar($paso);
    $duracionMs = (microtime(true) - $inicio) * 1000;

    $repo->registrarPaso(
        $ejecucionId,
        $numeroPaso,
        $paso['nombre'],
        $resultado['ok'] ? 'completado' : 'fallido',
        $resultado['mensaje'],
        $resultado['conteo'],
        $resultado['detalle_tecnico'],
        $duracionMs
    );

    $esUltimo = $numeroPaso === count($pasos);
    $respuesta = [
        'ok' => $resultado['ok'],
        'paso' => $numeroPaso,
        'nombre' => $paso['nombre'],
        'mensaje' => $resultado['mensaje'],
        'conteo' => $resultado['conteo'],
        'detalle_tecnico' => $resultado['detalle_tecnico'],
        'es_ultimo' => $esUltimo,
    ];

    if ($numeroPaso === 11) {
        $respuesta['aserciones'] = parsearAserciones((string) $resultado['detalle_tecnico']);
    }

    if ($resultado['ok'] && $esUltimo) {
        $repo->finalizar($ejecucionId, 'completado');
        $respuesta['metricas'] = ArchivoService::metricas($ejecucion['periodo']);
    }

    jsonSalida($respuesta);
}

function manejarCancelar(array $cuerpo, EjecucionRepository $repo): void
{
    $ejecucionId = (int) ($cuerpo['ejecucion_id'] ?? 0);
    $repo->finalizar($ejecucionId, 'fallido');
    jsonSalida(['ok' => true]);
}
