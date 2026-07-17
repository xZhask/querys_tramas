# Informe de Cierre de Semestre: Armonización, Deduplicación y Reclasificación de Tramas LNS (Julio - Diciembre 2025)

> [!IMPORTANT]
> **Nota de alcance (reemisión 2026-07-17)**: este informe cubre
> **exclusivamente el Hospital Nacional PNP Luis N. Sáenz (HN PNP LNS,
> nivel III, `codigo_ipress` 00013591)**. Las demás IPRESS de la red PNP
> (Legía, Arequipa, Chiclayo, San José y ~30 más) las trabaja otro equipo con
> otra base — quedaron fuera de todos los números de esta reemisión. La
> versión anterior de este informe incluía datos de toda la red porque
> ninguna extracción filtraba por establecimiento (o filtraba por la
> *historia* del paciente en vez de por la *sede de la prestación*, en el
> caso de procedimientos SIGESAPOL). Ver `CONTEXTO_CANONICO.md` §1.9 y §3
> (entrada 2026-07-17) para el detalle completo del cambio.

## 1. Resumen Ejecutivo

Este informe consolida los resultados técnicos, operativos y económicos del procesamiento, depuración y reclasificación de las tramas médicas de Consulta Externa, Emergencia, Hospitalización y Farmacia del Hospital LNS para el periodo de **julio a diciembre de 2025**.

La implementación del nuevo pipeline automatizado ha permitido integrar de manera hermética las bases de datos de **CPT (Sistema local de facturación)** y **SIGESAPOL (Sistema institucional en adopción y fuente canónica)**. Se resolvieron de forma definitiva las inconsistencias de CPMS de alta en emergencias y se aplicó la regla de permanencia mayor a 24 horas.

### Hitos Clave del Semestre (alcance LNS):
* **Monto Total Recuperado por Regla de 24 Horas**: Se capturó una facturación adicional y defendible de **S/. 4,873,686.93** mediante la reclasificación de estancias de emergencia de más de 24 horas a hospitalización especializada y la unificación de estancias solapadas (Caso A). La versión anterior de este informe (multi-IPRESS) reportaba S/. 6,879,013.18 — la sección 4 explica la reconciliación y la magnitud del cambio por alcance.
* **Ahorro Financiero por Deduplicación**: Se previno un doble cobro potencial de **S/. 490,401.29** al eliminar automáticamente duplicidades de prestaciones idénticas registradas en CPT y SIGESAPOL (prácticamente sin cambio frente al multi-IPRESS: S/. 491,713.41 — la fuente CPT de estos duplicados ya era LNS-only por diseño).
* **Conciliación de Atenciones Tipo 2 (Emergencia)**: Se conciliaron **29,000** atenciones de emergencia facturadas bajo la trama Tipo 2, acumulando un monto valorizado de **S/. 1,009,347.62** sustentado mediante CONTROL 15 (multi-IPRESS: 47,816 / S/. 1,585,426.27).
* **Volumen Total Procesado**: Se depuraron y generaron entregables finales con **1,233,686 registros** en Consulta Externa, **138,306** en Emergencia, **343,029** en Hospitalización y **647,774** dispensaciones de Farmacia (Farmacia sin cambio: ya filtraba por establecimiento).
* **Hermeticidad y Consistencia**: El 100% de los lotes cerró con **cero registros con doble cobro** entre la trama de emergencia y la trama de hospitalización (CONTROL 10 = 0) y las **4** aserciones de calidad (A1/A2/A3/A4 — A4 es la nueva aserción de pureza de alcance) en verde para los 6 meses.
* **Alcance depurado en la extracción**: se removieron 608,580 filas en SIGESAPOL (emergencias, hospitalización y, sobre todo, procedimientos por el fix historia-vs-prestación) y 542 filas / S/. 9,757.61 en CPT (laboratorio, único punto donde las funciones CPT originales sí mezclan establecimientos) — detalle por mes/tabla en la sección 4bis.

---

## 2. Impacto de Deduplicación: Evolución Mensual del Doble Cobro Evitado

La deduplicación automática de prestaciones detecta registros idénticos ingresados en ambas plataformas. Para los meses de julio a septiembre, la fuente canónica fue CPT (complementando con prestaciones únicas de SIGESAPOL). A partir de octubre, debido a la migración institucional del hospital, la regla canónica cambió a SIGESAPOL (complementando con CPT).

A continuación se detalla la evolución del cobro evitado:

| Periodo de Producción | Fuente Canónica | Duplicados Ciertos | Monto de Facturación Evitado (Soles) |
| :--- | :---: | :---: | :---: |
| **Julio 2025** | CPT | 2,819 | S/. 157,952.25 |
| **Agosto 2025** | CPT | 2,649 | S/. 145,873.60 |
| **Setiembre 2025** | CPT | 1,901 | S/. 120,034.31 |
| **Octubre 2025** | SIGESAPOL | 305 | S/. 12,286.28 |
| **Noviembre 2025** | SIGESAPOL | 383 | S/. 19,469.54 |
| **Diciembre 2025** | SIGESAPOL | 1,704 | S/. 34,785.31 |
| **TOTAL SEMESTRAL** | — | **9,761** | **S/. 490,401.29** |

> [!NOTE]
> **Alcance LNS (2026-07-17)**: cifras casi idénticas a la versión
> multi-IPRESS anterior (9,796 / S/. 491,713.41) porque `prestacion_cpt`
> (la tabla CPT de la que sale la mitad "cierta" de cada duplicado) no tiene
> columna de establecimiento — ya era, por diseño, exclusivamente de LNS.

---

## 3. Consolidación de Volúmenes de Tramas Semestrales (Líneas de Archivo)

Los archivos txt de tramas finales exportados a la carpeta `tramas_exportadas/` contienen el volumen total unificado por mes tras aplicar las reglas de reclasificación de 24 horas:

| Mes / Período | Consulta Externa | Emergencia | Hospitalización | Farmacia | Total Mes |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 222,089 | 25,642 | 73,407 | 105,694 | **426,832** |
| **Agosto 2025** | 220,648 | 24,059 | 61,464 | 103,258 | **409,429** |
| **Setiembre 2025** | 230,830 | 24,048 | 59,902 | 118,417 | **433,197** |
| **Octubre 2025** | 210,672 | 21,060 | 55,895 | 118,984 | **406,611** |
| **Noviembre 2025** | 181,432 | 22,646 | 48,972 | 102,455 | **355,505** |
| **Diciembre 2025** | 168,015 | 20,851 | 43,389 | 98,966 | **331,221** |
| **TOTAL TRAMA** | **1,233,686** | **138,306** | **343,029** | **647,774** | **2,362,795** |

> [!NOTE]
> **Nota de Consistencia en Hospitalización**:
> La integración del Caso A (unión de estancias sin umbral) ha estabilizado el volumen total de líneas de Hospitalización en valores estables, al absorber de manera coherente las estancias solapadas de emergencia dentro del flujo de hospitalización.
>
> **Nota de alcance (2026-07-17)**: estos volúmenes reemplazan a los de la
> versión multi-IPRESS anterior (Total: 2,956,003), que incluía toda la red
> PNP. La reducción por categoría es muy dispareja: Farmacia **0%** (ya
> filtraba por establecimiento), Hospitalización **-2.97%** (343,029 vs
> 353,525 — LNS ya concentraba la gran mayoría de las hospitalizaciones de
> la red), Consulta Externa **-30.55%** (1,233,686 vs 1,776,481) y
> Emergencia **-22.36%** (138,306 vs 178,223). Total semestral: **-20.1%**.

---

## 4. Recuperación Adicional por Regla de 24 Horas y Reclasificación

Siguiendo la directiva institucional, las emergencias con una duración real superior a 24 horas son reclasificadas a Hospitalización (Tipo 3). Aquellas que se solapan o tocan con una hospitalización existente se unifican en un rango único (Caso A), **sin umbral de horas** — el criterio de unión es continuidad física de la estancia, no duración. Las que no registran hospitalización previa y superan las 24 horas reales se convierten en nuevas estancias hospitalarias con código CPMS `99231.15` (Caso B).

Por otro lado, las emergencias con duración real menor o igual a 24 horas (y que no se solapan con ninguna hospitalización) permanecen como Tipo 2 en la trama de emergencias, forzando su CPMS al código canonical de consulta según su prioridad médica (99281-99285). Las estancias mayores a 15 días acumulados que cruzan de mes son catalogadas como Cierre Administrativo para depuración y no se facturan.

**Reconciliación de este cierre**: la tabla del cierre anterior sumaba más que el total de emergencias porque la columna "Excluidas por Solapamiento" duplicaba población ya contada dentro de "Caso A Unidas" (ambas contaban, con criterios ligeramente distintos, emergencias que se solapan con una hospitalización). Se eliminó esa columna y se verificó la partición con una query independiente (`CONTROL 13` en `04_CONTROL_integridad.sql`) que deriva cada categoría por separado — ninguna como resto de las demás — y confirma **residuo 0** en los 6 meses:

| Período | Emergencias Totales | Tipo 2 Facturadas | Caso B Reclass (Nueva Hosp) | Caso A Unidas (Overlap Hosp) | Cierre Admin (Excluidas) | Residuo | Facturación Recuperada Neto (S/.) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 5,683 | 5,006 | 219 | 379 | 79 | 0 | S/. 513,587.46 |
| **Agosto 2025** | 5,456 | 4,882 | 204 | 356 | 14 | 0 | S/. 591,592.00 |
| **Setiembre 2025** | 5,699 | 5,150 | 178 | 358 | 13 | 0 | S/. 485,178.63 |
| **Octubre 2025** | 5,735 | 4,672 | 335 | 392 | 336 | 0 | S/. 1,357,609.24 |
| **Noviembre 2025** | 5,755 | 4,826 | 264 | 368 | 297 | 0 | S/. 945,448.10 |
| **Diciembre 2025** | 5,175 | 4,464 | 236 | 421 | 54 | 0 | S/. 980,271.49 |
| **TOTAL** | **33,503** | **29,000** | **1,436** | **2,274** | **793** | **0** | **S/. 4,873,686.93** |

> [!NOTE]
> **Alcance LNS (2026-07-17)**: tabla recalculada íntegramente tras aplicar
> el filtro de alcance (`cfg_ipress_alcance`, ver `CONTEXTO_CANONICO.md`
> §1.9). Reemplaza la versión multi-IPRESS anterior (Total: 53,708
> emergencias / 47,816 Tipo 2 / 2,298 Caso B / 2,797 Caso A / 797 Cierre
> Admin / S/. 6,879,013.18) — misma metodología de `CONTROL 13`/`CONTROL 14`,
> misma partición con residuo 0 en los 6 meses, solo cambia el universo de
> origen.

> [!NOTE]
> **Metodología de "Facturación Recuperada Neto"**: se calcula como el diff antes/después de valorización por trama (`CONTROL 14`), no como una suma de tarifas nominales. Del lado hospitalización, se toma un snapshot de la valorización de cada estancia **antes** de aplicar la unión Caso A o insertar Caso B (capturado al inicio de `12_RECLASIFICAR_emergencias_24h.sql`, antes de mutar nada); así una estancia Caso A aporta solo su incremento real (la extensión de días), no el valor completo de la estancia original otra vez. Del lado emergencia, "antes" valoriza cada atención como si fuera Tipo 2 (tarifa por prioridad), y "después" solo las que sobreviven como Tipo 2. Los procedimientos/laboratorio que se mueven de trama conservan su propia valorización de origen y no aportan al neto.
>
> **Reconciliación contra cifras previas**: el semestre anterior reportaba S/. 4,711,557.11 (indeterminado qué query lo producía — no se encontró en el repositorio). La cifra ancla de julio en `CONTEXTO_CANONICO.md` (S/. 1,109,812.71) provenía de un checkpoint anterior (`expedientes/correccion_cpms/diff_tramas.md`) que tenía el mismo problema de medición que se acaba de corregir aquí: contaba el valor **completo** de una estancia Caso A como recuperación, en vez de solo el incremento. Con la metodología corregida, julio da S/. 562,337.47 — la diferencia frente a las cifras previas se explica por (a) el fix de medición de Caso A (evita contar dos veces el valor de la estancia original) y (b) la corrección de conteo de Caso A (2,797 casos reales vs. 2,567 en el cierre anterior, ver tabla arriba). No se encontró ningún artefacto en el repositorio que reproduzca el S/. 4,711,557.11 ni el S/. 8.42M mencionado en checkpoints previos; ambos quedan sin poder reconciliarse por falta de query de origen y se reemplazan por la cifra verificada de este cierre.
>
> Se descartó la sospecha de que el S/. 4,711,557.11 proviniera del antiguo grupo `PERMANENCIA_EN_EMERGENCIA` (clasificación provisional de una iteración anterior, con "EN", distinta de `PERMANENCIA_EMERGENCIA_24H` que usa el pipeline actual): ningún total en esa fuente reproduce la cifra.

> [!IMPORTANT]
> **Nota de Validación Médica**:
> Toda facturación reclasificada a hospitalización por permanencia en emergencias superior a 24 horas (Caso B) y toda unión de estancias (Caso A) se encuentra **sujeta a validación final y auditoría por parte de la Unidad de Auditoría Médica** — las uniones Caso A son *propuestas* en el libro de auditoría (fila RETENIDA, ver sección 6), no facturación aplicada. Los auditores médicos deberán refrendar las historias clínicas asociadas para confirmar la justificación de la estancia prolongada antes de la presentación formal del expediente de cobro a SALUDPOL.

---

## 4bis. Constancia de Depuración por Alcance (filas removidas por IPRESS fuera de LNS)

Registrado automáticamente en la tabla `log_alcance_depurado` (ambas BD) por
cada script de extracción, ANTES de aplicar su filtro de alcance — es la
constancia de qué se depuró y de dónde, para sustento ante auditoría interna.

**SIGESAPOL (filas de origen removidas antes de materializar), por mes:**

| Período | Emergencias | Hospitalización | Procedimientos | Total SIGESAPOL |
| :--- | :---: | :---: | :---: | :---: |
| **Julio 2025** | 2,901 | 0 | 43,909 | **46,810** |
| **Agosto 2025** | 2,945 | 167 | 47,655 | **50,767** |
| **Setiembre 2025** | 3,071 | 248 | 68,135 | **71,454** |
| **Octubre 2025** | 3,063 | 222 | 147,603 | **150,888** |
| **Noviembre 2025** | 4,267 | 196 | 146,037 | **150,500** |
| **Diciembre 2025** | 4,155 | 285 | 133,721 | **138,161** |
| **TOTAL SEMESTRE** | **20,402** | **1,118** | **587,060** | **608,580** |

**CPT (filas ya materializadas, removidas de las 3 tablas de laboratorio — el
único punto donde las funciones CPT originales mezclan establecimientos),
por mes:**

| Período | Filas removidas | Monto removido (S/.) |
| :--- | :---: | :---: |
| **Julio 2025** | 105 | 1,861.89 |
| **Agosto 2025** | 125 | 2,317.04 |
| **Setiembre 2025** | 74 | 1,424.63 |
| **Octubre 2025** | 111 | 1,824.15 |
| **Noviembre 2025** | 86 | 1,636.80 |
| **Diciembre 2025** | 41 | 693.11 |
| **TOTAL SEMESTRE** | **542** | **9,757.61** |

> [!NOTE]
> El desglose por establecimiento (Legía, Arequipa, Chiclayo, San José, y
> ~30 IPRESS menores en el caso de procedimientos SIGESAPOL) está disponible
> por consulta directa a `log_alcance_depurado` en cada base — no se incluye
> aquí por volumen (temp_sigesapol_procedimientos tiene entradas para 34
> IPRESS distintas solo en julio). El grueso de la depuración SIGESAPOL
> (587,060 de 608,580 filas, 96.5%) es procedimientos, y de ese grupo la
> mayoría es el fix historia-vs-prestación descrito en `CONTEXTO_CANONICO.md`
> §1.9: prestaciones cuya historia clínica pertenece a LNS pero que
> físicamente ocurrieron en otro establecimiento. El salto de julio-septiembre
> (~44k-68k/mes) a octubre-diciembre (~134k-148k/mes) coincide con el cambio
> de fuente canónica a SIGESAPOL (regla inmutable §1.1): a partir de octubre
> SIGESAPOL concentra más volumen total, y por tanto también más volumen a
> depurar de otras IPRESS.

---

## 5. Observaciones de Auditoría por Categoría y Mes

Además del descarte automático, el pipeline extrajo alertas de auditoría médica para revisión manual en la carpeta `expedientes/` para sustento ante auditorías externas de SALUDPOL:

* **Médico Distinto (Revisar)**: Prestaciones coincidentes en Paciente-Fecha-Procedimiento pero con firmas de médicos tratantes diferentes entre sistemas (indica posibles dobles registros legítimos o errores de digitación).
* **Cantidad Distinta (Revisar)**: Prestaciones de laboratorio o imágenes donde la cantidad facturada difiere entre CPT y SIGESAPOL.
* **Transiciones Emergencia→Hospitalización (CONTROL 5)**: Casos de solapamiento/contigüidad entre una atención de emergencia y una hospitalización del mismo paciente, para revisión de auditoría de la transición E→H.
* **Estancias Contiguas/Solapadas en CPT (CONTROL 9)**: Hospitalizaciones contiguas o solapadas del MISMO paciente dentro de CPT (no E→H), clasificadas para revisión de traslado doble de cama en auditoría.
* **Duplicados en Origen**: Prestaciones registradas dos veces dentro del propio sistema de origen SIGESAPOL.
* **Estancias de emergencia sin CPMS en origen (informativo)**: Egresos de emergencia registrados originalmente sin un código CPMS de alta médica, para los cuales el pipeline asignó el código correspondiente de consulta por prioridad (99281-99285) de forma automatizada (ya no representa un riesgo de derivación en la trama).
* **CPMS Derivado Hospitalización**: Estancias hospitalarias que no contaban con código CPMS de egreso en el origen y que el algoritmo imputó automáticamente a través de fallbacks regulatorios según la clase de cama asignada.

| Categoría de Observación | Julio | Agosto | Setiembre | Octubre | Noviembre | Diciembre | TOTAL |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Médico Distinto (Revisar)** ⁽¹⁾ | 384 | 297 | 371 | 271 | 296 | 283 | **1,902** |
| **Cantidad Distinta (Revisar)** ⁽¹⁾ | 277 | 209 | 148 | 0 | 0 | 2 | **636** |
| **Transiciones Emergencia→Hospitalización (CONTROL 5)** | 673 | 643 | 609 | 819 | 717 | 729 | **4,190** |
| **Estancias Contiguas/Solapadas en CPT (CONTROL 9)** | 39 | 37 | 39 | 6 | 8 | 15 | **144** |
| **Duplicados en Origen** ⁽²⁾ | 1,774 | 1,580 | 1,772 | 1,081 | 994 | 1,164 | **8,365** |
| **Estancias de emergencia sin CPMS en origen (informativo)** ⁽¹⁾ | 1,812 | 1,830 | 2,039 | 1,841 | 1,621 | 1,538 | **10,681** |
| **CPMS Derivado Hospitalización** ⁽¹⁾ | 861 | 1,002 | 1,095 | 1,286 | 1,257 | 1,376 | **6,877** |

> [!NOTE]
> **Alcance LNS (2026-07-17)** — filas recalculadas bajo el nuevo alcance:
> Transiciones E→H (CONTROL 5), Estancias Contiguas CPT (CONTROL 9) y
> Duplicados en Origen (fuente: `metricas.json.observaciones` de cada mes).
> ⁽¹⁾ Las filas marcadas **no se recalcularon en esta reemisión** — se
> mantienen los valores multi-IPRESS del cierre anterior porque no tienen
> una query de origen persistida en este repositorio para re-derivarlas mes
> a mes con el filtro de alcance; requieren una pasada aparte antes de
> usarse en una auditoría. ⁽²⁾ El conteo de "Duplicados en Origen" de este
> cierre (8,365) usa el campo `duplicados_origen` de `metricas.json`
> (post-fix del 2026-07-16, ver `CONTEXTO_CANONICO.md` §3) — es una fuente
> distinta y mayor a la del cierre anterior (2,309), no solo un efecto del
> alcance; ver sección 8, punto 5 de este mismo informe para el detalle de
> esa reconciliación.
>
> **Corrección heredada del cierre anterior**: la fila que antes se llamaba
> "Estancias Contiguas/Solapadas (C11)" y se describía como CONTROL 9 en
> realidad traía los conteos de CONTROL 5. Esta versión ya trae ambas filas
> separadas y correctamente etiquetadas.

---

## 6. Contrato de Salidas v2: Filas RETENIDA y Verificación de Aserciones

A partir de este cierre, los 6 períodos se entregan bajo la nueva estructura de
expediente `01_TRAMAS/ 02_AUDITORIA_<mes>.xlsx / 03_INFORMATIVOS/` por mes. Antes
de dar un mes por cerrado, el pipeline exige que se cumplan automáticamente 3
aserciones de calidad; si alguna falla, el proceso se detiene y no se libera el
expediente de ese mes:

* **A1 — Conservación**: `LIMPIA + RETENIDA + INFORMATIVA = total extraído del
  período`, sin residuo, calculado por separado para consulta externa,
  emergencia, hospitalización y farmacia (tabla `conservacion` en
  `metricas.json` de cada mes).
* **A2 — Paquete completo**: cero procedimientos/laboratorio de una estancia
  RETENIDA por solapamiento Emergencia→Hospitalización (Caso A) quedan huérfanos
  fuera de su trama de destino.
* **A3 — Ciclo**: correr `13_REINCORPORAR_decisiones.py` con el libro de
  decisiones vacío (todo pendiente) no modifica ningún archivo de
  `01_TRAMAS/` (idempotencia), y el CONTROL 10 (no doble reporte
  Emergencia/Hospitalización) se mantiene en cero.

**Filas RETENIDA por mes.** Conforme al contrato v2, RETENIDA agrupa dos
poblaciones distintas, ambas **propuestas en el libro de auditoría — no
facturación aplicada** — hasta que la Unidad de Auditoría Médica decida
PROCEDE / NO PROCEDE (duplicados) o SE UNE / NO SE UNE (Caso A) en el Excel
de auditoría:
1. **Pares Estancia E→H (Caso A)**: la unión propuesta de una emergencia con
   una hospitalización solapada — la mayoría de RETENIDA.
2. **Duplicados ciertos entre fuentes residuales**: prestaciones que
   coinciden exactamente en la llave de su tipo (médico para Tipo 1, cantidad
   para Tipo 2/3) entre CPT y SIGESAPOL y que no fueron ya resueltas por la
   deduplicación SQL previa (pasos 07/08) — en este cierre, 0 en los 6 meses,
   lo que confirma que esa deduplicación SQL ya captura la práctica totalidad
   de los duplicados ciertos antes de llegar a esta capa.

| Período | Pares Caso A | Duplicados Ciertos Residuales | Filas RETENIDA (hospitalización) | A1 | A2 | A3 (ciclo) | A3 (CONTROL 10) | A4 (alcance) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 620 | 0 | 637 | OK | OK | OK | OK | OK |
| **Agosto 2025** | 594 | 0 | 608 | OK | OK | OK | OK | OK |
| **Setiembre 2025** | 557 | 0 | 558 | OK | OK | OK | OK | OK |
| **Octubre 2025** | 753 | 0 | 783 | OK | OK | OK | OK | OK |
| **Noviembre 2025** | 658 | 0 | 660 | OK | OK | OK | OK | OK |
| **Diciembre 2025** | 682 | 0 | 682 | OK | OK | OK | OK | OK |
| **TOTAL** | **3,864** | **0** | **3,928** | | | | | |

> [!NOTE]
> **Dos correcciones de este cierre**: (1) **Alcance LNS** — tabla
> recalculada bajo el nuevo alcance (reemplaza el total multi-IPRESS de
> 5,431 pares Caso A). (2) **Fix del contador RETENIDA** (regla 8 del
> ancla) — "Pares Caso A" ahora es el conteo real de estancias unidas
> (`eh_groups` en `generate_outputs_v2.py`, la misma población que queda en
> la hoja `ESTANCIAS_E_H` del libro de auditoría), y "Filas RETENIDA" le
> suma el paquete de procedimientos/laboratorio que se mueve junto con cada
> par (637−620=17 en julio, por ejemplo). Antes del fix, ese paquete se
> contaba como LIMPIA en `metricas.json` (facturación aplicada) en vez de
> RETENIDA (propuesta pendiente de Auditoría Médica) — ver
> `CONTEXTO_CANONICO.md` §3, entrada 2026-07-17. La cifra vieja de "Pares
> Caso A" (667 en julio, 5,431 el semestre) venía de una query de
> emparejamiento distinta que mezclaba los pares reales con coincidencias
> del propio Caso B recién insertado (ver reconciliación abajo) — la nueva
> cifra usa directamente la población que el pipeline ya identifica como
> Caso A internamente, sin ese ruido.

> [!NOTE]
> **Metodología anterior (superada en este cierre)**: hasta el cierre
> pasado, "Pares Caso A" se contaba con una query de emparejamiento aparte
> (JOIN directo `temp_emergencia_sigesapol_estancia` × `temp_hospitalizacion_local`
> por documento y solapamiento de fechas) que, corrida *después* de insertar
> las hospitalizaciones nuevas del Caso B, mezclaba tres poblaciones
> distintas — para julio (multi-IPRESS): 386 verdaderos Caso A + 248
> coincidencias del propio Caso B recién insertado + 33 solapamientos
> duplicados/contiguos = 667. Esta versión usa en su lugar el conteo interno
> real de `generate_outputs_v2.py` (`eh_groups`), que ya excluye ese ruido
> por construcción — ver la nota de arriba para el detalle y las cifras
> LNS-only vigentes.

---

## 7. Incidencias Técnicas Resueltas durante el Proceso

Durante la corrida del lote semestral, se identificaron y resolvieron las siguientes incidencias técnicas:

1. **Aceleración por Índices Compuestos**:
   La consolidación de tablas demoraba más de 19 minutos por mes. Se automatizó la creación de índices compuestos por la llave (`numero_documento_paciente, fecha_atencion, codigo_procedimiento`), reduciendo el tiempo de proceso a **3.5 segundos por mes**.
2. **Error Sintáctico por BOM y codificaciones ANSI**:
   Los scripts psql fallaban debido a cabeceras UTF-8 BOM invisibles generadas por redirecciones PowerShell y lecturas ANSI de caracteres acentuados. Se implementó una rutina de lectura UTF-8 explícita a través de la API de .NET (`[System.IO.File]::ReadAllText`), garantizando la correcta codificación de acentos y caracteres especiales.
3. **Mapeo de la Estructura de Camas en Hospitalización**:
   Se corrigió la búsqueda de la columna de clasificación en la base de datos de origen, permitiendo la valorización correcta del 100% de las estancias hospitalarias de SIGESAPOL.
4. **Control de Cruce de Medianoche (V1)**:
   Se detectó que el cálculo por días calendario consideraba incorrectamente como reclass a hospitalización las estancias breves que ingresaban un día y salían al día siguiente (duración <= 24h). Se modificó la regla a duración por intervalo real (`sp_fecha_alta_emergencia - sp_fecha_atencion > INTERVAL '24 hours'`), salvando **1,433 registros** de emergencias breves en Julio de ser catalogados erróneamente.
5. **Corrupción de Texto por Caracteres de Control Embebidos (v2)**:
   Al implementar la verificación A3 (ciclo), se detectó que algunos campos de texto libre (p. ej. descripciones de diagnóstico) traen caracteres de control `\r` embebidos desde origen. Los escritores de trama (`generate_outputs_v2.py`, `13_REINCORPORAR_decisiones.py`) abrían los archivos en modo texto sin `newline=''`, por lo que cada reescritura traducía esos caracteres embebidos y los iba corrompiendo acumulativamente. Se corrigió la lectura (separando registros por el delimitador literal `|<salto de línea>` en vez de iterar línea a línea) y la escritura (`newline=''`) en ambos scripts, y se ajustó `13_REINCORPORAR_decisiones.py` para no reordenar filas cuando no hay ninguna consolidación real que aplicar. Esto fue lo que permitió que la aserción A3 cierre en OK de forma consistente para los 6 meses.
6. **Llave de Deduplicación Incompleta en `generate_outputs_v2.py`**:
   La función que clasifica duplicados entre CPT y SIGESAPOL agrupaba solo por paciente+fecha+código, sin el discriminador por tipo (médico para Tipo 1, cantidad para Tipo 2/3) que exige la regla de negocio. Esto generaba falsos positivos de "duplicado entre fuentes" (registros legítimamente distintos, marcados para descarte) e inflaba el conteo informativo de "duplicados de origen". Se corrigió agregando el discriminador a la llave; los duplicados ciertos entre fuentes residuales (los que no captura ya la deduplicación SQL previa) bajaron correctamente a 0 en los 6 meses.
7. **Partición de la Sección 4 con Doble Conteo**:
   La columna "Excluidas por Solapamiento" del cierre anterior contaba, con un criterio ligeramente distinto, población que ya estaba dentro de "Caso A Unidas", por lo que la suma de categorías excedía el total de emergencias del mes. Se agregó `CONTROL 13` (`04_CONTROL_integridad.sql`), que deriva Tipo2/Caso A/Caso B/Cierre Admin de forma independiente entre sí y verifica residuo 0; se eliminó la columna redundante.
8. **Medición de "Recuperación Neta" sin Snapshot Previo**:
   El primer intento de recalcular la recuperación neta por diffs antes/después contaba el valor **completo** de una estancia Caso A como ganancia, en vez de solo el incremento de días que aporta la unión — sobrestimando el neto recuperado (y replicando un problema que ya tenía el checkpoint histórico usado como ancla, `diff_tramas.md`). Se corrigió capturando un snapshot de la valorización de cada estancia hospitalaria al inicio de `12_RECLASIFICAR_emergencias_24h.sql`, antes de que Caso A/B mute cualquier fila (`CONTROL 14`).
9. **Mislabel de CONTROL 9 en el Informe**:
   La fila "Estancias Contiguas/Solapadas (C11)" de la sección 5 traía en realidad los conteos de CONTROL 5 (transiciones E→H), no de CONTROL 9 (hospitalizaciones contiguas/solapadas dentro de CPT, una población mucho menor). Se corrigió la etiqueta y se agregó CONTROL 9 como fila aparte con su valor real.
10. **Alcance nivel III no aplicado (2026-07-17)**:
    Ninguna extracción filtraba por establecimiento — CPT y SIGESAPOL son
    sistemas de toda la red PNP, no solo de LNS. En emergencias y
    hospitalización SIGESAPOL no había filtro alguno; en procedimientos
    SIGESAPOL el filtro existente usaba la *historia* del paciente
    (`asegurado_historias.id_establecimiento`) en vez de la *sede de la
    prestación* (`prestaciones.id_establecimiento`), dejando pasar 587,060
    prestaciones del semestre de pacientes con historia en LNS pero
    atendidos en otro establecimiento. Se agregó `cfg_ipress_alcance`
    (dato, no literal) a ambos instaladores, el filtro correspondiente a
    cada extracción, la tabla `log_alcance_depurado` como constancia (ver
    sección 4bis), y la aserción **A4** que verifica que ninguna trama
    exportada contenga otro `codigo_ipress`. Detalle completo en
    `CONTEXTO_CANONICO.md` §1.9 y §3.
11. **Saneo Incompleto de Caracteres de Control en la Exportación (2026-07-17)**:
    La incidencia #5 (arriba) corrigió la lectura/escritura de los archivos
    de trama, pero no eliminaba los propios caracteres `\r`/`\n` embebidos
    en un valor de campo — esos caracteres seguían literalmente dentro del
    `.txt` y partían una fila lógica en dos líneas físicas (62 registros de
    Consulta Externa en agosto, detectados por `wc -l` ≠ filas lógicas). Se
    corrigió `format_trama_val()` en `generate_outputs_v2.py` para
    reemplazarlos por espacio antes de escribir. Verificado: `wc -l` de las
    4 tramas coincide exactamente con `volumenes_tramas` de `metricas.json`
    en los 6 meses.
12. **Contador RETENIDA no incluía los Pares Caso A (2026-07-17)**:
    En la tabla `conservacion` de `metricas.json`, los pares Caso A
    (estancias unidas y su paquete de procedimientos/laboratorio) se
    contaban como LIMPIA en vez de RETENIDA, contradiciendo la regla 8 del
    ancla ("no son facturación aplicada"). Se corrigió sumándolos a
    `retenida_por_tipo['hospitalizacion']` y restando `retenida` (además de
    `informativa`) al calcular `limpia`. El residuo de la aserción A1 sigue
    en 0 en los 6 meses — es un fix de clasificación, no de conservación.
    Ver sección 6 para las cifras corregidas.

---

## 8. Pendientes Institucionales y Recomendaciones para la Jefatura

1. **Corte Definitivo entre Sistemas (Apagar CPT)**:
   Los datos demuestran que a partir de octubre de 2025, el volumen de prestaciones y estancias de hospitalización de LNS ya se registra mayoritariamente de forma nativa en SIGESAPOL (ver caída de volumen CPT en la sección 3, octubre en adelante). Se recomienda establecer una fecha de corte definitivo para apagar el ingreso de datos en CPT, reduciendo a cero el costo operativo de consolidar bases de datos.
2. **Capacitación para el llenado de cpms_alta en origen**:
   Se detectó que **10,681 egresos de emergencia** y **6,877 de hospitalización** se grabaron originalmente sin código de alta CPMS. *Nota de alcance*: estas dos cifras son de la versión multi-IPRESS anterior y no se recalcularon bajo el alcance LNS en esta reemisión (ver sección 5) — la recomendación de capacitación se mantiene, pero la cifra exacta de LNS debe re-verificarse antes de usarse en un reporte oficial. Se sugiere capacitar al personal médico para el llenado obligatorio de la codificación al momento del alta para evitar el uso de fallbacks lógicos automatizados.
3. **Actualización de Tarifario (Tarifas en Cero)**:
   Se identificaron procedimientos que se valorizan con importe "cero" debido a la falta de concordancia entre los códigos del petitorio LNS y los códigos estandarizados CPMS. Es urgente actualizar la tabla de equivalencias de precios de la IPRESS para evitar pérdidas financieras.
4. **Alerta Automática a las 20 horas de Estancia en Emergencia**:
   Se recomienda implementar una alerta automática en el sistema SIGESAPOL cuando un paciente cumpla **20 horas continuas de permanencia en Emergencia**. Esto servirá de aviso temprano al personal médico y administrativo para gestionar el traslado físico y formal del paciente a Hospitalización o su alta oportuna, evitando las reclasificaciones tardías. Los **1,436 casos del semestre** (alcance LNS; 2,298 en la versión multi-IPRESS anterior) que terminaron convirtiéndose en hospitalizaciones de facto (Caso B) sustentan la necesidad crítica de esta alerta como instrumento de control y reducción de glosas.
5. **Conteo de "Duplicados de Origen" en `generate_outputs_v2.py` — resuelto**:
   La incidencia técnica #6 (llave de deduplicación sin discriminador por tipo) había dejado el conteo informativo de "duplicados de origen" en un rango implausible (17,000-53,000 por mes). El fix del 2026-07-16 (incorporar el ID único del registro a la llave de agrupación, ver `CONTEXTO_CANONICO.md` §3) lo resolvió: bajo el alcance LNS de este cierre, el campo `duplicados_origen` de `metricas.json` da 994-1,774 por mes (sección 5, fila "Duplicados en Origen") — un rango plausible, mayor al de la versión multi-IPRESS anterior (149-582) porque usa una fuente de conteo distinta (y más completa) desde el fix, no solo un efecto del alcance. No afecta la facturación de las tramas ni las secciones 4 ni 6 de este informe.
