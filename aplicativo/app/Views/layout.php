<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= htmlspecialchars($titulo ?? 'Generador de Tramas LNS') ?> — Generador de Tramas LNS</title>
<link rel="stylesheet" href="assets/css/styles.css">
</head>
<body>
<header class="cabecera">
    <div class="cabecera-titulo">
        <span class="cabecera-sistema">Generador de Tramas LNS</span>
        <span class="cabecera-periodo"><?= htmlspecialchars($periodo ?? '') ?></span>
    </div>
    <nav class="cabecera-nav">
        <a href="index.php?vista=generar" class="<?= ($vistaActiva ?? '') === 'generar' ? 'activo' : '' ?>">Generar</a>
        <a href="index.php?vista=resultados" class="<?= ($vistaActiva ?? '') === 'resultados' ? 'activo' : '' ?>">Resultados</a>
        <a href="index.php?vista=reincorporar" class="<?= ($vistaActiva ?? '') === 'reincorporar' ? 'activo' : '' ?>">Reincorporar</a>
        <a href="index.php?vista=bitacora" class="<?= ($vistaActiva ?? '') === 'bitacora' ? 'activo' : '' ?>">Bitácora</a>
    </nav>
    <div class="cabecera-usuario">
        <span><?= htmlspecialchars(usuarioLocal()) ?></span>
    </div>
</header>
<main class="contenido">
<?php require __DIR__ . "/{$vista}.php"; ?>
</main>
<footer class="pie">
    Área de Estadística — DIRSAPOL PNP · Aplicativo local
</footer>
<script src="assets/js/app.js"></script>
</body>
</html>
