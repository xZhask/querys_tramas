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

---

## 2. NÚMEROS CANÓNICOS VERIFICADOS

| Métrica | Valor | Estado |
| --- | --- | --- |
| Doble cobro evitado, semestre completo (jul-dic 2025) | **S/. 491,713.41** (9,796 duplicados ciertos) | Verificado — coincide con §2 de `INFORME_CIERRE_SEMESTRE.md` |
| Recuperación neta por regla 24h, semestre completo (jul-dic 2025), **metodología corregida con snapshot pre-Caso-A** | **S/. 6,879,013.18** | Verificado por `CONTROL 14` — reemplaza tanto el 4,711,557.11 del cierre anterior como el ancla previa de julio (1,109,812.71, ver nota) |
| Julio 2025, recuperación neta por regla 24h (metodología corregida) | **S/. 562,337.47** | Verificado por `CONTROL 14` — ver nota sobre por qué reemplaza a 1,109,812.71 |
| Partición Sección 4 (Tipo2+CasoA+CasoB+CierreAdmin=Total, residuo 0) | Semestre: 47,816+2,797+2,298+797=53,708 | Verificado por `CONTROL 13`, residuo 0 en los 6 meses |
| Cuadratura C1 (= aserción A1 de conservación: LIMPIA + RETENIDA + INFORMATIVA = total extraído) | Cierra en **residuo 0** por mes y por tipo de trama, los 6 meses incluyendo julio | Verificado — las 3 aserciones (A1/A2/A3) están en OK para los 6 meses |
| Benchmark de eficiencia vs. proceso manual | **91.5%** | coincidencia de pares E→H vs proceso manual (ver `COMPARATIVO_FINAL_EXPOSICION.txt` para evidencia de rendimiento asociada) |
| Atenciones Tipo 2 (Emergencia) facturadas (CONTROL 15) | **47,816** atenciones / **S/. 1,585,426.27** | Verificado por CONTROL 15 en los 6 meses (Jul-Dic 2025) |

> **Resultado final de la Parte 1** (todo verificado por query contra la BD
> viva, pipeline completo jul-dic re-corrido tres veces con cada fix aplicado):
>
> 1. **Partición Sección 4**: la tabla del cierre anterior sumaba más que el
>    total porque "Excluidas por Solapamiento" duplicaba población ya
>    contada en "Caso A Unidas". `CONTROL 13` deriva las 4 categorías de
>    forma independiente y confirma residuo 0 los 6 meses. El Caso A real
>    semestral es **2,797**, no 2,567 (la cifra vieja subcontaba por ~230,
>    repartido de forma desigual por mes).
> 2. **Recuperación Neta**: el primer intento de recalcular por diffs
>    antes/después (sin snapshot) daba ~10.06M — sobrestimado, porque
>    contaba el valor COMPLETO de una estancia Caso A como ganancia, no solo
>    el incremento de días. Se corrigió con un snapshot de la valorización
>    hospitalaria tomado en `12_RECLASIFICAR_emergencias_24h.sql` ANTES de
>    unir/insertar nada (`CONTROL 14`). Resultado final: **S/. 6,879,013.18**
>    para el semestre, **S/. 562,337.47** para julio.
> 3. **Sobre 1,109,812.71** (la cifra ancla que este documento tenía): se
>    confirmó que salía de sumar el diff antes/después de `diff_tramas.md`
>    (hospitalización +1,477,173.28, emergencia -367,360.57), un checkpoint
>    ANTERIOR del pipeline que tenía EXACTAMENTE el mismo problema de
>    medición recién descrito (contaba el valor completo de la estancia
>    Caso A, no el incremento) — por eso esa cifra ya no es la referencia
>    correcta; se reemplaza por 562,337.47.
> 4. **Sobre el 4,711,557.11 y el "8.42M"** mencionados como totales previos:
>    ningún artefacto en el repositorio reproduce ninguno de los dos — no
>    hay query de origen preservada para ellos. Se reemplazan por la cifra
>    verificada de este cierre.
> 5. **Sobre la sospecha PERMANENCIA_EN_EMERGENCIA**: descartada. Esa
>    etiqueta (con "EN",
>    `expedientes/correccion_cpms/estancias_emergencia_no_facturadas.md`) es
>    una clasificación provisional de una iteración anterior (antes del fix
>    de cruce de medianoche), distinta de `PERMANENCIA_EMERGENCIA_24H` (sin
>    "EN") que usa el pipeline actual. Ningún total en esa fuente reproduce
>    4,711,557.11.

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

---

## 4. REGLA DE ENTRADA DE NÚMEROS A INFORMES

Ningún número entra a un informe (`INFORME_CIERRE_SEMESTRE.md` u otro) si no
cuadra contra la sección 2 de este documento, o si no trae su propia
reconciliación explícita documentada (query de origen + diff antes/después).
