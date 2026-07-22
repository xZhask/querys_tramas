# HALLAZGO — Estancias truncadas en CPT durante la migración a SIGESAPOL
# (patrón RECURRENTE mes a mes, no exclusivo de septiembre→octubre)

> Encontrado 2026-07-21 durante la regeneración de octubre 2025 con PARCHE
> D+E, al revisar el resumen de consolidación (paso 7,
> `08_CONSOLIDAR_fuentes_para_armado.sql`) y clasificar los fallos de A8
> (no-duplicación entre períodos) contra septiembre — pedido explícito del
> usuario de revisar octubre "con cuidado" por ser el primer mes donde PARCHE
> E opera sobre la rama canónica SIGESAPOL.
>
> **Actualización 2026-07-21 (misma fecha, tercera pasada) — HALLAZGO
> AMPLIADO**: al regenerar noviembre y verificar explícitamente la frontera
> octubre→noviembre (pedido del usuario: "si aparece, la migración no fue
> tan limpia como se asume — reportar de inmediato"), el mismo patrón
> **SÍ aparece**, con monto AÚN MAYOR que en sep→oct. CPT sigue recibiendo
> datos fragmentarios de forma dispersa incluso en octubre-noviembre — no es
> un efecto puntual de la fecha de corte institucional, es un patrón
> **recurrente que hay que verificar en cada frontera de mes mientras dure
> la migración**. Este documento se reporta ahora, ANTES de regenerar
> diciembre, tal como pidió el usuario. Documento standalone, mismo criterio
> que `HALLAZGO_SIGESAPOL_ventana_estancia.md` y
> `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md`.
>
> **Actualización 2026-07-22 — CIERRE METODOLÓGICO (techo real)**: se
> reemplazó el método mes-contra-mes (§3.5, que dejaba fuera las estancias
> que saltan más de una frontera) por un cruce **todos-contra-todos**: cada
> estancia con alta real en oct/nov/dic se verifica contra LAS SEIS tramas
> de hospitalización ya exportadas (jul-dic), no solo contra el mes
> inmediatamente anterior. El total inicial fue S/. 334,484.33 (§3.6),
> corregido a **S/. 335,783.97** en §3.7 (ventana de estancia extendida por
> unión E→H, no capturada por una consulta directa a la tabla cruda). Éste
> es el número que va al informe para Dirección.
>
> **Este archivo NO contiene documento ni nombre de paciente** (regla
> inmutable §1.10) — los casos usan identificador de sesión (`Paciente D`).

---

## 1. Resumen del hallazgo

Regla inmutable §1.1: la fuente canónica cambia de CPT (jul-sep 2025) a
SIGESAPOL (oct-dic 2025) por migración institucional. Para una hospitalización
cuyo ingreso cae en septiembre (CPT-canónico) pero cuya alta real cae en
octubre (SIGESAPOL-canónico), el diseño esperado es: septiembre no factura
nada de esa estancia (sigue "abierta" al cierre de septiembre, regla §1.11),
y octubre factura la estancia completa, incluidos los procedimientos de
septiembre, vía PARCHE D (lado CPT) o PARCHE E (lado SIGESAPOL) según qué
lado tenga el dato.

Lo que se encontró: **durante la transición, CPT dejó de recibir/actualizar
datos de una estancia a mitad de camino**, en el momento en que el personal
migró a cargar exclusivamente en SIGESAPOL. El último registro que CPT tiene
de esa estancia trae su propio `codigo_alta` (marca de alta) en una fecha que
NO es la fecha real de alta — es simplemente el último día en que alguien
todavía registró algo en CPT antes de dejar de usarlo para ese paciente.
`sp_hospitalizacion_en_periodo` (CPT, con PARCHE D) no tiene forma de saber
que la estancia continúa: para CPT, esa fecha truncada **es** la alta, así
que factura ese procedimiento en **septiembre** (correcto desde la
información parcial que CPT tiene). SIGESAPOL, con el cuadro completo, sabe
que la estancia real sigue hasta octubre, y correctamente factura el mismo
procedimiento (mismo código, misma fecha) en **octubre**. Resultado: el
mismo servicio clínico queda facturado dos veces, una vez en cada envío,
por una razón estructural de la migración — no un bug de PARCHE D ni de
PARCHE E, cada uno hizo lo correcto con la información que tenía disponible.

## 2. Evidencia verificada (solo lectura)

**Paciente D**: hospitalización SIGESAPOL con ingreso 2025-09-29, alta real
2025-10-02 (estado 6, válida). CPT tiene **un solo registro** de
`origen='HOSPITALIZACION'` para este paciente en esa ventana, fechado
2025-09-29, con `codigo_alta` presente (marca de alta) — y nada más hasta el
siguiente episodio en diciembre. Es decir, para CPT la estancia "cerró" el
mismo día que ingresó. Ese procedimiento del 29-set aparece en la trama de
septiembre (vía CPT, canónico ese mes) **y** en la trama de octubre (vía
SIGESAPOL, canónico ese mes, con la ventana completa `[29-set, 02-oct]`) —
exactamente el tipo de fila que A8 detecta como doble cobro entre envíos.

Verificado también contra otros dos ejemplos de los overlaps de A8
(septiembre vs. octubre): mismo patrón — hospitalización con ingreso a fines
de septiembre, transferencia Emergencia→Hospitalización el mismo día en
ambos casos (no relacionado con el hallazgo de consulta-vs-estancia, es un
mecanismo distinto), y alta real en octubre.

**El patrón no se limita a septiembre**: verificado además con los 3
ejemplos de overlap agosto-vs-octubre que reportó A8 — mismas
características (hospitalización con ingreso en agosto, transferencia
Emergencia→Hospitalización el mismo día, alta real en octubre). El
denominador común es "ingreso mientras CPT todavía se actualizaba, alta real
ya en territorio SIGESAPOL-canónico" — no importa si el ingreso fue en
agosto o septiembre, el mecanismo y el riesgo son los mismos. La
cuantificación de la sección 3 ya usa `ingreso <= 2025-09-30` (sin cota
inferior), así que agosto ya queda incluido en las 279/232.

## 3. Cuantificación

### 3.0 Corrección de metodología (importante, leer antes que la tabla)

La primera pasada de este hallazgo (misma fecha, corrida anterior) usó una
consulta SQL contra `prestacion_cpt` para clasificar estancias como
"truncadas" — 232 de 279 hospitalizaciones. Esa consulta solo confirma que
CPT tiene **datos crudos** de la estancia con fecha anterior a la alta real;
**no confirma que esos datos crudos hayan sido efectivamente extraídos y
facturados** en la trama de septiembre ya exportada (`sp_hospitalizacion_
en_periodo`, con PARCHE D, exige que CPT considere la estancia con alta
DENTRO del período para extraerla — un registro crudo suelto sin una
"estancia" reconocible por CPT puede simplemente no llegar a facturarse en
absoluto). Se repitió la verificación contra la trama de hospitalización de
septiembre **ya exportada** (`expedientes/2025-09/01_TRAMAS/
trama_hospitalizacion.txt`, dato real, no inferencia) cruzada con la de
octubre por documento+fecha: de las 232 estancias "truncadas" por el
heurístico SQL, **solo 7 tienen alguna fila real en la trama de septiembre**
dentro de su ventana. El heurístico SQL sirvió para encontrar el mecanismo
(sección 1-2, confirmado con evidencia real) pero sobreestimó severamente el
alcance — la tabla de abajo usa la cifra verificada contra archivo, no el
heurístico.

### 3.1 Hospitalización (riesgo real, verificado contra archivo)

| | Documentos / filas | Monto S/. |
| --- | --- | --- |
| Estancias que cruzan sep→oct (SQL, universo de partida) | 279 | — |
| ...de esas, con fila real en la trama de septiembre ya exportada | **7 documentos** | — |
| **A8-visible** (mismo documento+fecha+código en sep Y oct — A8 ya lo detecta) | 1,063 filas | **26,635.63** |
| **A8-invisible** (mismo documento+fecha, CÓDIGO DISTINTO entre sep y oct — A8 no lo ve, doble cobro real) | 156 filas | **52,752.11** |
| Sep tiene la fila, oct no tiene nada esa fecha (sin evidencia de doble cobro) | 445 filas | 39,760.99 (no sumar al riesgo) |
| **TOTAL riesgo real confirmado (A8-visible + A8-invisible)** | **1,219 filas, 7 pacientes** | **S/. 79,387.74** |

El bucket "A8-invisible" (S/. 52,752.11, mayor que el visible) es el número
que más le importa a Auditoría Médica: A8 no lo detecta porque el código de
procedimiento no coincide, pero es la misma fecha y el mismo paciente en dos
envíos distintos. Un solo caso concentra la mayor parte de ese monto: una
hospitalización larga (12-ago a 09-oct) donde septiembre facturó, para el
12-ago, un código de cuidados críticos (S/. 21,385.05) vía CPT, y octubre
factura para esa misma fecha códigos distintos (evaluación diaria,
radiografía) vía SIGESAPOL — mismo paciente, misma fecha, dos sistemas
codificaron el mismo episodio de forma distinta.

### 3.2 Emergencias — patrón NO confirmado en sep→oct (riesgo real: cero)

Repetida la misma verificación (SQL + cruce contra archivo real) para
emergencias que cruzan sep→oct: 419 emergencias en el universo SQL, 214
"truncadas" por el heurístico, pero **solo 9 documentos tienen alguna fila
real en la trama de septiembre**, y de esas, **ninguna coincide con una
fecha en la trama de octubre** (74 filas / S/. 2,809.23 quedan en el bucket
"sin evidencia", no hay ningún caso A8-visible ni A8-invisible). El
mecanismo de este hallazgo es, en la práctica, **exclusivo de
hospitalización** — las emergencias son episodios más cortos y no alcanzan a
generar el mismo patrón de facturación fraccionada entre dos períodos. (No
verificado todavía para la frontera oct→nov — pendiente.)

### 3.3 Hospitalización, frontera octubre→noviembre — CONFIRMADO, monto mayor

Misma verificación (SQL + cruce contra archivo real, esta vez trama de
octubre ya exportada vs. trama de noviembre): 249 hospitalizaciones cruzan
oct→nov (ingreso ≤31-oct, alta real en noviembre), 199 "truncadas" por CPT
según el heurístico SQL, de las cuales **8 documentos tienen fila real en la
trama de octubre ya exportada** dentro de su ventana (proporción similar a
sep→oct: ~4% del heurístico se traduce en riesgo real).

| | Documentos / filas | Monto S/. |
| --- | --- | --- |
| **A8-visible** (mismo documento+fecha+código en oct Y nov) | 751 filas | **28,003.31** |
| **A8-invisible** (mismo documento+fecha, código distinto) | 353 filas | **66,745.37** |
| Oct tiene la fila, nov no tiene nada esa fecha (sin evidencia) | 674 filas | 45,766.96 (no sumar) |
| **TOTAL riesgo real confirmado oct→nov** | **1,104 filas, 8 pacientes** | **S/. 94,748.68** |

**Esto confirma que el patrón es recurrente, no un evento único de la fecha
de corte institucional**: CPT sigue recibiendo datos fragmentarios y
dispersos de algunos pacientes incluso dos meses después de que SIGESAPOL
se volvió canónico. Uno de los casos de esta frontera (ingreso 26-ago, alta
real 02-nov — más de 2 meses de estancia) es el mismo tipo de episodio largo
que domina el bucket "invisible" de sep→oct: una sola estancia larga con
"apagones" intermitentes de CPT a lo largo de varios meses puede generar
doble cobro contra CADA período que toca, no solo el primero.

### 3.4 Frontera noviembre→diciembre — CONFIRMADO (hospitalización), CERO (emergencia)

Diciembre regenerado con PARCHE D+E (A1-A7 PASS). Misma verificación de las
dos secciones anteriores:

**Hospitalización**: 346 estancias cruzan nov→dic (ingreso ≤30-nov, alta
real en diciembre), 228 "truncadas" por el heurístico SQL, **7 documentos
con fila real en la trama de noviembre ya exportada**.

| | Documentos / filas | Monto S/. |
| --- | --- | --- |
| **A8-visible** | 456 filas | **15,792.15** |
| **A8-invisible** (código distinto) | 170 filas | **48,171.92** |
| Nov tiene la fila, dic no tiene nada esa fecha (sin evidencia) | 0 filas | 0.00 |
| **TOTAL riesgo real confirmado nov→dic** | **626 filas, 7 pacientes** | **S/. 63,964.07** |

**Emergencias**: 172 emergencias cruzan nov→dic, solo 10 "truncadas" por el
heurístico, **0 documentos con fila real en la trama de noviembre** dentro
de su ventana → riesgo real **CERO**, consistente con sep→oct y oct→nov.

### 3.5 Tabla resumen — las 3 fronteras verificadas (entregable para Auditoría)

| Frontera | Tipo | Pacientes con riesgo real | Filas A8-visible | Monto A8-visible | Filas A8-invisible | Monto A8-invisible (A8 NO lo detecta) | Filas totales | **Monto S/. total** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sep→oct | Hospitalización | 7 | 1,063 | 26,635.63 | 156 | 52,752.11 | 1,219 | **79,387.74** |
| sep→oct | Emergencia | 0 | 0 | 0.00 | 0 | 0.00 | 0 | **0.00** |
| oct→nov | Hospitalización | 8 | 751 | 28,003.31 | 353 | 66,745.37 | 1,104 | **94,748.68** |
| oct→nov | Emergencia | 0 | 0 | 0.00 | 0 | 0.00 | 0 | **0.00** |
| nov→dic | Hospitalización | 7 | 456 | 15,792.15 | 170 | 48,171.92 | 626 | **63,964.07** |
| nov→dic | Emergencia | 0 | 0 | 0.00 | 0 | 0.00 | 0 | **0.00** |
| **TOTAL** | | **22 estancias** | **2,270** | **70,431.09** | **679** | **167,669.40** | **2,949** | **S/. 238,100.49** |

Lectura del cuadro para la reunión: el riesgo es **exclusivo de
hospitalización** (emergencias en cero las 3 veces, patrón consistente y ya
no necesita reverificarse en próximas fronteras) y **más de dos tercios del
monto (S/. 167,669.40 de S/. 238,100.49, 70%) es invisible para A8** — el
control automático que ya corre en cada cierre solo vería el 30% de esto.
El monto no decrece con el tiempo (79K → 95K → 64K): la migración sigue sin
"cerrarse" del todo, CPT sigue aportando datos fragmentarios mes a mes.

**Límite conocido de esta cuantificación (§3.1-3.5)**: el método verifica
cada frontera contra el mes INMEDIATAMENTE anterior (sep-oct, oct-nov,
nov-dic). Una estancia que arrastra más de un mes de por medio no queda
cubierta por esta tabla — ver §3.6 para el cierre de este límite.

### 3.6 Cierre metodológico — cruce todos-contra-todos (el techo real)

El límite de §3.5 (solo mes-adyacente) se cerró reemplazando el método por
uno que cruza **cada estancia con alta real en oct/nov/dic contra las SEIS
tramas de hospitalización ya exportadas** (jul, ago, sep, oct, nov, dic),
no solo contra el mes anterior. Método (solo lectura, mismo criterio que
§3.0-3.4, sin restricción de "ingreso ≤ mes anterior" en el universo de
partida — la restricción real la impone la ventana `[ingreso, alta]` de
cada estancia):

1. Universo: TODAS las hospitalizaciones SIGESAPOL con alta real en
   oct/nov/dic 2025 (3,919 estancias, sin filtrar por fecha de ingreso).
2. Para cada una, se buscan en CADA período anterior a su mes de alta
   (jul...alta-1) las filas de esa trama ya exportada cuyo documento
   coincide y cuya fecha cae dentro de `[ingreso, alta]`.
3. Cada línea se clasifica igual que antes: **A8-visible** (mismo
   documento+fecha+código en el período de alta) o **A8-invisible** (mismo
   documento+fecha, código distinto). Si una fecha no tiene ninguna fila en
   el período de alta, se descarta (sin evidencia, no se cuenta como riesgo).
4. Para evitar contar dos veces la MISMA línea si reaparece re-exportada en
   más de un período antecedente, se toma la cantidad **máxima** entre
   períodos para cada combinación (fecha, código, valor unitario) — no la
   suma. Esto preserva líneas de múltiples unidades genuinas dentro de un
   mismo período (que sí deben contarse cada una) sin inflar por
   re-exportación entre meses. Verificado contra el control de §3.1
   (sep→oct, un solo período antecedente): reproduce exactamente 1,219
   filas / S/. 79,387.74 — mismo resultado que el método anterior cuando
   solo hay una frontera de por medio.

| Alta en | Pacientes con riesgo real | Filas A8-visible | Monto A8-visible | Filas A8-invisible | Monto A8-invisible | Filas totales | **Monto S/. total** |
| --- | --- | --- | --- | --- | --- | --- | --- |
| octubre | 6 | 1,063 | 26,635.63 | 156 | 52,752.11 | 1,219 | **79,387.74** |
| noviembre | 9 | 1,035 | 35,263.72 | 453 | 97,775.61 | 1,488 | **133,039.33** |
| diciembre | 10 | 821 | 27,712.85 | 267 | 94,344.41 | 1,088 | **122,057.26** |
| **TOTAL hospitalización** | **25 estancias** | **2,919** | **89,612.19** | **876** | **244,872.13** | **3,795** | **S/. 334,484.33** |

**Emergencias**: repetido el mismo cruce todos-contra-todos (28,155
estancias con alta oct-dic en el universo de partida) — **riesgo real CERO
en las tres fronteras**, confirma y cierra §3.2/§3.3/§3.4.

**Desglose por cuántos meses salta cada línea** (por qué el método
mes-a-mes se quedaba corto):

| Salto (meses entre el mes de origen CPT y el mes de alta real) | Filas | Monto S/. |
| --- | --- | --- |
| 1 (frontera adyacente — lo que ya cubría §3.1-3.5) | 3,156 | 259,476.59 |
| 2 | 186 | 18,287.20 |
| 3 | 404 | 45,938.70 |
| 4 | 49 | 10,781.85 |
| **TOTAL** | **3,795** | **334,484.33** |

El salto de 3 meses incluye el caso ya señalado como límite conocido en la
versión anterior de este documento (ingreso julio, fila truncada en CPT
detectada en septiembre, alta real diciembre — visible en el log de A8 de
diciembre, ejemplo con fecha 2025-07-23): con el cruce todos-contra-todos
queda cuantificado en **404 filas, S/. 45,938.70**, la mayor parte del
salto de 3 meses. El salto de 4 meses (49 filas, S/. 10,781.85) es un caso
nuevo, no visible en ningún log de A8 anterior porque A8 solo compara cada
período regenerado contra los que ya existían en `expedientes/` al momento
de correrlo — este caso conecta agosto con diciembre.

**Comparación con el piso anterior (§3.5)**: S/. 334,484.33 − S/. 238,100.49
= **S/. 96,383.84 adicionales** (+40.5%) que el método mes-a-mes no
capturaba. Este es el número techo — cierra la brecha metodológica, no
depende de decisiones pendientes de Auditoría Médica sobre el tratamiento.

Trazabilidad: script `frontera_todos_contra_todos.py` (cruce completo),
detalle línea por línea en `frontera_ttcc_hospitalizacion_detalle.csv` y
`frontera_ttcc_emergencia_detalle.csv` (ambos fuera de versionado, con
documento de paciente — regla §1.10).

### 3.7 Corrección de la cifra techo + investigación de A8 en septiembre (2026-07-22)

Al regenerar septiembre desde el aplicativo (confirmando el fix del bug de
"Generar tramas", ver bitácora de la sesión) A8 reportó 281 prestaciones
compartidas con otros períodos. Se investigó cada una para separar
"conocido" de "nuevo", con dos hallazgos:

**a) Corrección metodológica en el cálculo del techo (§3.6).** El script
`frontera_todos_contra_todos.py` tomaba la ventana `[ingreso, alta]` de cada
estancia desde la tabla cruda `hospitalizaciones` de SIGESAPOL. Cuando el
pipeline une una emergencia a una hospitalización (Caso A, E→H), la ventana
real de la estancia se **extiende hacia atrás** hasta el ingreso de la
emergencia — extensión que vive en la trama ya exportada, no en la tabla
cruda. Un caso quedó fuera del techo por esto (estancia con la ventana
extendida no capturada). Corregido usando la ventana **tal como la calcula
la propia trama** (fila `base='estancia hospitalaria'`, columnas
`sp_fecha_atencion`/`sp_fecha_alta`) en vez de una consulta aparte a la BD:

| | Antes (§3.6) | Corregido |
| --- | --- | --- |
| Docs | 25 | **26** |
| Filas | 3,795 | **3,807** |
| Monto S/. | 334,484.33 | **335,783.97** |

Diferencia: +S/. 1,299.64 (12 filas, un caso adicional con alta en
noviembre). El desglose por mes de alta actualizado:

| Alta en | Docs | Filas | Monto S/. |
| --- | --- | --- | --- |
| octubre | 6 | 1,219 | 79,387.74 (sin cambio) |
| noviembre | 10 | 1,500 | 134,338.97 (vis 35,263.72 / inv 99,075.25) |
| diciembre | 10 | 1,088 | 122,057.26 (sin cambio) |
| **TOTAL** | **26** | **3,807** | **S/. 335,783.97** |

**S/. 335,783.97 es la cifra techo corregida** (reemplaza los
S/. 334,484.33 de §3.6 en todo informe posterior).

**b) Dos hipótesis de patrones nuevos, investigadas y descartadas.** De las
281 prestaciones de septiembre, 268 correspondían a esta frontera
(hospitalización) y 13 no tenían una estancia de hospitalización en la BD
cruda que las explicara. La hipótesis inicial fue que eran dos fenómenos
nuevos no medidos (emergencia cruzando de período; CPT con una estancia
divergente entre dos meses CPT-canónico, sin migración de por medio). Se
corrió el mismo cruce todos-contra-todos ampliado a los 6 meses (no solo
oct-dic) para ambas hipótesis — **las dos resultaron ser artefactos de una
búsqueda por base de datos incompleta, no fenómenos reales**:

- La búsqueda por BD no encontraba la estancia de hospitalización porque
  (igual que en (a)) la ventana real está extendida por la unión E→H y la
  tabla cruda no la refleja.
- Verificado caso por caso contra la trama exportada (el dato real, no la
  BD): las 13 filas son, sin excepción, el patrón **ya documentado en
  `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md`** (Variante A: un registro
  CONSULTA duplica, en el instante de transferencia E→H, el mismo
  código+fecha que ya factura dentro del paquete de la hospitalización
  reclasificada). El número de septiembre (13 filas) coincide exactamente
  con la fila "2025-09" de la tabla de esa hallazgo (§3, "Variante A cruzan
  de período: 13 filas / S/. 276.11") — ya estaba cuantificado desde
  2026-07-21, antes de esta sesión.
- Repetido el cruce todos-contra-todos completo (jul-dic, no solo oct-dic)
  para emergencia: **riesgo real CERO confirmado en las 6 fronteras**, no
  solo en las 3 ya reportadas — refuerza (no corrige) la conclusión de
  §3.6.

**Conclusión**: las 281 prestaciones de septiembre están 100% explicadas por
los dos hallazgos ya documentados y ya reportados a Auditoría Médica
(frontera CPT/SIGESAPOL + consulta-vs-estancia). No hay un tercer patrón.
La regeneración de septiembre es correcta; lo que faltaba era que A8
clasificara esto en vez de bloquear (ver §6).

### 3.8 Corrección pendiente en `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md`

Ese hallazgo cuantificó jun-oct pero **no** noviembre-diciembre (nota propia
del documento, §4: "Pendiente ampliar a octubre-diciembre"). Con nov-dic ya
regenerados con PARCHE D+E en esta sesión, falta correr la misma
cuantificación (Variante A y B, filas que cruzan de período) para esos 2
meses y sumar al total S/. 4,967.69 / S/. 1,780.14 ya reportado. No se hizo
en esta sesión — pendiente antes de dar el mapa de fronteras por
completamente cerrado.

## 4. Por qué esto es distinto de los otros dos hallazgos

- `HALLAZGO_SIGESAPOL_ventana_estancia.md` (PARCHE E): un bug real, ya
  corregido, sobre cómo SIGESAPOL acotaba (o no) los procedimientos a la
  ventana de SU estancia.
- `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md`: doble registro DENTRO de
  SIGESAPOL mismo, en el instante de transferencia Emergencia→Hospitalización
  (un problema de calidad de dato de origen, independiente del período).
- **Este hallazgo**: ningún bug de código — CPT y SIGESAPOL, cada uno
  correctamente filtrado por su propio parche, **discrepan entre sí sobre
  cuándo terminó una estancia** porque CPT sigue recibiendo datos de forma
  intermitente durante toda la migración, no solo hasta una fecha de corte
  limpia. Confirmado que se repite en DOS fronteras consecutivas (sep→oct Y
  oct→nov) — la hipótesis original de que sería un evento único quedó
  descartada por evidencia directa.

## 5. Pendiente

- [ ] **Decisión de Auditoría Médica — prioridad 1 de la reunión**: para las
      26 estancias con doble cobro real confirmado (tabla §3.7,
      S/. 335,783.97, cifra techo corregida), ¿se excluye la porción del mes anterior
      (ya facturada con información incompleta de CPT) y se deja que el mes
      de alta facture la estancia completa? ¿O al revés? Cualquiera de las
      dos requiere decidir cuál de los dos envíos "gana" — no es una
      decisión técnica. Es el hallazgo con mayor monto verificado de los
      tres.
- [x] Cuantificar el monto S/. de las 3 fronteras (sep→oct, oct→nov,
      nov→dic) — hecho, ver §3.1/§3.3/§3.4, tabla consolidada en §3.5.
- [x] Verificar el mismo patrón en emergencias en las 3 fronteras — hecho:
      riesgo real confirmado es CERO, verificado tanto mes-a-mes (§3.2,
      §3.3, §3.4) como todos-contra-todos (§3.6).
- [x] Confirmar si el patrón se repite en oct→nov y nov→dic —
      **CONFIRMADO en ambas**. La hipótesis de que sería exclusivo de la
      fecha de corte institucional queda descartada; es un patrón
      recurrente mientras CPT siga recibiendo datos fragmentarios.
- [x] **Cerrar el límite metodológico del salto de frontera** (cruce
      todos-contra-todos, no solo mes adyacente) — hecho, ver §3.6. Monto
      techo corregido en §3.7: **S/. 335,783.97**.
- [x] **Investigar los overlaps de A8 en la regeneración de septiembre**
      (281 prestaciones) para separar conocido de nuevo — hecho, ver §3.7:
      268 = esta frontera, 13 = `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md`
      (coincide exacto con su fila de septiembre). Cero patrones nuevos.
      Corrección de metodología (ventana E→H) aplicada al techo.
- [ ] Diciembre es el último mes del semestre — no hay frontera dic→enero
      que verificar dentro del alcance de este cierre (enero 2026 queda
      fuera del semestre jul-dic 2025).
- [ ] Ampliar `HALLAZGO_SIGESAPOL_consulta_vs_estancia.md` a noviembre-
      diciembre (ver §3.8) — su propia cuantificación solo llega a octubre.
- [ ] Implementar en A8 (`14_VERIFICAR_ASERTOS.py`) la clasificación
      conocido/nuevo con el criterio verificado en §3.7 (ventana de estancia
      tal como la calcula la trama, no la tabla cruda) más el patrón
      consulta-vs-estancia, para que deje de bloquear "Generar tramas" por
      hallazgos ya gestionados — pendiente de implementar esta sesión.
- [ ] Una vez decidido el tratamiento, integrar a `CONTEXTO_CANONICO.md` §3
      y recalcular §2 (los montos de recuperación neta y demás cifras
      ancla deberían, en principio, ya reflejar las tramas tal como están
      — el ajuste por el tratamiento de frontera se aplicaría DESPUÉS de
      la decisión de Auditoría, como una entrada nueva, no reabriendo el
      recálculo base).
