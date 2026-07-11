# RUTA DE TRABAJO — Tramas Nivel 3 LNS, JULIO A DICIEMBRE 2025

## Matriz de fuentes por mes (la realidad verificada con datos)

| Componente | Jul–Sep 2025 | Oct–Dic 2025 |
|---|---|---|
| Estancias emergencia | SIGESAPOL (paso 1, query 10 corregida) | SIGESAPOL (igual) |
| Estancias hospitalización | **CPT canónico** (función 02) + complemento SIGESAPOL (10-bis, archivo 05) | **SIGESAPOL canónico** (10-bis) + complemento CPT |
| Procedimientos (todas las atenciones) | **CPT canónico** (función 03) + complemento SIGESAPOL (archivo 06) | **SIGESAPOL canónico** (archivo 06) + complemento CPT |
| Laboratorio | CPT (función 04 parcheada) + lo que traiga SIGESAPOL tipo_procedimiento=2 vía archivo 06 | Igual, con SIGESAPOL como canónico |
| Farmacia (trama 4) | SIGESAPOL (query 11) | SIGESAPOL (query 11) |
| Tipo de diagnóstico | **'2' fijo en todo** (regla SALUDPOL) | Igual |

El corte canónico jul-sep vs oct-dic sale de los checks: CPT es superconjunto de hospitalización hasta septiembre (99.3% de solapamiento medido) y colapsa en octubre; SIGESAPOL lo supera desde entonces. La fuente complementaria **siempre** entra por anti-join (archivo 07) — nunca se suman dos fuentes completas.

## Orden de ejecución por mes

| # | Script | BD | Notas |
|---|---|---|---|
| 0 | `01_PARCHES_funciones.sql` | ambas | Solo la primera vez |
| 1 | `02_MAESTRO_paso1_SIGESAPOL.sql` | SIGESAPOL | Editar cfg_periodo (única edición del lado SIGESAPOL) |
| 2 | `05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql` | SIGESAPOL | Estancias hosp. SIGESAPOL |
| 3 | `06_FASE2_SIGESAPOL_procedimientos.sql` | SIGESAPOL | Procedimientos SIGESAPOL (médicos+lab+imágenes) |
| 4 | Traslado de las 3 tablas a CPT (ver abajo) | — | padrón emergencia + estancias hosp + procedimientos |
| 5 | `03_MAESTRO_paso2_CPT.sql` | CPT | Editar cfg_periodo (única edición del lado CPT) |
| 6 | `07_FASE2_deduplicacion_CPT_SIGESAPOL.sql` | CPT | Genera complementos + reportes de duplicados |
| 7 | `04_CONTROL_integridad.sql` | CPT | Controles en cero antes de exportar |
| 8 | Armado 06/07/08 (+ complementos) y 11 farmacia | — | Exportar a Excel; tipo dx ya sale '2' |

## Cómo ejecutar el traslado (pg_dump) — paso a paso en Windows

Asumiendo que ambas bases están en tu mismo PostgreSQL local (como en tu PC con `db_cpt_junio26` y `sigesapol_junio`):

**1. Abre CMD o PowerShell y ubica el bin de PostgreSQL** (ajusta la versión):

```
cd "C:\Program Files\PostgreSQL\16\bin"
```

(Si usas el PostgreSQL de Laragon: `C:\laragon\bin\postgresql\<versión>\bin`)

**2. Exporta las tablas desde SIGESAPOL a un archivo:**

```
pg_dump -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia -t temp_hospitalizacion_sigesapol_estancia -t temp_sigesapol_procedimientos -f C:\temp\padron_sigesapol.sql
```

Te pedirá la contraseña del usuario postgres. El `-t` selecciona solo esas tablas (estructura + datos), nada más de la base.

**3. Limpia las versiones anteriores en CPT (si es re-corrida):**

```
psql -U postgres -d db_cpt_junio26 -c "DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia, temp_hospitalizacion_sigesapol_estancia, temp_sigesapol_procedimientos;"
```

**4. Importa en CPT:**

```
psql -U postgres -d db_cpt_junio26 -f C:\temp\padron_sigesapol.sql
```

**5. Verifica:**

```
psql -U postgres -d db_cpt_junio26 -c "SELECT COUNT(*) FROM temp_emergencia_sigesapol_estancia;"
```

Si el conteo coincide con el que viste al final del paso 1, el viaje fue exitoso.

**Atajo en un solo comando** (exporta e importa sin archivo intermedio, ideal para el lote automatizado con Claude Code):

```
pg_dump -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia -t temp_hospitalizacion_sigesapol_estancia -t temp_sigesapol_procedimientos | psql -U postgres -d db_cpt_junio26
```

(pedirá contraseña dos veces; para automatizar, define la variable de entorno `PGPASSWORD` antes: `set PGPASSWORD=tuclave` en CMD o `$env:PGPASSWORD="tuclave"` en PowerShell)

**Para producción** (si SIGESAPOL y CPT viven en servidores distintos): mismos comandos agregando `-h <ip_servidor>` a cada lado, o consultar al equipo si ya existe un mecanismo. Este sigue siendo el pendiente operativo a confirmar.

## Validación del primer mes

Julio 2025 es el candidato ideal para el piloto: si ya fue reportado con el método antiguo, compara contra ese Excel; los reportes B.1/B.2 del archivo 07 además te cuantifican el doble registro de ese mes — insumo directo para el informe a jefatura y la auditoría posterior.

## Reglas de deduplicación (FINALES, validadas con el piloto julio 2025)

| Tipo | Duplicado automático (se descarta del complemento) | Hoja "OBSERVACIONES DUPLICADOS" (decide auditoría) |
|---|---|---|
| 1 — Proc. médicos | paciente + fecha + código + **mismo médico** | mismo par con médico distinto → motivo "MEDICO DISTINTO ENTRE FUENTES" |
| 2 — Laboratorio y 3 — Imágenes | paciente + fecha + código + **misma cantidad** (médico ignorado: CPT firma el validador del servicio, SIGESAPOL el tratante — verificado) | mismo par con cantidad distinta → motivo "CANTIDAD DISTINTA ENTRE FUENTES" |
| Estancias | documento + solapamiento de fechas | — |

## Fallbacks de CPMS de estancia (por vacíos de origen verificados)

- **Emergencias** (22.5% de `cpms_alta` vacío): prioridad I → `99295`, resto → `99231.15` — la misma convención del sistema legado ("UNITIC regularizará"). Aplicado en el paso 1.
- **Hospitalizaciones** (100% vacío): por clase de cama — UCI/intensivos → `99295`, intermedios → `99305`, resto → `99231`. Aplicado en el archivo 05, con columna `clase_cama` para trazabilidad. Tarifas verificadas en `procedimientos.t_nivel3`.

## Ajustes incorporados tras el piloto

- Script 06 reescrito con la optimización validada (join relacional de diagnósticos + filtro de fecha sin cast: de >9 min a ~1 min 15 s), **conservando** los filtros de anulados/eliminados y el orden determinístico.
- El maestro paso 2 crea automáticamente la estructura vacía `temp_emergencia_local` (dependencia física de las funciones 03/04 aunque la rama no se ejecute).
- La deduplicación ahora incluye las tablas de **laboratorio de CPT** (ausentes en la primera versión del cruce).

## Pendientes abiertos

1. Confirmar con el equipo el mecanismo de traslado entre bases en producción (mientras tanto: el pg_dump documentado arriba).
2. Elevar al equipo/dirección: los 78 códigos sin tarifa en CPT (check 28) y el no-llenado de `cpms_alta` en los módulos de SIGESAPOL (para que la corrección venga de origen).
3. Fix permanente sugerido para las funciones 03/04 de CPT: refactor de `WHERE CASE` a `IF/ELSIF` con un `RETURN QUERY` por rama (elimina la dependencia fantasma y mejora índices). No urgente: el workaround ya está en el maestro.
4. Trama 2 directa en SQL (elimina el despivoteo en Excel) — mejora opcional a pedido.
