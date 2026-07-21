-- ============================================================================
-- 00_INSTALAR_APP.sql
-- Instala la tabla propia del aplicativo web "Generador de Tramas LNS":
-- app_ejecuciones (bitácora de generación y reincorporación). Correr UNA VEZ
-- en la BD CPT (db_cpt_junio26). IDEMPOTENTE: se puede correr las veces que
-- sea necesario.
--
-- Esta es la ÚNICA tabla que el aplicativo escribe/actualiza fuera de lo que
-- ya hacen los .sql/.py del pipeline (junto con las temp_*/cfg_* que esos
-- mismos scripts crean). Ningún DELETE/UPDATE fuera de esto.
--
-- El aplicativo no tiene login: se corre localmente por cada persona, y
-- "iniciado_por" en app_ejecuciones se llena con el usuario del sistema
-- operativo (ver usuarioLocal() en app/bootstrap.php).
-- ============================================================================

CREATE TABLE IF NOT EXISTS app_ejecuciones (
    id             SERIAL PRIMARY KEY,
    periodo        VARCHAR(7) NOT NULL,               -- 'YYYY-MM'
    tipo           VARCHAR(20) NOT NULL DEFAULT 'generacion', -- 'generacion' | 'reincorporacion'
    paso_actual    SMALLINT NOT NULL DEFAULT 0,
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- pendiente|en_curso|completado|fallido
    iniciado_por   VARCHAR(60) NOT NULL,
    iniciado_en    TIMESTAMP NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT now(),
    log            JSONB NOT NULL DEFAULT '[]'::jsonb,
    db_cpt         VARCHAR(255),
    db_sigesapol   VARCHAR(255)
);

CREATE INDEX IF NOT EXISTS idx_app_ejecuciones_periodo_tipo
    ON app_ejecuciones (periodo, tipo);

CREATE INDEX IF NOT EXISTS idx_app_ejecuciones_estado
    ON app_ejecuciones (estado);

-- Verificación final
SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'app_ejecuciones') > 0 AS app_ejecuciones_ok;
