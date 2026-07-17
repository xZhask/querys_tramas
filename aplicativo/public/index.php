<?php
declare(strict_types=1);

require_once __DIR__ . '/../app/bootstrap.php';
requerirLogin();

$vista = $_GET['vista'] ?? 'generar';

switch ($vista) {
    case 'resultados':
        ResultadosController::index();
        break;
    case 'reincorporar':
        ReincorporarController::index();
        break;
    case 'bitacora':
        BitacoraController::index();
        break;
    case 'generar':
    default:
        GenerarController::index();
        break;
}
