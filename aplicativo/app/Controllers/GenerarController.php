<?php
declare(strict_types=1);

class GenerarController
{
    public static function index(): void
    {
        $maxPeriodo = DatabaseService::obtenerUltimoMesCerrado();
        $periodo = $_GET['periodo'] ?? $maxPeriodo;
        if (!ArchivoService::periodoValido($periodo) || $periodo > $maxPeriodo) {
            $periodo = $maxPeriodo;
        }

        $repo = new EjecucionRepository(getCptPdo());
        $pasos = pipelineConfig();
        $ultimaCompletada = $repo->obtenerUltimaCompletada($periodo, 'generacion');
        $repo->liberarSiAbandonada();
        $enCurso = $repo->hayEnCurso();
        $ultimaCualquiera = $repo->listar($periodo, 'generacion', 1)[0] ?? null;

        $basesCpt = DatabaseService::listarBases('db_cpt');
        $basesSigesapol = DatabaseService::listarBases('sigesapol');
        if (empty($basesCpt)) $basesCpt = [DB_NAME_CPT];
        if (empty($basesSigesapol)) $basesSigesapol = [DB_NAME_SIGESAPOL];

        $dbCptSel = $_GET['db_cpt'] ?? ($basesCpt[0] ?? DB_NAME_CPT);
        $dbSigSel = $_GET['db_sigesapol'] ?? ($basesSigesapol[0] ?? DB_NAME_SIGESAPOL);

        if (!in_array($dbCptSel, $basesCpt, true)) $dbCptSel = $basesCpt[0];
        if (!in_array($dbSigSel, $basesSigesapol, true)) $dbSigSel = $basesSigesapol[0];

        $basesDistintas = false;
        if ($ultimaCualquiera !== null) {
            $ultCpt = !empty($ultimaCualquiera['db_cpt']) ? $ultimaCualquiera['db_cpt'] : DB_NAME_CPT;
            $ultSig = !empty($ultimaCualquiera['db_sigesapol']) ? $ultimaCualquiera['db_sigesapol'] : DB_NAME_SIGESAPOL;
            if ($ultCpt !== $dbCptSel || $ultSig !== $dbSigSel) {
                $basesDistintas = true;
            }
        }

        $fuenteCanonica = DatabaseService::obtenerFuenteCanonica($periodo);
        $alcance = DatabaseService::obtenerAlcance();

        renderizar('generar', [
            'titulo' => 'Generar tramas',
            'vistaActiva' => 'generar',
            'periodo' => $periodo,
            'maxPeriodo' => $maxPeriodo,
            'pasos' => $pasos,
            'ultimaCompletada' => $ultimaCompletada,
            'ultimaCualquiera' => $ultimaCualquiera,
            'enCurso' => $enCurso,
            'metricas' => $ultimaCompletada ? ArchivoService::metricas($periodo) : null,
            'basesCpt' => $basesCpt,
            'basesSigesapol' => $basesSigesapol,
            'dbCptSel' => $dbCptSel,
            'dbSigSel' => $dbSigSel,
            'basesDistintas' => $basesDistintas,
            'fuenteCanonica' => $fuenteCanonica,
            'alcance' => $alcance,
        ]);
    }
}
