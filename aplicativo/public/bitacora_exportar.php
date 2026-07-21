<?php
declare(strict_types=1);

require_once __DIR__ . '/../app/bootstrap.php';

$periodo = $_GET['periodo'] ?? null;
if ($periodo !== null && !ArchivoService::periodoValido($periodo)) {
    $periodo = null;
}

$repo = new EjecucionRepository(getCptPdo());
$ejecuciones = $repo->listar($periodo, null, 1000);

header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename="bitacora' . ($periodo ? "_{$periodo}" : '') . '.csv"');

$salida = fopen('php://output', 'w');
fwrite($salida, "\xEF\xBB\xBF"); // BOM UTF-8 para Excel
fputcsv($salida, ['id', 'periodo', 'tipo', 'paso_actual', 'estado', 'iniciado_por', 'iniciado_en', 'actualizado_en']);
foreach ($ejecuciones as $e) {
    fputcsv($salida, [
        $e['id'], $e['periodo'], $e['tipo'], $e['paso_actual'], $e['estado'],
        $e['iniciado_por'], $e['iniciado_en'], $e['actualizado_en'],
    ]);
}
fclose($salida);
