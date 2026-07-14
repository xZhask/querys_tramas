param (
    [int]$Year = 2025,
    [Parameter(Mandatory=$true)]
    [int]$Month
)

# 1. Configuracion de Variables del Periodo
$MonthPad = "{0:D2}" -f $Month
$daysInMonth = [DateTime]::DaysInMonth($Year, $Month)
$p_ini = "$Year-$MonthPad-01"
$p_fin = "$Year-$MonthPad-$daysInMonth"

# Canonico por mes
$canonico = "CPT"
if ($Month -ge 10) {
    $canonico = "SIGESAPOL"
}

Write-Output "=========================================================="
Write-Output "INICIANDO LOTE MENSUAL: $Year-$MonthPad (Canonico: $canonico)"
Write-Output "Rango: $p_ini a $p_fin"
Write-Output "=========================================================="

$env:PGPASSWORD = "root"
$psqlPath = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
$pgdumpPath = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"

$expPath = "$PSScriptRoot\expedientes\$Year-$MonthPad"
$tramaPath = "$PSScriptRoot\tramas_exportadas\$Year-$MonthPad"

New-Item -ItemType Directory -Force -Path $expPath | Out-Null
New-Item -ItemType Directory -Force -Path $tramaPath | Out-Null

$perf = @{}

# 2. Modificar y Ejecutar Script 02 (SIGESAPOL Maestro)
$t0 = Get-Date
$file02 = [System.IO.Path]::GetFullPath("02_MAESTRO_paso1_SIGESAPOL.sql")
$content02 = [System.IO.File]::ReadAllText($file02, [System.Text.Encoding]::UTF8)
$content02 = $content02 -replace "SELECT DATE '[0-9-]{10}' AS p_ini,[\s\S]*?DATE '[0-9-]{10}' AS p_fin", "SELECT DATE '$p_ini' AS p_ini,   -- <== inicio del periodo`r`n       DATE '$p_fin' AS p_fin"
[System.IO.File]::WriteAllText($file02, $content02, (New-Object System.Text.UTF8Encoding $false))

Write-Output "[1/12] Ejecutando 02_MAESTRO_paso1_SIGESAPOL.sql..."
& $psqlPath -U postgres -d sigesapol_junio -f $file02 | Out-Null
$perf["paso1"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 3. Ejecutar Script 05 (SIGESAPOL Hospitalizacion)
$t0 = Get-Date
Write-Output "[2/12] Ejecutando 05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql..."
$file05 = "05_FASE2_paso1b_SIGESAPOL_hospitalizacion.sql"
& $psqlPath -U postgres -d sigesapol_junio -f $file05 | Out-Null
$perf["paso1b_hosp"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 4. Ejecutar Script 06 (SIGESAPOL Procedimientos)
$t0 = Get-Date
Write-Output "[3/12] Ejecutando 06_FASE2_SIGESAPOL_procedimientos.sql..."
$file06 = "06_FASE2_SIGESAPOL_procedimientos.sql"
& $psqlPath -U postgres -d sigesapol_junio -f $file06 | Out-Null
$perf["paso1c_proc"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 5. Traslado de Tablas por pg_dump
$t0 = Get-Date
Write-Output "[4/12] Trasladando tablas de SIGESAPOL a CPT..."
& $psqlPath -U postgres -d db_cpt_junio26 -c "DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia, temp_hospitalizacion_sigesapol_estancia, temp_sigesapol_procedimientos;" | Out-Null
& $pgdumpPath -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia -t temp_hospitalizacion_sigesapol_estancia -t temp_sigesapol_procedimientos | & $psqlPath -U postgres -d db_cpt_junio26 | Out-Null
$perf["traslado_pgdump"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 6. Modificar y Ejecutar Script 03 (CPT Maestro)
$t0 = Get-Date
Write-Output "[5/12] Ejecutando 03_MAESTRO_paso2_CPT.sql..."
$file03 = [System.IO.Path]::GetFullPath("03_MAESTRO_paso2_CPT.sql")
$content03 = [System.IO.File]::ReadAllText($file03, [System.Text.Encoding]::UTF8)
$content03 = $content03 -replace "SELECT DATE '[0-9-]{10}' AS p_ini,[\s\S]*?DATE '[0-9-]{10}' AS p_fin", "SELECT DATE '$p_ini' AS p_ini,   -- <== inicio del periodo (igual al paso 1)`r`n       DATE '$p_fin' AS p_fin"
[System.IO.File]::WriteAllText($file03, $content03, (New-Object System.Text.UTF8Encoding $false))

& $psqlPath -U postgres -d db_cpt_junio26 -f $file03 | Out-Null

# Crear indices compuestos para acelerar la deduplicacion y consolidacion
Write-Output "Creando indices compuestos en CPT para optimizar cruces..."
$sqlIndices = "
CREATE INDEX IF NOT EXISTS idx_tmp_bdt_cons_doc_fecha_cod ON temp_bdt_consulta_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_bdt_emer_doc_fecha_cod ON temp_bdt_emergencia_sigesapol (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_bdt_hosp_doc_fecha_cod ON temp_bdt_hospitalizacion_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_lab_cons_doc_fecha_cod ON temp_laboratorio_consulta_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_lab_emer_doc_fecha_cod ON temp_laboratorio_emergencia_sigesapol (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_lab_hosp_doc_fecha_cod ON temp_laboratorio_hospitalizacion_local (numero_documento_paciente, fecha_atencion, codigo_procedimiento);
CREATE INDEX IF NOT EXISTS idx_tmp_sig_proc_trama ON temp_sigesapol_procedimientos (sp_numero_documento_paciente, sp_fecha_atencion, sp_codigo_procedimiento);
ANALYZE temp_bdt_consulta_local, temp_bdt_emergencia_sigesapol, temp_bdt_hospitalizacion_local, temp_laboratorio_consulta_local, temp_laboratorio_emergencia_sigesapol, temp_laboratorio_hospitalizacion_local, temp_sigesapol_procedimientos;
"
& $psqlPath -U postgres -d db_cpt_junio26 -c $sqlIndices | Out-Null

$perf["paso2_cpt"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 7. Ejecutar Deduplicacion (Script 07) y exportar reportes B.2 y B.3
$t0 = Get-Date
Write-Output "[6/12] Ejecutando 07_FASE2_deduplicacion_CPT_SIGESAPOL.sql..."
$file07 = "07_FASE2_deduplicacion_CPT_SIGESAPOL.sql"
& $psqlPath -U postgres -d db_cpt_junio26 -f $file07 | Out-Null

# Exportar reporte B.2 observaciones
$queryB2 = "SELECT cpt.numero_documento_paciente AS documento, cpt.fecha_atencion::date AS fecha, cpt.codigo_procedimiento, cpt.descripcion_procedimiento, sig.tipo_procedimiento, cpt.fuente_cpt, sig.base AS fuente_sigesapol, cpt.numero_documento_responsable AS medico_cpt, sig.sp_numero_documento_responsable AS medico_sigesapol, cpt.suma_cantidad_registro AS cantidad_cpt, sig.sp_suma_cantidad AS cantidad_sigesapol, cpt.valorizacion AS valorizacion_cpt, sig.sp_valorizacion_calculada AS valorizacion_sigesapol, CASE WHEN sig.tipo_procedimiento = 1 THEN 'MEDICO DISTINTO ENTRE FUENTES - VALIDAR POSIBLE DOBLE REGISTRO' ELSE 'CANTIDAD DISTINTA ENTRE FUENTES - VALIDAR CONSOLIDACION DE CANTIDADES' END AS motivo_observacion FROM temp_cpt_procedimientos_unificado cpt JOIN temp_sigesapol_procedimientos sig ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento WHERE NOT ( (sig.tipo_procedimiento = 1 AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable) OR (sig.tipo_procedimiento IN (2, 3) AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) ) ORDER BY motivo_observacion, documento, fecha"
$csvB2 = "$expPath/observaciones_duplicados.csv"
& $psqlPath -U postgres -d db_cpt_junio26 -c "\copy ($queryB2) TO '$csvB2' WITH CSV HEADER" | Out-Null

# Exportar reporte B.3 resumen doble cobro
$queryB3 = "SELECT sig.base, sig.tipo_procedimiento, COUNT(*) AS duplicados_ciertos, SUM(sig.sp_valorizacion_calculada) AS monto_evitado_doble_cobro FROM temp_cpt_procedimientos_unificado cpt JOIN temp_sigesapol_procedimientos sig ON sig.sp_numero_documento_paciente = cpt.numero_documento_paciente AND sig.sp_fecha_atencion::date = cpt.fecha_atencion::date AND sig.sp_codigo_procedimiento = cpt.codigo_procedimiento AND ( (sig.tipo_procedimiento = 1 AND sig.sp_numero_documento_responsable = cpt.numero_documento_responsable) OR (sig.tipo_procedimiento IN (2, 3) AND sig.sp_suma_cantidad = cpt.suma_cantidad_registro) ) GROUP BY sig.base, sig.tipo_procedimiento ORDER BY sig.base, sig.tipo_procedimiento"
$csvB3 = "$expPath/resumen_doble_cobro.csv"
& $psqlPath -U postgres -d db_cpt_junio26 -c "\copy ($queryB3) TO '$csvB3' WITH CSV HEADER" | Out-Null
$perf["deduplicacion"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 8. Modificar y Ejecutar Consolidacion (Script 08)
$t0 = Get-Date
Write-Output "[7/12] Ejecutando 08_CONSOLIDAR_fuentes_para_armado.sql..."
$file08 = [System.IO.Path]::GetFullPath("08_CONSOLIDAR_fuentes_para_armado.sql")
$content08 = [System.IO.File]::ReadAllText($file08, [System.Text.Encoding]::UTF8)
$content08 = $content08 -replace "SELECT '[^']+'::text AS fuente;", "SELECT '$canonico'::text AS fuente;"
[System.IO.File]::WriteAllText($file08, $content08, (New-Object System.Text.UTF8Encoding $false))

& $psqlPath -U postgres -d db_cpt_junio26 -f $file08 > "$expPath/resumen_consolidacion.txt"
$perf["consolidacion"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# Reclasificar emergencias > 24 horas y unión de estancias
$t0_rec = Get-Date
Write-Output "Ejecutando 12_RECLASIFICAR_emergencias_24h.sql..."
$file12 = "12_RECLASIFICAR_emergencias_24h.sql"
& $psqlPath -U postgres -d db_cpt_junio26 -f $file12 | Out-Null
$perf["reclasificacion_24h"] = [Math]::Round(((Get-Date) - $t0_rec).TotalSeconds, 2)

# 9. Ejecutar Control de Integridad (Script 04) y exportar Control 5
$t0 = Get-Date
Write-Output "[8/12] Ejecutando 04_CONTROL_integridad.sql..."
$file04 = "04_CONTROL_integridad.sql"
& $psqlPath -U postgres -d db_cpt_junio26 -f $file04 > "$expPath/controles_integridad.txt"

# Exportar Control 5 (transiciones)
$queryC5 = "SELECT e.sp_numero_documento_paciente AS documento, e.sp_apellido_paterno_paciente, e.sp_nombres_paciente, e.sp_fecha_atencion::date AS emerg_ingreso, e.sp_fecha_alta_emergencia::date AS emerg_alta, h.sp_fecha_atencion::date AS hosp_ingreso, h.sp_fecha_alta::date AS hosp_alta, CASE WHEN h.sp_fecha_atencion::date = e.sp_fecha_alta_emergencia::date THEN 'TRANSICION MISMO DIA' WHEN h.sp_fecha_atencion::date < e.sp_fecha_alta_emergencia::date THEN 'SOLAPAMIENTO' ELSE 'CONTIGUO' END AS observacion FROM temp_emergencia_sigesapol_estancia e JOIN temp_hospitalizacion_local h ON h.sp_numero_documento_paciente = e.sp_numero_documento_paciente AND h.sp_fecha_atencion::date <= e.sp_fecha_alta_emergencia::date + 1 AND h.sp_fecha_alta::date >= e.sp_fecha_atencion::date ORDER BY documento, emerg_ingreso"
$csvC5 = "$expPath/observaciones_transiciones.csv"
& $psqlPath -U postgres -d db_cpt_junio26 -c "\copy ($queryC5) TO '$csvC5' WITH CSV HEADER" | Out-Null
$perf["control_integridad"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 10. Correr Check de Hermeticidad (Check 9)
$t0 = Get-Date
Write-Output "[9/12] Ejecutando Check de Hermeticidad (Duplicados de Origen)..."
$queryHermeticidad = "
SELECT doc, fecha, cod, cant, id, COUNT(*) AS repeticiones
FROM (
    SELECT 'hospitalizacion'::text AS tabla, sp_numero_documento_paciente AS doc, sp_fecha_atencion::date AS fecha, sp_codigo_procedimiento AS cod, sp_dias_estancia AS cant, id_prestacion_cpt::text AS id
    FROM temp_hospitalizacion_local WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'bdt_consulta', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_cpt::text
    FROM temp_bdt_consulta_local WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'bdt_emergencia', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_cpt::text
    FROM temp_bdt_emergencia_sigesapol WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'bdt_hospitalizacion', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_cpt::text
    FROM temp_bdt_hospitalizacion_local WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'lab_consulta', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_laboratorio::text
    FROM temp_laboratorio_consulta_local WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'lab_emergencia', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_laboratorio::text
    FROM temp_laboratorio_emergencia_sigesapol WHERE digitador = 'SIGESAPOL'
    UNION ALL
    SELECT 'lab_hospitalizacion', numero_documento_paciente, fecha_atencion::date, codigo_procedimiento, suma_cantidad_registro, id_prestacion_laboratorio::text
    FROM temp_laboratorio_hospitalizacion_local WHERE digitador = 'SIGESAPOL'
) t
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1
"
$csvHermeticidad = "$expPath/observaciones_duplicados_origen.csv"
& $psqlPath -U postgres -d db_cpt_junio26 -c "\copy ($queryHermeticidad) TO '$csvHermeticidad' WITH CSV HEADER" | Out-Null
$perf["hermeticidad"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 11. Ejecutar y Exportar Armados de Consulta, Emergencia y Hospitalizacion (9, 10, 11)
$t0 = Get-Date
Write-Output "[10/12] Ejecutando armado de tramas consulta externa..."
& $psqlPath -U postgres -d db_cpt_junio26 -f "09_ARMADO_consulta_externa.sql" -o "$tramaPath/trama_consulta_externa.txt"
$perf["armado_consulta"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

$t0 = Get-Date
Write-Output "[11/12] Ejecutando armado de tramas emergencia..."
& $psqlPath -U postgres -d db_cpt_junio26 -f "10_ARMADO_emergencia.sql" -o "$tramaPath/trama_emergencia.txt"
$perf["armado_emergencia"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

$t0 = Get-Date
Write-Output "[11/12] Ejecutando armado de tramas hospitalizacion..."
& $psqlPath -U postgres -d db_cpt_junio26 -f "11_ARMADO_hospitalizacion.sql" -o "$tramaPath/trama_hospitalizacion.txt"
$perf["armado_hosp"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 12. Ejecutar y Exportar Farmacia (12_SIGESAPOL_farmacia.sql)
$t0 = Get-Date
Write-Output "[12/12] Ejecutando armado de trama farmacia..."
& $psqlPath -U postgres -d sigesapol_junio -f "12_SIGESAPOL_farmacia.sql" -o "$tramaPath/trama_farmacia.txt"
$perf["armado_farmacia"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 13. Recolectar Volumenes y Generar metricas.json
Write-Output "Recolectando metricas..."
$metrics = @{
    "periodo" = "$Year-$MonthPad"
    "fuente_canonica" = $canonico
    "volumenes_tablas" = @{}
    "volumenes_tramas" = @{}
    "deduplicacion" = @{}
    "observaciones" = @{}
    "tiempos_segundos" = $perf
}

# Obtener volumenes de tablas consolidadas (origen CPT vs SIGESAPOL)
$sqlVolTablas = "
SELECT 'bdt_consulta' AS t, digitador = 'SIGESAPOL' AS sig, COUNT(*) FROM temp_bdt_consulta_local GROUP BY 2
UNION ALL SELECT 'bdt_emergencia', digitador = 'SIGESAPOL', COUNT(*) FROM temp_bdt_emergencia_sigesapol GROUP BY 2
UNION ALL SELECT 'bdt_hospitalizacion', digitador = 'SIGESAPOL', COUNT(*) FROM temp_bdt_hospitalizacion_local GROUP BY 2
UNION ALL SELECT 'lab_consulta', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_consulta_local GROUP BY 2
UNION ALL SELECT 'lab_emergencia', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_emergencia_sigesapol GROUP BY 2
UNION ALL SELECT 'lab_hospitalizacion', digitador = 'SIGESAPOL', COUNT(*) FROM temp_laboratorio_hospitalizacion_local GROUP BY 2
UNION ALL SELECT 'estancias_hosp', digitador = 'SIGESAPOL', COUNT(*) FROM temp_hospitalizacion_local GROUP BY 2;
"
$resVolTablas = & $psqlPath -U postgres -d db_cpt_junio26 -A -t -c $sqlVolTablas
foreach ($line in ($resVolTablas -split "`r`n|`n")) {
    if ($line -match "^([^|]+)\|([^|]+)\|(\d+)$") {
        $tablaName = $Matches[1]
        $orig = if ($Matches[2] -eq "t") { "SIGESAPOL" } else { "CPT" }
        $cnt = [int]$Matches[3]
        if (-not $metrics["volumenes_tablas"][$tablaName]) {
            $metrics["volumenes_tablas"][$tablaName] = @{}
        }
        $metrics["volumenes_tablas"][$tablaName][$orig] = $cnt
    }
}

# Obtener volumenes de las tramas exportadas
$metrics["volumenes_tramas"]["trama_consulta_externa"] = (Get-Content "$tramaPath/trama_consulta_externa.txt" | Measure-Object -Line).Lines
$metrics["volumenes_tramas"]["trama_emergencia"] = (Get-Content "$tramaPath/trama_emergencia.txt" | Measure-Object -Line).Lines
$metrics["volumenes_tramas"]["trama_hospitalizacion"] = (Get-Content "$tramaPath/trama_hospitalizacion.txt" | Measure-Object -Line).Lines
$metrics["volumenes_tramas"]["trama_farmacia"] = (Get-Content "$tramaPath/trama_farmacia.txt" | Measure-Object -Line).Lines

# Obtener duplicados evitados y monto del reporte B.3
$sqlB3 = "SELECT SUM(duplicados_ciertos) AS d_tot, SUM(monto_evitado_doble_cobro) AS m_tot FROM ($queryB3) t;"
$resB3 = & $psqlPath -U postgres -d db_cpt_junio26 -A -t -c $sqlB3
if ($resB3 -match "^(\d+)\|([0-9.]+)") {
    $metrics["deduplicacion"]["duplicados_ciertos"] = [int]$Matches[1]
    $metrics["deduplicacion"]["monto_evitado_doble_cobro"] = [double]$Matches[2]
} else {
    $metrics["deduplicacion"]["duplicados_ciertos"] = 0
    $metrics["deduplicacion"]["monto_evitado_doble_cobro"] = 0.0
}

# Obtener conteo de observaciones
$metrics["observaciones"]["medico_distinto"] = (Import-Csv $csvB2 | Where-Object { $_.tipo_procedimiento -eq "1" } | Measure-Object).Count
$metrics["observaciones"]["cantidad_distinta"] = (Import-Csv $csvB2 | Where-Object { $_.tipo_procedimiento -ne "1" } | Measure-Object).Count
$metrics["observaciones"]["transiciones"] = (Import-Csv $csvC5 | Measure-Object).Count
$metrics["observaciones"]["duplicados_origen"] = (Import-Csv $csvHermeticidad | Measure-Object).Count

# Obtener CPMS derivado en estancias
$sqlDerivado = "
SELECT 'emergencia' AS tipo, COUNT(*) FROM temp_emergencia_sigesapol_estancia WHERE es_cpms_derivado = true
UNION ALL
SELECT 'hospitalizacion', COUNT(*) FROM temp_hospitalizacion_sigesapol_estancia WHERE es_cpms_derivado = true;
"
$resDerivado = & $psqlPath -U postgres -d db_cpt_junio26 -A -t -c $sqlDerivado
foreach ($line in ($resDerivado -split "`r`n|`n")) {
    if ($line -match "^([^|]+)\|(\d+)$") {
        $metrics["observaciones"]["cpms_derivado_" + $Matches[1]] = [int]$Matches[2]
    }
}

# Guardar metricas.json
$jsonStr = ConvertTo-Json $metrics -Depth 10
[System.IO.File]::WriteAllText("$expPath/metricas.json", $jsonStr, (New-Object System.Text.UTF8Encoding $false))

Write-Output "=========================================================="
Write-Output "PERIODO FINALIZADO EXITOSAMENTE: $Year-$MonthPad"
Write-Output "Duplicados evitados: $($metrics["deduplicacion"]["duplicados_ciertos"])"
Write-Output "Monto evitado: S/. $($metrics["deduplicacion"]["monto_evitado_doble_cobro"])"
Write-Output "=========================================================="
