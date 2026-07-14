# Análisis de Impacto de Corrección de CPMS de Emergencia (Lote Semestral 2025)

Este documento detalla la comparación antes y después de aplicar la regla de las 24 horas real (duración real > 24 horas, excluyendo cruces de medianoche) y reclasificación de estancias de emergencia a hospitalización en las tramas exportadas y base de datos para el periodo de **Julio 2025**.

---

## Checkpoint: Julio 2025

### 1. Comparación en Trama de Emergencia (`trama_emergencia.txt`)

| Métrica | Antes de la Reclasificación | Después de la Reclasificación (V2) | Diferencia Neta |
| :--- | :---: | :---: | :---: |
| **Filas / Registros** | 40,117 | 33,189 | **-6,928** |
| **Monto Valorizado (S/.)** | S/. 1,550,441.41 | S/. 1,183,080.84 | **-S/. 367,360.57** |

#### Desglose de Emergencia después de la Reclasificación:
* **Estancias en Emergencia (Tipo 2)**: 7,651 filas | **S/. 250,095.37** *(Se activó el reporte de estancias <= 24h, forzando códigos CPMS por prioridad y tarifa canonical)*
* **Procedimientos CPT-SIGESAPOL**: 14,176 filas | **S/. 728,461.45**
* **Laboratorios CPT-SIGESAPOL**: 11,362 filas | **S/. 204,524.02**

> [!NOTE]
> La corrección V2 ignora cualquier código `cpms_alta` pre-almacenado incorrecto (como `99234` o `99231.15`) en estancias de emergencia, forzándolos a códigos de consulta por prioridad (99281-99285) con cantidad 1, alineados con la práctica de SALUDPOL.

---

### 2. Comparación en Trama de Hospitalización (`trama_hospitalizacion.txt`)

| Métrica | Antes de la Reclasificación | Después de la Reclasificación (V1) | Diferencia Neta |
| :--- | :---: | :---: | :---: |
| **Filas / Registros** | 51,697 | 67,824 | **+16,127** |
| **Monto Valorizado (S/.)** | S/. 6,333,089.49 | S/. 7,810,262.77 | **+S/. 1,477,173.28** |

#### Desglose de Hospitalización después de la Reclasificación:
* **Estancia Hospitalaria (Tipo 3)**: 1,452 filas | **S/. 4,479,085.00**
  * *Originales (Pre-existentes)*: 1,025 filas
  * *Unidas (Caso A)*: 179 filas *(Absorbieron emergencias contiguas o solapadas)*
  * *Nuevas por Permanencia > 24h real (Caso B)*: 248 filas *(Código CPMS 99231.15)*
* **Procedimientos Hospitalización (Originales)**: 28,048 filas | **S/. 2,252,771.92**
* **Laboratorios Hospitalización (Originales)**: 28,492 filas | **S/. 614,827.92**
* **Procedimientos Reclasificados (desde Emergencia > 24h)**: 3,444 filas | **S/. 335,203.70**
* **Laboratorios Reclasificados (desde Emergencia > 24h)**: 6,387 filas | **S/. 128,374.23**

---

### 3. Resumen del Impacto Financiero y Controles de Integridad

* **Impacto Financiero Neto (Julio 2025)**: **+S/. 1,115,969.98** *(Adicional facturado y defendible)*
* **Control de No-Doble-Reporte (CONTROL 10)**: **0** *(Verificado exitosamente: ningún documento + fecha + código se repite simultáneamente entre tramas).*
* **Estancias Solapadas / Contiguas CPT (CONTROL 9)**: **39 casos** detectados y clasificados como Transferencia de Cama en auditoría para revisión manual.

> [!IMPORTANT]
> **Impacto del Fix de Cruce de Medianoche (V1):**
> De las estancias de emergencia originalmente consideradas de "más de 1 día", **1,433 registros** tenían una duración real menor o igual a 24 horas (cruces de medianoche). Al aplicar la regla de duración real (`sp_fecha_alta_emergencia - sp_fecha_atencion > INTERVAL '24 hours'`), estos registros fueron devueltos a la trama de emergencias como Tipo 2 y facturados bajo tarifa canonical, eliminando riesgos de auditoría por doble facturación de estancia. Solo **315 registros** cumplieron la regla real de permanencia > 24 horas y fueron reclasificados a Hospitalización.
