<?php
declare(strict_types=1);

class BitacoraController
{
    public static function index(): void
    {
        $periodo = $_GET['periodo'] ?? null;
        if ($periodo !== null && !ArchivoService::periodoValido($periodo)) {
            $periodo = null;
        }

        $repo = new EjecucionRepository(getCptPdo());
        $ejecuciones = $repo->listar($periodo, null, 200);

        renderizar('bitacora', [
            'titulo' => 'Bitácora',
            'vistaActiva' => 'bitacora',
            'periodo' => $periodo,
            'ejecuciones' => $ejecuciones,
        ]);
    }
}
