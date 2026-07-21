# GUIA DE EJECUCIÓN MANUAL — PIPELINE V3.3

## 0. Prerequisitos

Antes de iniciar el ciclo mensual, asegúrese de haber corrido los instaladores **por única vez tras restaurar la base de datos**:

### Configuración del Período
Usted debe configurar el período de interés (ej. `'2025-07-01'`) en las variables `cfg_periodo` de los scripts:
1. `2_02_MAESTRO_paso1_SIGESAPOL.sql`
2. `7_03_MAESTRO_paso2_CPT.sql`

Los dos deben quedar con **exactamente la misma fecha** — el guardián del
período (ver más abajo) aborta el paso 9 si no coinciden.

### Guardián de período (protección contra contaminación entre meses)

El paso 2 (`2_02_MAESTRO_paso1_SIGESAPOL.sql`) crea, al final, una tabla
sello `temp_sigesapol_cfg_periodo` con el `cfg_periodo` de SIGESAPOL en ese
momento. Esa tabla viaja junto con las demás en el traslado (paso 4) hacia
CPT. El paso 9 (`9_08_CONSOLIDAR_fuentes_para_armado.sql`) la lee de vuelta y
**aborta con `RAISE EXCEPTION`** si:
- falta la tabla (no se trasladó, o se saltó el paso 2), o
- el período que declara SIGESAPOL (`temp_sigesapol_cfg_periodo`) no coincide
  exactamente con el período declarado en CPT (`cfg_periodo` del paso 7).

Esto existe porque una extracción con el período editado solo de un lado
(p. ej. CPT ya apunta a septiembre pero las tablas trasladadas siguen siendo
las de julio) arma tramas contaminadas con prestaciones de otro mes, sin
ningún error visible hasta la auditoría. **Si el paso 9 aborta por esto,
vuelva al paso 2**, corrija el período en ambos scripts y repita desde ahí
(incluido el traslado).

> ⚠️ Los 14 archivos de esta carpeta son **copias exactas y regeneradas** de
> los originales en la raíz del repo (ver encabezado "ARCHIVO GENERADO - NO
> EDITAR" en cada uno). Antes de v3.3, esta carpeta había quedado desactualizada:
> le faltaba por completo el guardián de período (ni la creación de
> `temp_sigesapol_cfg_periodo` en el paso 2, ni la validación en el paso 9) y
> varios filtros de fecha en los armados (9/10/11) y en farmacia (14) — es
> decir, quien corriera el pipeline manualmente por esta vía NO tenía ninguna
> de las dos protecciones contra contaminación entre períodos. Corregido y
> re-sincronizado en v3.3; si alguna vez edita un archivo de esta carpeta
> a mano, volverá a desincronizarse — repórtelo para regenerarlo desde el
> original en vez de mantenerlo editado a mano.

### Ruta Lógica del Pipeline
1. Extracción de **SIGESAPOL** (hosp, proc, eme).
2. **Traslado** de tablas temporales desde SIGESAPOL a CPT.
3. Extracción de **CPT**.
4. **Deduplicación y consolidación** de fuentes (controles cruzados).
5. **Armado** de las 3 tramas finales.

---

## 1. PASO A PASO DEL PERÍODO

Esta carpeta contiene copias exactas de todos los scripts necesarios. Si utiliza **PgAdmin**, abra y ejecute cada archivo individualmente en el siguiente orden:

### FASE SIGESAPOL (Base de datos: SIGESAPOL)

| # | Archivo | Qué hace (Ancla) | Expectativa (Ref. Jul 2025) | Precaución |
|---|---|---|---|---|
| **1** | `1_00_INSTALAR_post_restauracion_SIGESAPOL.sql` | Instalador post-restore | Funciones generadas | Solo 1 vez |
| **2** | `2_02_MAESTRO_paso1_SIGESAPOL.sql` | Establece el período, limpia tablas temp y extrae emergencias excluyendo anulados. | ~5,000 atenciones tipo 2 | Configurar `cfg_periodo`. |
| **3** | `3_05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql` | Genera estancias hospitalarias con fallbacks de CPMS según clase de cama. | | |
| **4** | `4_06_FASE2_SIGESAPOL_procedimientos.sql` | Extrae procedimientos y laboratorio de CE/EME/HOSP. | ~180k filas esperadas | |

> **TRASLADO DE TABLAS:** Terminado el Paso 4, debe usar el método de traslado (ej. `pg_dump` vía consola de Windows) para migrar las tablas `temp_emergencia_sigesapol_estancia`, `temp_hospitalizacion_sigesapol_estancia` y `temp_sigesapol_procedimientos` a la base de datos CPT.

### FASE CPT (Base de datos: CPT)

| # | Archivo | Qué hace (Ancla) | Expectativa (Ref. Jul 2025) | Precaución |
|---|---|---|---|---|
| **5** | `5_00_INSTALAR_post_restauracion_CPT.sql` | Instalador post-restore | Funciones generadas | Solo 1 vez |
| **6** | `6_01_PARCHES_funciones.sql` | Parches a SPs | Correcciones aplicadas | Solo 1 vez |
| **7** | `7_03_MAESTRO_paso2_CPT.sql` | Establece el período, limpia tablas temp locales y extrae CPT LNS. | | Configurar `cfg_periodo` al mismo mes que Paso 2. |
| **8** | `8_07_FASE2_deduplicacion_CPT_SIGESAPOL.sql` | Evalúa reglas de deduplicación y marca Casos A (solapamientos E->H). | ~395 solapamientos E->H | |
| **9** | `9_08_CONSOLIDAR_fuentes_para_armado.sql` | **DESTRUCTIVO:** Unifica las fuentes aplicando reglas canónicas y marcando excluidos. |  | ⚠️ **Si falla o necesita re-correr, VUELVA AL PASO 7**. |
| **10** | `10_04_CONTROL_integridad.sql` | Audita la integridad. | Controles 1–4 y 7–8 = 0 | |
| **11** | `11_09_ARMADO_consulta_externa.sql` | Construye formato final Trama CE. | `temp_bdt_consulta_local` | |
| **12** | `12_10_ARMADO_emergencia.sql` | Construye formato final Trama EME. | `temp_bdt_emergencia_local` | |
| **13** | `13_11_ARMADO_hospitalizacion.sql` | Construye formato final Trama HOSP. | `temp_bdt_hospitalizacion_local` | |

### EXTRAS

- `14_12_SIGESAPOL_farmacia.sql`: Se ejecuta **directamente en SIGESAPOL**.
- `15_12_EXPORTAR_TRAMAS_CONSOLA.sql`: (En CPT) Úselo al final para sacar los datos a Excel sin saltos de línea.
- `16_CONSULTAS_OBSERVACION.sql`: (En CPT) Equivalentes de auditoría del aplicativo.

> **Nota de numeración:** el prefijo de estos archivos (1-16) es el orden de
> ejecución de la vía consola/PgAdmin. Es una numeración distinta de los
> "pasos 1-11" del aplicativo (`aplicativo/config/pipeline.php`) y del "paso
> 12" (reincorporación) de la sección 4 — no son el mismo contador.

---

## 2. ASERCIONES A1-A8 (contrato de salidas v2, v3.3)

Las 8 aserciones automáticas viven en `14_VERIFICAR_ASERTOS.py` (raíz del
repo) y corren **después de exportar** las 4 tramas (`generate_outputs_v2.py`),
sea que las haya generado el aplicativo o la vía consola — el script no
distingue el origen, solo lee `expedientes/<periodo>/` y consulta ambas BD en
vivo. Ejecútelo siempre, incluso si armó las tramas manualmente con esta
carpeta:

```
python 14_VERIFICAR_ASERTOS.py --year 2025 --month 7
```

| Asercion | Qué verifica | Dónde vive |
|---|---|---|
| **A1** (conservación) | `LIMPIA + RETENIDA + INFORMATIVA = total extraído`, residuo 0 por tipo de trama. | `metricas.json` |
| **A2** (paquete completo) | Cero fugas de pares Caso A (E→H) en `trama_emergencia.txt`. | `.retained_package_*.json` vs trama |
| **A3-ciclo** | `13_REINCORPORAR_decisiones.py` con libro de decisiones en blanco no modifica ningún .txt (defaults = lo que ya escribió `generate_outputs_v2.py`). | corre el script 13 en un entorno de prueba y restaura todo al terminar |
| **A3-CONTROL10** | Ningún par (documento+fecha+código) aparece a la vez en trama de emergencia y de hospitalización. | consulta viva a CPT |
| **A4** (pureza de alcance) | El único `codigo_ipress` en las 4 tramas es `00013591` (LNS). | trama_*.txt + `CONTROL 4` en `04_CONTROL_integridad.sql` |
| **A5** (ventana temporal) | Ninguna fecha de las tramas cae fuera del período declarado. | trama_*.txt |
| **A6-integridad** *(antes "A6", renombrada en v3.3 — su lógica no cambió)* | El recuento físico de líneas de cada `trama_*.txt` coincide con `metricas.json.volumenes_tramas`. Detecta corrupción/truncamiento de archivo, **no** cobertura contra origen (para eso está A7). | trama_*.txt vs `metricas.json` |
| **A7-cobertura** *(nueva en v3.3)* | Cuenta las prestaciones del período **directamente en las tablas de origen** (`emergencias`, `hospitalizaciones`, `prestaciones`+`prestacion_procedimientos` en SIGESAPOL; `prestacion_cpt`+`procedimiento_cpt` en CPT), con una consulta que NO pasa por ninguna tabla `temp_*` del pipeline. La contrasta contra `volumenes_raw` de `metricas.json` (descontando `log_alcance_depurado`) y **falla fuerte** si una trama queda en 0 filas con métricas coherentes, o si la extracción reporta más filas que las que existen en origen (fuga de período). Requiere conexión viva a ambas BD (usar `--skip-a7-db` para omitir). | conexión en vivo a CPT + SIGESAPOL |
| **A8-no-duplicación entre períodos** *(nueva en v3.3)* | Ninguna prestación (documento+fecha+código) de este período aparece también en las tramas de **otro** período ya generado en `expedientes/` (doble cobro entre envíos — el caso de estancias largas que cruzan de mes). Control permanente: córralo en cada cierre de período. | compara `expedientes/<periodo>/01_TRAMAS/` contra los demás períodos en `expedientes/` |

---

## 3. INNOVACIONES V3.1 VS MÉTODO ANTIGUO

| Paso | Mejora implementada respecto a V2 |
|---|---|
| **Paso 1** | Ignora registros anulados nativamente en SIGESAPOL; aplica CPMS de estancias dinámicamente según prioridad. |
| **Paso 2** | Fallback de CPMS en estancias de hospitalización es 100% auditable a través de la nueva columna `clase_cama`. |
| **Paso 4** | El alcance LNS (15 IPRESS autorizadas) es automático por fecha y reemplaza las sub-consultas rígidas. |
| **Paso 5** | La deduplicación ahora distingue por TIPO (mismo médico en CE; misma cantidad en EME/HOSP). |
| **Paso 5** | Detecta las transiciones E->H por fecha de solapamiento O "toca" (<= 24h), uniendo el caso en paquete completo. |
| **Paso 8/9/10** | Los armados son simples volcados de las temporales finales; ya no cruzan lógica de negocio ni deduplicaciones ocultas. |
| **Bugs Corregidos**| - **Cruce de Documentos:** Se corrigieron los problemas de padding (ceros a la izquierda) y tipos de datos que causaban que los números de documento no cruzaran bien entre CPT y SIGESAPOL, evitando la pérdida silenciosa de registros.<br>- **Registros Anulados/Eliminados:** Se parcharon las funciones base para excluir diagnósticos y atenciones que tenían borrado lógico o estaban anuladas (antes entraban como válidas).<br>- **Fechas Dispersas:** Se eliminó el hardcodeo de fechas en 8 lugares distintos de las queries originales; ahora todo se maneja desde una sola variable centralizada. |

---

## 4. AUDITORÍA MÉDICA (Reemplazo Visual de Python)

El archivo **`CONSULTAS_OBSERVACION.sql`** provee los queries directos (SELECTs) para observar en la grilla los datos crudos que Python normalmente agrupa y exporta en el Excel de Auditoría. Incluye:
1. **ESTANCIAS E->H (Caso A):** Para visualizar los paquetes de transición propuestos por el pipeline.
2. **DUPLICADOS FUENTES/ORIGEN:** Agrupación emulada SQL para observar choques por paciente/fecha/código y discriminador.
3. **TRANSFERENCIAS HUÉRFANAS:** Visión de altas con condición 3 sin hospitalización de destino.

---

## 5. PASO 12 — REINCORPORACIÓN DE DECISIONES DE AUDITORÍA MÉDICA

Tras cerrar el período (pasos 1-11 del aplicativo, o su equivalente 1-16 de
esta carpeta + `generate_outputs_v2.py` + `14_VERIFICAR_ASERTOS.py`), la
Unidad de Auditoría Médica revisa el libro `02_AUDITORIA_<periodo>.xlsx` y
marca PROCEDE/NO PROCEDE en la columna de decisión de sus 4 hojas
(`ESTANCIAS_E_H`, `DUPLICADOS_FUENTES`, `DUPLICADOS_ORIGEN`,
`TRANSF_HUERFANAS`). El "paso 12" es subir ese libro decidido y aplicarlo:

- **Vía aplicativo**: pantalla de reincorporación (`aplicativo/public/reincorporar.php`),
  que reemplaza el libro de auditoría del expediente y corre
  `13_REINCORPORAR_decisiones.py` + `14_VERIFICAR_ASERTOS.py` en secuencia.
- **Vía consola**: correr manualmente
  `python 13_REINCORPORAR_decisiones.py --year <A> --month <M>` desde la raíz
  del repo, con el libro ya decidido en
  `expedientes/<periodo>/02_AUDITORIA_<periodo>.xlsx`.

> ⚠️ **ADVERTENCIA DE NO-IDEMPOTENCIA**: a diferencia de los pasos 1-11 (que
> son re-ejecutables porque cada uno empieza con `DROP TABLE IF EXISTS` /
> vuelve a generar sus tramas desde cero), **el paso 12 SÍ muta las tramas ya
> exportadas en el lugar**, tomando como base lo que haya en el libro de
> auditoría en ESE momento. Si lo corre dos veces (p. ej. una vez con
> decisiones parciales y otra con el libro final), la segunda corrida parte
> de las tramas YA modificadas por la primera, no de las tramas originales de
> `generate_outputs_v2.py` — el resultado puede no ser el mismo que correrlo
> una sola vez con el libro completo. **Reglas de uso:**
> 1. Corra el paso 12 **una sola vez por período**, solo cuando el libro de
>    auditoría tenga TODAS las decisiones finales de Auditoría Médica.
> 2. Si necesita corregir una decisión después de haber corrido el paso 12,
>    **no vuelva a correrlo sobre el resultado**: restaure primero las 4
>    tramas y el .xlsx desde el respaldo que el aplicativo guarda
>    automáticamente (o desde `generate_outputs_v2.py` re-ejecutado desde
>    cero), y recién ahí aplique el libro corregido.
> 3. La propia aserción **A3-ciclo** (`14_VERIFICAR_ASERTOS.py`) prueba esta
>    propiedad en cada corrida: ejecuta el paso 12 con un libro de decisiones
>    en blanco (todo pendiente = defaults de código) sobre una COPIA temporal
>    y verifica que las tramas no cambien byte a byte; si A3-ciclo falla, es
>    señal de que el paso 12 dejó de ser seguro de repetir con defaults.
