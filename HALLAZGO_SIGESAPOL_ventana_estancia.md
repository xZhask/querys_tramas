# HALLAZGO — Fuga de período en procedimientos/laboratorio de hospitalización y
# emergencia del lado SIGESAPOL (bug paralelo, sin corregir, a PARCHE D)

> Encontrado 2026-07-21 durante la validación de casos frontera del PARCHE D
> (misión de corrección de causa raíz, v3.3/v3.4). Documento standalone por
> pedido explícito — no forma parte todavía de `CONTEXTO_CANONICO.md` §3;
> una vez corregido y verificado, su resumen debe integrarse ahí como
> "PARCHE E" junto a la entrada de PARCHE D.
>
> **Este archivo NO contiene documento ni nombre de paciente** (regla
> inmutable §1.10 de `CONTEXTO_CANONICO.md`) — todos los ejemplos usan un
> identificador de sesión (`Paciente A`, `Paciente B`) en vez del DNI real;
> el detalle con documento vive únicamente en la sesión de validación, no
> versionado.


---

## 1. Resumen del hallazgo

PARCHE D (`01_PARCHES_funciones.sql`, 2026-07-21) corrigió dos funciones
PL/pgSQL de **CPT** (`sp_procedimientos_segun_tipo_atencion` y
`sp_laboratorio_segun_tipo_atencion`) que traían procedimientos de
hospitalizaciones/emergencias **distintas y ya cerradas** del mismo paciente,
en vez de acotarlos a la ventana `[ingreso, alta]` de la estancia específica
que se factura en el período.

Al validar ese fix con casos frontera (estancias que cruzan de mes), se
encontró que el **lado SIGESAPOL nunca tuvo ningún acotamiento por estancia
en absoluto** — ni la versión con bug de PARCHE D, ni la corregida. El script
`06_FASE2_SIGESAPOL_procedimientos.sql` (paso 3 del pipeline, corre en la BD
SIGESAPOL) extrae procedimientos/laboratorio de **consulta + emergencia +
hospitalización en una sola consulta**, con un único filtro de fecha:

```sql
WHERE pre.id_tipo_atencion IN (1, 5, 7, 2, 3, 6, 8)
  AND p2.tipo_procedimiento IN (1, 2, 3)
  AND pre.fecha_atencion >= (SELECT p_ini FROM cfg_periodo)
  AND pre.fecha_atencion <  (SELECT p_fin FROM cfg_periodo) + INTERVAL '1 day'
  AND pre.id_establecimiento = (SELECT id_establecimiento_sigesapol FROM cfg_ipress_alcance)
```

Para **consulta** (tipo 1/5/7) este filtro es correcto: no existe noción de
"estancia", cada atención ambulatoria factura en su propia fecha.

Para **emergencia** (tipo 2) y **hospitalización** (tipo 3/6/8), este filtro
es INCORRECTO frente a la regla inmutable §1.11 (factura solo en el período
del ALTA de la estancia): cualquier procedimiento con `pre.fecha_atencion`
dentro del mes calendario entra a la trama de ese mes, **sin verificar en
absoluto a qué estancia pertenece ni si esa estancia ya se dio de alta**.

## 2. Evidencia verificada (julio 2025, solo lectura, sin mutar ninguna tabla)

Se identificó una estancia de origen real con ingreso el 2025-07-02 y alta el
2025-08-07 (confirmado contra `procedimiento_cpt`/`prestacion_cpt`, lado
CPT). Esta estancia **debe facturar íntegra en agosto**, no en julio.

- **Lado CPT (con PARCHE D aplicado)**: correcto. Al simular agosto en modo
  solo lectura (`sp_hospitalizacion_en_periodo('2025-08-01','2025-08-31')`
  invocada directamente, sin escribir ninguna tabla), se encontraron 5
  procedimientos de esa estancia con fecha entre 02 y 15 de julio,
  correctamente ligados a la estancia que cierra en agosto — y verificado
  que NINGUNO de ellos aparece hoy en la trama de julio del lado CPT.
- **Lado SIGESAPOL**: incorrecto. La trama de hospitalización de julio
  (`temp_bdt_hospitalizacion_local`, ya generada) tiene **14 filas** para
  ese mismo paciente con `fecha_atencion` desde el 2025-07-02 en adelante —
  procedimientos de la estancia que se dará de alta en agosto, ya
  facturados indebidamente en julio. Se confirmó por descarte que estas 14
  filas NO provienen de CPT (0 coincidencias en `prestacion_cpt`/
  `procedimiento_cpt` para ese documento+fecha), por lo que solo pueden
  venir de `temp_sigesapol_procedimientos` (lado SIGESAPOL).

**Consecuencia si no se corrige antes de generar agosto**: cuando se
regenere agosto, esta misma estancia entrará correctamente completa (con sus
procedimientos de julio incluidos, por el lado CPT ya corregido, y de nuevo
por el lado SIGESAPOL sin corregir) — las 14 filas ya cobradas en julio se
**duplicarían**, cobrándose una segunda vez en agosto. Esto es exactamente
el escenario que A8 (no-duplicación entre períodos) está diseñada para
detectar, y por lo que la parte 4 de la misión (rollout agosto-diciembre)
pide "atención especial a las estancias en stand-by que cambian de mes".

## 3. Alcance del bug

Afecta **toda fila de `temp_sigesapol_procedimientos`** con
`id_tipo_atencion IN (2, 3, 6, 8)` (emergencia y hospitalización, ambas
ramas) para **cualquier período ya generado o por generar**, no solo julio.
Es estructuralmente el mismo defecto que tenían `sp_procedimientos_segun_
tipo_atencion` y `sp_laboratorio_segun_tipo_atencion` antes de PARCHE D,
solo que en SIGESAPOL nunca hubo ni siquiera el filtro parcial (`fecha <=
p_fin_periodo`) que esas funciones CPT sí tenían — aquí es un filtro de
calendario puro (`BETWEEN p_ini AND p_fin`), sin ninguna referencia a la
estancia en absoluto.

## 4. Fix propuesto (PARCHE E, pendiente de aprobación — no aplicado aún)

Acotar las ramas de emergencia (tipo 2) y hospitalización (tipo 3/6/8) de
`06_FASE2_SIGESAPOL_procedimientos.sql` con un `EXISTS` contra la ventana
`[ingreso, alta]` de la estancia específica, mismo patrón que PARCHE D:

- Para tipo 2 (emergencia): `EXISTS (SELECT 1 FROM
  temp_emergencia_sigesapol_estancia et WHERE et.sp_numero_documento_paciente
  = a.nro_doc_ident AND pre.fecha_atencion BETWEEN et.sp_fecha_atencion AND
  et.sp_fecha_alta_emergencia)` — tabla ya disponible en la BD SIGESAPOL en
  el momento en que corre el paso 3 (se crea en el paso 1).
- Para tipo 3/6/8 (hospitalización): `EXISTS (SELECT 1 FROM
  temp_hospitalizacion_sigesapol_estancia ht WHERE ht.sp_numero_documento_
  paciente = a.nro_doc_ident AND pre.fecha_atencion BETWEEN ht.sp_fecha_
  atencion AND ht.sp_fecha_alta)` — tabla ya disponible (se crea en el
  paso 2, antes del paso 3).
- Tipo 1/5/7 (consulta) queda sin cambios (el filtro de calendario ya es
  correcto para ambulatorio).

Falta confirmar el nombre exacto de la columna de documento en `asegurados`
(`a.nro_doc_ident`, verificado en `02_MAESTRO_paso1_SIGESAPOL.sql`) y el
formato de comparación (mismo padding que ya usa el resto del script) antes
de escribir el `CREATE OR REPLACE`/edición final.

## 5. Pendiente

- [ ] Aprobar el diseño del fix (EXISTS por ventana de estancia, igual
      criterio que PARCHE D).
- [ ] Aplicar el fix a `06_FASE2_SIGESAPOL_procedimientos.sql` (raíz) y
      regenerar el espejo `consola/4_06_FASE2_SIGESAPOL_procedimientos.sql`.
- [ ] Re-generar julio con el fix aplicado (pasos 1-11) y confirmar que las
      14 filas contaminadas desaparecen de `temp_bdt_hospitalizacion_local`.
- [ ] Completar la validación caso (c) de la misión original (muestra de 10
      de las -743 filas removidas de julio) con julio ya limpio en ambos
      lados (CPT + SIGESAPOL).
- [ ] Verificar si existe el mismo patrón en algún otro script SIGESAPOL no
      revisado todavía (p. ej. si hay una extracción de laboratorio
      separada; en este pipeline el laboratorio SIGESAPOL viaja en la misma
      tabla `temp_sigesapol_procedimientos` que los procedimientos médicos,
      así que el mismo fix cubriría ambos — pendiente confirmar que no hay
      una segunda fuente).
- [ ] Una vez corregido y verificado, integrar el resumen a
      `CONTEXTO_CANONICO.md` §3 como "PARCHE E" y actualizar la regla
      inmutable §1.11 si hace falta precisar algo sobre el lado SIGESAPOL.
