<?php
declare(strict_types=1);

/**
 * Resuelve rutas del contrato de salidas v2 (expedientes/<AAAA-MM>/...).
 * Único punto del aplicativo que sabe dónde vive cada archivo generado por
 * el pipeline; descargar.php nunca concatena input del usuario directo a una
 * ruta de filesystem, siempre pasa por acá.
 */
class ArchivoService
{
    public static function periodoValido(string $periodo): bool
    {
        return (bool) preg_match('/^\d{4}-(0[1-9]|1[0-2])$/', $periodo);
    }

    public static function carpetaExpediente(string $periodo): string
    {
        return REPO_ROOT . '/expedientes/' . $periodo;
    }

    /**
     * @return array<int,array{nombre:string,existe:bool,tamano:?int}>
     */
    public static function listarTramas(string $periodo): array
    {
        $archivos = [
            'trama_consulta_externa.txt',
            'trama_emergencia.txt',
            'trama_hospitalizacion.txt',
            'trama_farmacia.txt',
        ];
        $dir = self::carpetaExpediente($periodo) . '/01_TRAMAS';
        return self::describirArchivos($dir, $archivos);
    }

    public static function nombreAuditoria(string $periodo): string
    {
        return "02_AUDITORIA_{$periodo}.xlsx";
    }

    public static function rutaAuditoria(string $periodo): string
    {
        return self::carpetaExpediente($periodo) . '/' . self::nombreAuditoria($periodo);
    }

    /**
     * @return array<int,array{nombre:string,existe:bool,tamano:?int}>
     */
    public static function listarInformativos(string $periodo): array
    {
        $dir = self::carpetaExpediente($periodo) . '/03_INFORMATIVOS';
        $archivos = ['controles_integridad.txt', 'controles_integridad_raw.txt', 'metricas.json', 'reincorporacion.log'];
        return self::describirArchivos($dir, $archivos);
    }

    /**
     * @param array<int,string> $archivos
     * @return array<int,array{nombre:string,existe:bool,tamano:?int}>
     */
    private static function describirArchivos(string $dir, array $archivos): array
    {
        $resultado = [];
        foreach ($archivos as $nombre) {
            $ruta = $dir . '/' . $nombre;
            $existe = is_file($ruta);
            $resultado[] = [
                'nombre' => $nombre,
                'existe' => $existe,
                'tamano' => $existe ? filesize($ruta) : null,
            ];
        }
        return $resultado;
    }

    /**
     * Resuelve una descarga validando período + grupo + archivo contra la
     * whitelist real (nunca contra el input crudo). Devuelve null si no
     * corresponde a nada permitido.
     */
    public static function resolverDescarga(string $periodo, string $grupo, string $archivo): ?string
    {
        if (!self::periodoValido($periodo)) {
            return null;
        }

        switch ($grupo) {
            case 'tramas':
                foreach (self::listarTramas($periodo) as $t) {
                    if ($t['nombre'] === $archivo && $t['existe']) {
                        return self::carpetaExpediente($periodo) . '/01_TRAMAS/' . $t['nombre'];
                    }
                }
                return null;

            case 'auditoria':
                $ruta = self::rutaAuditoria($periodo);
                return ($archivo === self::nombreAuditoria($periodo) && is_file($ruta)) ? $ruta : null;

            case 'informativos':
                foreach (self::listarInformativos($periodo) as $i) {
                    if ($i['nombre'] === $archivo && $i['existe']) {
                        return self::carpetaExpediente($periodo) . '/03_INFORMATIVOS/' . $i['nombre'];
                    }
                }
                return null;

            default:
                return null;
        }
    }

    public static function metricas(string $periodo): ?array
    {
        $ruta = self::carpetaExpediente($periodo) . '/03_INFORMATIVOS/metricas.json';
        if (!is_file($ruta)) {
            return null;
        }
        $contenido = file_get_contents($ruta);
        $datos = json_decode($contenido, true);
        return is_array($datos) ? $datos : null;
    }

    /**
     * Lista los períodos con expediente generado (carpetas expedientes/AAAA-MM).
     * @return array<int,string>
     */
    public static function periodosDisponibles(): array
    {
        $base = REPO_ROOT . '/expedientes';
        if (!is_dir($base)) {
            return [];
        }
        $periodos = [];
        foreach (scandir($base) as $entrada) {
            if (self::periodoValido($entrada) && is_dir($base . '/' . $entrada)) {
                $periodos[] = $entrada;
            }
        }
        rsort($periodos);
        return $periodos;
    }
}
