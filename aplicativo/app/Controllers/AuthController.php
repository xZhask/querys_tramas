<?php
declare(strict_types=1);

class AuthController
{
    public static function mostrarLogin(?string $error = null): void
    {
        require __DIR__ . '/../Views/login.php';
    }

    public static function procesarLogin(string $usuario, string $password): bool
    {
        $stmt = getCptPdo()->prepare('SELECT * FROM app_usuarios WHERE usuario = :usuario');
        $stmt->execute(['usuario' => $usuario]);
        $fila = $stmt->fetch();

        if ($fila === false || !password_verify($password, $fila['password_hash'])) {
            return false;
        }

        $_SESSION['usuario'] = ['id' => $fila['id'], 'usuario' => $fila['usuario'], 'nombre' => $fila['nombre_completo']];
        return true;
    }

    public static function logout(): void
    {
        $_SESSION = [];
        session_destroy();
    }
}
