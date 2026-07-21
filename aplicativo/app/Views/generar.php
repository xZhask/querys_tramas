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

    <?php if ($ultimaCualquiera !== null): ?>
        <p class="aviso aviso-verde">
            El período <strong><?= htmlspecialchars($periodo) ?></strong> ya tiene historial de ejecución
            (último movimiento: <?= htmlspecialchars($ultimaCualquiera['actualizado_en']) ?>).
            Puede revisar los resultados o reiniciar el proceso.
        </p>
        <button id="boton-reiniciar-completo" class="boton-secundario">Reiniciar ciclo completo (Paso 1)</button>
        <button id="boton-reiniciar-paso5" class="boton-secundario" style="margin-left:0.5rem;">Reiniciar desde paso 5</button>
    <?php endif; ?>

    <div class="db-selectors" style="margin-bottom: 1rem;">
        <label for="select-cpt">Base CPT:</label>
        <select id="select-cpt" class="input-periodo">
            <?php foreach ($basesCpt ?? [] as $db): ?>
                <option value="<?= htmlspecialchars($db) ?>"><?= htmlspecialchars($db) ?></option>
            <?php endforeach; ?>
        </select>

        <label for="select-sigesapol" style="margin-left: 1rem;">Base SIGESAPOL:</label>
        <select id="select-sigesapol" class="input-periodo">
            <?php foreach ($basesSigesapol ?? [] as $db): ?>
                <option value="<?= htmlspecialchars($db) ?>"><?= htmlspecialchars($db) ?></option>
            <?php endforeach; ?>
        </select>
    </div>

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
