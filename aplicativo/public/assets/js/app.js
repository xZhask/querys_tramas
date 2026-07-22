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
        const botonReiniciarPaso5 = document.getElementById('boton-reiniciar-paso5');
        const inputPeriodo = document.getElementById('input-periodo');
        const selectCpt = document.getElementById('select-cpt');
        const selectSigesapol = document.getElementById('select-sigesapol');
        const modalConfirmar = document.getElementById('modal-confirmar');
        const btnCancelarModal = document.getElementById('modal-btn-cancelar');
        const btnConfirmarModal = document.getElementById('modal-btn-confirmar');
        const botonLiberarBloqueo = document.getElementById('boton-liberar-bloqueo');

        if (!listaPasos || !botonGenerar) return;

        function actualizarUrl() {
            const p = inputPeriodo ? inputPeriodo.value : estado.periodo;
            const cpt = selectCpt ? selectCpt.value : '';
            const sig = selectSigesapol ? selectSigesapol.value : '';
            let url = '?vista=generar&periodo=' + encodeURIComponent(p);
            if (cpt) url += '&db_cpt=' + encodeURIComponent(cpt);
            if (sig) url += '&db_sigesapol=' + encodeURIComponent(sig);
            window.location.href = url;
        }

        if (inputPeriodo) {
            inputPeriodo.addEventListener('change', () => {
                if (estado.maxPeriodo && inputPeriodo.value > estado.maxPeriodo) {
                    alert('El período no puede ser mayor al último mes cerrado (' + estado.maxPeriodo + ').');
                    inputPeriodo.value = estado.maxPeriodo;
                }
                actualizarUrl();
            });
        }
        if (selectCpt) selectCpt.addEventListener('change', actualizarUrl);
        if (selectSigesapol) selectSigesapol.addEventListener('change', actualizarUrl);

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
            if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = true;
            resetPasos();

            const cuerpo = { accion: 'iniciar', periodo: estado.periodo };
            if (forzarDesdePaso) cuerpo.forzar_desde_paso = forzarDesdePaso;
            if (selectCpt) cuerpo.db_cpt = selectCpt.value;
            if (selectSigesapol) cuerpo.db_sigesapol = selectSigesapol.value;

            fetch('ejecutar_paso.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(cuerpo),
            })
                .then(porJson)
                .then((r) => {
                    if (!r.ok) {
                        alert(r.mensaje);
                        botonGenerar.disabled = false;
                        if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
                        return;
                    }
                    correrPaso(r.ejecucion_id, r.primer_paso);
                })
                .catch((e) => {
                    alert('Error de comunicación con el servidor: ' + e);
                    botonGenerar.disabled = false;
                    if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
                });
        }

        function correrPaso(ejecucionId, numeroPaso) {
            const li = itemPaso(numeroPaso);
            if (li) pintarSemaforo(li, 'en-curso');

            const cuerpo = { accion: 'correr_paso', ejecucion_id: ejecucionId, paso: numeroPaso };
            if (selectCpt) cuerpo.db_cpt = selectCpt.value;
            if (selectSigesapol) cuerpo.db_sigesapol = selectSigesapol.value;

            fetch('ejecutar_paso.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(cuerpo),
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
                            fetch('ejecutar_paso.php', {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ accion: 'cancelar', ejecucion_id: ejecucionId }),
                            }).then(() => {
                                botonGenerar.disabled = false;
                                if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
                            });
                        };
                        acciones.appendChild(btnCancelar);

                        botonGenerar.disabled = false;
                        if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
                        return;
                    }

                    if (numeroPaso === 11 && r.aserciones) {
                        mostrarAserciones(r.aserciones);
                    }

                    if (r.es_ultimo) {
                        botonGenerar.disabled = false;
                        if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
                        if (r.metricas) mostrarResumen(r.metricas);
                    } else {
                        correrPaso(ejecucionId, numeroPaso + 1);
                    }
                })
                .catch((e) => {
                    if (li) pintarSemaforo(li, 'fallido');
                    alert('Error de comunicación con el servidor: ' + e);
                    botonGenerar.disabled = false;
                    if (botonReiniciarPaso5) botonReiniciarPaso5.disabled = false;
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

        function pedirConfirmacionSobrescribir(onConfirm) {
            if (!modalConfirmar) {
                if (confirm('El período ' + estado.periodo + ' ya cuenta con un expediente de tramas. Se perderán las decisiones de auditoría registradas. ¿Continuar?')) {
                    onConfirm();
                }
                return;
            }

            if (typeof modalConfirmar.showModal === 'function') {
                modalConfirmar.showModal();
            } else {
                modalConfirmar.setAttribute('open', 'true');
            }

            const handleCancel = () => {
                if (typeof modalConfirmar.close === 'function') modalConfirmar.close();
                else modalConfirmar.removeAttribute('open');
                btnCancelarModal.removeEventListener('click', handleCancel);
                btnConfirmarModal.removeEventListener('click', handleConfirm);
            };

            const handleConfirm = () => {
                if (typeof modalConfirmar.close === 'function') modalConfirmar.close();
                else modalConfirmar.removeAttribute('open');
                btnCancelarModal.removeEventListener('click', handleCancel);
                btnConfirmarModal.removeEventListener('click', handleConfirm);
                onConfirm();
            };

            btnCancelarModal.addEventListener('click', handleCancel);
            btnConfirmarModal.addEventListener('click', handleConfirm);
        }

        botonGenerar.addEventListener('click', () => {
            if (estado.tieneHistorial) {
                // La confirmación del modal ES la decisión de reinicio: ciclo completo (paso 1).
                pedirConfirmacionSobrescribir(() => iniciar(1));
            } else {
                iniciar(null);
            }
        });

        if (botonReiniciarPaso5) {
            botonReiniciarPaso5.addEventListener('click', () => {
                if (confirm('Esto volverá a correr deduplicación, consolidación, reclasificación y generación de tramas para ' + estado.periodo + '. ¿Continuar?')) {
                    iniciar(5);
                }
            });
        }

        if (estado.metricasIniciales) {
            mostrarResumen(estado.metricasIniciales);
        }

        if (botonLiberarBloqueo) {
            botonLiberarBloqueo.addEventListener('click', () => {
                if (!confirm('Esto marcará la ejecución en curso como detenida y volverá a habilitar los controles. Úselo solo si el proceso ya no sigue corriendo realmente. ¿Continuar?')) {
                    return;
                }
                botonLiberarBloqueo.disabled = true;
                fetch('ejecutar_paso.php', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ accion: 'liberar' }),
                })
                    .then(porJson)
                    .then(() => window.location.reload())
                    .catch((e) => {
                        alert('Error de comunicación con el servidor: ' + e);
                        botonLiberarBloqueo.disabled = false;
                    });
            });
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
            fetch('reincorporar.php', { method: 'POST', body: datos })
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
