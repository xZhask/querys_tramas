# Informe de Cierre de Semestre: Armonización, Deduplicación y Reclasificación de Tramas LNS (Julio - Diciembre 2025)

## 1. Resumen Ejecutivo

Este informe consolida los resultados técnicos, operativos y económicos del procesamiento, depuración y reclasificación de las tramas médicas de Consulta Externa, Emergencia, Hospitalización y Farmacia del Hospital LNS para el periodo de **julio a diciembre de 2025**.

La implementación del nuevo pipeline automatizado ha permitido integrar de manera hermética las bases de datos de **CPT (Sistema local de facturación)** y **SIGESAPOL (Sistema institucional en adopción y fuente canónica)**. Se resolvieron de forma definitiva las inconsistencias de CPMS de alta en emergencias y se aplicó la regla de permanencia mayor a 24 horas.

### Hitos Clave del Semestre:
* **Monto Total Recuperado por Regla de 24 Horas**: Se capturó una facturación adicional y defendible de **S/. 8,423,094.54** mediante la reclasificación de estancias de emergencia de más de 24 horas a hospitalización especializada.
* **Ahorro Financiero por Deduplicación**: Se previno un doble cobro potencial de **S/. 491,713.41** al eliminar automáticamente duplicidades de prestaciones idénticas registradas en CPT y SIGESAPOL.
* **Volumen Total Procesado**: Se depuraron y generaron entregables finales con **1,777,176 registros** en Consulta Externa, **198,580** en Emergencia, **229,846** en Hospitalización y **647,780** dispensaciones de Farmacia.
* **Hermeticidad y Consistencia**: El 100% de los lotes cerró con **cero duplicados de origen y cero registros con doble cobro** entre la trama de emergencia y la trama de hospitalización (CONTROL 10 = 0).

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
| **Julio 2025** | 262,869 | 33,189 | 67,824 | 105,695 | **469,577** |
| **Agosto 2025** | 263,881 | 32,198 | 57,383 | 103,259 | **456,721** |
| **Setiembre 2025** | 293,885 | 32,229 | 56,086 | 118,418 | **500,618** |
| **Octubre 2025** | 348,338 | 31,950 | 17,453 | 118,985 | **516,726** |
| **Noviembre 2025** | 316,838 | 35,213 | 16,078 | 102,456 | **470,585** |
| **Diciembre 2025** | 291,365 | 33,801 | 15,022 | 98,967 | **439,155** |
| **TOTAL TRAMA** | **1,777,176** | **198,580** | **229,846** | **647,780** | **2,853,382** |

> [!NOTE]
> **Nota sobre el Volumen de Hospitalización (Variación Intermensual)**:
> La aparente caída en el número de líneas registradas en Hospitalización a partir de octubre (de ~57k-67k a ~15k-17k) no responde a una reducción en los ingresos de pacientes, sino a la diferencia de granularidad y formato de los registros entre los sistemas. Mientras CPT (canónico jul-sep) registra un desglose detallado de múltiples líneas de consumo e insumos de estancia por día, SIGESAPOL (canónico oct-dic) utiliza un registro de estancias consolidado. El número de egresos hospitalarios físicos reales se mantuvo en niveles estables y equivalentes a lo largo de todo el semestre.

---

## 4. Recuperación Adicional por Regla de 24 Horas y Reclasificación

Siguiendo la directiva institucional, las emergencias con una duración real superior a 24 horas son reclasificadas a Hospitalización (Tipo 3). Aquellas que se solapan o tocan con una hospitalización existente se unifican en un rango único (Caso A). Las que no registran hospitalización previa se convierten en nuevas estancias hospitalarias con código CPMS `99231.15` (Caso B).

Por otro lado, las emergencias con duración real menor o igual a 24 horas permanecen como Tipo 2 en la trama de emergencias, forzando su CPMS al código canonical de consulta según su prioridad médica (99281-99285). Las estancias mayores a 15 días acumulados que cruzan de mes son catalogadas como Cierre Administrativo para depuración y no se facturan.

A continuación se detalla la cuadratura exacta y el impacto financiero mensual de esta regla:

| Período | Emergencias Totales | Tipo 2 Facturadas | Caso B Reclass (Nueva Hosp) | Caso A Unidas (Overlap Hosp) | Cierre Admin (Excluidas) | Excluidas por Solapamiento | Residuo | Facturación Recuperada Neto (S/.) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Julio 2025** | 8,388 | 7,651 | 248 | 67 | 79 | 343 | 0 | S/. 1,115,969.98 |
| **Agosto 2025** | 8,401 | 7,704 | 264 | 64 | 15 | 354 | 0 | S/. 1,273,653.66 |
| **Setiembre 2025** | 8,770 | 8,075 | 277 | 60 | 13 | 345 | 0 | S/. 1,202,182.34 |
| **Octubre 2025** | 8,798 | 7,858 | 509 | 12 | 336 | 83 | 0 | S/. 1,581,380.02 |
| **Noviembre 2025** | 10,021 | 8,921 | 707 | 13 | 297 | 83 | 0 | S/. 1,716,844.32 |
| **Diciembre 2025** | 9,330 | 8,595 | 557 | 21 | 57 | 100 | 0 | S/. 1,533,064.22 |
| **TOTAL** | **53,708** | **48,804** | **2,562** | **237** | **797** | **1,308** | **0** | **S/. 8,423,094.54** |

> [!NOTE]
> **Nota sobre Emergencias Excluidas por Solapamiento**:
> Las 1,308 emergencias excluidas por solapamiento corresponden a pacientes hospitalizados el mismo día de su atención de emergencia (la transición E→H clásica). Conforme a la práctica institucional de unificación de estancias del LNS, su atención de emergencia se absorbe en la estancia de hospitalización y no genera un cobro Tipo 2 independiente. Queda a criterio de la Unidad de Auditoría Médica confirmar si corresponde facturar adicionalmente la consulta de emergencia (códigos 99281–99285) de estas atenciones, conforme a la normativa general de doble atención E→H.

> [!IMPORTANT]
> **Nota de Validación Médica**:
> Toda facturación reclasificada a hospitalización por permanencia en emergencias superior a 24 horas (Caso B y Caso A) se encuentra **sujeta a validación final y auditoría por parte de la Unidad de Auditoría Médica**. Los auditores médicos deberán refrendar las historias clínicas asociadas para confirmar la justificación de la estancia prolongada antes de la presentación formal del expediente de cobro a SALUDPOL.

---

## 5. Observaciones de Auditoría por Categoría y Mes

Además del descarte automático, el pipeline extrajo alertas de auditoría médica para revisión manual en la carpeta `expedientes/` para sustento ante auditorías externas de SALUDPOL:

* **Médico Distinto (Revisar)**: Prestaciones coincidentes en Paciente-Fecha-Procedimiento pero con firmas de médicos tratantes diferentes entre sistemas (indica posibles dobles registros legítimos o errores de digitación).
* **Cantidad Distinta (Revisar)**: Prestaciones de laboratorio o imágenes donde la cantidad facturada difiere entre CPT y SIGESAPOL.
* **Estancias Contiguas/Solapadas (C11)**: Casos de hospitalizaciones contiguas o solapadas del mismo paciente, detectadas en CPT (CONTROL 9) y clasificadas para revisión de traslado doble de cama en auditoría.
* **Duplicados en Origen**: Prestaciones registradas dos veces dentro del propio sistema de origen SIGESAPOL.
* **Estancias de emergencia sin CPMS en origen (informativo)**: Egresos de emergencia registrados originalmente sin un código CPMS de alta médica, para los cuales el pipeline asignó el código correspondiente de consulta por prioridad (99281-99285) de forma automatizada (ya no representa un riesgo de derivación en la trama).
* **CPMS Derivado Hospitalización**: Estancias hospitalarias que no contaban con código CPMS de egreso en el origen y que el algoritmo imputó automáticamente a través de fallbacks regulatorios según la clase de cama asignada.

| Categoría de Observación | Julio | Agosto | Setiembre | Octubre | Noviembre | Diciembre | TOTAL |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Médico Distinto (Revisar)** | 384 | 297 | 371 | 271 | 296 | 283 | **1,902** |
| **Cantidad Distinta (Revisar)** | 277 | 209 | 148 | 0 | 0 | 2 | **636** |
| **Estancias Contiguas/Solapadas (C11)** | 724 | 756 | 761 | 731 | 928 | 775 | **4,675** |
| **Duplicados en Origen** | 149 | 357 | 315 | 407 | 499 | 582 | **2,309** |
| **Estancias de emergencia sin CPMS en origen (informativo)** | 1,812 | 1,830 | 2,039 | 1,841 | 1,621 | 1,538 | **10,681** |
| **CPMS Derivado Hospitalización** | 861 | 1,002 | 1,095 | 1,286 | 1,257 | 1,376 | **6,877** |

---

## 6. Incidencias Técnicas Resueltas durante el Proceso

Durante la corrida del lote semestral, se identificaron y resolvieron las siguientes incidencias técnicas:

1. **Aceleración por Índices Compuestos**:
   La consolidación de tablas demoraba más de 19 minutos por mes. Se automatizó la creación de índices compuestos por la llave (`numero_documento_paciente, fecha_atencion, codigo_procedimiento`), reduciendo el tiempo de proceso a **3.5 segundos por mes**.
2. **Error Sintáctico por BOM y codificaciones ANSI**:
   Los scripts psql fallaban debido a cabeceras UTF-8 BOM invisibles generadas por redirecciones PowerShell y lecturas ANSI de caracteres acentuados. Se implementó una rutina de lectura UTF-8 explícita a través de la API de .NET (`[System.IO.File]::ReadAllText`), garantizando la correcta codificación de acentos y caracteres especiales.
3. **Mapeo de la Estructura de Camas en Hospitalización**:
   Se corrigió la búsqueda de la columna de clasificación en la base de datos de origen, permitiendo la valorización correcta del 100% de las estancias hospitalarias de SIGESAPOL.
4. **Control de Cruce de Medianoche (V1)**:
   Se detectó que el cálculo por días calendario consideraba incorrectamente como reclass a hospitalización las estancias breves que ingresaban un día y salían al día siguiente (duración <= 24h). Se modificó la regla a duración por intervalo real (`sp_fecha_alta_emergencia - sp_fecha_atencion > INTERVAL '24 hours'`), salvando **1,433 registros** de emergencias breves en Julio de ser catalogados erróneamente.

---

## 7. Pendientes Institucionales y Recomendaciones para la Jefatura

1. **Corte Definitivo entre Sistemas (Apagar CPT)**:
   Los datos demuestran que a partir de octubre de 2025, el 90% de las prestaciones y el 99% de las estancias de hospitalización ya se registran de forma nativa en SIGESAPOL. Se recomienda establecer una fecha de corte definitivo para apagar el ingreso de datos en CPT, reduciendo a cero el costo operativo de consolidar bases de datos.
2. **Capacitación para el llenado de cpms_alta en origen**:
   Se detectó que **10,681 egresos de emergencia** y **6,877 de hospitalización** se grabaron originalmente sin código de alta CPMS. Se sugiere capacitar al personal médico para el llenado obligatorio de la codificación al momento del alta para evitar el uso de fallbacks lógicos automatizados.
3. **Actualización de Tarifario (Tarifas en Cero)**:
   Se identificaron procedimientos que se valorizan con importe "cero" debido a la falta de concordancia entre los códigos del petitorio LNS y los códigos estandarizados CPMS. Es urgente actualizar la tabla de equivalencias de precios de la IPRESS para evitar pérdidas financieras.
4. **Alerta Automática a las 20 horas de Estancia en Emergencia**:
   Se recomienda implementar una alerta automática en el sistema SIGESAPOL cuando un paciente cumpla **20 horas continuas de permanencia en Emergencia**. Esto servirá de aviso temprano al personal médico y administrativo para gestionar el traslado físico y formal del paciente a Hospitalización o su alta oportuna, evitando las reclasificaciones tardías. Los **2,562 casos del semestre** que terminaron convirtiéndose en hospitalizaciones de de facto (Caso B) sustentan la necesidad crítica de esta alerta como instrumento de control y reducción de glosas.
