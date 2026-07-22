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

    public function crear(string $periodo, string $tipo, string $iniciadoPor, int $pasoInicial = 0, ?string $dbCpt = null, ?string $dbSig = null): int
    {
        $stmt = $this->pdo->prepare(
            "INSERT INTO app_ejecuciones (periodo, tipo, paso_actual, estado, iniciado_por, log, db_cpt, db_sigesapol)
             VALUES (:periodo, :tipo, :paso, 'en_curso', :usuario, '[]'::jsonb, :db_cpt, :db_sig)
             RETURNING id"
        );
        $stmt->execute([
            'periodo' => $periodo,
            'tipo' => $tipo,
            'paso' => $pasoInicial,
            'usuario' => $iniciadoPor,
            'db_cpt' => $dbCpt,
            'db_sig' => $dbSig,
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

    /**
     * Libera automáticamente un candado 'en_curso' que lleva más de
     * $segundosInactividad sin avance (proceso abandonado: el navegador se
     * cerró, Apache mató el worker, etc.). Se llama tanto al renderizar la
     * pantalla Generar como al intentar iniciar una nueva ejecución, para
     * que el botón no quede deshabilitado indefinidamente por un candado
     * huérfano.
     *
     * La comparación de inactividad se calcula EN POSTGRES (EXTRACT(EPOCH
     * FROM now() - actualizado_en)), no con time()/strtotime() en PHP: la
     * columna es 'timestamp without time zone' y refleja la hora local de
     * la sesión de Postgres (America/Bogota, UTC-5), mientras que PHP corre
     * con date.timezone=UTC. Comparar strtotime($valor) contra time() da un
     * desfase constante de 5 horas (18000s) y marcaba como abandonada
     * cualquier ejecución recién creada.
     *
     * El umbral por defecto es alto (2 horas) a propósito: actualizado_en
     * solo se refresca cuando UN PASO TERMINA (registrarPaso), no mientras
     * corre, y un solo paso puede tardar minutos largos (paso 5 de
     * setiembre tardó 942s = 15.7 min; meses con más volumen pueden tardar
     * más). Con FcgidBusyTimeout ahora en 36000s, Apache tolera pasos aún
     * más largos. Un umbral corto liberaría el candado de una ejecución que
     * SIGUE corriendo de verdad, permitiendo que otra arranque en paralelo
     * y corrompa las mismas tablas temp_*. Esta función ahora se invoca en
     * cada carga de la pantalla Generar (antes solo al pulsar el botón), así
     * que el margen de seguridad debe ser generoso; para el caso de un
     * candado reciente que el usuario SABE que ya no sigue corriendo, se usa
     * el botón manual "Detener y reiniciar" (acción 'liberar'), que no
     * depende de este umbral.
     */
    public function liberarSiAbandonada(int $segundosInactividad = 7200): void
    {
        $stmt = $this->pdo->prepare(
            "SELECT id, EXTRACT(EPOCH FROM (now() - actualizado_en)) AS segundos_inactivo
             FROM app_ejecuciones WHERE estado = 'en_curso'
             ORDER BY iniciado_en DESC LIMIT 1"
        );
        $stmt->execute();
        $row = $stmt->fetch();
        if ($row !== null && (float) $row['segundos_inactivo'] > $segundosInactividad) {
            $this->finalizar((int) $row['id'], 'fallido');
        }
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
