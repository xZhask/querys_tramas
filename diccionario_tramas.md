# Diccionario de columnas — tramas STIPS (01_TRAMAS/*.txt)

> Referencia de solo lectura. Los archivos `01_TRAMAS/*.txt` son texto
> delimitado por `|` **sin fila de cabecera** — es el formato que exige el
> validador STIPS de SALUDPOL, y agregarle una fila de títulos haría que el
> validador lo rechace. Este documento existe para dar esa referencia sin
> tocar los `.txt`: aquí sí se listan los nombres, en el mismo orden exacto
> en que aparecen las columnas separadas por `|` en cada archivo.
>
> Generado a partir de `.trama_columns.json` (mismo array de columnas que
> escribe el pipeline en `03_INFORMATIVOS/` de cada período — determinado
> por el código de `generate_outputs_v2.py`, no por los datos, así que es
> idéntico mes a mes; verificado igual en 2025-07 y 2025-12). Si el pipeline
> cambia el orden o agrega/quita una columna, este archivo debe regenerarse
> a partir del `.trama_columns.json` de un período nuevo — no editar a mano.
>
> No contiene datos de pacientes (regla inmutable §1.10) — solo nombres de
> columna.

## CSV de análisis (`04_ANALISIS/*.csv`, generados desde 2026-07-22)

Desde `generate_outputs_v2.py`, cada corrida del pipeline escribe además, en
`expedientes/<periodo>/04_ANALISIS/`, una copia en CSV de cada una de las 4
tramas — mismos valores fila por fila que su `.txt` correspondiente en
`01_TRAMAS/`, pero:

- **con fila de cabecera** (los mismos nombres de columna listados abajo),
- **UTF-8 con BOM** (tildes/ñ correctas en Excel, sin filas fantasma en la
  vista de filtro),
- con una columna adicional **`Prestacion_ID`** al final, **vacía** — sirve
  para que Auditoría Médica la llene a mano tras su revisión (mismo patrón
  que la data de la gestión anterior, `TRAMA JUNIO 2025 VERSION FINAL_v2.xlsx`,
  donde ese campo aparecía en blanco hasta la revisión). El pipeline nunca
  la llena — es un paso posterior, manual, fuera de este proceso.

Estos CSV son **para análisis y comparación** (contra la data de la gestión
anterior, o entre meses) — **no son el archivo que se remite a SALUDPOL**.
El envío oficial sigue siendo exclusivamente `01_TRAMAS/*.txt`, sin cabecera,
sin la columna `Prestacion_ID`, sin ningún cambio de formato.


## trama_consulta_externa.txt (37 columnas)

| # | Columna |
| --- | --- |
| 1 | `base` |
| 2 | `sp_tipo_documento_paciente` |
| 3 | `sp_numero_documento_paciente` |
| 4 | `sp_apellido_paterno_paciente` |
| 5 | `sp_apellido_materno_paciente` |
| 6 | `sp_nombres_paciente` |
| 7 | `sp_fecha_nacimiento` |
| 8 | `sp_genero_paciente` |
| 9 | `sp_condicion_asegurado` |
| 10 | `sp_tipo_atencion` |
| 11 | `sp_codigo_ipress` |
| 12 | `sp_nombre_ipress` |
| 13 | `sp_fecha_atencion` |
| 14 | `sp_fecha_alta` |
| 15 | `sp_tipo_documento_responsable` |
| 16 | `sp_numero_documento_responsable` |
| 17 | `sp_apellido_paterno_responsable` |
| 18 | `sp_apellido_materno_responsable` |
| 19 | `sp_nombres_responsable` |
| 20 | `sp_profesion_responsable` |
| 21 | `sp_especialidad_responsable` |
| 22 | `sp_circunstancia_alta` |
| 23 | `sp_upss_servicio` |
| 24 | `sp_upss_descripcion` |
| 25 | `sp_hospitalizacion` |
| 26 | `sp_tipo_diagnostico` |
| 27 | `sp_codigo_diagnostico` |
| 28 | `sp_descripcion_diagnostico` |
| 29 | `sp_codigo_procedimiento` |
| 30 | `sp_descripcion_procedimiento` |
| 31 | `sp_suma_cantidad` |
| 32 | `sp_valorizacion_total` |
| 33 | `digitador_cpt` |
| 34 | `fecha_registro_cpt` |
| 35 | `hora_registro_cpt` |
| 36 | `id_prestacion_cpt` |
| 37 | `id_prestacion_laboratorio` |


## trama_emergencia.txt (59 columnas)

| # | Columna |
| --- | --- |
| 1 | `base` |
| 2 | `prioridad` |
| 3 | `sp_tipo_documento_paciente` |
| 4 | `sp_numero_documento_paciente` |
| 5 | `sp_apellido_paterno_paciente` |
| 6 | `sp_apellido_materno_paciente` |
| 7 | `sp_nombres_paciente` |
| 8 | `sp_fecha_nacimiento` |
| 9 | `sp_genero_paciente` |
| 10 | `sp_condicion_asegurado` |
| 11 | `sp_tipo_atencion` |
| 12 | `sp_codigo_ipress` |
| 13 | `sp_nombre_ipress` |
| 14 | `sp_fecha_atencion` |
| 15 | `sp_fecha_alta` |
| 16 | `sp_tipo_documento_responsable` |
| 17 | `sp_numero_documento_responsable` |
| 18 | `sp_apellido_paterno_responsable` |
| 19 | `sp_apellido_materno_responsable` |
| 20 | `sp_nombres_responsable` |
| 21 | `sp_profesion_responsable` |
| 22 | `sp_especialidad_responsable` |
| 23 | `sp_circunstancia_alta` |
| 24 | `sp_upss_codigo` |
| 25 | `sp_upss_descripcion` |
| 26 | `hospitalizacion` |
| 27 | `sp_tipo_dx_01` |
| 28 | `sp_codigo_dx_01` |
| 29 | `sp_descripcion_dx_01` |
| 30 | `sp_tipo_dx_02` |
| 31 | `sp_codigo_dx_02` |
| 32 | `sp_descripcion_dx_02` |
| 33 | `sp_tipo_dx_03` |
| 34 | `sp_codigo_dx_03` |
| 35 | `sp_descripcion_dx_03` |
| 36 | `digitador_prestacion` |
| 37 | `fecha_registro_prestacion` |
| 38 | `hora_registro_prestacion` |
| 39 | `id_atencion_emergencia` |
| 40 | `sp_codigo_procedimiento` |
| 41 | `sp_descripcion_procedimiento` |
| 42 | `sp_suma_cantidad` |
| 43 | `sp_valorizacion_total` |
| 44 | `documento_responsable_cpt` |
| 45 | `nombre_responsable_cpt` |
| 46 | `upss_codigo_cpt` |
| 47 | `upss_descripcion_cpt` |
| 48 | `fecha_procedimiento` |
| 49 | `upss_codigo_procedimiento` |
| 50 | `upss_descripcion_procedimiento` |
| 51 | `numero_documento_responsable_procedimiento` |
| 52 | `apellido_paterno_responsable_procedimiento` |
| 53 | `apellido_materno_responsable_procedimiento` |
| 54 | `nombres_responsable_procedimiento` |
| 55 | `digitador_cpt` |
| 56 | `fecha_registro_cpt` |
| 57 | `hora_registro_cpt` |
| 58 | `id_prestacion_cpt` |
| 59 | `id_prestacion_laboratorio` |


## trama_hospitalizacion.txt (51 columnas)

| # | Columna |
| --- | --- |
| 1 | `base` |
| 2 | `sp_tipo_documento_paciente` |
| 3 | `sp_numero_documento_paciente` |
| 4 | `sp_apellido_paterno_paciente` |
| 5 | `sp_apellido_materno_paciente` |
| 6 | `sp_nombres_paciente` |
| 7 | `sp_fecha_nacimiento` |
| 8 | `sp_genero_paciente` |
| 9 | `sp_condicion_asegurado` |
| 10 | `sp_tipo_atencion` |
| 11 | `sp_codigo_ipress` |
| 12 | `sp_nombre_ipress` |
| 13 | `sp_fecha_atencion` |
| 14 | `sp_fecha_alta` |
| 15 | `sp_tipo_documento_responsable` |
| 16 | `sp_numero_documento_responsable` |
| 17 | `sp_apellido_paterno_responsable` |
| 18 | `sp_apellido_materno_responsable` |
| 19 | `sp_nombres_responsable` |
| 20 | `sp_profesion_responsable` |
| 21 | `sp_especialidad_responsable` |
| 22 | `sp_circunstancia_alta` |
| 23 | `sp_upss_codigo` |
| 24 | `sp_upss_descripcion` |
| 25 | `hospitalizacion` |
| 26 | `sp_tipo_dx_01` |
| 27 | `sp_codigo_dx_01` |
| 28 | `sp_descripcion_dx_01` |
| 29 | `sp_tipo_dx_02` |
| 30 | `sp_codigo_dx_02` |
| 31 | `sp_descripcion_dx_02` |
| 32 | `sp_tipo_dx_03` |
| 33 | `sp_codigo_dx_03` |
| 34 | `sp_descripcion_dx_03` |
| 35 | `digitador_prestacion` |
| 36 | `fecha_registro_prestacion` |
| 37 | `hora_registro_prestacion` |
| 38 | `id_prestacion_cpt` |
| 39 | `sp_codigo_procedimiento` |
| 40 | `sp_descripcion_procedimiento` |
| 41 | `sp_suma_cantidad` |
| 42 | `sp_valorizacion_total` |
| 43 | `documento_responsable_cpt` |
| 44 | `nombre_responsable_cpt` |
| 45 | `upss_codigo_cpt` |
| 46 | `upss_descripcion_cpt` |
| 47 | `digitador_cpt` |
| 48 | `fecha_atencion_procedimiento` |
| 49 | `fecha_registro_cpt` |
| 50 | `hora_registro_cpt` |
| 51 | `id_prestacion_laboratorio` |


## trama_farmacia.txt (48 columnas)

| # | Columna |
| --- | --- |
| 1 | `paciente_tipo_documento` |
| 2 | `paciente_numero_documento` |
| 3 | `paterno_beneficiario` |
| 4 | `materno_beneficiario` |
| 5 | `nombre_beneficiario` |
| 6 | `fecha_nacimiento_pnp` |
| 7 | `sexo_paciente` |
| 8 | `tipo_beneficiario_pnp` |
| 9 | `tipo_atencion` |
| 10 | `ipress_codigo` |
| 11 | `eess` |
| 12 | `fecha_atencion_medica` |
| 13 | `fecha_dispensacion` |
| 14 | `dni_medico` |
| 15 | `paterno_medico` |
| 16 | `materno_medico` |
| 17 | `nomb_medico` |
| 18 | `sp_nombre_profesion_responsable` |
| 19 | `sp_codigo_profesion_responsable` |
| 20 | `sp_codigo_especialidad` |
| 21 | `fecha_dispensacion_como_atencion` |
| 22 | `sp_fecha_alta` |
| 23 | `sp_circunstancia_alta` |
| 24 | `codigo_upss` |
| 25 | `servicio` |
| 26 | `hospitalizacion` |
| 27 | `id_tipo_diagnostico` |
| 28 | `cod_dx` |
| 29 | `diagnostico` |
| 30 | `genero` |
| 31 | `dni_dispensacion` |
| 32 | `paterno_dispensacion` |
| 33 | `materno_dispensacion` |
| 34 | `nomb_dispensador` |
| 35 | `tipo` |
| 36 | `tipo_producto` |
| 37 | `cod_petitorio` |
| 38 | `principio_activo` |
| 39 | `cod_trama` |
| 40 | `desc_trama` |
| 41 | `cantidad` |
| 42 | `precio_unitario` |
| 43 | `precio_ejecutora` |
| 44 | `precio_trama` |
| 45 | `valorizado_1` |
| 46 | `codigo_procedimiento` |
| 47 | `nombre_procedimiento` |
| 48 | `precio_tarifario_procedimiento` |
