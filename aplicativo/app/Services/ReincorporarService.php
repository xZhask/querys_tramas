<?php
declare(strict_types=1);

require_once REPO_ROOT . '/aplicativo/vendor/autoload.php';

use PhpOffice\PhpSpreadsheet\IOFactory;

/**
 * Valida el libro de auditoría subido por el usuario ANTES de invocar
 * 13_REINCORPORAR_decisiones.py, y orquesta la reincorporación completa.
 * No decide nada sobre los datos (eso lo hace el script 13); solo protege
 * la entrada: mismo período, decisiones válidas, columnas llave intactas.
 */
class ReincorporarService
{
    private const HOJAS = ['ESTANCIAS_E_H', 'DUPLICADOS_FUENTES', 'DUPLICADOS_ORIGEN', 'TRANSF_HUERFANAS'];

    // Índice 0-based de columnas del contrato del libro de auditoría.
    private const COL_PERIODO = 0;
    private const COL_MOTIVO = 18;
    private const COL_DECISION = 19;
    private const COL_OBSERVACION = 20;

    private const DECISIONES_VALIDAS = [
        'ESTANCIAS_E_H' => ['SE UNE', 'NO SE UNE'],
        'DUPLICADOS_FUENTES' => ['PROCEDE', 'NO PROCEDE'],
        'DUPLICADOS_ORIGEN' => ['CONSOLIDAR CANTIDAD', 'PROCEDE INDEPENDIENTE'],
        'TRANSF_HUERFANAS' => ['PROCEDE', 'NO PROCEDE'],
    ];

    /**
     * @return array{ok:bool,errores:array<int,string>}
     */
    public function validar(string $periodo, string $rutaSubida): array
    {
        $errores = [];

        $rutaOriginal = ArchivoService::rutaAuditoria($periodo);
        if (!is_file($rutaOriginal)) {
            return ['ok' => false, 'errores' => ["No existe un libro de auditoría generado para el período {$periodo}. Genere las tramas primero."]];
        }

        try {
            $wbSubido = IOFactory::load($rutaSubida);
            $wbOriginal = IOFactory::load($rutaOriginal);
        } catch (Throwable $e) {
            return ['ok' => false, 'errores' => ["El archivo subido no es un libro de Excel válido: " . $e->getMessage()]];
        }

        foreach (self::HOJAS as $hoja) {
            if (!$wbSubido->sheetNameExists($hoja)) {
                $errores[] = "Falta la hoja \"{$hoja}\" en el libro subido.";
                continue;
            }
            if (!$wbOriginal->sheetNameExists($hoja)) {
                continue;
            }
            $filasSubidas = $wbSubido->getSheetByName($hoja)->toArray(null, true, false, false);
            $filasOriginales = $wbOriginal->getSheetByName($hoja)->toArray(null, true, false, false);

            if (count($filasSubidas) !== count($filasOriginales)) {
                $errores[] = "La hoja \"{$hoja}\" tiene " . count($filasSubidas) . " filas, se esperaban " . count($filasOriginales) . " (no se pueden agregar ni quitar filas).";
                continue;
            }

            foreach ($filasSubidas as $i => $filaSubida) {
                if ($i === 0) {
                    continue; // encabezado
                }
                $filaOriginal = $filasOriginales[$i] ?? null;
                if ($filaOriginal === null) {
                    continue;
                }
                if (($filaSubida[self::COL_PERIODO] ?? '') === '' && ($filaOriginal[self::COL_PERIODO] ?? '') === '') {
                    continue; // fila vacía en ambos
                }
                if (trim((string) ($filaSubida[self::COL_PERIODO] ?? '')) !== $periodo
                    && trim((string) ($filaOriginal[self::COL_PERIODO] ?? '')) === $periodo) {
                    $errores[] = "Hoja \"{$hoja}\", fila " . ($i + 1) . ": la columna 'periodo' no coincide con {$periodo}.";
                }

                for ($col = self::COL_PERIODO; $col <= self::COL_MOTIVO; $col++) {
                    $valorSubido = trim((string) ($filaSubida[$col] ?? ''));
                    $valorOriginal = trim((string) ($filaOriginal[$col] ?? ''));
                    if ($valorSubido !== $valorOriginal) {
                        $errores[] = "Hoja \"{$hoja}\", fila " . ($i + 1) . ": se modificó una columna llave (no editable). Solo DECISION_AUDITORIA y OBSERVACION_AUDITORIA pueden cambiar.";
                        break;
                    }
                }

                $decision = strtoupper(trim((string) ($filaSubida[self::COL_DECISION] ?? '')));
                if ($decision !== '' && !in_array($decision, self::DECISIONES_VALIDAS[$hoja], true)) {
                    $permitidas = implode(' / ', self::DECISIONES_VALIDAS[$hoja]);
                    $errores[] = "Hoja \"{$hoja}\", fila " . ($i + 1) . ": DECISION_AUDITORIA \"{$decision}\" no es válida (use: {$permitidas}).";
                }

                if (count($errores) > 30) {
                    $errores[] = "Se alcanzó el máximo de errores mostrados; corrija los anteriores y vuelva a subir el archivo.";
                    break 2;
                }
            }
        }

        return ['ok' => empty($errores), 'errores' => $errores];
    }

    /**
     * Respalda el xlsx actual (reversible) y copia el subido a su ruta
     * canónica, la que espera 13_REINCORPORAR_decisiones.py.
     */
    public function reemplazarLibroAuditoria(string $periodo, string $rutaSubida): string
    {
        $rutaOriginal = ArchivoService::rutaAuditoria($periodo);
        $timestamp = date('Ymd_His');
        $rutaRespaldo = ArchivoService::carpetaExpediente($periodo) . "/02_AUDITORIA_{$periodo}.pre_reincorporacion_{$timestamp}.xlsx";
        copy($rutaOriginal, $rutaRespaldo);
        move_uploaded_file($rutaSubida, $rutaOriginal) || copy($rutaSubida, $rutaOriginal);
        return $rutaRespaldo;
    }
}
