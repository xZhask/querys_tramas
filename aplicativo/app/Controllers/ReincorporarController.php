<?php
declare(strict_types=1);

class ReincorporarController
{
    public static function index(): void
    {
        $periodos = ArchivoService::periodosDisponibles();
        $periodo = $_GET['periodo'] ?? ($periodos[0] ?? null);
        if ($periodo !== null && !in_array($periodo, $periodos, true)) {
            $periodo = $periodos[0] ?? null;
        }

        $repo = new EjecucionRepository(getCptPdo());

        renderizar('reincorporar', [
            'titulo' => 'Reincorporar decisiones de auditoría',
            'vistaActiva' => 'reincorporar',
            'periodo' => $periodo,
            'periodos' => $periodos,
            'nombreAuditoria' => $periodo ? ArchivoService::nombreAuditoria($periodo) : null,
            'ultimaReincorporacion' => $periodo ? ($repo->listar($periodo, 'reincorporacion', 1)[0] ?? null) : null,
        ]);
    }
}
