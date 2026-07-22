<?php
declare(strict_types=1);

require_once __DIR__ . '/../app/bootstrap.php';

$periodo = (string) ($_GET['periodo'] ?? '');
$grupo = (string) ($_GET['grupo'] ?? '');
$archivo = (string) ($_GET['archivo'] ?? '');

$ruta = ArchivoService::resolverDescarga($periodo, $grupo, $archivo);
if ($ruta === null) {
    http_response_code(404);
    echo 'Archivo no encontrado.';
    exit;
}

$extension = strtolower(pathinfo($ruta, PATHINFO_EXTENSION));
$tipoMime = match ($extension) {
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt', 'log' => 'text/plain; charset=utf-8',
    'csv' => 'text/csv; charset=utf-8',
    'json' => 'application/json; charset=utf-8',
    default => 'application/octet-stream',
};

header('Content-Type: ' . $tipoMime);
header('Content-Disposition: attachment; filename="' . basename($ruta) . '"');
header('Content-Length: ' . filesize($ruta));
header('X-Content-Type-Options: nosniff');
readfile($ruta);
