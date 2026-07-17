<section class="tarjeta">
    <h2>Período a generar</h2>
    <form id="form-periodo" class="form-periodo">
        <label for="input-periodo">Mes / Año</label>
        <input type="month" id="input-periodo" name="periodo" value="<?= htmlspecialchars($periodo) ?>">
        <button type="submit" class="boton-secundario">Cambiar período</button>
    </form>

    <?php if ($enCurso !== null && $enCurso['periodo'] !== $periodo): ?>
        <p class="aviso aviso-ambar">
            Hay una ejecución en curso para el período <strong><?= htmlspecialchars($enCurso['periodo']) ?></strong>.
            Debe esperar a que termine antes de generar otro período.
        </p>
    <?php endif; ?>

    <?php if ($ultimaCompletada !== null): ?>
        <p class="aviso aviso-verde">
            El período <strong><?= htmlspecialchars($periodo) ?></strong> ya fue generado completamente
            (<?= htmlspecialchars($ultimaCompletada['actualizado_en']) ?>).
            Puede revisar los resultados o, si corrigió algo en el origen, reiniciar desde el paso 5.
        </p>
        <button id="boton-reiniciar" class="boton-secundario">Reiniciar desde paso 5</button>
    <?php endif; ?>

    <button id="boton-generar" class="boton-primario" <?= $enCurso !== null ? 'disabled' : '' ?>>
        Generar tramas
    </button>
</section>

<section class="tarjeta">
    <h2>Progreso del pipeline</h2>
    <ol id="lista-pasos" class="lista-pasos">
        <?php foreach ($pasos as $p): ?>
            <li data-paso="<?= (int) $p['numero'] ?>" class="paso paso-pendiente">
                <span class="semaforo" aria-hidden="true"></span>
                <span class="paso-nombre"><?= (int) $p['numero'] ?>. <?= htmlspecialchars($p['nombre']) ?></span>
                <span class="paso-conteo"></span>
                <span class="paso-acciones"></span>
                <div class="paso-detalle" hidden></div>
            </li>
        <?php endforeach; ?>
    </ol>
</section>

<section class="tarjeta" id="tarjeta-resumen" hidden>
    <h2>Resumen del período</h2>
    <div id="resumen-conservacion" class="resumen-grid"></div>
    <h3>Aserciones</h3>
    <div id="resumen-aserciones" class="resumen-aserciones"></div>
</section>

<script>
window.LNS_ESTADO = {
    periodo: <?= json_encode($periodo) ?>,
    pasos: <?= json_encode(array_map(fn($p) => ['numero' => $p['numero'], 'nombre' => $p['nombre']], $pasos)) ?>,
    enCurso: <?= json_encode($enCurso) ?>,
    metricasIniciales: <?= json_encode($metricas) ?>
};
</script>
