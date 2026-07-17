<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ingresar — Generador de Tramas LNS</title>
<link rel="stylesheet" href="/aplicativo/public/assets/css/styles.css">
</head>
<body class="pagina-login">
<div class="tarjeta-login">
    <h1>Generador de Tramas LNS</h1>
    <p class="subtitulo">Área de Estadística — DIRSAPOL PNP</p>
    <?php if (!empty($error)): ?>
        <p class="mensaje-error"><?= htmlspecialchars($error) ?></p>
    <?php endif; ?>
    <form method="post" action="/aplicativo/public/login.php">
        <label for="usuario">Usuario</label>
        <input type="text" id="usuario" name="usuario" required autofocus>
        <label for="password">Contraseña</label>
        <input type="password" id="password" name="password" required>
        <button type="submit">Ingresar</button>
    </form>
</div>
</body>
</html>
