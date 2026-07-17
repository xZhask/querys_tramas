<section class="tarjeta">
    <h2>Período</h2>
    <form method="get" action="/aplicativo/public/index.php" class="form-periodo">
        <input type="hidden" name="vista" value="resultados">
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
<?php if ($metricas !== null): ?>
<section class="tarjeta">
    <h2>Totales del período</h2>
    <table class="tabla-metricas">
        <thead><tr><th>Trama</th><th>LIMPIA</th><th>RETENIDA</th><th>INFORMATIVA</th><th>Total extraído</th><th>Residuo</th></tr></thead>
        <tbody>
        <?php foreach (($metricas['conservacion'] ?? []) as $tipo => $c): ?>
            <tr>
                <td><?= htmlspecialchars(ucfirst($tipo)) ?></td>
                <td><?= (int) $c['limpia'] ?></td>
                <td><?= (int) $c['retenida'] ?></td>
                <td><?= (int) $c['informativa'] ?></td>
                <td><?= (int) $c['total_extraido'] ?></td>
                <td class="<?= (int) $c['residuo'] === 0 ? 'texto-ok' : 'texto-error' ?>"><?= (int) $c['residuo'] ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</section>
<?php endif; ?>

<section class="tarjeta">
    <h2>📄 Tramas</h2>
    <ul class="lista-descargas">
        <?php foreach ($tramas as $t): ?>
            <li>
                <?= htmlspecialchars($t['nombre']) ?>
                <?php if ($t['existe']): ?>
                    <a class="boton-descarga" href="/aplicativo/public/descargar.php?periodo=<?= urlencode($periodo) ?>&grupo=tramas&archivo=<?= urlencode($t['nombre']) ?>">Descargar</a>
                <?php else: ?>
                    <span class="texto-atenuado">no generado</span>
                <?php endif; ?>
            </li>
        <?php endforeach; ?>
    </ul>
</section>

<section class="tarjeta">
    <h2>📋 Libro de Auditoría</h2>
    <?php if ($auditoriaExiste): ?>
        <a class="boton-descarga" href="/aplicativo/public/descargar.php?periodo=<?= urlencode($periodo) ?>&grupo=auditoria&archivo=<?= urlencode($nombreAuditoria) ?>">Descargar <?= htmlspecialchars($nombreAuditoria) ?></a>
    <?php else: ?>
        <p class="texto-atenuado">No generado.</p>
    <?php endif; ?>
</section>

<section class="tarjeta">
    <h2>📊 Informativos</h2>
    <ul class="lista-descargas">
        <?php foreach ($informativos as $i): ?>
            <li>
                <?= htmlspecialchars($i['nombre']) ?>
                <?php if ($i['existe']): ?>
                    <a class="boton-descarga" href="/aplicativo/public/descargar.php?periodo=<?= urlencode($periodo) ?>&grupo=informativos&archivo=<?= urlencode($i['nombre']) ?>">Descargar</a>
                <?php else: ?>
                    <span class="texto-atenuado">no generado</span>
                <?php endif; ?>
            </li>
        <?php endforeach; ?>
    </ul>
</section>
<?php endif; ?>
