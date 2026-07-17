<section class="tarjeta">
    <h2>Período</h2>
    <form method="get" action="/aplicativo/public/index.php" class="form-periodo">
        <input type="hidden" name="vista" value="reincorporar">
        <label for="select-periodo">Seleccionar período generado</label>
        <select id="select-periodo" name="periodo" onchange="this.form.submit()">
            <?php foreach ($periodos as $p): ?>
                <option value="<?= htmlspecialchars($p) ?>" <?= $p === $periodo ? 'selected' : '' ?>><?= htmlspecialchars($p) ?></option>
            <?php endforeach; ?>
        </select>
    </form>
    <?php if (empty($periodos)): ?>
        <p class="aviso aviso-ambar">Todavía no hay ningún período generado. Vaya a la pantalla "Generar" primero.</p>
    <?php endif; ?>
</section>

<?php if ($periodo && !empty($periodos)): ?>
<section class="tarjeta">
    <h2>Subir libro de auditoría con decisiones</h2>
    <p>
        Descargue el libro <strong><?= htmlspecialchars($nombreAuditoria) ?></strong> desde "Resultados",
        complete la columna <code>DECISION_AUDITORIA</code> en las hojas correspondientes, y súbalo aquí.
        No modifique ninguna otra columna ni agregue/quite filas.
    </p>
    <form id="form-reincorporar" enctype="multipart/form-data">
        <input type="hidden" name="periodo" value="<?= htmlspecialchars($periodo) ?>">
        <input type="file" name="archivo" accept=".xlsx" required>
        <button type="submit" class="boton-primario">Validar y reincorporar</button>
    </form>
    <div id="reincorporar-errores" class="lista-errores" hidden></div>
    <div id="reincorporar-resultado" hidden>
        <h3>Aserciones tras la reincorporación</h3>
        <div id="reincorporar-aserciones" class="resumen-aserciones"></div>
        <h3>Log del proceso</h3>
        <pre id="reincorporar-log" class="bloque-log"></pre>
        <p class="texto-atenuado">Respaldo del libro anterior: <span id="reincorporar-respaldo"></span></p>
    </div>
</section>

<?php if ($ultimaReincorporacion !== null): ?>
<section class="tarjeta">
    <h2>Última reincorporación</h2>
    <p>
        Estado: <strong><?= htmlspecialchars($ultimaReincorporacion['estado']) ?></strong>
        · Por <?= htmlspecialchars($ultimaReincorporacion['iniciado_por']) ?>
        · <?= htmlspecialchars($ultimaReincorporacion['actualizado_en']) ?>
        · <a href="/aplicativo/public/index.php?vista=bitacora&periodo=<?= urlencode($periodo) ?>">Ver en bitácora</a>
    </p>
</section>
<?php endif; ?>
<?php endif; ?>

<script>
window.LNS_ESTADO = { periodo: <?= json_encode($periodo) ?> };
</script>
