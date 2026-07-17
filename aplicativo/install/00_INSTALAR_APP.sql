-- ============================================================================
-- 00_INSTALAR_APP.sql
-- Instala las tablas propias del aplicativo web "Generador de Tramas LNS":
-- app_usuarios (login) y app_ejecuciones (bitácora de generación y
-- reincorporación). Correr UNA VEZ en la BD CPT (db_cpt_junio26).
-- IDEMPOTENTE: se puede correr las veces que sea necesario.
--
-- Estas son las ÚNICAS tablas que el aplicativo escribe/actualiza fuera de lo
-- que ya hacen los .sql/.py del pipeline (junto con las temp_*/cfg_* que esos
-- mismos scripts crean). Ningún DELETE/UPDATE fuera de esto.
-- ============================================================================

CREATE TABLE IF NOT EXISTS app_usuarios (
    id            SERIAL PRIMARY KEY,
    usuario       VARCHAR(60) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(150) NOT NULL DEFAULT '',
    creado_en     TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app_ejecuciones (
    id             SERIAL PRIMARY KEY,
    periodo        VARCHAR(7) NOT NULL,               -- 'YYYY-MM'
    tipo           VARCHAR(20) NOT NULL DEFAULT 'generacion', -- 'generacion' | 'reincorporacion'
    paso_actual    SMALLINT NOT NULL DEFAULT 0,
    estado         VARCHAR(20) NOT NULL DEFAULT 'pendiente', -- pendiente|en_curso|completado|fallido
    iniciado_por   VARCHAR(60) NOT NULL,
    iniciado_en    TIMESTAMP NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMP NOT NULL DEFAULT now(),
    log            JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_app_ejecuciones_periodo_tipo
    ON app_ejecuciones (periodo, tipo);

CREATE INDEX IF NOT EXISTS idx_app_ejecuciones_estado
    ON app_ejecuciones (estado);

-- ============================================================================
-- Usuario admin por defecto. Password temporal: "CambiarAhora2025" (hash
-- bcrypt generado con password_hash() de PHP). Cambiarla desde el primer
-- login o con un UPDATE manual — ver README.md del aplicativo.
-- ============================================================================
INSERT INTO app_usuarios (usuario, password_hash, nombre_completo)
SELECT 'admin', '$2y$12$quJcgA/RgQIL9kn0heoYpOiZqeZxkkOWacILVAYFCRcaA38Q3oTG2', 'Administrador'
WHERE NOT EXISTS (SELECT 1 FROM app_usuarios WHERE usuario = 'admin');

-- Verificación final
SELECT
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'app_usuarios') > 0 AS app_usuarios_ok,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'app_ejecuciones') > 0 AS app_ejecuciones_ok,
    (SELECT COUNT(*) FROM app_usuarios WHERE usuario = 'admin') > 0 AS admin_creado;
