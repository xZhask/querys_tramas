# RUTA DEFINITIVA — Tramas Nivel 3 LNS | Julio a Diciembre 2025

## Inventario completo de archivos

**Nuevos (este paquete):** 00_RUTA (este documento), 01_PARCHES, 02_MAESTRO_paso1,
03_MAESTRO_paso2, 04_CONTROL, 05_FASE2 (hosp. SIGESAPOL), 06_FASE2 (proc.
SIGESAPOL), 07_FASE2 (reportes de deduplicación), 08_CONSOLIDAR,
09/10/11_ARMADO (copias de los armados originales con UNION ALL).

**Del paquete original, aún necesarios (sin modificar):**
- Funciones CPT: `00_sp_diagnostico_en_prestacion_cpt`, `02_SP_HOSPITALIZACION`,
  `03_SP_PROCEDIMIENTOS` — el maestro las invoca.
- `11_SIGESAPOL_farmacia` — trama 4.

**Del paquete original, retirados:** 00_SIGESAPOL (→ Parche A), 01 y
00_emergencia CPT (legado sin datos), 04 (→ Parche B), 05 (→ 03_MAESTRO),
09 (→ 06_FASE2), 10 (→ 02_MAESTRO_paso1), 11_CREAR_TABLA_EMERGENCIA (obsoleto),
06/07/08 armados (→ copias 09/10/11_ARMADO), carpeta HISTORICO.

---

## SECUENCIA DE EJECUCIÓN

### FASE 0 — Instalación (UNA SOLA VEZ por servidor)

| # | Archivo | BD | Qué hace |
|---|---|---|---|
| 0.1 | `00_sp_diagnostico_en_prestacion_cpt` (original) | CPT | Función de dx CPT |
| 0.2 | `02_SP_HOSPITALIZACION_3_diagnosticos` (original) | CPT | Función de estancias hosp. CPT |
| 0.3 | `03_SP_PROCEDIMIENTOS_SEGUN_TIPO_ATENCION` (original) | CPT | Función de procedimientos CPT |
| 0.4 | `01_PARCHES_funciones.sql` — Parches B y C | CPT | Laboratorio corregido + dx emergencia legado |
| 0.5 | `01_PARCHES_funciones.sql` — Parche A | SIGESAPOL | Dx SIGESAPOL sin anulados |

### FASE MENSUAL (repetir por cada período, jul → dic 2025)

| # | Archivo | BD | Edición requerida |
|---|---|---|---|
| 1 | `02_MAESTRO_paso1_SIGESAPOL.sql` | SIGESAPOL | **Editar cfg_periodo** (única edición del lado SIGESAPOL) |
| 2 | `05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql` | SIGESAPOL | — |
| 3 | `06_FASE2_SIGESAPOL_procedimientos.sql` | SIGESAPOL | — |
| 4 | **Traslado** de las 3 tablas a CPT (pg_dump, comandos abajo) | — | — |
| 5 | `03_MAESTRO_paso2_CPT.sql` | CPT | **Editar cfg_periodo** (mismo período del paso 1) |
| 6 | `07_FASE2_deduplicacion_CPT_SIGESAPOL.sql` | CPT | — · Exportar B.2 (hoja OBSERVACIONES DUPLICADOS) y B.3 (resumen para jefatura) ANTES del paso 7 |
| 7 | `08_CONSOLIDAR_fuentes_para_armado.sql` | CPT | **Editar cfg_canonico**: 'CPT' (jul–sep) / 'SIGESAPOL' (oct–dic) |
| 8 | `04_CONTROL_integridad.sql` | CPT | — · Controles 1–4 y 7–8 en cero; control 5 = hoja OBSERVACIONES transiciones |
| 9 | `09_ARMADO_consulta_externa.sql` | CPT | Exportar → tramas de consulta externa |
| 10 | `10_ARMADO_emergencia.sql` | CPT | Exportar → tramas de emergencia |
| 11 | `11_ARMADO_hospitalizacion.sql` | CPT | Exportar → tramas de hospitalización |
| 12 | `11_SIGESAPOL_farmacia` (original) | SIGESAPOL | Exportar → trama 4 (ajustar su fecha al período) |
| 13 | Excel: despivotear dx a trama 2, integrar hojas de observaciones, depuración de auditoría | — | — |

**Regla de oro de la secuencia:** el paso 7 modifica las tablas en el lugar; si
necesitas repetirlo, vuelve al paso 5 primero. Y el paso 6 se exporta ANTES del
7, porque tras consolidar los pares duplicados ya no son visibles en el cruce.

### Traslado (paso 4) — pg_dump en Windows

```
cd "C:\Program Files\PostgreSQL\16\bin"
psql -U postgres -d db_cpt_junio26 -c "DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia, temp_hospitalizacion_sigesapol_estancia, temp_sigesapol_procedimientos;"
pg_dump -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia -t temp_hospitalizacion_sigesapol_estancia -t temp_sigesapol_procedimientos | psql -U postgres -d db_cpt_junio26
psql -U postgres -d db_cpt_junio26 -c "SELECT COUNT(*) FROM temp_sigesapol_procedimientos;"
```
(Contraseña: `set PGPASSWORD=...` en CMD para automatizar. Producción en
servidores distintos: agregar `-h <ip>` en cada lado.)

---

## Reglas de deduplicación (validadas con piloto julio 2025)

| Tipo | Duplicado automático | Hoja OBSERVACIONES (auditoría decide) |
|---|---|---|
| 1 — Proc. médicos | paciente+fecha+código+**mismo médico** | médico distinto |
| 2 Lab / 3 Imágenes | paciente+fecha+código+**misma cantidad** (médico ignorado: CPT firma el validador del servicio) | cantidad distinta |
| Estancias | documento + solapamiento de fechas | — |

## Fallbacks de CPMS de estancia (vacíos de origen verificados)

- Emergencias (22.5% vacío): prioridad I → 99295, resto → 99231.15 (convención legada). En paso 1.
- Hospitalizaciones (100% vacío): UCI → 99295, intermedios → 99305, resto → 99231, por clase de cama, con columna `clase_cama` de trazabilidad. En archivo 05.

## Pendientes institucionales (no bloquean)

1. Mecanismo oficial de traslado entre bases en producción (mientras: pg_dump).
2. Elevar: 78 códigos sin tarifa en CPT + no-llenado de `cpms_alta` en SIGESAPOL.
3. Refactor `WHERE CASE` → `IF/ELSIF` en funciones 03/04 CPT (mejora, no urgente).
4. Trama 2 directa en SQL (elimina despivoteo del paso 13) — a pedido.
