<?php
declare(strict_types=1);

class GenerarController
{
    public static function index(): void
    {
        $hoy = new DateTime();
        $periodo = $_GET['periodo'] ?? $hoy->format('Y-m');
        if (!ArchivoService::periodoValido($periodo)) {
            $periodo = $hoy->format('Y-m');
        }

        $repo = new EjecucionRepository(getCptPdo());
        $pasos = pipelineConfig();
        $ultimaCompletada = $repo->obtenerUltimaCompletada($periodo, 'generacion');
        $enCurso = $repo->hayEnCurso();
        $ultimaCualquiera = $repo->listar($periodo, 'generacion', 1)[0] ?? null;

        renderizar('generar', [
            'titulo' => 'Generar tramas',
            'vistaActiva' => 'generar',
            'periodo' => $periodo,
            'pasos' => $pasos,
            'ultimaCompletada' => $ultimaCompletada,
            'ultimaCualquiera' => $ultimaCualquiera,
            'enCurso' => $enCurso,
            'metricas' => $ultimaCompletada ? ArchivoService::metricas($periodo) : null,
        ]);
    }
}
