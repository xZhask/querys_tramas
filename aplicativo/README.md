# Generador de Tramas LNS — Aplicativo web

Orquestador PHP + PostgreSQL del pipeline de `querys_tramas`. No reimplementa
ninguna regla de negocio: ejecuta los mismos `.sql` y scripts `.py` del repo,
en el mismo orden que `run_month.ps1`, con el período como único parámetro.
Ver `CONTEXTO_CANONICO.md` y `00_RUTA_jul_dic_2025.md` (raíz del repo) para el
detalle de las reglas que este aplicativo orquesta.

## Despliegue en Laragon (5 pasos)

1. **Ubicar la carpeta.** Este `aplicativo/` debe quedar accesible como
   `http://localhost/aplicativo/public/`. Si el repo `ruta_querys` ya está
   dentro de `www` de Laragon, no hay que mover nada; si no, cree un symlink
   o virtual host de Laragon apuntando a la raíz del repo.

2. **Habilitar las extensiones de PostgreSQL en PHP.** Edite el `php.ini` que
   usa Laragon (ver ruta con `php --ini`) y descomente/agregue:
   ```
   extension=pdo_pgsql
   extension=pgsql
   ```
   Reinicie Apache desde Laragon.

3. **Instalar dependencias PHP y Python.** Desde `aplicativo/`:
   ```
   composer install
   ```
   (Ya trae `composer.json`/`composer.lock` con PhpSpreadsheet; este paso solo
   descarga `vendor/` si no vino incluido.) Desde la raíz del repo, instale
   además las dependencias de los 3 scripts `.py` del pipeline
   (`generate_outputs_v2.py`, `14_VERIFICAR_ASERTOS.py`,
   `13_REINCORPORAR_decisiones.py`):
   ```
   python -m pip install -r requirements.txt
   ```
   Use el mismo intérprete que apuntará `LNS_PYTHON_BIN` (paso 4) o el
   `python` del PATH si no la define.

4. **Configurar credenciales (si difieren de los valores por defecto).**
   `config/database.php` usa por defecto usuario `postgres`, password `root`,
   host `localhost`, bases `db_cpt_junio26` (CPT) y `sigesapol_junio`
   (SIGESAPOL) — los mismos que usa `run_month.ps1`. Para cambiarlos sin tocar
   el archivo, defina las variables de entorno `LNS_DB_HOST`, `LNS_DB_PORT`,
   `LNS_DB_USER`, `LNS_DB_PASSWORD`, `LNS_DB_CPT`, `LNS_DB_SIGESAPOL` o
   `LNS_PYTHON_BIN` (ruta al intérprete de Python usado para los 3 scripts del
   pipeline) antes de arrancar Apache.

5. **Instalar la tabla del aplicativo y entrar.** Corra
   `install/00_INSTALAR_APP.sql` contra la BD CPT (psql o pgAdmin), luego
   abra `http://localhost/aplicativo/public/`. No hay login: el aplicativo se
   corre localmente, una instalación por persona, y la bitácora
   (`app_ejecuciones.iniciado_por`) identifica cada ejecución con el usuario
   de Windows de quien la corrió.

## Qué hace y qué NO hace

- El aplicativo **corre** `02_MAESTRO_paso1_SIGESAPOL.sql`,
  `05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql`,
  `06_FASE2_SIGESAPOL_procedimientos.sql`, el traslado SIGESAPOL→CPT,
  `03_MAESTRO_paso2_CPT.sql`, `07_FASE2_deduplicacion_CPT_SIGESAPOL.sql`,
  `08_CONSOLIDAR_fuentes_para_armado.sql`, `12_RECLASIFICAR_emergencias_24h.sql`,
  `04_CONTROL_integridad.sql`, `generate_outputs_v2.py`,
  `14_VERIFICAR_ASERTOS.py` y, en la pantalla Reincorporar,
  `13_REINCORPORAR_decisiones.py` — todos tal cual están en la raíz del repo.
- **Nunca** decide deduplicación, reclasificación de emergencias, cálculo de
  aserciones A1/A2/A3 ni ninguna otra regla de negocio: si una regla cambia,
  se edita el `.sql`/`.py` correspondiente, no el PHP.
- Los pasos "de una sola pasada" (deduplicación, consolidación,
  reclasificación) quedan bloqueados para un período ya generado; solo se
  repiten con el botón explícito "Reiniciar desde paso 5" en la pantalla
  Generar.
- El período se sustituye reescribiendo el bloque `DATE '...' AS p_ini / p_fin`
  dentro de `02_MAESTRO_paso1_SIGESAPOL.sql` y `03_MAESTRO_paso2_CPT.sql` —
  el mismo mecanismo que ya usa `run_month.ps1`. Por eso solo puede haber UNA
  ejecución en curso a la vez (el aplicativo lo controla solo).

## Estructura

```
aplicativo/
  public/        Front controller, endpoints AJAX, descargas, assets
  app/
    Controllers/ Un controlador por pantalla
    Services/    PipelineRunner, TrasladoService, ArchivoService,
                 ReincorporarService, EjecucionRepository
    Views/       Plantillas PHP (layout.php + una por pantalla)
  config/        database.php (credenciales), pipeline.php (mapeo de pasos)
  install/       00_INSTALAR_APP.sql
```

## Solución de problemas

- **"could not find driver" / pantalla en blanco al conectar:** falta activar
  `pdo_pgsql` en `php.ini` (paso 2).
- **Un paso SQL falla con un error de PostgreSQL:** el mensaje técnico
  completo queda en el detalle plegable de ese paso y en `app_ejecuciones.log`
  (pantalla Bitácora). El `.sql` no se toca por el aplicativo salvo el bloque
  de período en los pasos 1 y 5.
- **Un paso Python falla con `ModuleNotFoundError` (p. ej. `psycopg2`,
  `openpyxl`):** confirme que `LNS_PYTHON_BIN` apunta a un Python con las
  dependencias de `requirements.txt` (raíz del repo) instaladas — corra
  `python -m pip install -r requirements.txt` con ESE mismo intérprete
  (los mismos paquetes que usa `run_month.ps1`). Tras instalar, use el botón
  "Reintentar paso" en la pantalla Generar; no hace falta rehacer los pasos
  previos ya completados.
