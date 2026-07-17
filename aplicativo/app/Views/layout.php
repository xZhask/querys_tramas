<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= htmlspecialchars($titulo ?? 'Generador de Tramas LNS') ?> — Generador de Tramas LNS</title>
<link rel="stylesheet" href="/aplicativo/public/assets/css/styles.css">
</head>
<body>
<header class="cabecera">
    <div class="cabecera-titulo">
        <span class="cabecera-sistema">Generador de Tramas LNS</span>
        <span class="cabecera-periodo"><?= htmlspecialchars($periodo ?? '') ?></span>
    </div>
    <nav class="cabecera-nav">
        <a href="/aplicativo/public/index.php?vista=generar" class="<?= ($vistaActiva ?? '') === 'generar' ? 'activo' : '' ?>">Generar</a>
        <a href="/aplicativo/public/index.php?vista=resultados" class="<?= ($vistaActiva ?? '') === 'resultados' ? 'activo' : '' ?>">Resultados</a>
        <a href="/aplicativo/public/index.php?vista=reincorporar" class="<?= ($vistaActiva ?? '') === 'reincorporar' ? 'activo' : '' ?>">Reincorporar</a>
        <a href="/aplicativo/public/index.php?vista=bitacora" class="<?= ($vistaActiva ?? '') === 'bitacora' ? 'activo' : '' ?>">Bitácora</a>
    </nav>
    <div class="cabecera-usuario">
        <?php $u = usuarioActual(); ?>
        <span><?= htmlspecialchars($u['nombre'] ?: $u['usuario']) ?></span>
        <a href="/aplicativo/public/logout.php">Salir</a>
    </div>
</header>
<main class="contenido">
<?php require __DIR__ . "/{$vista}.php"; ?>
</main>
<footer class="pie">
    Área de Estadística — DIRSAPOL PNP · Aplicativo local
</footer>
<script src="/aplicativo/public/assets/js/app.js"></script>
</body>
</html>
