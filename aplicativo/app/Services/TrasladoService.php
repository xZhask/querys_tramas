<?php
declare(strict_types=1);

/**
 * Paso 4 del pipeline: traslada las 3 tablas temp_* de SIGESAPOL a CPT.
 * Reemplaza el pg_dump manual documentado en 00_RUTA_jul_dic_2025.md por
 * lectura en cursor + inserción por lotes de 5,000 vía PDO, con verificación
 * de conteo origen = destino antes de continuar. No decide nada sobre los
 * datos: es transporte puro.
 */
class TrasladoService
{
    private const TAMANO_LOTE = 5000;

    public function __construct(private PDO $origen, private PDO $destino)
    {
    }

    /**
     * @param array<int,string> $tablas
     * @return array{ok:bool,total:?int,detalle:?string}
     */
    public function ejecutar(array $tablas): array
    {
        $totalGeneral = 0;
        $detalles = [];
        try {
            foreach ($tablas as $tabla) {
                $conteo = $this->trasladarTabla($tabla);
                $totalGeneral += $conteo;
                $detalles[] = "{$tabla}: {$conteo} filas";
            }
            return ['ok' => true, 'total' => $totalGeneral, 'detalle' => implode('; ', $detalles)];
        } catch (Throwable $e) {
            return ['ok' => false, 'total' => null, 'detalle' => $e->getMessage()];
        }
    }

    private function trasladarTabla(string $tabla): int
    {
        $columnas = $this->columnasDeOrigen($tabla);
        if (empty($columnas)) {
            throw new RuntimeException("La tabla origen {$tabla} no existe o no tiene columnas.");
        }

        $this->destino->exec("DROP TABLE IF EXISTS {$tabla}");
        $this->destino->exec($this->ddlCreateTable($tabla, $columnas));

        $nombresCol = array_map(fn($c) => $c['column_name'], $columnas);
        $listaCol = implode(', ', $nombresCol);

        // PDO limita a 65,535 parámetros por sentencia preparada: con tablas
        // de muchas columnas, un lote de 5,000 filas los excede. Se ajusta el
        // tamaño de lote hacia abajo según el número de columnas, sin superar
        // el límite pedido de 5,000 filas.
        $tamanoLote = max(1, min(self::TAMANO_LOTE, intdiv(65000, count($nombresCol))));

        $stmtOrigen = $this->origen->query("SELECT {$listaCol} FROM {$tabla}");
        $totalCopiado = 0;
        $lote = [];

        while (($fila = $stmtOrigen->fetch(PDO::FETCH_NUM)) !== false) {
            $lote[] = $fila;
            if (count($lote) >= $tamanoLote) {
                $totalCopiado += $this->insertarLote($tabla, $nombresCol, $lote);
                $lote = [];
            }
        }
        if (!empty($lote)) {
            $totalCopiado += $this->insertarLote($tabla, $nombresCol, $lote);
        }

        $conteoOrigen = (int) $this->origen->query("SELECT COUNT(*) FROM {$tabla}")->fetchColumn();
        $conteoDestino = (int) $this->destino->query("SELECT COUNT(*) FROM {$tabla}")->fetchColumn();
        if ($conteoOrigen !== $conteoDestino) {
            throw new RuntimeException(
                "Conteo no coincide para {$tabla}: origen={$conteoOrigen} destino={$conteoDestino}"
            );
        }

        return $conteoDestino;
    }

    /**
     * @return array<int,array{column_name:string,udt_name:string,character_maximum_length:?int,numeric_precision:?int,numeric_scale:?int}>
     */
    private function columnasDeOrigen(string $tabla): array
    {
        $stmt = $this->origen->prepare(
            "SELECT column_name, udt_name, character_maximum_length, numeric_precision, numeric_scale
             FROM information_schema.columns
             WHERE table_name = :tabla AND table_schema = 'public'
             ORDER BY ordinal_position"
        );
        $stmt->execute(['tabla' => $tabla]);
        return $stmt->fetchAll();
    }

    private function ddlCreateTable(string $tabla, array $columnas): string
    {
        $defs = [];
        foreach ($columnas as $c) {
            $defs[] = '"' . $c['column_name'] . '" ' . $this->tipoColumna($c);
        }
        return "CREATE TABLE {$tabla} (" . implode(', ', $defs) . ')';
    }

    private function tipoColumna(array $c): string
    {
        $udt = $c['udt_name'];
        return match ($udt) {
            'varchar', 'bpchar' => $c['character_maximum_length']
                ? "varchar({$c['character_maximum_length']})"
                : 'varchar',
            'numeric' => ($c['numeric_precision'] && $c['numeric_scale'] !== null)
                ? "numeric({$c['numeric_precision']},{$c['numeric_scale']})"
                : 'numeric',
            default => $udt,
        };
    }

    /**
     * @param array<int,string> $columnas
     * @param array<int,array<int,mixed>> $lote
     */
    private function insertarLote(string $tabla, array $columnas, array $lote): int
    {
        $numCol = count($columnas);
        $placeholderFila = '(' . implode(', ', array_fill(0, $numCol, '?')) . ')';
        $placeholders = implode(', ', array_fill(0, count($lote), $placeholderFila));
        $listaCol = implode(', ', $columnas);

        $stmt = $this->destino->prepare("INSERT INTO {$tabla} ({$listaCol}) VALUES {$placeholders}");
        $valoresPlanos = [];
        foreach ($lote as $fila) {
            foreach ($fila as $valor) {
                // PDO_PGSQL vincula un PHP bool `false` como '' en vez de
                // 'f' (verificado empíricamente contra columnas bool reales
                // como es_cpms_derivado), lo que Postgres rechaza. Se
                // convierte explícitamente a texto boolean de Postgres.
                if (is_bool($valor)) {
                    $valor = $valor ? 't' : 'f';
                }
                $valoresPlanos[] = $valor;
            }
        }
        $stmt->execute($valoresPlanos);
        return count($lote);
    }
}
