<section class="tarjeta">
    <h2>Historial de ejecuciones</h2>
    <form method="get" action="/aplicativo/public/index.php" class="form-periodo">
        <input type="hidden" name="vista" value="bitacora">
        <label for="input-periodo-filtro">Filtrar por período (opcional)</label>
        <input type="month" id="input-periodo-filtro" name="periodo" value="<?= htmlspecialchars($periodo ?? '') ?>">
        <button type="submit" class="boton-secundario">Filtrar</button>
        <a class="boton-secundario" href="/aplicativo/public/bitacora_exportar.php<?= $periodo ? '?periodo=' . urlencode($periodo) : '' ?>">Exportar CSV</a>
    </form>

    <table class="tabla-bitacora">
        <thead>
        <tr><th>ID</th><th>Período</th><th>Tipo</th><th>Paso</th><th>Estado</th><th>Usuario</th><th>Inicio</th><th>Última actualización</th></tr>
        </thead>
        <tbody>
        <?php foreach ($ejecuciones as $e): ?>
            <tr class="fila-<?= htmlspecialchars($e['estado']) ?>">
                <td><?= (int) $e['id'] ?></td>
                <td><?= htmlspecialchars($e['periodo']) ?></td>
                <td><?= htmlspecialchars($e['tipo']) ?></td>
                <td><?= (int) $e['paso_actual'] ?></td>
                <td><span class="etiqueta-estado etiqueta-<?= htmlspecialchars($e['estado']) ?>"><?= htmlspecialchars($e['estado']) ?></span></td>
                <td><?= htmlspecialchars($e['iniciado_por']) ?></td>
                <td><?= htmlspecialchars($e['iniciado_en']) ?></td>
                <td><?= htmlspecialchars($e['actualizado_en']) ?></td>
            </tr>
            <tr class="fila-detalle-log">
                <td colspan="8">
                    <details>
                        <summary>Detalle del log</summary>
                        <pre class="bloque-log"><?php
                            $log = json_decode($e['log'], true) ?: [];
                            foreach ($log as $entrada) {
                                $linea = sprintf(
                                    "[%s] Paso %s (%s): %s — %s",
                                    $entrada['timestamp'] ?? '',
                                    $entrada['paso'] ?? '',
                                    $entrada['nombre'] ?? '',
                                    $entrada['estado'] ?? '',
                                    $entrada['mensaje'] ?? ''
                                );
                                echo htmlspecialchars($linea) . "\n";
                            }
                        ?></pre>
                    </details>
                </td>
            </tr>
        <?php endforeach; ?>
        <?php if (empty($ejecuciones)): ?>
            <tr><td colspan="8" class="texto-atenuado">Sin ejecuciones registradas.</td></tr>
        <?php endif; ?>
        </tbody>
    </table>
</section>
