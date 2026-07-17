<?php
declare(strict_types=1);

class ResultadosController
{
    public static function index(): void
    {
        $periodos = ArchivoService::periodosDisponibles();
        $periodo = $_GET['periodo'] ?? ($periodos[0] ?? (new DateTime())->format('Y-m'));
        if (!in_array($periodo, $periodos, true)) {
            $periodo = $periodos[0] ?? $periodo;
        }

        renderizar('resultados', [
            'titulo' => 'Resultados',
            'vistaActiva' => 'resultados',
            'periodo' => $periodo,
            'periodos' => $periodos,
            'tramas' => $periodo ? ArchivoService::listarTramas($periodo) : [],
            'auditoriaExiste' => $periodo ? is_file(ArchivoService::rutaAuditoria($periodo)) : false,
            'nombreAuditoria' => $periodo ? ArchivoService::nombreAuditoria($periodo) : null,
            'informativos' => $periodo ? ArchivoService::listarInformativos($periodo) : [],
            'metricas' => $periodo ? ArchivoService::metricas($periodo) : null,
        ]);
    }
}
