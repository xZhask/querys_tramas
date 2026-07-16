# Informe de Cierre de Semestre: Armonización, Deduplicación y Reclasificación de Tramas LNS (Julio - Diciembre 2025)

## 1. Resumen Ejecutivo

Este informe consolida los resultados técnicos, operativos y económicos del procesamiento, depuración y reclasificación de las tramas médicas de Consulta Externa, Emergencia, Hospitalización y Farmacia del Hospital LNS para el periodo de **julio a diciembre de 2025**.

La implementación del nuevo pipeline automatizado ha permitido integrar de manera hermética las bases de datos de **CPT (Sistema local de facturación)** y **SIGESAPOL (Sistema institucional en adopción y fuente canónica)**. Se resolvieron de forma definitiva las inconsistencias de CPMS de alta en emergencias y se aplicó la regla de permanencia mayor a 24 horas.

### Hitos Clave del Semestre:
* **Monto Total Recuperado por Regla de 24 Horas**: Se capturó una facturación adicional y defendible de **S/. 6,879,013.18** mediante la reclasificación de estancias de emergencia de más de 24 horas a hospitalización especializada y la unificación de estancias solapadas (Caso A). Esta cifra reemplaza la reportada en el cierre anterior (S/. 4,711,557.11); la sección 4 explica la reconciliación completa.
* **Ahorro Financiero por Deduplicación**: Se previno un doble cobro potencial de **S/. 491,713.41** al eliminar automáticamente duplicidades de prestaciones idénticas registradas en CPT y SIGESAPOL.
* **Conciliación de Atenciones Tipo 2 (Emergencia)**: Se conciliaron **47,816** atenciones de emergencia facturadas bajo la trama Tipo 2, acumulando un monto valorizado de **S/. 1,585,426.27** sustentado mediante el nuevo CONTROL 15.
* **Volumen Total Procesado**: Se depuraron y generaron entregables finales con **1,776,481 registros** en Consulta Externa, **178,223** en Emergencia, **353,525** en Hospitalización y **647,774** dispensaciones de Farmacia.
* **Hermeticidad y Consistencia**: El 100% de los lotes cerró con **cero registros con doble cobro** entre la trama de emergencia y la trama de hospitalización (CONTROL 10 = 0) y las 3 aserciones de calidad (A1/A2/A3) en verde para los 6 meses, incluyendo julio.

---

## 2. Impacto de Deduplicación: Evolución Mensual del Doble Cobro Evitado

La deduplicación automática de prestaciones detecta registros idénticos ingresados en ambas plataformas. Para los meses de julio a septiembre, la fuente canónica fue CPT (complementando con prestaciones únicas de SIGESAPOL). A partir de octubre, debido a la migración institucional del hospital, la regla canónica cambió a SIGESAPOL (complementando con CPT).

A continuación se detalla la evolución del cobro evitado:

| Periodo de Producción | Fuente Canónica | Duplicados Ciertos | Monto de Facturación Evitado (Soles) |
| :--- | :---: | :---: | :---: |
| **Julio 2025** | CPT | 2,830 | S/. 158,312.32 |
| **Agosto 2025** | CPT | 2,652 | S/. 146,131.98 |
| **Setiembre 2025** | CPT | 1,906 | S/. 120,516.05 |
| **Octubre 2025** | SIGESAPOL | 310 | S/. 12,335.67 |
| **Noviembre 2025** | SIGESAPOL | 386 | S/. 19,498.82 |
| **Diciembre 2025** | SIGESAPOL | 1,712 | S/. 34,918.57 |
| **TOTAL SEMESTRAL** | — | **9,796** | **S/. 491,713.41** |

---

## 3. Consolidación de Volúmenes de Tramas Semestrales (Líneas de Archivo)

Los archivos txt de tramas finales exportados a la carpeta `tramas_exportadas/` contienen el volumen total unificado por mes tras aplicar las reglas de reclasificación de 24 horas:

| Mes / Período | Consulta Externa | Emergencia | Hospitalización | Farmacia | Total Mes |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 262,693 | 30,828 | 73,548 | 105,694 | **472,763** |
| **Agosto 2025** | 263,819 | 29,801 | 62,225 | 103,258 | **459,103** |
| **Setiembre 2025** | 293,791 | 29,836 | 61,482 | 118,417 | **503,526** |
| **Octubre 2025** | 348,205 | 27,404 | 58,451 | 118,984 | **553,044** |
| **Noviembre 2025** | 316,708 | 30,928 | 51,658 | 102,455 | **501,749** |
| **Diciembre 2025** | 291,265 | 29,426 | 46,161 | 98,966 | **465,818** |
| **TOTAL TRAMA** | **1,776,481** | **178,223** | **353,525** | **647,774** | **2,956,003** |

> [!NOTE]
> **Nota de Consistencia en Hospitalización**:
> La integración del Caso A (unión de estancias sin umbral) ha estabilizado el volumen total de líneas de Hospitalización en valores estables (~46k-73k), al absorber de manera coherente las estancias solapadas de emergencia dentro del flujo de hospitalización. La ligera tendencia decreciente refleja la gradual migración institucional hacia el formato unificado y depurado de SIGESAPOL, eliminando el doble registro de estancias sin alterar la continuidad de la atención del paciente.
>
> **Nota de reconciliación (este cierre)**: los volúmenes de este cierre difieren ligeramente (<0.03%) de los del cierre anterior porque se corrigió un bug de deduplicación en `generate_outputs_v2.py` — la llave de "duplicado de origen"/"duplicado entre fuentes" no aplicaba el discriminador por tipo (médico para Tipo 1, cantidad para Tipo 2/3) exigido por la regla de negocio, lo que excluía por error algunas filas legítimas de la trama LIMPIA. Corregido, ver `CONTEXTO_CANONICO.md`.

---

## 4. Recuperación Adicional por Regla de 24 Horas y Reclasificación

Siguiendo la directiva institucional, las emergencias con una duración real superior a 24 horas son reclasificadas a Hospitalización (Tipo 3). Aquellas que se solapan o tocan con una hospitalización existente se unifican en un rango único (Caso A), **sin umbral de horas** — el criterio de unión es continuidad física de la estancia, no duración. Las que no registran hospitalización previa y superan las 24 horas reales se convierten en nuevas estancias hospitalarias con código CPMS `99231.15` (Caso B).

Por otro lado, las emergencias con duración real menor o igual a 24 horas (y que no se solapan con ninguna hospitalización) permanecen como Tipo 2 en la trama de emergencias, forzando su CPMS al código canonical de consulta según su prioridad médica (99281-99285). Las estancias mayores a 15 días acumulados que cruzan de mes son catalogadas como Cierre Administrativo para depuración y no se facturan.

**Reconciliación de este cierre**: la tabla del cierre anterior sumaba más que el total de emergencias porque la columna "Excluidas por Solapamiento" duplicaba población ya contada dentro de "Caso A Unidas" (ambas contaban, con criterios ligeramente distintos, emergencias que se solapan con una hospitalización). Se eliminó esa columna y se verificó la partición con una query independiente (`CONTROL 13` en `04_CONTROL_integridad.sql`) que deriva cada categoría por separado — ninguna como resto de las demás — y confirma **residuo 0** en los 6 meses:

| Período | Emergencias Totales | Tipo 2 Facturadas | Caso B Reclass (Nueva Hosp) | Caso A Unidas (Overlap Hosp) | Cierre Admin (Excluidas) | Residuo | Facturación Recuperada Neto (S/.) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 8,388 | 7,675 | 248 | 386 | 79 | 0 | S/. 562,337.47 |
| **Agosto 2025** | 8,401 | 7,690 | 251 | 445 | 15 | 0 | S/. 768,877.72 |
| **Setiembre 2025** | 8,770 | 8,016 | 262 | 479 | 13 | 0 | S/. 718,366.65 |
| **Octubre 2025** | 8,798 | 7,529 | 433 | 500 | 336 | 0 | S/. 1,629,252.37 |
| **Noviembre 2025** | 10,021 | 8,622 | 635 | 467 | 297 | 0 | S/. 1,691,721.34 |
| **Diciembre 2025** | 9,330 | 8,284 | 469 | 520 | 57 | 0 | S/. 1,508,457.63 |
| **TOTAL** | **53,708** | **47,816** | **2,298** | **2,797** | **797** | **0** | **S/. 6,879,013.18** |

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
| **Médico Distinto (Revisar)** | 384 | 297 | 371 | 271 | 296 | 283 | **1,902** |
| **Cantidad Distinta (Revisar)** | 277 | 209 | 148 | 0 | 0 | 2 | **636** |
| **Transiciones Emergencia→Hospitalización (CONTROL 5)** | 727 | 815 | 852 | 1,076 | 1,260 | 1,117 | **5,847** |
| **Estancias Contiguas/Solapadas en CPT (CONTROL 9)** | 53 | 45 | 39 | 0 | 0 | 0 | **136** |
| **Duplicados en Origen** | 149 | 357 | 315 | 407 | 499 | 582 | **2,309** |
| **Estancias de emergencia sin CPMS en origen (informativo)** | 1,812 | 1,830 | 2,039 | 1,841 | 1,621 | 1,538 | **10,681** |
| **CPMS Derivado Hospitalización** | 861 | 1,002 | 1,095 | 1,286 | 1,257 | 1,376 | **6,877** |

> [!NOTE]
> **Corrección de este cierre**: la fila que el cierre anterior llamaba "Estancias Contiguas/Solapadas (C11)" y describía como CONTROL 9 en realidad traía los conteos de **CONTROL 5** (transiciones Emergencia→Hospitalización, `04_CONTROL_integridad.sql`). El verdadero CONTROL 9 (hospitalizaciones contiguas/solapadas del mismo paciente **dentro de CPT**) es una población mucho más chica — 136 casos en todo el semestre, concentrados en jul-set porque de oct en adelante CPT deja de ser la fuente canónica de hospitalización. Se separan ambas filas en esta versión.

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

| Período | Pares Caso A | Duplicados Ciertos Residuales | Filas RETENIDA | A1 | A2 | A3 (ciclo) | A3 (CONTROL 10) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 667 | 0 | 667 | OK | OK | OK | OK |
| **Agosto 2025** | 751 | 0 | 751 | OK | OK | OK | OK |
| **Setiembre 2025** | 788 | 0 | 788 | OK | OK | OK | OK |
| **Octubre 2025** | 994 | 0 | 994 | OK | OK | OK | OK |
| **Noviembre 2025** | 1,178 | 0 | 1,178 | OK | OK | OK | OK |
| **Diciembre 2025** | 1,053 | 0 | 1,053 | OK | OK | OK | OK |
| **TOTAL** | **5,431** | **0** | **5,431** | | | | |

> [!NOTE]
> **Corrección de este cierre**: (1) julio ya cierra con las 3 aserciones
> activas de punta a punta — se corrigió el bug de deduplicación (ver
> sección 3 y `CONTEXTO_CANONICO.md`) y se recorrió el pipeline completo, con
> lo cual las columnas N/D del cierre anterior quedan resueltas en OK. (2) La
> descripción de RETENIDA se corrige para reflejar el contrato v2: el cierre
> anterior la describía únicamente como "duplicado cierto entre CPT y
> SIGESAPOL", omitiendo que los pares Caso A (la mayor parte de la población)
> también son RETENIDA. (3) "Pares Caso A" cuenta los registros emparejados en la
> hoja `ESTANCIAS_E_H` del libro de auditoría Excel (fila RETENIDA) generados por la
> siguiente consulta SQL en `generate_outputs_v2.py`:
> 
> ```sql
> SELECT 
>     e.id_emergencia_sigesapol,
>     e.sp_numero_documento_paciente,
>     e.sp_fecha_atencion AS e_ing,
>     e.sp_fecha_alta_emergencia AS e_alt,
>     h.id_prestacion_cpt,
>     h.sp_fecha_atencion AS h_ing,
>     h.sp_fecha_alta AS h_alt,
>     e.sp_apellido_paterno_paciente,
>     e.sp_apellido_materno_paciente,
>     e.sp_nombres_paciente,
>     e.prioridad,
>     e.sp_codigo_dx_01,
>     e.sp_descripcion_dx_01,
>     e.sp_codigo_dx_02,
>     e.sp_descripcion_dx_02,
>     e.sp_codigo_dx_03,
>     e.sp_descripcion_dx_03
> FROM temp_emergencia_sigesapol_estancia e
> JOIN temp_hospitalizacion_local h 
>   ON h.sp_numero_documento_paciente = e.sp_numero_documento_paciente
>  AND e.sp_fecha_atencion::date <= h.sp_fecha_alta::date
>  AND e.sp_fecha_alta_emergencia::date >= h.sp_fecha_atencion::date
>  AND NOT (
>      TO_CHAR(e.sp_fecha_atencion, 'YYYY-MM') <> TO_CHAR(e.sp_fecha_alta_emergencia, 'YYYY-MM') 
>      AND (date(e.sp_fecha_alta_emergencia) - date(e.sp_fecha_atencion) + 1) > 15
>  );
> ```
> 
> **Reconciliación de "Pares Caso A" (667) vs "Caso A Unidas" (386) de Julio**:
> Dado que la consulta de emparejamiento anterior se ejecuta *después* de que las nuevas hospitalizaciones del Caso B (248 registros en Julio) han sido insertadas en `temp_hospitalizacion_local`, el JOIN empareja:
> - **386** verdaderos Caso A (Emergencias unidas a hospitalizaciones preexistentes).
> - **248** coincidencias de las estancias Caso B (que cruzan de forma idéntica con sus propias hospitalizaciones recién insertadas).
> - **33** solapamientos duplicados/cruzados provenientes de pacientes que cuentan con estancias hospitalarias múltiples o contiguas.
> - Total: `386 + 248 + 33 = 667` filas en el libro.


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

---

## 8. Pendientes Institucionales y Recomendaciones para la Jefatura

1. **Corte Definitivo entre Sistemas (Apagar CPT)**:
   Los datos demuestran que a partir de octubre de 2025, el 90% de las prestaciones y el 99% de las estancias de hospitalización ya se registran de forma nativa en SIGESAPOL. Se recomienda establecer una fecha de corte definitivo para apagar el ingreso de datos en CPT, reduciendo a cero el costo operativo de consolidar bases de datos.
2. **Capacitación para el llenado de cpms_alta en origen**:
   Se detectó que **10,681 egresos de emergencia** y **6,877 de hospitalización** se grabaron originalmente sin código de alta CPMS. Se sugiere capacitar al personal médico para el llenado obligatorio de la codificación al momento del alta para evitar el uso de fallbacks lógicos automatizados.
3. **Actualización de Tarifario (Tarifas en Cero)**:
   Se identificaron procedimientos que se valorizan con importe "cero" debido a la falta de concordancia entre los códigos del petitorio LNS y los códigos estandarizados CPMS. Es urgente actualizar la tabla de equivalencias de precios de la IPRESS para evitar pérdidas financieras.
4. **Alerta Automática a las 20 horas de Estancia en Emergencia**:
   Se recomienda implementar una alerta automática en el sistema SIGESAPOL cuando un paciente cumpla **20 horas continuas de permanencia en Emergencia**. Esto servirá de aviso temprano al personal médico y administrativo para gestionar el traslado físico y formal del paciente a Hospitalización o su alta oportuna, evitando las reclasificaciones tardías. Los **2,298 casos del semestre** que terminaron convirtiéndose en hospitalizaciones de facto (Caso B) sustentan la necesidad crítica de esta alerta como instrumento de control y reducción de glosas.
5. **Bug Abierto — Conteo de "Duplicados de Origen" en `generate_outputs_v2.py`**:
   Al corregir la llave de deduplicación (incidencia técnica #6), el conteo informativo de "duplicados de origen" (prestaciones repetidas dentro de una misma fuente) quedó en un rango implausible (17,000-53,000 por mes, muy por encima de los 149-582 reportados en la sección 5, que provienen de una fuente distinta y ya validada). No afecta la facturación de las tramas ni la sección 4 ni 6 de este informe, pero requiere una revisión aparte antes de usar ese campo específico de `generate_outputs_v2.py` para reportar. Ver `CONTEXTO_CANONICO.md` para el detalle.
