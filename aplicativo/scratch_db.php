<?php
require 'aplicativo/config/database.php';
require 'aplicativo/app/Services/DatabaseService.php';
$pdo = getCptPdo();
$stmt = $pdo->query("SELECT * FROM app_ejecuciones ORDER BY id DESC LIMIT 5;");
print_r($stmt->fetchAll());
$pdoS = getSigesapolPdo();
$stmt2 = $pdoS->query("SELECT * FROM cfg_periodo;");
echo "SIGESAPOL cfg_periodo:\n";
print_r($stmt2->fetchAll());
$stmt3 = $pdo->query("SELECT id, periodo, db_cpt, db_sigesapol, iniciado_en FROM app_ejecuciones WHERE periodo = '2025-09' ORDER BY id DESC LIMIT 5");
echo "app_ejecuciones 2025-09:\n";
print_r($stmt3->fetchAll());

