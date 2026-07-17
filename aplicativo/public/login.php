<?php
declare(strict_types=1);

require_once __DIR__ . '/../app/bootstrap.php';

if (usuarioActual() !== null) {
    header('Location: /aplicativo/public/index.php');
    exit;
}

$error = null;
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $usuario = trim((string) ($_POST['usuario'] ?? ''));
    $password = (string) ($_POST['password'] ?? '');
    if (AuthController::procesarLogin($usuario, $password)) {
        header('Location: /aplicativo/public/index.php');
        exit;
    }
    $error = 'Usuario o contraseña incorrectos.';
}

AuthController::mostrarLogin($error);
