<?php
declare(strict_types=1);

/**
 * Credenciales y rutas del entorno. Único lugar donde deben vivir —
 * los controladores y servicios siempre pasan por getCptPdo()/getSigesapolPdo().
 */

// Raíz del repo querys_tramas (dos niveles arriba de config/), donde viven
// los .sql, los 3 scripts .py y las carpetas expedientes/ y tramas_exportadas/.
define('REPO_ROOT', dirname(__DIR__, 2));

define('DB_HOST', getenv('LNS_DB_HOST') ?: 'localhost');
define('DB_PORT', getenv('LNS_DB_PORT') ?: '5432');
define('DB_USER', getenv('LNS_DB_USER') ?: 'postgres');
define('DB_PASSWORD', getenv('LNS_DB_PASSWORD') ?: 'root');
define('DB_NAME_CPT', getenv('LNS_DB_CPT') ?: 'db_cpt_junio26');
define('DB_NAME_SIGESAPOL', getenv('LNS_DB_SIGESAPOL') ?: 'sigesapol_junio');

// Ruta al intérprete de Python usado para generate_outputs_v2.py,
// 13_REINCORPORAR_decisiones.py y 14_VERIFICAR_ASERTOS.py.
define('PYTHON_BIN', getenv('LNS_PYTHON_BIN') ?: 'python');

function lns_pdo(string $dbname): PDO
{
    $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', DB_HOST, DB_PORT, $dbname);
    $pdo = new PDO($dsn, DB_USER, DB_PASSWORD, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    ]);
    return $pdo;
}

function getCptPdo(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = lns_pdo(DB_NAME_CPT);
    }
    return $pdo;
}

function getSigesapolPdo(): PDO
{
    static $pdo = null;
    if ($pdo === null) {
        $pdo = lns_pdo(DB_NAME_SIGESAPOL);
    }
    return $pdo;
}
