<?php
require 'aplicativo/config/database.php';
$pdo = getCptPdo();
$stmt = $pdo->query("SELECT * FROM app_ejecuciones WHERE periodo = '2025-08' ORDER BY id DESC LIMIT 1;");
print_r($stmt->fetchAll());
