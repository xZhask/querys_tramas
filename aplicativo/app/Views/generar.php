<section class="tarjeta">
    <h2>Configuración de generación</h2>

    <!-- Fila de configuración de 3 columnas -->
    <div class="grid-configuracion">
        <div class="campo-config">
            <label for="input-periodo">Período</label>
            <input type="month" id="input-periodo" name="periodo" 
                   value="<?= htmlspecialchars($periodo) ?>" 
                   max="<?= htmlspecialchars($maxPeriodo) ?>"
                   class="control-config">
        </div>

        <div class="campo-config">
            <label for="select-cpt">Base CPT</label>
            <select id="select-cpt" class="control-config">
                <?php foreach ($basesCpt ?? [] as $db): ?>
                    <option value="<?= htmlspecialchars($db) ?>" <?= $db === $dbCptSel ? 'selected' : '' ?>>
                        <?= htmlspecialchars($db) ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>

        <div class="campo-config">
            <label for="select-sigesapol">Base SIGESAPOL</label>
            <select id="select-sigesapol" class="control-config">
                <?php foreach ($basesSigesapol ?? [] as $db): ?>
                    <option value="<?= htmlspecialchars($db) ?>" <?= $db === $dbSigSel ? 'selected' : '' ?>>
                        <?= htmlspecialchars($db) ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
    </div>

    <!-- Banda de valores derivados -->
    <div class="banda-derivados">
        <div class="item-derivado">
            <span class="label-derivado">Fuente canónica:</span>
            <strong id="val-fuente"><?= htmlspecialchars($fuenteCanonica['fuente'] ?? 'CPT') ?></strong>
            <span id="val-vigencia" class="texto-atenuado">(<?= htmlspecialchars($fuenteCanonica['vigencia'] ?? 'vigente') ?>)</span>
        </div>
        <div class="item-derivado">
            <span class="label-derivado">Alcance:</span>
            <span id="val-alcance"><?= htmlspecialchars($alcance['texto'] ?? 'Hospital Nacional PNP Luis N. Saenz (00013591)') ?></span>
        </div>
        <div class="item-derivado">
            <span class="label-derivado">Pasos a ejecutar:</span>
            <span><strong>1 al 11</strong> (Ciclo completo)</span>
        </div>
    </div>

    <!-- Avisos e historiales -->
    <?php if ($enCurso !== null): ?>
        <div class="aviso aviso-ambar" role="alert">
            <p style="margin: 0 0 0.3rem 0;">
                Hay una ejecución en curso para el período <strong><?= htmlspecialchars($enCurso['periodo']) ?></strong>
                (paso <?= (int) $enCurso['paso_actual'] ?>, última actividad:
                <strong><?= htmlspecialchars(date('d/m/Y H:i', strtotime($enCurso['actualizado_en']))) ?></strong>).
                Mientras tanto no se puede iniciar ninguna otra generación.
            </p>
            <p style="margin: 0 0 0.5rem 0; font-size: 0.84rem; color: var(--gris-texto);">
                Si el proceso quedó colgado (navegador cerrado, servidor reiniciado, etc.) sin terminar realmente,
                puede liberarlo manualmente en vez de esperar.
            </p>
            <button id="boton-liberar-bloqueo" class="boton-secundario" type="button">
                Detener y reiniciar
            </button>
        </div>
    <?php endif; ?>

    <?php if ($ultimaCualquiera !== null): ?>
        <div class="aviso aviso-ambar" role="status">
            <p style="margin: 0 0 0.3rem 0;">
                El período <strong><?= htmlspecialchars($periodo) ?></strong> ya tiene historial de ejecución
                (última corrida: <strong><?= htmlspecialchars(date('d/m/Y H:i', strtotime($ultimaCualquiera['actualizado_en']))) ?></strong>).
            </p>
            <p style="margin: 0; font-size: 0.84rem; color: var(--gris-texto);">
                Bases usadas anteriormente: CPT = <code><?= htmlspecialchars($ultimaCualquiera['db_cpt'] ?: DB_NAME_CPT) ?></code>,
                SIGESAPOL = <code><?= htmlspecialchars($ultimaCualquiera['db_sigesapol'] ?: DB_NAME_SIGESAPOL) ?></code>.
                Generar reemplazará las tramas, el libro de auditoría y los informes existentes.
            </p>
        </div>
    <?php endif; ?>

    <?php if ($basesDistintas): ?>
        <div class="aviso aviso-ambar aviso-alerta-bases" role="alert" style="margin-top: 0.5rem;">
            <strong>⚠️ Atención:</strong> Las bases seleccionadas actualmente 
            (CPT: <code><?= htmlspecialchars($dbCptSel) ?></code>, SIGESAPOL: <code><?= htmlspecialchars($dbSigSel) ?></code>)
            difieren de las utilizadas en la última corrida de este período
            (CPT: <code><?= htmlspecialchars($ultimaCualquiera['db_cpt'] ?: DB_NAME_CPT) ?></code>, 
             SIGESAPOL: <code><?= htmlspecialchars($ultimaCualquiera['db_sigesapol'] ?: DB_NAME_SIGESAPOL) ?></code>).
        </div>
    <?php endif; ?>

    <!-- Botón primario único -->
    <div class="acciones-principales" style="margin-top: 1rem;">
        <button id="boton-generar" class="boton-primario" <?= $enCurso !== null ? 'disabled' : '' ?>>
            Generar tramas
        </button>
    </div>

    <!-- Opciones avanzadas -->
    <details class="opciones-avanzadas" style="margin-top: 1.25rem;">
        <summary>Opciones avanzadas</summary>
        <div class="contenido-avanzadas">
            <p class="nota-avanzadas">
                Uso exclusivo de diagnóstico o desarrollo. Asume que las tablas maestras SIGESAPOL (pasos 1 al 4) ya existen en la base de datos y corresponden a este mismo período. Aborta si las tablas no existen o pertenecen a otro mes.
            </p>
            <button id="boton-reiniciar-paso5" class="boton-secundario" <?= $enCurso !== null ? 'disabled' : '' ?>>
                Reanudar desde el paso 5
            </button>
        </div>
    </details>
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

<!-- Modal de confirmación antes de sobrescribir -->
<dialog id="modal-confirmar" class="modal-dialog">
    <div class="modal-contenido">
        <h3 class="modal-titulo">¿Sobrescribir expediente de tramas?</h3>
        <div class="modal-cuerpo">
            <p>
                El período <strong id="modal-periodo-txt"><?= htmlspecialchars($periodo) ?></strong> ya cuenta con un expediente de tramas generado anteriormente.
            </p>
            <div class="aviso aviso-rojo" style="margin: 0.75rem 0;">
                <strong>⚠️ ADVERTENCIA DE PÉRDIDA DE DATOS:</strong> Al volver a generar este período, 
                <strong>se perderán todas las decisiones ya registradas en el libro de auditoría</strong> 
                (<code>02_AUDITORIA_<?= htmlspecialchars($periodo) ?>.xlsx</code>), así como las tramas e informativos actuales.
            </div>
            <p>¿Está seguro de que desea continuar con la generación completa (pasos 1 al 11)?</p>
        </div>
        <div class="modal-acciones">
            <button id="modal-btn-cancelar" class="boton-secundario" type="button">Cancelar</button>
            <button id="modal-btn-confirmar" class="boton-peligro" type="button">Sí, sobrescribir y generar</button>
        </div>
    </div>
</dialog>

<script>
window.LNS_ESTADO = {
    periodo: <?= json_encode($periodo) ?>,
    maxPeriodo: <?= json_encode($maxPeriodo) ?>,
    pasos: <?= json_encode(array_map(fn($p) => ['numero' => $p['numero'], 'nombre' => $p['nombre']], $pasos)) ?>,
    enCurso: <?= json_encode($enCurso) ?>,
    tieneHistorial: <?= json_encode($ultimaCualquiera !== null) ?>,
    metricasIniciales: <?= json_encode($metricas) ?>,
    dbCptSel: <?= json_encode($dbCptSel) ?>,
    dbSigSel: <?= json_encode($dbSigSel) ?>
};
</script>
