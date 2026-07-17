<?php
declare(strict_types=1);

error_reporting(E_ALL);
ini_set('display_errors', '0'); // nunca mostrar errores crudos de PHP al usuario

session_start();

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/../vendor/autoload.php';

foreach (glob(__DIR__ . '/Services/*.php') as $archivo) {
    require_once $archivo;
}
foreach (glob(__DIR__ . '/Controllers/*.php') as $archivo) {
    require_once $archivo;
}

function pipelineConfig(): array
{
    return require __DIR__ . '/../config/pipeline.php';
}

function usuarioActual(): ?array
{
    return $_SESSION['usuario'] ?? null;
}

function requerirLogin(): void
{
    if (usuarioActual() === null) {
        header('Location: /aplicativo/public/login.php');
        exit;
    }
}

function jsonSalida(array $datos, int $codigoHttp = 200): void
{
    http_response_code($codigoHttp);
    header('Content-Type: application/json; charset=utf-8');
    // JSON_INVALID_UTF8_SUBSTITUTE: la salida de los scripts .py puede traer
    // bytes que no son UTF-8 válido (consola de Windows); sin esto,
    // json_encode() devuelve false y la respuesta queda vacía.
    echo json_encode($datos, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function renderizar(string $vista, array $datos = []): void
{
    extract($datos, EXTR_SKIP);
    require __DIR__ . '/Views/layout.php';
}

function mensajeAmigablePdo(Throwable $e): string
{
    return 'Ocurrió un error al comunicarse con la base de datos. Revise el detalle técnico o contacte al administrador.';
}

/**
 * Extrae líneas "A1 [periodo]: PASS/FALLO/SKIPPED" del stdout de
 * 14_VERIFICAR_ASERTOS.py para mostrarlas como semáforo. Solo parseo de
 * presentación: la decisión PASS/FALLO la toma el script, no esta función.
 */
function parsearAserciones(string $salida): array
{
    $aserciones = [];
    foreach (explode("\n", $salida) as $linea) {
        if (preg_match('/^(A1|A2|A3-ciclo|A3-CONTROL10|A4)\s*\[[^\]]+\]:\s*(PASS|FALLO|SKIPPED)(.*)$/', trim($linea), $m)) {
            $aserciones[] = ['nombre' => $m[1], 'estado' => $m[2], 'detalle' => trim($m[3], " -")];
        }
    }
    return $aserciones;
}
