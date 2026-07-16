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

if (-not $env:PGPASSWORD) {
    $env:PGPASSWORD = "root"
}
$psqlPath = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
if (-not (Test-Path $psqlPath)) {
    $psqlPath = "C:\Program Files\PostgreSQL\16\bin\psql.exe"
}
$pgdumpPath = "C:\Program Files\PostgreSQL\18\bin\pg_dump.exe"
if (-not (Test-Path $pgdumpPath)) {
    $pgdumpPath = "C:\Program Files\PostgreSQL\16\bin\pg_dump.exe"
}
$dbname_cpt = if ($env:PGDATABASE) { $env:PGDATABASE } else { "db_cpt_junio26" }

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
& $psqlPath -U postgres -d $dbname_cpt -c "DROP TABLE IF EXISTS temp_emergencia_sigesapol_estancia, temp_hospitalizacion_sigesapol_estancia, temp_sigesapol_procedimientos;" | Out-Null
& cmd.exe /c "set PGPASSWORD=$($env:PGPASSWORD)&& `"$pgdumpPath`" -U postgres -d sigesapol_junio -t temp_emergencia_sigesapol_estancia -t temp_hospitalizacion_sigesapol_estancia -t temp_sigesapol_procedimientos | `"$psqlPath`" -U postgres -d $dbname_cpt" | Out-Null
$perf["traslado_pgdump"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 6. Modificar y Ejecutar Script 03 (CPT Maestro)
$t0 = Get-Date
Write-Output "[5/12] Ejecutando 03_MAESTRO_paso2_CPT.sql..."
$file03 = [System.IO.Path]::GetFullPath("03_MAESTRO_paso2_CPT.sql")
$content03 = [System.IO.File]::ReadAllText($file03, [System.Text.Encoding]::UTF8)
$content03 = $content03 -replace "SELECT DATE '[0-9-]{10}' AS p_ini,[\s\S]*?DATE '[0-9-]{10}' AS p_fin", "SELECT DATE '$p_ini' AS p_ini,   -- <== inicio del periodo (igual al paso 1)`r`n       DATE '$p_fin' AS p_fin"
[System.IO.File]::WriteAllText($file03, $content03, (New-Object System.Text.UTF8Encoding $false))

& $psqlPath -U postgres -d $dbname_cpt -f $file03 | Out-Null

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
& $psqlPath -U postgres -d $dbname_cpt -c $sqlIndices | Out-Null

$perf["paso2_cpt"] = [Math]::Round(((Get-Date) - $t0).TotalSeconds, 2)

# 7. Ejecutar Deduplicacion (Script 07) y exportar reportes B.2 y B.3
$t0 = Get-Date
Write-Output "[6/12] Ejecutando 07_FASE2_deduplicacion_CPT_SIGESAPOL.sql..."
$file07 = "07_FASE2_deduplicacion_CPT_SIGESAPOL.sql"
& $psqlPath -U postgres -d $dbname_cpt -f $file07 | Out-Null

# 8. Ejecutar Consolidacion (Script 08) -- cfg_canonico ya se auto-deriva de
#    cfg_fuente_canonica dentro del propio script, no se edita mas a mano.
$t0 = Get-Date
Write-Output "[7/9] Ejecutando 08_CONSOLIDAR_fuentes_para_armado.sql (canonico: $canonico)..."
$file08 = [System.IO.Path]::GetFullPath("08_CONSOLIDAR_fuentes_para_armado.sql")

& $psqlPath -U postgres -d $dbname_cpt -f $file08 | Out-Null

# 9. Reclasificar emergencias > 24 horas y unión de estancias
Write-Output "[8/9] Ejecutando 12_RECLASIFICAR_emergencias_24h.sql..."
$file12 = "12_RECLASIFICAR_emergencias_24h.sql"
& $psqlPath -U postgres -d $dbname_cpt -f $file12 | Out-Null

# 10. Ejecutar Control de Integridad (Script 04)
Write-Output "[9/9] Ejecutando 04_CONTROL_integridad.sql..."
$file04 = "04_CONTROL_integridad.sql"
$infosPath = "$expPath\03_INFORMATIVOS"
New-Item -ItemType Directory -Force -Path $infosPath | Out-Null
& $psqlPath -U postgres -d $dbname_cpt -f $file04 > "$infosPath\controles_integridad_raw.txt"

# 11. Generar Salidas Rediseñadas v2 (TRAMAS + EXCEL DE AUDITORIA)
Write-Output "Generando salidas Rediseñadas v2 (01_TRAMAS + 02_AUDITORIA + 03_INFORMATIVOS)..."
& python "$PSScriptRoot\generate_outputs_v2.py" --year $Year --month $Month
if ($LASTEXITCODE -ne 0) {
    throw "generate_outputs_v2.py fallo (aserciones A1/A2) para $Year-$MonthPad. Revisar salida arriba. DETENIDO."
}

# 12. Verificar aserciones A1/A2/A3 del contrato de salidas v2
Write-Output "Verificando aserciones A1/A2/A3 para $Year-$MonthPad..."
& python "$PSScriptRoot\14_VERIFICAR_ASERTOS.py" --year $Year --month $Month
if ($LASTEXITCODE -ne 0) {
    throw "Aserciones A1/A2/A3 fallidas para $Year-$MonthPad. Revisar salida arriba. DETENIDO."
}

Write-Output "=========================================================="
Write-Output "PERIODO MENSUAL PROCESADO EXITOSAMENTE: $Year-$MonthPad"
Write-Output "=========================================================="
