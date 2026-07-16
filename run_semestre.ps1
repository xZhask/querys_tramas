param(
    [string]$Year = "2025"
)
foreach ($month in 7..12) {
    Write-Output "=========================================="
    Write-Output "EJECUTANDO PERIODO: $Year-$month"
    Write-Output "=========================================="
    powershell -ExecutionPolicy Bypass -File .\run_month.ps1 -Year $Year -Month $month
}
