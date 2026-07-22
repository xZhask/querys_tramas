# HALLAZGO — Duplicación de origen SIGESAPOL en el instante de transferencia
# Emergencia→Hospitalización (dos variantes, sin corregir)

> Encontrado 2026-07-21 durante la regeneración de julio/agosto/septiembre con
> PARCHE D+E aplicado, al investigar por qué A8 (no-duplicación entre
> períodos) seguía marcando FALLO entre meses YA regenerados con el fix
> (no explicable por "el otro período sigue sin parche"). Cuantificado
> 2026-07-21 (mismo día, segunda pasada, solo lectura). Documento standalone
> por el mismo motivo que `HALLAZGO_SIGESAPOL_ventana_estancia.md` —
> pendiente de integrar a `CONTEXTO_CANONICO.md` §3 una vez que Auditoría
> Médica decida el tratamiento.
>
> **Este archivo NO contiene documento ni nombre de paciente** (regla
> inmutable §1.10) — los casos usan identificador de sesión (`Paciente A/B/C`).
>
> **Actualización 2026-07-22 — Variante A cerrada jun-dic; Variante B queda
> como pregunta abierta para Auditoría Médica, no como cifra del pipeline.**
> Ver §3.1 (Variante A, ahora con nov-dic) y §3.2 (por qué Variante B no se
> cuantifica). Motivado por la implementación de clasificación
> conocido/nuevo en A8 (`14_VERIFICAR_ASERTOS.py`) — A8 ya reconoce ambas
> variantes como conocido-explicado sin necesitar un monto cerrado de
> Variante B para eso; el monto solo hace falta para el informe de
> Dirección/Auditoría, y ahí no se puede escribir un número que no pasó su
> propio certificado (regla §4 de `CONTEXTO_CANONICO.md`).

---

## 1. Resumen del hallazgo

PARCHE D (CPT) y PARCHE E (SIGESAPOL) corrigen la ventana de estancia para
**emergencia y hospitalización** (tipo_atencion 2/3/6/8): cada procedimiento
solo entra si cae dentro de `[ingreso, alta]` de LA estancia específica. Con
julio y agosto ya regenerados con ambos parches, A8 (no-duplicación entre
períodos, `14_VERIFICAR_ASERTOS.py`) seguía marcando filas repetidas entre
períodos que **ya no deberían tener el bug de ventana**. Investigado caso por
caso: la causa no es la ventana de estancia — es que **SIGESAPOL registra el
mismo código+cantidad dos veces** en el instante exacto en que una emergencia
se transfiere a hospitalización (alta de emergencia = ingreso de
hospitalización, mismo día o mismo instante). Se identificaron **dos
variantes** del mismo mecanismo de fondo:

- **Variante A — CONSULTA duplica la estancia**: el código aparece una vez
  como **`id_tipo_atencion = 1` (CONSULTA)** — categoría que, por diseño
  (consulta no tiene noción de "estancia"), **nunca lleva ventana**: factura
  siempre por calendario puro, en el mes de su propia fecha — y otra vez
  dentro del paquete de procedimientos de la emergencia/hospitalización real
  (`id_tipo_atencion` 2/3/6/8), que sí factura correctamente en el mes del
  alta de esa estancia.
- **Variante B — la propia EMERGENCIA duplica la HOSPITALIZACIÓN**: sin
  ningún registro CONSULTA de por medio, el código aparece una vez ligado a
  la prestación de la emergencia (`id_tipo_atencion = 2`, la misma que
  participa en la transferencia) y otra vez dentro del paquete de la
  hospitalización (`id_tipo_atencion` 3/6/8) que la absorbe. Como la
  emergencia por sí sola SÍ tiene ventana propia (PARCHE E), esta variante
  solo cruza de período cuando la emergencia y la hospitalización cierran en
  meses distintos.

En ambas variantes, cuando la estancia real cierra en un mes distinto al del
registro duplicado, el mismo procedimiento aparece en dos períodos distintos
— doble cobro potencial a SALUDPOL por el mismo servicio clínico. Ninguna
regla de deduplicación existente cubre esto: el paso 6
(`07_FASE2_deduplicacion_CPT_SIGESAPOL.sql`) dedupe CPT vs SIGESAPOL por la
llave de tipo de procedimiento (regla inmutable §1.2), pero esto es
SIGESAPOL contra sí mismo, cruzando tipo de atención — una categoría de
duplicado no contemplada.

## 2. Evidencia verificada (julio/agosto, solo lectura, sin mutar tablas)

**Paciente A** (variante A; overlap detectado por A8 entre julio y agosto
regenerados): emergencia con alta 2025-07-16 00:00 → hospitalización con
ingreso 2025-07-16 00:00 (mismo instante, transferencia física inmediata).
SIGESAPOL tiene un registro `id_tipo_atencion=1` fechado 2025-07-16 con 4
códigos (evaluación + interconsulta) que coinciden EXACTAMENTE con códigos
del mismo día dentro del paquete de la hospitalización (`id_tipo_atencion=3`,
que trae además numerosos códigos repetidos internamente — calidad de dato
aparte, fuera del alcance de este hallazgo). La hospitalización cierra en
agosto (alta 2025-08-01); el registro CONSULTA, sin ventana, factura en
julio de todas formas.

**Paciente B** (variante A; overlap entre agosto y septiembre): mismo patrón
exacto — emergencia con alta 2025-08-29 00:00 → hospitalización con ingreso
2025-08-29 00:00. Registro `id_tipo_atencion=1` duplicado el mismo día con
los mismos códigos que arrastra la hospitalización (que cierra en
septiembre).

**Paciente C** (variante B, no A — corregido tras verificar en detalle;
overlap entre agosto y septiembre): emergencia con alta 2025-08-27 →
hospitalización con ingreso 2025-08-27 mismo día. Aquí **no** hay ningún
registro CONSULTA involucrado: el código de radiología duplicado aparece una
vez ligado directamente a la prestación de la emergencia
(`id_tipo_atencion=2`, fecha 2025-08-27) y otra vez dentro del paquete de la
hospitalización (`id_tipo_atencion=3`, fecha 2025-08-28) que la absorbió.

Un cuarto caso investigado (overlap agosto vs. octubre) **no** corresponde a
ninguna de las dos variantes: es una cadena emergencia(>24h)→hospitalización
real que octubre, aún sin PARCHE D+E (fuera del alcance de esta tanda), sigue
capturando sin acotar por ventana — se espera que se resuelva solo cuando
octubre se regenere con el fix, sin relación con este hallazgo.

## 3. Cuantificación

### 3.1 Variante A (CONSULTA duplica la estancia) — CERRADA jun-dic 2025

Consulta de dimensionamiento (no una auditoría fila-por-fila, mismo espíritu
de "orden de magnitud" que A7). Match: `id_tipo_atencion=1` (CONSULTA)
fechado EXACTAMENTE el día de una transferencia emergencia→hospitalización
verificada para ese paciente (alta de emergencia = ingreso de
hospitalización, mismo día), con código+cantidad presente en algún
procedimiento `id_tipo_atencion IN (2,3,6,8)` del mismo paciente dentro de
±1 día de esa transferencia. El anclaje a la transferencia verificada (en
vez de "cualquier consulta del mes con un match coincidental") se agregó
2026-07-22 tras encontrar que sin él el query sobreestimaba 10-50× (493-697
filas/mes vs. las 10-57 ya validadas) — certificado reproduciendo julio
(42 filas esperado vs. 50 obtenido, mismo orden de magnitud) antes de
aplicar a noviembre-diciembre.

| Período (mes de la fecha del registro duplicado) | Variante A filas / S/. | Variante A cruzan de período (filas / S/.) |
| --- | --- | --- |
| 2025-06 | 7 / 138.01 | 4 / 73.65 |
| 2025-07 | 42 / 828.17 | 13 / 238.91 |
| 2025-08 | 57 / 1,343.55 | 14 / 278.71 |
| 2025-09 | 41 / 1,002.86 | 13 / 276.11 |
| 2025-10 | 10 / 210.16 | 2 / 43.78 |
| 2025-11 | 58 / 1,591.80 | 0 / 0.00 |
| 2025-12 | 75 / 2,303.60 | 3 / 48.12 |
| **TOTAL jun-dic** | **290 / 7,417.99** | **36 / 680.46** |

Top códigos (concentración, sugiere patrón sistemático de registro, no
consultas legítimas distintas al azar, medido sobre jun-oct): `99233` (38),
`59025` (24, código obstétrico), `99402.01` (19). 22-25 códigos distintos en
total — la mayoría de la masa está en 3-4 códigos recurrentes de
evaluación/monitoreo.

Para contexto de magnitud: el monto total evitado por deduplicación CPT/
SIGESAPOL ya establecida fue S/. 151,892.24 (julio) y S/. 145,873.60
(agosto) — Variante A es una fracción mínima de esa magnitud, y el
subconjunto "cruza de período" (el que realmente duplica cobro entre dos
envíos ya facturados por separado) es varias veces menor todavía. Real pero
acotado; no cambia el orden de magnitud de los números ya verificados en
`CONTEXTO_CANONICO.md` §2.

### 3.2 Variante B (la emergencia duplica la hospitalización) — PENDIENTE DE DEFINICIÓN CLÍNICA, no cuantificada

El número de jun-oct de una corrida anterior de esta sesión (35 filas para
julio, tabla previa a esta actualización) **no se pudo reproducir de forma
confiable** al reconstruir el query con dos anclajes distintos probados el
2026-07-22:

1. **Match dentro de ±1 día de la fecha de transferencia** (mismo anclaje
   que cerró Variante A): julio da **316 filas** contra las 35 esperadas —
   9× por encima. Códigos dominantes (`99402.01`, `94760`, `99207.03`,
   `99283`, oximetría, infusiones, interconsultas) son clínicamente
   plausibles, no ruido — distribuidos entre 125 pacientes distintos sin un
   caso atípico que concentre el conteo.
2. **Match dentro del rango `[ingreso, alta]` de la hospitalización
   específica de esa transferencia** (no ±1 día genérico, sino la estancia
   puntual): julio sube a **340 filas** — el ajuste empeoró el número en
   vez de mejorarlo, porque una hospitalización dura varios días y esa
   ventana es más permisiva que ±1 día, no menos. Esto descarta que el
   problema sea "a qué hospitalización se ancla el match" — el factor real
   no se identificó.

Ninguno de los dos anclajes pasa el certificado (reproducir julio dentro del
orden de magnitud 10-57 ya validado para el resto de esta tabla). Por
decisión explícita: **no se escribe una cifra de Variante B** hasta que se
entienda el factor faltante — o hasta que Auditoría Médica revise una
muestra y determine si el fenómeno real es más grande de lo asumido
originalmente (i.e. las "35 filas" de la corrida previa hayan sido, a su
vez, un subconteo por un query aún más restrictivo de lo necesario) en vez
de un artefacto de query. Variante B se lleva a la reunión como **pregunta
abierta**, no como número.

Query de referencia de Variante A (SIGESAPOL, solo lectura) conservada
fuera del repositorio (scratch de la sesión) — reproducible con las
condiciones descritas arriba si se necesita re-ejecutar. Los dos intentos
de Variante B también quedan fuera del repositorio, sin promoverse a
metodología de referencia por no haber pasado el certificado.

## 4. Pendiente

- [ ] Decisión de Auditoría Médica: ¿el registro duplicado (CONSULTA en
      variante A, o la prestación de emergencia en variante B) en el instante
      de transferencia es sistemáticamente un doble registro a excluir, o hay
      casos legítimos donde son servicios distintos que sí deben cobrarse
      ambos (necesita revisión de una muestra clínica, no solo de sistema)?
      La concentración en 3-4 códigos recurrentes de Variante A (§3.1) apunta
      a un patrón de registro sistemático más que a coincidencias — dato de
      apoyo, no concluyente por sí solo.
- [ ] **Variante B — pregunta abierta para Auditoría Médica, prioridad
      antes que la deduplicación técnica**: ¿cuál es el criterio clínico
      real para considerar dos registros (emergencia + hospitalización)
      como "el mismo servicio duplicado"? El pipeline probó dos anclajes
      temporales distintos (§3.2) y ninguno reprodujo la cifra de referencia
      de julio — no es un problema que un tercer query vaya a resolver sin
      antes acordar la definición clínica del duplicado.
- [ ] Si se confirma como duplicado sistemático (Variante A, y Variante B
      una vez definida): diseñar la regla de deduplicación (posible
      extensión de regla inmutable §1.2/§1.8, o una nueva regla) y dónde
      aplicarla (paso 6, o filtro adicional en
      `06_FASE2_SIGESAPOL_procedimientos.sql`) — probablemente dos reglas
      distintas para variante A y variante B, dado que son mecanismos de
      origen distintos.
- [x] Cuantificar alcance real de Variante A (filas y monto S/.), jun-dic
      completo — hecho 2026-07-21/22, ver §3.1.
- [ ] Cuantificar Variante B — bloqueado, ver §3.2. No se reintenta con una
      tercera hipótesis de query sin antes tener el criterio clínico de
      Auditoría Médica.
- [x] A8 (`14_VERIFICAR_ASERTOS.py`) ya clasifica estos overlaps como
      conocido-explicado (superficie `consulta_estancia`) en vez de fallar
      — implementado 2026-07-22. No excluye filas del pipeline, solo deja
      de bloquear la generación por un hallazgo ya gestionado.
- [ ] Una vez haya decisión (y, para Variante B, definición clínica),
      integrar a `CONTEXTO_CANONICO.md` §3.
