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

    public static function obtenerUltimoMesCerrado(): string
    {
        $dt = new DateTime('first day of this month');
        $dt->modify('-1 month');
        return $dt->format('Y-m');
    }

    public static function obtenerFuenteCanonica(string $periodo): ?array
    {
        try {
            $pdo = getCptPdo();
            $fecha = $periodo . '-01';
            $stmt = $pdo->prepare(
                "SELECT fuente, periodo_desde, periodo_hasta, sustento 
                 FROM cfg_fuente_canonica 
                 WHERE periodo_desde <= :fecha AND (periodo_hasta IS NULL OR periodo_hasta >= :fecha) 
                 LIMIT 1"
            );
            $stmt->execute(['fecha' => $fecha]);
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                return null;
            }

            $meses = [
                1 => 'Ene', 2 => 'Feb', 3 => 'Mar', 4 => 'Abr', 5 => 'May', 6 => 'Jun',
                7 => 'Jul', 8 => 'Ago', 9 => 'Set', 10 => 'Oct', 11 => 'Nov', 12 => 'Dic'
            ];

            $fmtFecha = function(?string $f) use ($meses): string {
                if (!$f) return 'vigente';
                $ts = strtotime($f);
                $m = (int)date('n', $ts);
                return $meses[$m] . ' ' . date('Y', $ts);
            };

            $vigDesde = $fmtFecha($row['periodo_desde']);
            $vigHasta = $row['periodo_hasta'] ? $fmtFecha($row['periodo_hasta']) : 'vigente';

            if ($row['periodo_hasta'] === null) {
                $vigenciaTexto = "Desde {$vigDesde} (vigente)";
            } else {
                $vigenciaTexto = "{$vigDesde} – {$vigHasta}";
            }

            return [
                'fuente' => $row['fuente'],
                'vigencia' => $vigenciaTexto,
                'sustento' => $row['sustento'],
            ];
        } catch (Throwable $e) {
            return null;
        }
    }

    public static function obtenerAlcance(): ?array
    {
        try {
            $pdo = getCptPdo();
            $stmt = $pdo->query("SELECT codigo_ipress, id_establecimiento_sigesapol, descripcion FROM cfg_ipress_alcance LIMIT 1");
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            if (!$row) {
                return null;
            }

            $nombre = 'Hospital Nacional PNP Luis N. Saenz';
            if (preg_match('/^(Hospital[^(]+)/i', $row['descripcion'], $m)) {
                $nombre = trim($m[1]);
            }

            return [
                'codigo' => $row['codigo_ipress'],
                'descripcion' => $row['descripcion'],
                'texto' => "{$nombre} ({$row['codigo_ipress']})",
            ];
        } catch (Throwable $e) {
            return null;
        }
    }
}
