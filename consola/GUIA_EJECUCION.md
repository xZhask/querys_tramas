# GUIA DE EJECUCIÓN MANUAL — PIPELINE V3.1

## 0. Prerequisitos

Antes de iniciar el ciclo mensual, asegúrese de haber corrido los instaladores **por única vez tras restaurar la base de datos**:

### Configuración del Período
Usted debe configurar el período de interés (ej. `'2025-07-01'`) en las variables `cfg_periodo` de los scripts:
1. `2_02_MAESTRO_paso1_SIGESAPOL.sql`
2. `7_03_MAESTRO_paso2_CPT.sql`

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

---

## 2. INNOVACIONES V3.1 VS MÉTODO ANTIGUO

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

## 3. AUDITORÍA MÉDICA (Reemplazo Visual de Python)

El archivo **`CONSULTAS_OBSERVACION.sql`** provee los queries directos (SELECTs) para observar en la grilla los datos crudos que Python normalmente agrupa y exporta en el Excel de Auditoría. Incluye:
1. **ESTANCIAS E->H (Caso A):** Para visualizar los paquetes de transición propuestos por el pipeline.
2. **DUPLICADOS FUENTES/ORIGEN:** Agrupación emulada SQL para observar choques por paciente/fecha/código y discriminador.
3. **TRANSFERENCIAS HUÉRFANAS:** Visión de altas con condición 3 sin hospitalización de destino.
