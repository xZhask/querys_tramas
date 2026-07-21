<?php
require_once __DIR__ . '/config/database.php';

$pdo = getCptPdo();
$pdo->exec("ALTER TABLE app_ejecuciones ADD COLUMN IF NOT EXISTS db_cpt VARCHAR(255);");
$pdo->exec("ALTER TABLE app_ejecuciones ADD COLUMN IF NOT EXISTS db_sigesapol VARCHAR(255);");
echo "Alterado correctamente.";
