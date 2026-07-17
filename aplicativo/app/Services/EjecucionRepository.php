<?php
declare(strict_types=1);

/**
 * CRUD sobre app_ejecuciones. Es la única tabla que el aplicativo escribe
 * para llevar el estado del pipeline (además de las tablas temp_ y cfg_
 * que los propios .sql/.py del repo crean).
 */
class EjecucionRepository
{
    private PDO $pdo;

    public function __construct(PDO $pdo)
    {
        $this->pdo = $pdo;
    }

    public function crear(string $periodo, string $tipo, string $iniciadoPor, int $pasoInicial = 0): int
    {
        $stmt = $this->pdo->prepare(
            "INSERT INTO app_ejecuciones (periodo, tipo, paso_actual, estado, iniciado_por, log)
             VALUES (:periodo, :tipo, :paso, 'en_curso', :usuario, '[]'::jsonb)
             RETURNING id"
        );
        $stmt->execute([
            'periodo' => $periodo,
            'tipo' => $tipo,
            'paso' => $pasoInicial,
            'usuario' => $iniciadoPor,
        ]);
        return (int) $stmt->fetchColumn();
    }

    public function porId(int $id): ?array
    {
        $stmt = $this->pdo->prepare('SELECT * FROM app_ejecuciones WHERE id = :id');
        $stmt->execute(['id' => $id]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public function hayEnCurso(): ?array
    {
        $stmt = $this->pdo->query(
            "SELECT * FROM app_ejecuciones WHERE estado = 'en_curso' ORDER BY iniciado_en DESC LIMIT 1"
        );
        $row = $stmt->fetch();
        return $row ?: null;
    }

    public function obtenerUltimaCompletada(string $periodo, string $tipo = 'generacion'): ?array
    {
        $stmt = $this->pdo->prepare(
            "SELECT * FROM app_ejecuciones
             WHERE periodo = :periodo AND tipo = :tipo AND estado = 'completado'
             ORDER BY iniciado_en DESC LIMIT 1"
        );
        $stmt->execute(['periodo' => $periodo, 'tipo' => $tipo]);
        $row = $stmt->fetch();
        return $row ?: null;
    }

    /**
     * Agrega una entrada al log jsonb y actualiza paso_actual/estado.
     */
    public function registrarPaso(
        int $id,
        int $paso,
        string $nombrePaso,
        string $estadoPaso,
        ?string $mensaje = null,
        ?int $conteo = null,
        ?string $detalleTecnico = null,
        ?float $duracionMs = null
    ): void {
        // La salida de los scripts .py (stdout/stderr de proc_open) puede
        // traer bytes que no son UTF-8 válido (consola de Windows en otro
        // codepage). Sin JSON_INVALID_UTF8_SUBSTITUTE, json_encode() devuelve
        // false en ese caso y rompe el cast a jsonb más abajo.
        $entrada = json_encode([
            'paso' => $paso,
            'nombre' => $nombrePaso,
            'estado' => $estadoPaso,
            'mensaje' => $mensaje,
            'conteo' => $conteo,
            'detalle_tecnico' => $detalleTecnico,
            'duracion_ms' => $duracionMs,
            'timestamp' => (new DateTime())->format(DateTime::ATOM),
        ], JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);

        if ($entrada === false) {
            $entrada = json_encode([
                'paso' => $paso,
                'nombre' => $nombrePaso,
                'estado' => $estadoPaso,
                'mensaje' => $mensaje,
                'conteo' => $conteo,
                'detalle_tecnico' => '(detalle técnico omitido: contenía datos no serializables)',
                'duracion_ms' => $duracionMs,
                'timestamp' => (new DateTime())->format(DateTime::ATOM),
            ]);
        }

        $stmt = $this->pdo->prepare(
            "UPDATE app_ejecuciones
             SET log = log || :entrada::jsonb,
                 paso_actual = :paso,
                 actualizado_en = now()
             WHERE id = :id"
        );
        $stmt->execute(['entrada' => $entrada, 'paso' => $paso, 'id' => $id]);
    }

    public function finalizar(int $id, string $estadoFinal): void
    {
        $stmt = $this->pdo->prepare(
            "UPDATE app_ejecuciones SET estado = :estado, actualizado_en = now() WHERE id = :id"
        );
        $stmt->execute(['estado' => $estadoFinal, 'id' => $id]);
    }

    /**
     * True si, para el período dado, algún paso >= $desdePaso ya corrió
     * 'completado' en la última ejecución 'generacion' completada. Se usa
     * para bloquear el re-disparo accidental de los pasos de una sola pasada
     * (6/7/8) al presionar "Generar tramas" sobre un período ya procesado.
     */
    public function tieneAvanceDesde(string $periodo, int $desdePaso): bool
    {
        $ultima = $this->obtenerUltimaCompletada($periodo, 'generacion');
        if ($ultima === null) {
            return false;
        }
        $log = json_decode($ultima['log'], true) ?: [];
        foreach ($log as $entrada) {
            if (($entrada['paso'] ?? 0) >= $desdePaso && ($entrada['estado'] ?? '') === 'completado') {
                return true;
            }
        }
        return false;
    }

    /**
     * @return array<int,array>
     */
    public function listar(?string $periodo = null, ?string $tipo = null, int $limite = 100): array
    {
        $condiciones = [];
        $params = [];
        if ($periodo !== null) {
            $condiciones[] = 'periodo = :periodo';
            $params['periodo'] = $periodo;
        }
        if ($tipo !== null) {
            $condiciones[] = 'tipo = :tipo';
            $params['tipo'] = $tipo;
        }
        $where = $condiciones ? ('WHERE ' . implode(' AND ', $condiciones)) : '';
        $stmt = $this->pdo->prepare(
            "SELECT * FROM app_ejecuciones $where ORDER BY iniciado_en DESC LIMIT :limite"
        );
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->bindValue('limite', $limite, PDO::PARAM_INT);
        $stmt->execute();
        return $stmt->fetchAll();
    }
}
