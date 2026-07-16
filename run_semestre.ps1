param(
    [string]$Year = "2025",
    [int]$StartMonth = 7,
    [int]$EndMonth = 12
)
foreach ($month in $StartMonth..$EndMonth) {
    Write-Output "=========================================="
    Write-Output "EJECUTANDO PERIODO: $Year-$month"
    Write-Output "=========================================="
    powershell -ExecutionPolicy Bypass -File .\run_month.ps1 -Year $Year -Month $month
    if ($LASTEXITCODE -ne 0) {
        Write-Output "=========================================="
        Write-Output "DETENIDO: el periodo $Year-$month fallo (ver salida arriba). No se continua con los meses siguientes."
        Write-Output "=========================================="
        exit 1
    }
}
