<?php
require 'aplicativo/config/database.php';
$pdo = getCptPdo();
$stmt = $pdo->query("SELECT * FROM app_ejecuciones ORDER BY id DESC LIMIT 5;");
print_r($stmt->fetchAll());
$pdoS = getSigesapolPdo();
$stmt2 = $pdoS->query("SELECT * FROM cfg_periodo;");
echo "SIGESAPOL cfg_periodo:\n";
print_r($stmt2->fetchAll());
$stmt3 = $pdo->query("SELECT * FROM cfg_periodo;");
echo "CPT cfg_periodo:\n";
print_r($stmt3->fetchAll());
