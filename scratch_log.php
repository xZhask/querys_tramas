<?php
require_once __DIR__ . '/aplicativo/config/database.php';
$pdo = getCptPdo();
$stmt = $pdo->query("SELECT log FROM app_ejecuciones WHERE periodo = '2025-10' ORDER BY id DESC LIMIT 1");
$log = $stmt->fetchColumn();
echo $log;
