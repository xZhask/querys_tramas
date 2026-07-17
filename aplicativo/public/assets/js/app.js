(function () {
    'use strict';

    const estado = window.LNS_ESTADO || {};

    function porJson(respuesta) {
        return respuesta.json();
    }

    function pintarSemaforo(li, claseEstado) {
        li.classList.remove('paso-pendiente', 'paso-en-curso', 'paso-completado', 'paso-fallido');
        li.classList.add('paso-' + claseEstado);
    }

    function pintarPastillaAserto(nombre, valEstado, detalle) {
        const clase = valEstado === 'PASS' ? 'pastilla-pass' : (valEstado === 'SKIPPED' ? 'pastilla-skipped' : 'pastilla-fallo');
        const span = document.createElement('span');
        span.className = 'pastilla-aserto ' + clase;
        span.textContent = nombre + ': ' + valEstado + (detalle ? ' — ' + detalle : '');
        return span;
    }

    // ---------------------------------------------------------------
    // Pantalla GENERAR
    // ---------------------------------------------------------------
    function initGenerar() {
        const listaPasos = document.getElementById('lista-pasos');
        const botonGenerar = document.getElementById('boton-generar');
        const botonReiniciar = document.getElementById('boton-reiniciar');
        if (!listaPasos || !botonGenerar) return;

        function itemPaso(numero) {
            return listaPasos.querySelector('li[data-paso="' + numero + '"]');
        }

        function resetPasos() {
            estado.pasos.forEach((p) => {
                const li = itemPaso(p.numero);
                if (!li) return;
                pintarSemaforo(li, 'pendiente');
                li.querySelector('.paso-conteo').textContent = '';
                li.querySelector('.paso-acciones').innerHTML = '';
                const det = li.querySelector('.paso-detalle');
                det.hidden = true;
                det.textContent = '';
            });
        }

        function iniciar(forzarDesdePaso) {
            botonGenerar.disabled = true;
            if (botonReiniciar) botonReiniciar.disabled = true;
            resetPasos();

            const cuerpo = { accion: 'iniciar', periodo: estado.periodo };
            if (forzarDesdePaso) cuerpo.forzar_desde_paso = forzarDesdePaso;

            fetch('/aplicativo/public/ejecutar_paso.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(cuerpo),
            })
                .then(porJson)
                .then((r) => {
                    if (!r.ok && r.requiere_confirmacion) {
                        if (confirm(r.mensaje + '\n\n¿Confirma reiniciar desde el paso 5?')) {
                            iniciar(5);
                        } else {
                            botonGenerar.disabled = false;
                            if (botonReiniciar) botonReiniciar.disabled = false;
                        }
                        return;
                    }
                    if (!r.ok) {
                        alert(r.mensaje);
                        botonGenerar.disabled = false;
                        if (botonReiniciar) botonReiniciar.disabled = false;
                        return;
                    }
                    correrPaso(r.ejecucion_id, r.primer_paso);
                })
                .catch((e) => {
                    alert('Error de comunicación con el servidor: ' + e);
                    botonGenerar.disabled = false;
                });
        }

        function correrPaso(ejecucionId, numeroPaso) {
            const li = itemPaso(numeroPaso);
            if (li) pintarSemaforo(li, 'en-curso');

            fetch('/aplicativo/public/ejecutar_paso.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ accion: 'correr_paso', ejecucion_id: ejecucionId, paso: numeroPaso }),
            })
                .then(porJson)
                .then((r) => {
                    if (!li) return;
                    pintarSemaforo(li, r.ok ? 'completado' : 'fallido');
                    if (r.conteo !== null && r.conteo !== undefined) {
                        li.querySelector('.paso-conteo').textContent = r.conteo + ' filas';
                    } else {
                        li.querySelector('.paso-conteo').textContent = r.ok ? 'OK' : 'Error';
                    }

                    if (r.detalle_tecnico) {
                        const det = li.querySelector('.paso-detalle');
                        det.hidden = false;
                        det.textContent = r.detalle_tecnico;
                    }

                    const acciones = li.querySelector('.paso-acciones');
                    acciones.innerHTML = '';

                    if (!r.ok) {
                        const btnReintentar = document.createElement('button');
                        btnReintentar.className = 'boton-secundario';
                        btnReintentar.textContent = 'Reintentar paso';
                        btnReintentar.onclick = () => correrPaso(ejecucionId, numeroPaso);
                        acciones.appendChild(btnReintentar);

                        const btnCancelar = document.createElement('button');
                        btnCancelar.className = 'boton-secundario';
                        btnCancelar.textContent = 'Cancelar ejecución';
                        btnCancelar.onclick = () => {
                            fetch('/aplicativo/public/ejecutar_paso.php', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ accion: 'cancelar', ejecucion_id: ejecucionId }),
                            }).then(() => {
                                botonGenerar.disabled = false;
                                if (botonReiniciar) botonReiniciar.disabled = false;
                            });
                        };
                        acciones.appendChild(btnCancelar);

                        botonGenerar.disabled = false;
                        if (botonReiniciar) botonReiniciar.disabled = false;
                        return;
                    }

                    if (numeroPaso === 11 && r.aserciones) {
                        mostrarAserciones(r.aserciones);
                    }

                    if (r.es_ultimo) {
                        botonGenerar.disabled = false;
                        if (botonReiniciar) botonReiniciar.disabled = false;
                        if (r.metricas) mostrarResumen(r.metricas);
                    } else {
                        correrPaso(ejecucionId, numeroPaso + 1);
                    }
                })
                .catch((e) => {
                    if (li) pintarSemaforo(li, 'fallido');
                    alert('Error de comunicación con el servidor: ' + e);
                    botonGenerar.disabled = false;
                });
        }

        function mostrarResumen(metricas) {
            const tarjeta = document.getElementById('tarjeta-resumen');
            const grid = document.getElementById('resumen-conservacion');
            grid.innerHTML = '';
            const conservacion = metricas.conservacion || {};
            Object.keys(conservacion).forEach((tipo) => {
                const c = conservacion[tipo];
                const div = document.createElement('div');
                div.className = 'tarjeta';
                div.innerHTML = '<strong>' + tipo.toUpperCase() + '</strong><br>' +
                    'LIMPIA: ' + c.limpia + '<br>' +
                    'RETENIDA: ' + c.retenida + '<br>' +
                    'INFORMATIVA: ' + c.informativa + '<br>' +
                    '<span class="' + (c.residuo === 0 ? 'texto-ok' : 'texto-error') + '">Residuo: ' + c.residuo + '</span>';
                grid.appendChild(div);
            });
            tarjeta.hidden = false;
        }

        function mostrarAserciones(aserciones) {
            const tarjeta = document.getElementById('tarjeta-resumen');
            const cont = document.getElementById('resumen-aserciones');
            cont.innerHTML = '';
            aserciones.forEach((a) => cont.appendChild(pintarPastillaAserto(a.nombre, a.estado, a.detalle)));
            tarjeta.hidden = false;
        }

        botonGenerar.addEventListener('click', () => iniciar(null));
        if (botonReiniciar) {
            botonReiniciar.addEventListener('click', () => {
                if (confirm('Esto volverá a correr deduplicación, consolidación, reclasificación y generación de tramas para ' + estado.periodo + '. ¿Continuar?')) {
                    iniciar(5);
                }
            });
        }

        if (estado.metricasIniciales) {
            mostrarResumen(estado.metricasIniciales);
        }
    }

    // ---------------------------------------------------------------
    // Pantalla REINCORPORAR
    // ---------------------------------------------------------------
    function initReincorporar() {
        const form = document.getElementById('form-reincorporar');
        if (!form) return;

        form.addEventListener('submit', (ev) => {
            ev.preventDefault();
            const boton = form.querySelector('button[type="submit"]');
            boton.disabled = true;

            const divErrores = document.getElementById('reincorporar-errores');
            const divResultado = document.getElementById('reincorporar-resultado');
            divErrores.hidden = true;
            divErrores.innerHTML = '';
            divResultado.hidden = true;

            const datos = new FormData(form);
            fetch('/aplicativo/public/reincorporar.php', { method: 'POST', body: datos })
                .then(porJson)
                .then((r) => {
                    boton.disabled = false;
                    if (r.errores && r.errores.length) {
                        divErrores.hidden = false;
                        const ul = document.createElement('ul');
                        r.errores.forEach((e) => {
                            const li = document.createElement('li');
                            li.textContent = e;
                            ul.appendChild(li);
                        });
                        divErrores.appendChild(document.createTextNode(r.ok ? '' : 'No se aplicó ningún cambio:'));
                        divErrores.appendChild(ul);
                        return;
                    }

                    divResultado.hidden = false;
                    const cont = document.getElementById('reincorporar-aserciones');
                    cont.innerHTML = '';
                    (r.aserciones || []).forEach((a) => cont.appendChild(pintarPastillaAserto(a.nombre, a.estado, a.detalle)));
                    document.getElementById('reincorporar-log').textContent = r.log || '(sin log)';
                    document.getElementById('reincorporar-respaldo').textContent = r.respaldo || '-';
                })
                .catch((e) => {
                    boton.disabled = false;
                    divErrores.hidden = false;
                    divErrores.textContent = 'Error de comunicación con el servidor: ' + e;
                });
        });
    }

    document.addEventListener('DOMContentLoaded', () => {
        initGenerar();
        initReincorporar();
    });
})();
