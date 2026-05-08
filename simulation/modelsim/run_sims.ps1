# PowerShell script para ejecutar ambas simulaciones

Set-Location $PSScriptRoot

Write-Host "=== Ejecutando simulación MSI ===" -ForegroundColor Green
Write-Host "$(Get-Date): Iniciando MSI..."

$sw = [System.Diagnostics.Stopwatch]::StartNew()
& vsim -do "Top_run_msim_rtl_verilog.do" 2>&1 | Out-File -FilePath msi_run_output.txt
$sw.Stop()

Write-Host "MSI completed in $($sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
Start-Sleep -Seconds 3

# Mostrar resultados MSI
$transcriptFile = if (Test-Path transcript) { "transcript" } else { "msim_transcript" }
$results = Get-Content $transcriptFile -Tail 40 | Select-String -Pattern "CORE|Requests|Invalidaciones|Ciclos|Total"
if ($results) {
    Write-Host "`n=== RESULTADOS MSI ===" -ForegroundColor Cyan
    $results | ForEach-Object { Write-Host $_.Line }
} else {
    Write-Host "No se encontraron resultados MSI" -ForegroundColor Yellow
    Write-Host "Últimas líneas del transcript:" 
    Get-Content $transcriptFile -Tail 20
}

# Limpiar y ejecutar FF
Write-Host "`n=== Ejecutando simulación FF ===" -ForegroundColor Green
Remove-Item -Recurse -Force rtl_work -ErrorAction SilentlyContinue
Remove-Item transcript -Force -ErrorAction SilentlyContinue
Remove-Item msim_transcript -Force -ErrorAction SilentlyContinue

Write-Host "$(Get-Date): Iniciando FF..."
$sw = [System.Diagnostics.Stopwatch]::StartNew()
& vsim -do "Top_ff_run_msim_rtl_verilog.do" 2>&1 | Out-File -FilePath ff_run_output.txt
$sw.Stop()

Write-Host "FF completed in $($sw.Elapsed.TotalSeconds)s" -ForegroundColor Green
Start-Sleep -Seconds 2

# Mostrar resultados FF
$transcriptFile = if (Test-Path transcript) { "transcript" } else { "msim_transcript" }
$results = Get-Content $transcriptFile -Tail 40 | Select-String -Pattern "CORE|Requests|Updates|Ciclos|Total"
if ($results) {
    Write-Host "`n=== RESULTADOS FF ===" -ForegroundColor Cyan
    $results | ForEach-Object { Write-Host $_.Line }
} else {
    Write-Host "No se encontraron resultados FF" -ForegroundColor Yellow
    Write-Host "Últimas líneas del transcript:" 
    Get-Content $transcriptFile -Tail 20
}

Write-Host "`nSimulaciones completadas." -ForegroundColor Green
