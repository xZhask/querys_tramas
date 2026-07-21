<?php
declare(strict_types=1);

require_once __DIR__ . '/TrasladoService.php';

/**
 * Ejecuta UN paso del pipeline según config/pipeline.php. Nunca reimplementa
 * lógica de negocio: para pasos 'sql' hace PDO::exec() del archivo del repo
 * (con sustitución de período si corresponde, igual que run_month.ps1); para
 * pasos 'python' invoca el script real con proc_open; para 'traslado' delega
 * en TrasladoService.
 */
class PipelineRunner
{
    public function __construct(private int $year, private int $month)
    {
    }

    public function periodo(): string
    {
        return sprintf('%04d-%02d', $this->year, $this->month);
    }

    private function rangoPeriodo(): array
    {
        $pIni = sprintf('%04d-%02d-01', $this->year, $this->month);
        $dias = (int) cal_days_in_month(CAL_GREGORIAN, $this->month, $this->year);
        $pFin = sprintf('%04d-%02d-%02d', $this->year, $this->month, $dias);
        return [$pIni, $pFin];
    }

    /**
     * @return array{ok:bool,mensaje:string,conteo:?int,detalle_tecnico:?string}
     */
    public function ejecutar(array $paso): array
    {
        try {
            switch ($paso['tipo']) {
                case 'sql':
                    return $this->ejecutarSql($paso);
                case 'traslado':
                    return $this->ejecutarTraslado($paso);
                case 'python':
                    return $this->ejecutarPython($paso);
                default:
                    throw new RuntimeException("Tipo de paso desconocido: {$paso['tipo']}");
            }
        } catch (Throwable $e) {
            return [
                'ok' => false,
                'mensaje' => $this->mensajeAmigable($paso),
                'conteo' => null,
                'detalle_tecnico' => $e->getMessage(),
            ];
        }
    }

    private function mensajeAmigable(array $paso): string
    {
        return "No se pudo completar el paso \"{$paso['nombre']}\". Revise el detalle técnico o reintente.";
    }

    private function ejecutarSql(array $paso): array
    {
        $ruta = REPO_ROOT . DIRECTORY_SEPARATOR . $paso['archivo'];
        if (!is_file($ruta)) {
            throw new RuntimeException("No se encontró el archivo del pipeline: {$paso['archivo']}");
        }
        $sql = file_get_contents($ruta);
        if ($sql === false) {
            throw new RuntimeException("No se pudo leer {$paso['archivo']}");
        }

        if (!empty($paso['edita_periodo'])) {
            [$pIni, $pFin] = $this->rangoPeriodo();
            $sql = $this->sustituirPeriodo($sql, $pIni, $pFin);
            file_put_contents($ruta, $sql);
        }

        $pdo = $paso['bd'] === 'sigesapol' ? getSigesapolPdo() : getCptPdo();

        if (!empty($paso['limpiar_indices_antes'])) {
            foreach ($paso['limpiar_indices_antes'] as $indice) {
                $pdo->exec("DROP INDEX IF EXISTS {$indice}");
            }
        }

        if (!empty($paso['guarda_salida_en'])) {
            // Este paso solo tiene SELECTs de diagnóstico (sin mutar datos):
            // se corre sentencia por sentencia para capturar su salida
            // tabular, igual que "psql -f ... > archivo.txt" en run_month.ps1.
            $this->ejecutarYGuardarSalida($pdo, $sql, $paso);
        } else {
            // PDO_PGSQL no admite múltiples sentencias en un solo exec()
            // ("no se pueden insertar múltiples órdenes en una sentencia
            // preparada", verificado empíricamente) — a diferencia de
            // psql -f, que sí lo hace. Se corre sentencia por sentencia.
            foreach ($this->dividirSentencias($sql) as $sentencia) {
                $pdo->exec($sentencia);
            }
        }

        if (!empty($paso['crear_indices_despues'])) {
            $this->crearIndicesPostMaterializacion($pdo);
        }

        return $this->validar($paso, null);
    }

    /**
     * Índices compuestos sobre las tablas temp_bdt_ y temp_laboratorio_
     * recién materializadas por 03_MAESTRO_paso2_CPT.sql, igual que
     * run_month.ps1 los crea antes de la deduplicación/consolidación (pasos
     * 6/7). No son parte del archivo .sql porque son una optimización de
     * infraestructura, no una regla de negocio.
     */
    private function crearIndicesPostMaterializacion(PDO $pdo): void
    {
        $sentencias = [
            "CREATE INDEX IF NOT EXISTS idx_tmp_bdt_cons_doc_fecha_cod ON temp_bdt_consulta_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_bdt_emer_doc_fecha_cod ON temp_bdt_emergencia_sigesapol (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_bdt_hosp_doc_fecha_cod ON temp_bdt_hospitalizacion_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_lab_cons_doc_fecha_cod ON temp_laboratorio_consulta_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_lab_emer_doc_fecha_cod ON temp_laboratorio_emergencia_sigesapol (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_lab_hosp_doc_fecha_cod ON temp_laboratorio_hospitalizacion_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento)",
            "CREATE INDEX IF NOT EXISTS idx_tmp_sig_proc_trama ON temp_sigesapol_procedimientos (sp_numero_documento_paciente, sp_fecha_atencion, sp_codigo_procedimiento)",
            "ANALYZE temp_bdt_consulta_local, temp_bdt_emergencia_sigesapol, temp_bdt_hospitalizacion_local, temp_laboratorio_consulta_local, temp_laboratorio_emergencia_sigesapol, temp_laboratorio_hospitalizacion_local, temp_sigesapol_procedimientos",
        ];
        foreach ($sentencias as $sentencia) {
            $pdo->exec($sentencia);
        }
    }

    /**
     * Reemplaza el bloque "SELECT DATE '...' AS p_ini, ... DATE '...' AS p_fin"
     * dentro del propio archivo .sql — el mismo mecanismo, ya validado en
     * producción, que usa run_month.ps1 (ver 02_MAESTRO_paso1_SIGESAPOL.sql y
     * 03_MAESTRO_paso2_CPT.sql, bloque "CONFIGURAR PERÍODO AQUÍ").
     */
    private function sustituirPeriodo(string $sql, string $pIni, string $pFin): string
    {
        $patron = "/SELECT DATE '[0-9-]{10}' AS p_ini,[\\s\\S]*?DATE '[0-9-]{10}' AS p_fin/";
        $reemplazo = "SELECT DATE '{$pIni}' AS p_ini,   -- <== inicio del periodo\n       DATE '{$pFin}' AS p_fin";
        $resultado = preg_replace($patron, $reemplazo, $sql, 1, $conteo);
        if ($resultado === null || $conteo !== 1) {
            throw new RuntimeException('No se encontró el bloque de período a sustituir en el archivo .sql (¿cambió su formato?).');
        }
        return $resultado;
    }

    private function ejecutarYGuardarSalida(PDO $pdo, string $sql, array $paso): void
    {
        $destino = REPO_ROOT . '/expedientes/' . $this->periodo() . '/' . $paso['guarda_salida_en'];
        $dir = dirname($destino);
        if (!is_dir($dir)) {
            mkdir($dir, 0777, true);
        }
        $lineas = [];
        foreach ($this->dividirSentencias($sql) as $sentencia) {
            $stmt = $pdo->query($sentencia);
            if ($stmt !== false && $stmt->columnCount() > 0) {
                $encabezados = [];
                for ($i = 0; $i < $stmt->columnCount(); $i++) {
                    $meta = $stmt->getColumnMeta($i);
                    $encabezados[] = $meta['name'] ?? "col{$i}";
                }
                $lineas[] = implode(' | ', $encabezados);
                foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $fila) {
                    $lineas[] = implode(' | ', array_map(fn($v) => $v ?? '', $fila));
                }
                $lineas[] = str_repeat('-', 40);
            }
        }
        file_put_contents($destino, implode("\n", $lineas));
    }

    /**
     * Divide un archivo .sql en sentencias individuales por ';' de nivel
     * superior, respetando comentarios (--, /* *\/), strings entre comillas
     * simples (con '' como escape) y bloques con dólar-comillas ($$ ... $$
     * o $tag$ ... $tag$) como los "DO $$ BEGIN ... END $$;" que usan
     * 02/03/05/06/08 para validar que cfg_periodo exista.
     *
     * @return array<int,string>
     */
    private function dividirSentencias(string $sql): array
    {
        $sentencias = [];
        $actual = '';
        $len = strlen($sql);
        $i = 0;
        $enComentarioLinea = false;
        $enComentarioBloque = false;
        $enComillaSimple = false;
        $enComillaDoble = false;
        $tagDolar = null;

        while ($i < $len) {
            $c = $sql[$i];
            $dos = substr($sql, $i, 2);

            if ($enComentarioLinea) {
                if ($c === "\n") {
                    $enComentarioLinea = false;
                    $actual .= $c;
                }
                $i++;
                continue;
            }
            if ($enComentarioBloque) {
                if ($dos === '*/') {
                    $enComentarioBloque = false;
                    $i += 2;
                    continue;
                }
                $i++;
                continue;
            }
            if ($enComillaSimple) {
                $actual .= $c;
                if ($c === "'") {
                    if (($sql[$i + 1] ?? '') === "'") {
                        $actual .= "'";
                        $i += 2;
                        continue;
                    }
                    $enComillaSimple = false;
                }
                $i++;
                continue;
            }
            if ($enComillaDoble) {
                $actual .= $c;
                if ($c === '"') {
                    $enComillaDoble = false;
                }
                $i++;
                continue;
            }
            if ($tagDolar !== null) {
                if (substr($sql, $i, strlen($tagDolar)) === $tagDolar) {
                    $actual .= $tagDolar;
                    $i += strlen($tagDolar);
                    $tagDolar = null;
                    continue;
                }
                $actual .= $c;
                $i++;
                continue;
            }

            // Estado normal (fuera de comentarios/strings/bloques $$).
            if ($dos === '--') {
                $enComentarioLinea = true;
                $i += 2;
                continue;
            }
            if ($dos === '/*') {
                $enComentarioBloque = true;
                $i += 2;
                continue;
            }
            if ($c === "'") {
                $enComillaSimple = true;
                $actual .= $c;
                $i++;
                continue;
            }
            if ($c === '"') {
                $enComillaDoble = true;
                $actual .= $c;
                $i++;
                continue;
            }
            if ($c === '$' && preg_match('/\G\$[a-zA-Z_]*\$/', $sql, $m, 0, $i)) {
                $tagDolar = $m[0];
                $actual .= $tagDolar;
                $i += strlen($tagDolar);
                continue;
            }
            if ($c === ';') {
                $sentencias[] = trim($actual);
                $actual = '';
                $i++;
                continue;
            }
            $actual .= $c;
            $i++;
        }
        if (trim($actual) !== '') {
            $sentencias[] = trim($actual);
        }

        return array_values(array_filter($sentencias, fn($s) => $s !== ''));
    }

    private function ejecutarTraslado(array $paso): array
    {
        $servicio = new TrasladoService(getSigesapolPdo(), getCptPdo());
        $resultado = $servicio->ejecutar($paso['tablas']);
        return [
            'ok' => $resultado['ok'],
            'mensaje' => $resultado['ok']
                ? 'Traslado completado, conteos verificados origen = destino.'
                : $this->mensajeAmigable($paso),
            'conteo' => $resultado['total'] ?? null,
            'detalle_tecnico' => $resultado['detalle'] ?? null,
        ];
    }

    private function ejecutarPython(array $paso): array
    {
        $resultado = $this->ejecutarScriptCrudo($paso['archivo']);
        $detalle = trim($resultado['stdout'] . "\n" . $resultado['stderr']);
        return $this->validar($paso, $detalle, $resultado['codigo'], $resultado['stdout']);
    }

    /**
     * Corre cualquier script .py del repo con --year/--month para este
     * período, sin pasar por la tabla de validación de config/pipeline.php.
     * Usado también fuera del pipeline numerado (13_REINCORPORAR_decisiones.py,
     * re-verificación de aserciones tras reincorporar).
     *
     * @return array{codigo:int,stdout:string,stderr:string}
     */
    public function ejecutarScriptCrudo(string $archivoRelativo): array
    {
        $script = REPO_ROOT . DIRECTORY_SEPARATOR . $archivoRelativo;
        $cmd = [PYTHON_BIN, $script, '--year', (string) $this->year, '--month', (string) $this->month];

        $descriptores = [1 => ['pipe', 'w'], 2 => ['pipe', 'w']];
        $proceso = proc_open($cmd, $descriptores, $tuberias, REPO_ROOT);
        if (!is_resource($proceso)) {
            throw new RuntimeException("No se pudo iniciar el proceso Python para {$archivoRelativo}");
        }
        $stdout = stream_get_contents($tuberias[1]);
        $stderr = stream_get_contents($tuberias[2]);
        fclose($tuberias[1]);
        fclose($tuberias[2]);
        $codigo = proc_close($proceso);

        return ['codigo' => $codigo, 'stdout' => $stdout, 'stderr' => $stderr];
    }

    /**
     * @return array{ok:bool,mensaje:string,conteo:?int,detalle_tecnico:?string}
     */
    private function validar(array $paso, ?string $detalleProceso, ?int $codigoSalida = 0, ?string $stdout = null): array
    {
        $v = $paso['validacion'];
        switch ($v['tipo']) {
            case 'conteo':
                $pdo = $v['bd'] === 'sigesapol' ? getSigesapolPdo() : getCptPdo();
                $conteo = (int) $pdo->query("SELECT COUNT(*) FROM {$v['tabla']}")->fetchColumn();
                return [
                    'ok' => true,
                    'mensaje' => "Paso completado. {$v['tabla']}: {$conteo} filas.",
                    'conteo' => $conteo,
                    'detalle_tecnico' => null,
                ];

            case 'sin_error':
                return [
                    'ok' => true,
                    'mensaje' => 'Paso completado sin errores.',
                    'conteo' => null,
                    'detalle_tecnico' => null,
                ];

            case 'exit_0':
                $ok = $codigoSalida === 0;
                return [
                    'ok' => $ok,
                    'mensaje' => $ok
                        ? 'Verificación de aserciones completada: A1/A2/A3/A4/A5 en PASS.'
                        : $this->mensajeAmigable($paso),
                    'conteo' => null,
                    'detalle_tecnico' => $detalleProceso,
                ];

            case 'archivo_existe':
                $rutaMetricas = REPO_ROOT . '/expedientes/' . $this->periodo() . '/03_INFORMATIVOS/metricas.json';
                $ok = $codigoSalida === 0 && is_file($rutaMetricas);
                return [
                    'ok' => $ok,
                    'mensaje' => $ok
                        ? 'Tramas y libro de auditoría generados.'
                        : $this->mensajeAmigable($paso),
                    'conteo' => null,
                    'detalle_tecnico' => $detalleProceso,
                ];

            default:
                throw new RuntimeException("Validación desconocida: {$v['tipo']}");
        }
    }
}
