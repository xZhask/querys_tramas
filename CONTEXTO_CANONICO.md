# CONTEXTO CANÓNICO — Proyecto Tramas LNS (Julio-Diciembre 2025)

> Leer este archivo al inicio de TODA sesión futura antes de tocar cualquier
> script o el informe de cierre. Si en algún momento un número, regla o script
> contradice lo aquí escrito, gana este archivo hasta que se actualice
> explícitamente con su propia entrada en la sección 3.

---

## 1. REGLAS DE NEGOCIO INMUTABLES

1. **Fuente canónica por vigencias** (tabla `cfg_fuente_canonica`, ver Parte 2
   de `00_RUTA_jul_dic_2025.md`): `2024-01-01 → 2025-09-30` = CPT (sustento:
   check 23, 99.3% de solapamiento entre ambas fuentes); `2025-10-01 → NULL
   (vigente)` = SIGESAPOL (sustento: crossover checks 15a/16, migración
   institucional del hospital). *Justificación: antes de octubre CPT era el
   sistema de registro predominante; desde octubre SIGESAPOL lo es, y usar la
   fuente predominante como canónica minimiza los huecos que debe rellenar la
   fuente complementaria.*

2. **Llaves de deduplicación por tipo de procedimiento** (independiente del tipo de atención): 
   - **1 (Procedimientos médicos)** = documento + fecha + procedimiento + **médico tratante**.
   - **2 (Laboratorio) y 3 (Imágenes)** = documento + fecha + procedimiento + **cantidad**.
   *Justificación real: CPT firma el validador del servicio y SIGESAPOL el tratante (verificado por muestra).*

3. **Regla de 24 horas REAL aplica solo a Caso B** (nueva estancia hospitalaria
   sin hospitalización previa que solape): se exige duración real, por
   intervalo exacto (`sp_fecha_alta_emergencia - sp_fecha_atencion > INTERVAL
   '24 hours'`), no por conteo de días calendario. *Justificación: el conteo
   por día calendario reclasificaba erróneamente estancias breves que cruzaban
   la medianoche; el fix por intervalo real salvó 1,433 registros de
   emergencias breves solo en julio (ver §3, incidencia 2026-07-11-A).*

4. **Caso A (unión Emergencia→Hospitalización) no tiene umbral de horas**:
   toda emergencia que se solapa o toca con una hospitalización existente se
   unifica en un rango único desde el ingreso físico a emergencia, sin
   importar cuántas horas duró. *Justificación: el criterio de unión no es
   tiempo sino continuidad física de la estancia — el paciente nunca dejó el
   hospital, solo cambió de servicio.*

5. **Prioridad IV en Tipo 2 → CPMS 99281, cantidad 1**: toda emergencia que
   permanece en trama Tipo 2 (≤24h reales) fuerza su código de alta al CPMS
   canónico de consulta según prioridad médica; prioridad IV siempre resuelve
   a 99281 cantidad 1. *Justificación real: la prioridad IV no genera estancia, por lo que SIGESAPOL deja cpms_alta vacío por diseño (100% de vacíos), y 99281 es una consulta de emergencia de baja complejidad.*

6. **Trama Tipo 2 admite SOLO códigos 9928x por prioridad** (99281-99285):
   cualquier otro código de alta en una fila Tipo 2 es un error de mapeo que
   debe corregirse antes de facturar, no una excepción válida.

7. **Cierre Administrativo no factura**: estancias con más de 15 días
   acumulados que cruzan de mes se catalogan como Cierre Administrativo y se
   excluyen de la trama facturable. *Justificación: estancias que exceden ese
   umbral operativo se consideran atípicas y requieren depuración/revisión
   administrativa manual antes de poder facturarse, no reclasificación
   automática.*

8. **Contrato de salidas v2 — estados LIMPIA / RETENIDA / INFORMATIVA**:
   - `LIMPIA`: fila que entra a la trama facturable final sin observación.
   - `RETENIDA`: (a) pares Caso A (Emergencia→Hospitalización) **propuestos**
     por el pipeline — quedan en el libro de auditoría a la espera de que la
     Unidad de Auditoría Médica confirme PROCEDE/NO PROCEDE, **no son
     facturación aplicada**; y (b) duplicados **a revisar** entre CPT y
     SIGESAPOL cuya coincidencia es parcial (médico distinto o cantidad
     distinta según la llave del tipo — ver regla 2), que requieren juicio
     humano.
   - `INFORMATIVA`: hallazgos que no bloquean la trama (p. ej. duplicados de
     origen dentro de la misma fuente, estancias sin CPMS de alta que el
     pipeline completó por fallback).
   - Los duplicados **CIERTOS** (coincidencia exacta según la llave de su
     tipo — mismo médico en Tipo 1, misma cantidad en Tipo 2/3) se descartan
     **automáticamente** de la fuente complementaria, con evidencia trazada
     como **B.1** (ver `07_FASE2_deduplicacion_CPT_SIGESAPOL.sql`), y **no**
     entran a RETENIDA — RETENIDA es solo para lo que necesita revisión
     humana.

9. **Alcance nivel III — EXCLUSIVAMENTE Hospital Luis N. Sáenz (LNS)**: este
   generador cubre solo el HN PNP LNS (`codigo_ipress` SIGESAPOL `00013591`,
   `id_establecimiento_sigesapol` 76). Las demás IPRESS (nivel I/II de la red
   PNP) las trabaja otro equipo con otra base. El filtro es **siempre** por
   código/ID de establecimiento — **nunca por nombre** (LNS tiene dos grafías
   legítimas en origen, "LUIS N SAENZ" y "LUIS N. SAENZ", ambas dentro de
   alcance). El dato vive en `cfg_ipress_alcance` (duplicada en ambas BD,
   mismo patrón que `cfg_periodo`) — los filtros de extracción leen de ahí,
   cero literales dispersos. *Justificación: CPT y SIGESAPOL son sistemas de
   toda la red PNP, no solo de LNS; sin este filtro, las tramas incluían
   consultas/emergencias/hospitalizaciones/laboratorios de otros hospitales
   (Legía, Arequipa, Chiclayo, San José y otros), que otro equipo debe
   facturar con otra base — ver §3, entrada 2026-07-17.*

10. **`expedientes/` contiene PHI y está excluido del versionado**: toda la
    carpeta (expedientes mensuales, libros de auditoría `02_AUDITORIA_*.xlsx`,
    hojas de referencia manuales) trae documento/nombre de paciente y vive
    fuera de git (`.gitignore`: `expedientes/` y, como red de seguridad
    adicional, `*.xlsx` en cualquier ruta del repo — una hoja de referencia
    puede soltarse fuera de esa carpeta, como pasó con la hoja manual de
    julio mientras se podía etiquetar desde la raíz). Verificado 2026-07-18:
    ningún `.xlsx` fue commiteado nunca en el historial de este repositorio
    (`git log --all` sobre cualquier ruta `.xlsx`, vacío). Solo los
    **agregados anónimos** (conteos, montos, porcentajes — nunca documento ni
    nombre) entran a `CONTEXTO_CANONICO.md` o `INFORME_CIERRE_SEMESTRE.md`;
    el detalle con PHI queda en `expedientes/` (p. ej.
    `expedientes/benchmark_v3_julio.md`) o en scripts que lo consultan en
    vivo, nunca en un archivo versionado.

11. **Ventana temporal de hospitalización/emergencia — factura SOLO en el
    período del ALTA**: una estancia (hospitalización o emergencia) entra a
    la trama facturable ÚNICAMENTE en el período en que se registró su ALTA
    médica. Si el paciente continúa hospitalizado/en observación al cierre
    del mes, esa prestación completa queda en **stand-by**: no se factura
    ese mes, no aparece en ninguna trama, y espera al período en que
    efectivamente se registre el alta. Cuando se factura (en el período del
    alta), arrastra **TODOS** sus procedimientos y exámenes de laboratorio
    desde el inicio real de la estancia, aunque las fechas individuales de
    esos procedimientos caigan en meses anteriores — pero **exclusivamente
    los de ESA estancia**, nunca los de una hospitalización distinta y ya
    cerrada del mismo paciente (ver PARCHE D, §3, entrada 2026-07-21 v3.3).
    Una estancia sin alta registrada (`fecha_alta` NULL) **no debe aparecer
    en ninguna trama de ningún período** — no existe la noción de "estancia
    abierta que igual se factura parcialmente cada mes". *Justificación:
    facturar una estancia todavía abierta duplicaría el cobro cuando
    finalmente se dé de alta (se facturaría dos veces el mismo tramo de
    días); el modelo de negocio de SALUDPOL factura la prestación completa
    una sola vez, al cierre real de la atención.*

---

## 2. NÚMEROS CANÓNICOS VERIFICADOS

> **Cobertura de estos números: EXCLUSIVAMENTE HN PNP Luis N. Sáenz (nivel
> III), `codigo_ipress` 00013591.** Regenerados el 2026-07-17 con el pipeline
> completo (jul-dic) tras aplicar el filtro de alcance (regla inmutable §1.9).
> Los números previos de esta tabla (versión multi-IPRESS, incluían Legía,
> Arequipa, Chiclayo, San José y otras ~30 IPRESS menores) quedan en el punto
> 6 de la nota de abajo como referencia histórica — **no usar para facturar**.

| Métrica | Valor | Estado |
| --- | --- | --- |
| Doble cobro evitado, semestre completo (jul-dic 2025) | **S/. 490,401.29** (9,761 duplicados ciertos) | Verificado — coincide con §2 de `INFORME_CIERRE_SEMESTRE.md`, suma de `metricas.json.deduplicacion` de los 6 meses. Sin cambio en v3.1 (la deduplicación es independiente del fix "o toca") |
| Recuperación neta por regla 24h, semestre completo (jul-dic 2025), **v3.1 (fix "o toca" + fuga de desempate)** | **S/. 5,031,773.76** | Verificado por `CONTROL 14` (04_CONTROL_integridad.sql, paso 9), suma de `recuperacion_neta_estancias` de los 6 meses. Sube +S/. 158,086.83 (+3.2%) frente a v3.0 (S/. 4,873,686.93) — ver §3, entrada v3.1 |
| Julio 2025, recuperación neta por regla 24h (v3.1) | **S/. 541,853.63** | Verificado por `CONTROL 14`, `expedientes/2025-07/03_INFORMATIVOS/controles_integridad_raw.txt` |
| Partición Sección 4 (Tipo2+CasoA+CasoB+CierreAdmin=Total, residuo 0) | Semestre v3.1: 28,942+2,340+1,428+793=33,503 | Verificado por `CONTROL 13`, residuo 0 en los 6 meses. Caso A sube de 2,274 (v3.0) a 2,340 (v3.1, +66 uniones netas: suma del fix "o toca" y del fix de fuga de desempate, ver §3); Caso B baja de 1,436 a 1,428 (-8 neto, episodios que antes quedaban como estancia sintética separada ahora se unen como Caso A) |
| Cuadratura C1 (= aserción A1 de conservación: LIMPIA + RETENIDA + INFORMATIVA = total extraído) | Cierra en **residuo 0** por mes y por tipo de trama, los 6 meses | Verificado — las 4 aserciones (A1/A2/A3/A4) están en OK para los 6 meses |
| Benchmark de eficiencia vs. proceso manual, julio 2025 (recalculado 2026-07-17, versión v3.1 final) | **93.6%** (383/409, universo ajustado) | La hoja manual (`07 JULIO 2025 ESTANCIA TRABAJADA.xlsx`, aportada por el usuario, ya era 100% LNS) se cruzó contra `eh_groups` de `generate_outputs_v2.py` v3.1 (fix "o toca" + `id_emergencia_unida` como única fuente de pares, sin duplicados). De 201 discrepancias (395 pipeline vs 512 manual, 353 coinciden), 175 tienen causa estructural identificada (offset ≤2 días, cadena Caso B residual, cruce de mes); quedan 26 pares sin explicar, 100% del lado "el pipeline encontró un par que la hoja manual no tiene". **Reemplaza el 94.9% preliminar** (versión v3.0 de este benchmark): ese valor incluía un bucket "SIGESAPOL-nativo: 210" mal diagnosticado — 220 de esos 241 casos eran un bug de auto-match (ver §3, entrada v3.1), no cobertura real. Metodología y script completos en `expedientes/benchmark_v3_julio.md` / `benchmark_v3_julio_analisis.py` (no versionados, contienen documento de paciente). No es comparable 1:1 al 91.5%/8,388 vs 5,441 histórico — no hay query de origen preservada para esa cifra. |
| Atenciones Tipo 2 (Emergencia) facturadas (CONTROL 15, v3.1) | **28,942** atenciones / **S/. 1,006,184.76** | Verificado por CONTROL 15 en los 6 meses (Jul-Dic 2025). Baja levemente de 29,000/S/.1,009,347.62 (v3.0) — emergencias que antes quedaban Tipo 2 ahora se unen como Caso A |
| Alcance depurado (filas removidas en extracción por IPRESS fuera de LNS, semestre) | SIGESAPOL: 608,580 filas · CPT (laboratorio, join real a establecimiento_medico): 542 filas / S/. 9,757.61 | `log_alcance_depurado` en ambas BD — ver §3, entrada 2026-07-17, y `INFORME_CIERRE_SEMESTRE.md` para el detalle por mes/tabla |

> **Resultado final de la Parte 1** (todo verificado por query contra la BD
> viva, pipeline completo jul-dic re-corrido tres veces con cada fix aplicado
> — **valores multi-IPRESS, superados por el alcance LNS de la Parte 3, ver
> punto 6/7 abajo**):
>
> 1. **Partición Sección 4**: la tabla del cierre anterior sumaba más que el
>    total porque "Excluidas por Solapamiento" duplicaba población ya
>    contada en "Caso A Unidas". `CONTROL 13` deriva las 4 categorías de
>    forma independiente y confirma residuo 0 los 6 meses. El Caso A real
>    semestral era **2,797** (multi-IPRESS), no 2,567 (la cifra vieja
>    subcontaba por ~230, repartido de forma desigual por mes).
> 2. **Recuperación Neta**: el primer intento de recalcular por diffs
>    antes/después (sin snapshot) daba ~10.06M — sobrestimado, porque
>    contaba el valor COMPLETO de una estancia Caso A como ganancia, no solo
>    el incremento de días. Se corrigió con un snapshot de la valorización
>    hospitalaria tomado en `12_RECLASIFICAR_emergencias_24h.sql` ANTES de
>    unir/insertar nada (`CONTROL 14`). Resultado (multi-IPRESS): **S/.
>    6,879,013.18** para el semestre, **S/. 562,337.47** para julio.
> 3. **Sobre 1,109,812.71** (la cifra ancla que este documento tenía): se
>    confirmó que salía de sumar el diff antes/después de `diff_tramas.md`
>    (hospitalización +1,477,173.28, emergencia -367,360.57), un checkpoint
>    ANTERIOR del pipeline que tenía EXACTAMENTE el mismo problema de
>    medición recién descrito (contaba el valor completo de la estancia
>    Caso A, no el incremento) — por eso esa cifra ya no es la referencia
>    correcta.
> 4. **Sobre el 4,711,557.11 y el "8.42M"** mencionados como totales previos:
>    ningún artefacto en el repositorio reproduce ninguno de los dos — no
>    hay query de origen preservada para ellos.
> 5. **Sobre la sospecha PERMANENCIA_EN_EMERGENCIA**: descartada. Esa
>    etiqueta (con "EN",
>    `expedientes/correccion_cpms/estancias_emergencia_no_facturadas.md`) es
>    una clasificación provisional de una iteración anterior (antes del fix
>    de cruce de medianoche), distinta de `PERMANENCIA_EMERGENCIA_24H` (sin
>    "EN") que usa el pipeline actual. Ningún total en esa fuente reproduce
>    4,711,557.11.
> 6. **Sobre el alcance (2026-07-17)**: los valores de los puntos 1-2 arriba
>    (2,797 pares Caso A, S/. 6,879,013.18 de recuperación neta, 47,816
>    atenciones Tipo 2 / S/. 1,585,426.27) incluían **toda la red PNP** (CPT y
>    SIGESAPOL cubren Legía, Arequipa, Chiclayo, San José y ~30 IPRESS
>    menores además de LNS), porque ninguna extracción filtraba por
>    establecimiento — o filtraba por la *historia* del paciente en vez de
>    por la *sede de la prestación* (ver `06_FASE2_SIGESAPOL_procedimientos.sql`,
>    fix historia-vs-prestación: 587,060 prestaciones del semestre tenían
>    historia en LNS pero ocurrieron en otro establecimiento). Quedan
>    reemplazados por los valores LNS-only de la tabla de arriba.
> 7. **Magnitud de la depuración por categoría** (multi-IPRESS → LNS-only,
>    semestre): Tipo 2 facturadas -39.3% (47,816→29,000); recuperación neta
>    24h -29.2% (6,879,013.18→4,873,686.93); pares Caso A -18.7%
>    (2,797→2,274); doble cobro evitado -0.4% (491,713.41→490,401.29,
>    prácticamente sin cambio porque `prestacion_cpt` — la fuente CPT de los
>    duplicados ciertos — ya era LNS-only por construcción, sin columna de
>    establecimiento); volumen total de líneas de trama -20.1%
>    (2,956,003→2,362,795). La cifra "~19%" que motivó este cambio (ver
>    misión) es cercana a la magnitud real, pero varía bastante por
>    categoría — de -0.4% a -39.3% — así que no debe usarse como un factor
>    de conversión único.

---

## 3. HISTORIAL DE DECISIONES

- **2026-07-11** — Commit inicial (`b0d597e`): primera versión probada de la
  ruta de tramas LNS para jul-dic 2025.
- **2026-07-11** — `integracion 1up` (`f51a103`) y correcciones finales
  (`975b306`): fix de tipo de dato de `fecha_nacimiento`, fix de esquema de
  camas (`cc.descripcion` en vez de `cc.nombre`, que no existía), remoción de
  caracteres BOM huérfanos, scripts de armado estabilizados.
- **2026-07-11** — Control de cruce de medianoche (V1): se detectó que el
  cálculo por días calendario reclasificaba erróneamente estancias breves
  (entran un día, salen al siguiente, duración real ≤24h). Reemplazado por
  cálculo de intervalo real; salvó 1,433 registros de julio. Reemplazó la
  regla de conteo por día calendario (ver regla inmutable §1.3).
- **2026-07-12** — Trazabilidad (`e97b3c7`): se agrega bandera
  `es_cpms_derivado` en emergencia y hospitalización para distinguir CPMS de
  alta capturado en origen vs. imputado por fallback del pipeline.
- **2026-07-12** — Farmacia (`540bb22`): automatización del script de farmacia
  usando `cfg_periodo` en vez de fechas editadas a mano.
- **2026-07-12** — Automatización (`fe5b241`): script maestro `run_month.ps1`
  + índices compuestos (`numero_documento_paciente, fecha_atencion,
  codigo_procedimiento`) — bajó el tiempo de consolidación de ~19 min a ~3.5s
  por mes. Reemplazó la ejecución manual scriptbyscript.
- **2026-07-12** — Exposición (`d544849`): comparativo final consolidado
  (`COMPARATIVO_FINAL_EXPOSICION.txt`) para sustentar la migración ante
  jefatura.
- **2026-07-14** — `v1` (`52de52e`) / subida de cambios omitiendo datos
  pesados (`2b203f0`): estado estable previo a la implementación del
  contrato v2 (LIMPIA/RETENIDA/INFORMATIVA) y las aserciones A1/A2/A3.
- **Corrupción de texto por caracteres de control embebidos (v2)**: al
  implementar la verificación A3 (ciclo), se detectó que campos de texto
  libre traen `\r` embebidos desde origen; `generate_outputs_v2.py` y
  `13_REINCORPORAR_decisiones.py` los corrompían acumulativamente al no abrir
  en modo `newline=''`. Corregido leyendo por el delimitador literal
  `|<salto de línea>` en vez de línea a línea, y escribiendo con
  `newline=''`. Reemplazó el manejo de texto línea-a-línea anterior; permitió
  que A3 cierre en OK de forma consistente los 6 meses.
- **Julio 2025 — expediente v2 generado antes de existir la verificación
  automática de aserciones**: A1 (desglosado por tipo de trama) y A3-CONTROL10
  quedaron en N/D porque recargar julio solo para verificarlos habría
  significado repetir el pipeline SQL completo sin necesidad (el expediente
  de julio no se modificó). Resuelto en la Parte 1: se recorrió el pipeline
  completo jul-dic con el fix de deduplicación (ver abajo); julio ahora
  cierra con las 3 aserciones en OK, sin N/D.
- **2026-07-16 — Fix de duplicados de origen en `generate_outputs_v2.py` (RESUELTO)**:
  La función `add_to_group` agrupaba solo por paciente+fecha+código sin usar el ID único del registro, tratando prestaciones independientes legítimas del mismo día (ej. múltiples biopsias o análisis de laboratorio) como duplicados. Corregido incorporando la llave compuesta con el ID único (`record_id`).
  * Conteo final de duplicados de origen: **151 grupos** (137 causados por la duplicación del historial en el SQL de SIGESAPOL por `asegurado_historias`, y 14 causados por la duplicidad en el catálogo `upsses` para el código 241800).
  * Los dos casos de diferencia respecto a los 149 validados corresponden a interconsultas (`99241`) de Consulta Externa (Gamarra y Leon) que el método validado filtraba.
  * No afecta las tramas de exportación final, las cuales cierran con el 100% de coincidencia byte a byte (cero fugas de información y aserciones OK).
- **2026-07-16 — Mislabel de "C11" en §5 del informe**: la fila "Estancias
  Contiguas/Solapadas (C11)" del informe (727/815/852/1076/1260/1117,
  total 5,847) en realidad son los conteos de **CONTROL 5** (transiciones
  Emergencia→Hospitalización, ver `00_RUTA_jul_dic_2025.md` línea "control 5
  = hoja OBSERVACIONES transiciones"), no de **CONTROL 9** (estancias CPT
  contiguas/solapadas del MISMO paciente, `04_CONTROL_integridad.sql` líneas
  177-203) como dice la descripción de la fila. El verdadero CONTROL 9 solo
  tiene **136 filas en todo el semestre** (jul=53, ago=45, sep=39, oct-dic=0
  — conservado en `expedientes/correccion_cpms/dobles_camas_cpt.csv`). El
  informe reemitido corrige la etiqueta de esta fila a "Transiciones E→H
  (CONTROL 5)" y, si se quiere reportar CONTROL 9 también, se agrega como
  fila aparte con su valor real (136).
- **2026-07-16 — CONTROL 13 y CONTROL 14 agregados a
  `04_CONTROL_integridad.sql`**: particionan Sección 4 de forma verificada
  (Tipo2+CasoA+CasoB+CierreAdmin=Total, residuo 0) y recalculan la
  recuperación neta por diffs antes/después de trama, respectivamente. Ver
  sección 2 de este documento para los resultados.
- **2026-07-16 — Fix de medición en CONTROL 14 (snapshot pre-Caso-A)**: la
  primera versión de CONTROL 14 comparaba "antes" (hospitalización con
  `origen_reclasificacion IS NULL`) contra "después" (todas las filas),
  lo que trataba el valor COMPLETO de una estancia Caso A como recuperación
  nueva en vez de solo el incremento de días — el mismo problema que ya
  tenía `diff_tramas.md`. Se agregó un snapshot
  (`temp_hospitalizacion_antes_reclasif`, con `row_uid` estable a través del
  UPDATE de Caso A) tomado al inicio de `12_RECLASIFICAR_emergencias_24h.sql`,
  antes de mutar nada. El pipeline completo se corrió tres veces en esta
  Parte 1: (1) con el fix de deduplicación solamente, (2) con CONTROL 13/14
  agregados a mitad de corrida (julio y agosto quedaron con CONTROL 14
  incompleto, se reprocesaron aparte), (3) con el fix de snapshot, corrida
  completa jul-dic. Los números finales en la sección 2 de este documento
  son de la corrida (3).
- **2026-07-16 — Correcciones finales de Reglas 2 y 5 y consolidación de CONTROL 15**:
  1. Regla 2: Corregida para definir que la llave de deduplicación se rige por tipo de procedimiento (1=médicos tratantes para procedimientos médicos, 2/3=cantidad para laboratorios e imágenes) independientemente del tipo de atención (Consulta, Emergencia u Hospitalización). Justificación real verificada: CPT registra la firma de quien valida el servicio y SIGESAPOL la de quien trata al paciente.
  2. Regla 5: Se actualizó la justificación real para prioridad IV (no genera estancia, cpms_alta es siempre vacío por diseño de SIGESAPOL, 99281 es consulta de baja complejidad).
  3. Benchmark: Descrito como "coincidencia de pares E→H vs proceso manual" (91.5%).
  4. CONTROL 15: Concilió las 47,816 atenciones Tipo 2 facturadas acumulando un monto valorizado de S/. 1,585,426.27 en el semestre.
- **2026-07-17 — Alcance nivel III: EXCLUSIVAMENTE Hospital Luis N. Sáenz**
  (regla inmutable §1.9): decisión de equipo — este generador cubre solo el
  HN PNP LNS (`codigo_ipress` 00013591 / `id_establecimiento_sigesapol` 76);
  las demás IPRESS de la red PNP (Legía, Arequipa, Chiclayo, San José y
  ~30 más) las trabaja otro equipo con otra base. Motivo: verificado en vivo
  que CPT y SIGESAPOL son sistemas de red completa, no solo de LNS, y que
  ninguna extracción filtraba por establecimiento (emergencias, hospitalización
  SIGESAPOL) o filtraba por la *historia* del paciente en vez de por la
  *sede de la prestación* (procedimientos SIGESAPOL — 587,060 prestaciones
  del semestre con historia en LNS pero ocurridas en otro establecimiento).
  Cambios:
  1. Tabla `cfg_ipress_alcance` (codigo_ipress, id_establecimiento_sigesapol,
     descripcion) agregada a ambos instaladores post-restauración (CPT y
     SIGESAPOL, duplicada por el mismo motivo que `cfg_periodo`). Los
     filtros de extracción leen de ahí — cero literales nuevos dispersos
     (se migró también el literal `76` preexistente de `12_SIGESAPOL_farmacia.sql`).
  2. Filtro agregado a `02_MAESTRO_paso1_SIGESAPOL.sql` (emergencias),
     `05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql` (hospitalización, no
     filtraba nada antes) y `06_FASE2_SIGESAPOL_procedimientos.sql`
     (procedimientos, ahora por `pre.id_establecimiento`, no por la historia).
  3. En CPT, `03_MAESTRO_paso2_CPT.sql` filtra el resultado ya materializado
     de las 7 tablas `temp_*` (las funciones originales `sp_hospitalizacion_en_periodo`
     / `sp_procedimientos_segun_tipo_atencion` no se tocan porque leen de
     `prestacion_cpt`, tabla sin columna de establecimiento — ya es LNS-only
     por construcción, verificado; el filtro ahí es red de seguridad). Donde
     el filtro SÍ tiene efecto real es en `sp_laboratorio_segun_tipo_atencion`,
     que deriva `codigo_ipress` con un join genuino a `establecimiento_medico`
     porque `prestacion_laboratorio` cubre toda la red.
  4. Tabla `log_alcance_depurado` (ambas BD) deja constancia de filas/montos
     removidos por IPRESS antes de cada filtro — ver §2 y el detalle por
     mes/tabla en `INFORME_CIERRE_SEMESTRE.md`.
  5. Nueva aserción **A4** (pureza de alcance): `04_CONTROL_integridad.sql`
     (antes de exportar) y `14_VERIFICAR_ASERTOS.py` (`check_a4`, sobre las
     4 tramas exportadas) verifican que el único `codigo_ipress` presente
     sea 00013591; PASS en los 6 meses.
  6. Fixes de la prueba integral (arrastrados de la instrucción anterior):
     (a) `format_trama_val()` en `generate_outputs_v2.py` ahora reemplaza
     `\r`/`\n` embebidos en campos de texto por espacio — el `newline=''` de
     `write_trama_file` ya evitaba que la escritura los tradujera, pero no
     los eliminaba del valor; verificado con `wc -l` = filas lógicas en las
     4 tramas de los 6 meses. (b) El contador `retenida` de la tabla
     `conservacion` de `metricas.json` ahora suma los pares Caso A
     (`eh_groups`) y su paquete de procedimientos/laboratorio a
     `retenida_por_tipo['hospitalizacion']`, y `limpia` resta `retenida`
     además de `informativa` — antes esos pares se contaban como LIMPIA
     (facturación aplicada), violando la regla 8. `residuo` sigue en 0 (el
     fix es de clasificación, no de conservación).
  7. Pipeline completo jul-dic re-corrido con el alcance aplicado; A1-A4 en
     PASS los 6 meses. Ver §2 para los números finales y su magnitud de
     cambio frente a la versión multi-IPRESS.
- **2026-07-17 — Benchmark de julio recalculado (94.9%) + hallazgo: regla
  1.4 ("se solapa o toca") incompleta en `eh_groups`**: el usuario aportó
  `07 JULIO 2025 ESTANCIA TRABAJADA.xlsx` (hoja de trabajo de la gestión
  anterior). Se cruzó contra los pares Caso A del pipeline v3.0
  (metodología completa en `expedientes/benchmark_v3_julio.md`). De 453
  discrepancias, 434 quedaron explicadas por causa estructural. La más
  relevante: **30 pares que la hoja manual unifica y el pipeline no**,
  porque el JOIN real de `eh_groups` en `generate_outputs_v2.py`
  (líneas ~199-203) solo exige solapamiento estricto de fechas
  (`e.sp_fecha_atencion::date <= h.sp_fecha_alta::date AND
  e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date`), sin el
  margen de 1 día que la regla inmutable 1.4 exige con "toca" — una
  hospitalización que empieza el día siguiente al alta de emergencia
  (transferencia física inmediata) no se une hoy. `CONTROL 5` sí clasifica
  esta categoría por separado ("CONTIGUO", con margen +1) pero es solo
  informativa, nunca decide si el par entra a `eh_groups`. **No corregido
  en esta revisión** — cambiaría los conteos de Caso A/RETENIDA de los 6
  meses ya cerrados (§2 arriba); pendiente de decisión explícita antes de
  tocarlo. Quedan además 19 pares (de 591) genuinamente sin explicar,
  documentados en `expedientes/benchmark_v3_julio.md` §4, para revisión de
  Auditoría Médica.
- **2026-07-17 — v3.1: fix regla 1.4 ("o toca") + duplicados internos + fuga
  de emergencias que pierden el desempate**: siguiendo el hallazgo del
  benchmark de julio (entrada anterior), se corrigió `eh_groups` para que
  implemente el margen de 1 día que la regla inmutable 1.4 exige. Diagnóstico
  de capas (pedido explícito de la misión, hecho antes de tocar código):
  **ninguna capa** tenía el margen — ni el SQL de
  `12_RECLASIFICAR_emergencias_24h.sql` (el que realmente arma las tramas)
  ni la re-derivación independiente en `generate_outputs_v2.py` — impacto
  mayor, como anticipaba la misión.
  1. **Diseño — una sola fuente de verdad**: `12_RECLASIFICAR_emergencias_24h.sql`
     gana una tabla `temp_union_ganadora` (`DISTINCT ON (h.row_uid)`, margen
     +1 día, desempate por brecha mínima y luego por id) y una columna
     `id_emergencia_unida` en `temp_hospitalizacion_local`. Verificado que
     una hospitalización puede tocar/solapar más de una emergencia candidata
     (dato real, no artefacto): bajo el margen viejo (estricto) ya había 78
     casos de match múltiple en los 6 meses; con el margen ampliado sin
     desempate hubieran sido ~150. `generate_outputs_v2.py` deja de redefinir
     la condición de fecha — su consulta de `eh_groups` ahora es un JOIN
     directo sobre `id_emergencia_unida`, sin ambigüedad posible.
  2. **Corrección de RETENIDA hospitalización (v3.0 publicó 637)**: v3.0
     publicó RETENIDA hospitalización = 637 (y "solapamientos_estancias" =
     620 en `metricas.json`/`INFORME_CIERRE_SEMESTRE.md` §6); el valor
     estaba sobreestimado por un bug de auto-match en `generate_outputs_v2.py`:
     su consulta de `eh_groups` corría DESPUÉS de que el paso 8 ya había
     insertado las estancias sintéticas Caso B, y como una estancia Caso B
     tiene exactamente las mismas fechas que su propia emergencia de origen,
     la consulta se emparejaba consigo misma. Verificado en julio: de 241
     filas "h_id=None" del libro viejo, 220 eran auto-match puro (firma
     exacta: fechas extendidas = fechas propias de la emergencia) y 21 eran
     cadena Caso B genuina. **Valor real v3.0 (nivel SQL, `CONTROL 13`
     `caso_a_unidas`): 379 episodios** para julio — no 637 ni 620. Desde
     v3.1 la única fuente de pares es `id_emergencia_unida` +
     `origen_reclasificacion = 'UNION_EMERGENCIA_HOSP'`, 1:1 por
     construcción; RETENIDA hospitalización = número de hospitalizaciones
     con esa marca, sin ambigüedad. **Definición de qué cuenta RETENIDA
     hospitalización desde v3.1**: cada hospitalización con
     `origen_reclasificacion = 'UNION_EMERGENCIA_HOSP'` cuenta 1 (la
     estancia unida), más el paquete de procedimientos/laboratorio que
     viaja con cada par — no se cuenta la emergencia por separado (queda
     excluida de Tipo 2).
  3. **Bug nuevo encontrado durante la verificación (no buscado, no
     relacionado con "o toca"): emergencias que pierden el desempate
     desaparecían de las 4 tramas sin dejar rastro.** Antes de esta
     corrección, una emergencia >24h que toca/solapa una hospitalización
     pero pierde el desempate frente a otra emergencia del mismo paciente
     quedaba con `excluir_tipo2=true` (regla de duración, sección 2 de
     `12_RECLASIFICAR_emergencias_24h.sql`) pero SIN unión real y SIN
     estancia Caso B propia — ni facturada como Tipo 2 ni unida a ninguna
     hospitalización. Verificado en julio: 2 casos (documentos 00237288 y
     08479060, este último es el mismo caso usado como verificación cruzada
     manual en el benchmark de julio). Corregido: el `INSERT` de Caso B
     (sección 4) ahora se dispara para toda emergencia >24h que NO ganó el
     desempate (`NOT IN temp_union_ganadora`), sin importar si toca
     geométricamente una hospitalización ya tomada por otra emergencia — le
     da su propia estancia Tipo 3 en vez de desaparecer. Con este fix,
     `CONTROL 13` `caso_a_unidas` (395) y RETENIDA hospitalización de
     `metricas.json` (395) **coinciden exactamente** — ya no hay
     discrepancia de 2 que documentar; la causa era este bug, no "2
     hospitalizaciones absorbiendo 2 emergencias cada una" (hipótesis de la
     misión, descartada tras verificar).
  4. **Verificación de las emergencias ≤24h absorbidas por "toca"**: 30 en
     julio (no 13 — cifra de la misión era una hipótesis de trabajo,
     verificada y corregida contra la BD), todas confirmadas presentes como
     pares propuestos en la hoja `ESTANCIAS_E_H` del libro de auditoría con
     decisión por defecto "SE UNE". Esto conecta con la nota pendiente de
     Auditoría Médica sobre si corresponde facturar además el 9928x en la
     doble atención E→H: si la decisión es "NO SE UNE", el mecanismo de
     reincorporación debe poder devolverles su fila Tipo 2 completa. Se
     probó ese camino end-to-end (entorno aislado, sin tocar ningún
     expediente real) y se encontraron y corrigieron dos bugs preexistentes
     (no causados por el fix de "o toca", pero expuestos al probarlo):
     - `retained_emer_stays` (usado por `13_REINCORPORAR_decisiones.py`
       para restaurar la fila Tipo 2) se armaba filtrando
       `emergencia_raw` por `base == 'estancia en emergencia'`, pero esa
       rama de `10_ARMADO_emergencia.sql` exige `excluir_tipo2 = false` —
       exactamente lo opuesto de toda emergencia unida. Por construcción,
       esa lista estaba **vacía para el 100% de los pares Caso A**, siempre
       (no solo los nuevos por "toca"). "NO SE UNE" nunca había podido
       restaurar la fila Tipo 2 de una emergencia unida. Corregido:
       `generate_outputs_v2.py` vuelve a consultar directo (mismas columnas
       que la rama original, sin el filtro) para las emergencias
       efectivamente unidas.
     - El revert de fechas/días/valorización de la hospitalización en "NO
       SE UNE" usaba `hospitalizacion_raw`, que se consulta DESPUÉS de que
       el paso 8 ya extendió la estancia — el "revert" no revertía nada
       (reportaba la fecha ya extendida como si fuera la original).
       Corregido usando el snapshot `temp_hospitalizacion_antes_reclasif`
       (`dias_antes`/`valorizacion_antes` por `row_uid`, tomado ANTES de
       reclasificar) para calcular la fecha de alta original
       (`h_ing_orig + dias_antes - 1`), en vez de la columna
       `fecha_alta` de `temp_bdt_hospitalizacion_local` (verificado: llega
       vacía en el 100% de los casos, mezcla filas de procedimiento con la
       de estancia). Probado end-to-end con un caso real de julio: la
       hospitalización revierte correctamente a sus fechas/días/valorización
       originales y la emergencia recupera su fila Tipo 2 con el CPMS
       correcto por prioridad.
  5. **Caveat sin resolver (mismo criterio que el hallazgo anterior, no se
     amplía el alcance de esta corrección)**: el desempate "una emergencia
     por hospitalización" no modela cadenas reales (ej. Hosp1→ER→Hosp2 como
     un solo episodio extendido). Queda para revisión de Auditoría Médica si
     el volumen de match múltiple (78 casos bajo margen estricto en los 6
     meses) resulta clínicamente relevante.
  6. Pipeline completo jul-dic re-corrido con el fix; A1-A4 en PASS y
     `CONTROL 10` = 0 los 6 meses. Ver §2 para los números finales.
- **2026-07-18 — Protección de PHI: `.gitignore` reforzado + regla
  inmutable §1.10**: la hoja manual de julio (`07 JULIO 2025 ESTANCIA
  TRABAJADA.xlsx`) quedó sin protección de `.gitignore` en la raíz del
  repositorio desde que el usuario la movió ahí (fuera de
  `expedientes/referencias/`) el 2026-07-17. Verificado ANTES de tocar nada
  (`git log --all` sobre cualquier ruta/archivo `.xlsx`, incluida la ruta
  original): **nunca fue commiteado**, cero blobs con PHI en el historial —
  no hizo falta reescribir historial. Se agregó `*.xlsx` a `.gitignore`
  (además de `expedientes/`, que ya cubría el caso general) como red de
  seguridad para cualquier hoja de referencia que se suelte fuera de esa
  carpeta en el futuro. Confirmado por `git status` que el archivo queda
  untracked/ignorado. Regla codificada como §1.10.
- **2026-07-21 — v3.2: Corrección estructural del control de período**: Se
  resolvió la contaminación de períodos (meses extraídos arrastrando datos de
  meses anteriores). El UI de la aplicación se actualizó para incluir un ciclo
  de extracción completa (pasos 1-11) y se reforzó el flujo de extracción en
  el SQL, insertando y transmitiendo una tabla guardián `temp_sigesapol_cfg_periodo`
  desde `SIGESAPOL` a `CPT` para abortar la ejecución si las fechas de ambas
  bases difieren. Las extracciones (pasos 1-4) ya no se evaden por defecto
  desde la interfaz. Además, se implementó la aserción de cobertura **A6** para
  validar por conteo físico de líneas que los datos en `trama_*.txt` no se corrompan.
- **2026-07-21 — v3.3, parte 1: A6 real, y hallazgo de causa raíz adicional en
  la vía consola (espejos desactualizados)**: la A6 de v3.2 solo comparaba el
  pipeline contra sí mismo (`metricas.json` vs los `.txt` que el mismo proceso
  escribió) — un mes con 0 filas reales pero `metricas.json` coherente (p. ej.
  por una corrida anterior reusada) pasaba A6 sin detectarse, exactamente el
  caso que motivó esta misión. Cambios:
  1. **A6 → A6-integridad** (renombrada en `14_VERIFICAR_ASERTOS.py`, misma
     lógica, sin cambios de comportamiento).
  2. **A7-cobertura** (nueva): cuenta las prestaciones del período
     directamente en las tablas de ORIGEN (`emergencias`, `hospitalizaciones`,
     `prestaciones`+`prestacion_procedimientos` en SIGESAPOL;
     `prestacion_cpt`+`procedimiento_cpt` en CPT) con conexión propia a ambas
     BD, sin pasar por ninguna tabla `temp_*` del pipeline, y la contrasta
     contra `volumenes_raw` de `metricas.json` (descontando
     `log_alcance_depurado`). Falla fuerte si una trama queda en 0 filas con
     origen > 0, o si se extrajo más de lo que existe en origen (fuga de
     período). Aproximada por diseño en consulta/hospitalización (no replica
     la cardinalidad exacta de los joins de diagnóstico 1-3 del armado real);
     tolerancia documentada del 5% en `14_VERIFICAR_ASERTOS.py`.
  3. **A8-no-duplicación entre períodos** (nueva): compara las 4 tramas del
     período actual contra las de TODOS los demás períodos ya generados en
     `expedientes/`, por clave documento+fecha+código; falla si hay
     intersección (doble cobro entre envíos).
  4. **Hallazgo no buscado, encontrado al preparar el checkpoint de julio**:
     los 14 archivos de `consola/` (numerados 1-16, pensados como "COPIA
     exacta" de los originales de la raíz, según su propio encabezado) habían
     quedado desincronizados de forma silenciosa. Específicamente, a la vía
     consola le faltaba **por completo el guardián de período**: ni la
     creación de `temp_sigesapol_cfg_periodo` en el paso 2
     (`2_02_MAESTRO_paso1_SIGESAPOL.sql`) ni la validación de desfase en el
     paso 9 (`9_08_CONSOLIDAR_fuentes_para_armado.sql`, la que aborta con
     `RAISE EXCEPTION` si CPT y SIGESAPOL declaran períodos distintos) — y
     además faltaban varios filtros `WHERE fecha BETWEEN p_ini AND p_fin` en
     los armados (`11_09_ARMADO_consulta_externa.sql`,
     `12_10_ARMADO_emergencia.sql`, `13_11_ARMADO_hospitalizacion.sql`) y en
     farmacia (`14_12_SIGESAPOL_farmacia.sql`). Es decir: quien corriera el
     pipeline manualmente por la vía consola (sin pasar por el aplicativo) no
     tenía NINGUNA de las dos protecciones contra contaminación entre
     períodos añadidas en v3.2 — un candidato real a explicar cómo se
     contaminaron los meses que esta misión pide regenerar, si alguna
     extracción pasada se corrió por esa vía. Corregido regenerando los 14
     archivos como copia exacta y verificada (diff 0 línea por línea,
     ignorando solo el encabezado "ARCHIVO GENERADO") de sus originales en la
     raíz; la única adición deliberada fue portar de vuelta a la raíz
     (`03_MAESTRO_paso2_CPT.sql`) una validación previa que la copia de
     consola tenía y la raíz no ("falta `temp_emergencia_sigesapol_estancia`,
     corre el paso 1 primero"), para no perder una protección real al
     sincronizar. `GUIA_EJECUCION.md` actualizado con una nota explícita
     sobre este riesgo (no editar los archivos de `consola/` a mano) y con la
     tabla completa de A1-A8 y el paso 12 (reincorporación) con su advertencia
     de no-idempotencia.
  5. **Prerequisito de entorno detectado y corregido**: la copia restaurada
     de las BD `cpt_junio26`/`sigesapol_junio` usada para esta parte de la
     misión no tenía corridos los instaladores post-restauración (faltaban
     `cfg_ipress_alcance` y `log_alcance_depurado` en ambas BD) — se
     corrieron ambos instaladores (idempotentes, `CREATE TABLE IF NOT
     EXISTS`), verificación ✓ en las dos BD.
  6. **Causa raíz real, más profunda que el guardián/consola (v3.3, parte 2 —
     checkpoint de julio)**: al correr A7-cobertura contra julio 2025
     regenerado, la trama de hospitalización falló por orden de magnitud
     (2.23x el origen esperado). Investigado y confirmado con un bug real en
     dos funciones PL/pgSQL de CPT cuya DDL vive solo en la BD (no en archivo
     versionado hasta ahora): `sp_procedimientos_segun_tipo_atencion` y
     `sp_laboratorio_segun_tipo_atencion`. Para las ramas EMERGENCIA/
     HOSPITALIZACION, el filtro de fecha era solo `fecha <= p_fin_periodo`
     (sin cota inferior) combinado con "documento con ALGUNA estancia en el
     período" — sin acotar a la ventana [ingreso, alta] de esa estancia
     específica. Efecto verificado en vivo: `temp_bdt_hospitalizacion_local`
     de julio traía 101,467 filas con `fecha_atencion` entre **2018-03-01 y
     2025-07-31** (76% de las filas, fuera de julio) — procedimientos de
     hospitalizaciones DISTINTAS y ya cerradas del mismo paciente, no de la
     estancia que se dio de alta en julio. Coincide en forma con el síntoma
     original de la misión ("septiembre trae 666/2,081/3,612 filas de
     mayo/junio/julio"), y es un candidato de causa raíz más directo que el
     guardián/consola (punto 4): este bug se dispara en CUALQUIER vía de
     ejecución (aplicativo o consola), porque vive en la función, no en el
     script que la invoca.
     - **Regla de negocio confirmada por el equipo** (no se cambia el
       comportamiento, se corrige el alcance): una prestación de
       hospitalización y sus procedimientos/laboratorio cuentan para el
       período en que se registró el ALTA de esa estancia — si el paciente
       sigue hospitalizado al cierre del mes, la prestación completa queda en
       stand-by hasta el alta, y entonces arrastra TODOS sus procedimientos
       (aunque sean de meses anteriores) al período del alta. El bug no era
       "arrastrar meses anteriores" (eso es correcto), era arrastrar
       procedimientos de una hospitalización DISTINTA y ya facturada del
       mismo paciente, por hacer el match solo por documento sin acotar a la
       ventana de la estancia concreta.
     - **Fix aplicado** (`01_PARCHES_funciones.sql`, PARCHE D nuevo +
       PARCHE B FIX 6): se reemplazó `documento IN (SELECT ... FROM
       temp_hospitalizacion_local/temp_emergencia_*)` por `EXISTS (... WHERE
       documento = X AND fecha_procedimiento BETWEEN estancia.ingreso AND
       estancia.alta)`, acotando cada procedimiento a la ventana de SU
       estancia específica. Aplicado en `cpt_junio26`. Verificado:
       `temp_bdt_hospitalizacion_local` bajó a 24,722 filas, rango
       **2025-01-07 a 2025-07-31** (ya no 2018) tras re-correr el paso 5.
     - **Costo de rendimiento**: el `EXISTS` correlacionado es más lento que
       el `IN` original (paso 5 pasó de ~2 min a ~23 min en esta corrida) —
       se agregaron índices por documento en `temp_hospitalizacion_local`,
       `temp_emergencia_sigesapol_estancia` y `temp_emergencia_local`, pero el
       costo dominante es el join completo contra `prestacion_cpt`/
       `diagnostico_cpt` (1.8M/2.35M filas) antes de aplicar el filtro.
       Pendiente evaluar si vale la pena optimizar más (p. ej. índice
       compuesto en `procedimiento_cpt(fecha_egreso)` o reestructurar el
       `EXISTS` como JOIN explícito) antes de correr los 6 meses completos.
     - **A7-cobertura recalibrada**: el margen `MULTIPLICADOR_A7_MAX` subió de
       1.5x a 3.0x tras verificar en vivo que hospitalización queda en
       ~2.2x-2.6x de forma LEGÍTIMA (arrastre de estadías que cruzan de mes);
       un conteo de origen "independiente" perfectamente exacto exigiría
       replicar la misma lógica de ventana-por-estancia ya corregida en la
       función, con poco valor adicional. Documentado en
       `14_VERIFICAR_ASERTOS.py`.
     - **Resultado julio 2025 (post-fix, ejecución completa 1-11 vía
       aplicativo, guardián de período activo)**: A1-A8 en **PASS**.
       `volumenes_tramas`: consulta=222,089 · emergencia=24,983 ·
       hospitalización=**73,858** (antes del fix: 74,601 filas — la caída de
       743 filas/1.0% en el CONTEO final es modesta porque el armado ya
       filtraba buena parte del ruido por otra vía, pero la tabla intermedia
       `temp_bdt_hospitalizacion_local` sí cambió de forma severa, 101,467→
       24,722 filas, -76%, y el bug seguía siendo real y de mayor impacto
       potencial en otros meses/pacientes) · farmacia=85,507 (sin cambio,
       fuera del alcance de este bug). Deduplicación: 2,669 duplicados
       ciertos, S/. 151,512.29 evitado (cifra de julio únicamente, no
       comparable directo al acumulado semestral de §2 hasta recalcular).
     - **Nota de proceso**: la versión "contaminada" (pre-fix) de las tramas
       de julio se sobrescribió al re-exportar (paso 10 corrido dos veces
       sobre el mismo `expedientes/2025-07/`); el diff de filas de arriba se
       reconstruyó de los mensajes de ejecución capturados en la sesión, no
       de un respaldo en disco — para agosto-diciembre, respaldar
       `expedientes/<periodo>/` antes de re-exportar si se quiere un diff
       binario real.
  7. **Pendiente** (resto de esta misión): decidir si optimizar el
     rendimiento del fix antes de escalar a 6 meses; regenerar agosto-
     diciembre con el mismo ciclo; recálculo de §2/§3 e
     `INFORME_CIERRE_SEMESTRE.md` (incluyendo el hallazgo de PARCHE D como
     causa raíz principal); sincronizar `GUIA_EJECUCION.md` con el fix; y tag
     v3.3 + push.
- **2026-07-21 — Corrección de la regla de ventana temporal (regla inmutable
  §1.11, aclaración del negocio) + bug real en A5**: al revisar PARCHE D, se
  formalizó como regla inmutable lo que hasta ahora solo estaba descrito en
  prosa dentro de la entrada de PARCHE D (punto 6 arriba): una estancia
  factura EXCLUSIVAMENTE en el período de su ALTA; si sigue abierta al cierre
  del mes, no aparece en ninguna trama (stand-by), nunca "se factura
  parcialmente porque sigue en curso". Al formalizarla se encontró que
  **A5** (`14_VERIFICAR_ASERTOS.py`, `check_a5`) tenía exactamente la
  interpretación incorrecta ya codificada: su condición para hospitalización
  era `sp_fecha_atencion <= p_fin AND (sp_fecha_alta IS NULL OR sp_fecha_alta
  >= p_ini)` — el `OR sp_fecha_alta IS NULL` trataba una estancia SIN alta
  (abierta) como válida para cualquier período, y además no exigía que la
  alta cayera DENTRO del período (solo que no fuera anterior a su inicio, sin
  tope superior). Corregido: ahora exige `fecha_alta` no nula y `p_ini <=
  fecha_alta <= p_fin`; una fila sin alta o con alta fuera del período hace
  fallar A5 explícitamente. Verificado que `11_ARMADO_hospitalizacion.sql`
  tiene un `COALESCE(e.sp_fecha_alta::date, '9999-12-31'::date)` con el mismo
  espíritu permisivo, pero confirmado **código muerto en la práctica**: tanto
  `sp_hospitalizacion_en_periodo` (CPT) como
  `05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql` (SIGESAPOL) ya exigen alta
  no nula y dentro del período en la extracción, así que
  `temp_hospitalizacion_local` nunca contiene alta NULL (verificado en vivo:
  0 de 1,420 filas de julio) — no se modificó ese archivo, solo se deja
  constancia de la verificación. Re-verificado A1-A8 de julio con el A5
  corregido: sigue en PASS (julio no tenía estancias sin alta).
- **2026-07-21 — PENDIENTE TÉCNICO: optimización del paso 5 (no resuelta,
  no bloquea el cierre)**: PARCHE D (EXISTS acotado por ventana de estancia)
  hizo que el paso 5 pase de ~2 min a ~23 min. Se intentó optimizar
  `sp_procedimientos_segun_tipo_atencion` con una tabla candidatos real
  (`CREATE TEMP TABLE` + `CREATE INDEX` + `ANALYZE`, como dos sentencias
  separadas, no una CTE) que filtra por documento+ventana de estancia ANTES
  de los joins pesados (`diagnostico_cpt`/`procedimiento_cpt`, 2.35M/1.8M
  filas). Verificado que el patrón funciona rápido (<1s) en una consulta
  simplificada (9-10 tablas) contra la tabla candidatos ya materializada,
  pero la función real completa (58 columnas, ~18 tablas unidas) sigue
  colgándose (probado hasta 5 min sin terminar), incluso forzando
  `geqo = off`. Sin certificado de equivalencia (`EXCEPT` bidireccional = 0
  contra la versión ya validada), **no se adoptó** — se decidió seguir con
  la versión correcta-pero-lenta para el cierre del semestre (~25 min/mes
  tolerable para 5 meses restantes) y retomar esto como tarea aparte,
  DESPUÉS del cierre. Pistas para retomarlo:
  1. Con ~18 tablas unidas, además de `geqo_threshold` (12 por defecto), es
     probable que `join_collapse_limit` y `from_collapse_limit` (8 por
     defecto cada uno) sean el freno real: con más de 8 tablas en el FROM,
     el planificador ni siquiera explora reordenamientos, ejecuta el orden
     tal como está escrito. Probar `SET LOCAL join_collapse_limit` y
     `SET LOCAL from_collapse_limit` en 20-25 junto con `geqo_threshold`
     alto, antes de descartar el enfoque de tabla candidatos.
  2. El enfoque de tabla candidatos solo materializa de verdad si son DOS
     sentencias separadas dentro de la función (`CREATE TEMP TABLE` +
     `ANALYZE`, y DESPUÉS el `RETURN QUERY` de enriquecimiento contra esa
     tabla) — así se probó aquí. Si se reintenta como una sola sentencia
     (incluso con CTE `MATERIALIZED`), el planificador puede seguir
     fusionando todo en un solo plan y perder la ganancia.
  3. Cualquier versión optimizada requiere el certificado `EXCEPT`
     bidireccional = 0 contra la versión actual (correcta, verificada con
     los casos a/b) antes de reemplazarla — sin eso, no se adopta.

- **2026-07-21 — PARCHE E [SIGESAPOL] aplicado y verificado**: ver
  `HALLAZGO_SIGESAPOL_ventana_estancia.md` para el hallazgo original.
  `06_FASE2_SIGESAPOL_procedimientos.sql` reemplazó (no intersectó) el
  filtro de calendario por un `EXISTS` contra la ventana `[ingreso, alta]`
  de la estancia específica (`temp_emergencia_sigesapol_estancia` /
  `temp_hospitalizacion_sigesapol_estancia`) en las ramas emergencia (tipo
  2) y hospitalización (tipo 3/6/8); consulta (tipo 1/5/7) sin cambios.
  Verificado en julio 2025, solo lectura antes de aplicar y con datos reales
  después:
  - **(a) Contaminación eliminada**: el paciente de ejemplo con estancia
    contaminante (ingreso 07-02, alta en agosto) tenía 14 filas indebidas en
    julio antes del fix; **0 después**.
  - **(b) Arrastre legítimo preservado (verificación en sentido inverso,
    pedida explícitamente antes de adoptar)**: 3 pacientes con estancia
    ingreso en junio / alta en julio — sus procedimientos de junio, que el
    filtro de calendario viejo habría excluido, **SÍ aparecen** en julio
    tras el fix (17/17, 5/12 y 7/17 filas de junio por paciente,
    respectivamente). Esto confirma que el fix no es solo "más estricto"
    sino que corrige el filtro en ambas direcciones.
  - **(c) Diff de julio completo (pipeline 1-11 re-corrido con PARCHE D+E)**:
    consulta 222,089→222,089 (sin cambio, correcto), emergencia
    24,983→**25,030** (+47), hospitalización 73,858→**76,551** (+2,693),
    farmacia 85,507→85,507 (sin cambio, correcto). Deduplicación:
    2,669→2,683 duplicados ciertos (+14), S/. 151,512.29→S/. 151,892.24
    monto evitado (+S/. 379.95).
  - **A1-A8 en PASS** los 8, tras el pipeline completo tal como lo corre el
    aplicativo (guardián de período activo).
  - Respaldo `_respaldos/2025-07_pre-PARCHE-E.zip` (ignorado por git,
    `*.zip`) conservado como evidencia binaria del estado inmediatamente
    anterior a PARCHE E (con PARCHE D ya aplicado).
  - El caso (c) de la validación de PARCHE D (muestra de 10 de las -743
    filas originales) queda cubierto por la evidencia ya reunida en el caso
    (a) de PARCHE D (5 pacientes con ejemplos concretos línea por línea,
    todos confirmados como pertenecientes a OTRA estancia ya cerrada) — el
    número exacto "-743" quedó superado por los cambios de PARCHE E y no se
    persigue de nuevo.
  - Espejo `consola/4_06_FASE2_SIGESAPOL_procedimientos.sql` regenerado
    (copia exacta, diff 0).

---

## 4. REGLA DE ENTRADA DE NÚMEROS A INFORMES

Ningún número entra a un informe (`INFORME_CIERRE_SEMESTRE.md` u otro) si no
cuadra contra la sección 2 de este documento, o si no trae su propia
reconciliación explícita documentada (query de origen + diff antes/después).
