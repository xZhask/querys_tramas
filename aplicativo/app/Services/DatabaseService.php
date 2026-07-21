<?php
declare(strict_types=1);

class DatabaseService
{
    public static function listarBases(string $prefijo = ''): array
    {
        $dsn = sprintf('pgsql:host=%s;port=%s;dbname=postgres', DB_HOST, DB_PORT);
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASSWORD, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
            $sql = "SELECT datname FROM pg_database WHERE datistemplate = false";
            if ($prefijo !== '') {
                $sql .= " AND datname LIKE " . $pdo->quote($prefijo . '%');
            }
            $sql .= " ORDER BY datname DESC";
            $stmt = $pdo->query($sql);
            return $stmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (PDOException $e) {
            return [];
        }
    }

    public static function validarTablas(string $dbName, array $tablasRequeridas): array
    {
        $dsn = sprintf('pgsql:host=%s;port=%s;dbname=%s', DB_HOST, DB_PORT, $dbName);
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASSWORD, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
            $faltantes = [];
            foreach ($tablasRequeridas as $tabla) {
                $stmt = $pdo->prepare("SELECT 1 FROM information_schema.tables WHERE table_name = ?");
                $stmt->execute([$tabla]);
                if (!$stmt->fetch()) {
                    $faltantes[] = $tabla;
                }
            }
            return ['ok' => empty($faltantes), 'faltantes' => $faltantes];
        } catch (PDOException $e) {
            return ['ok' => false, 'error' => $e->getMessage()];
        }
    }
}
