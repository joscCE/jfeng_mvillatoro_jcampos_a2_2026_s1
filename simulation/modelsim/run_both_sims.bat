@echo off
REM Script para ejecutar ambas simulaciones y guardar resultados

echo ===================================
echo Ejecutando MSI simulation...
echo ===================================
vsim -do "Top_run_msim_rtl_verilog.do" > msi_results.log 2>&1

echo.
echo ===================================
echo MSI simulation complete. Waiting...
echo ===================================
timeout /t 2

echo.
echo ===================================
echo Ejecutando FF simulation...
echo ===================================
vsim -do "Top_ff_run_msim_rtl_verilog.do" > ff_results.log 2>&1

echo.
echo ===================================
echo FF simulation complete
echo ===================================
echo.
echo MSI RESULTS:
type msi_results.log | findstr /C:"REPORTE" /C:"CORE" /C:"Requests" /C:"Invalidaciones" /C:"Updates" /C:"Total"
echo.
echo FF RESULTS:
type ff_results.log | findstr /C:"REPORTE" /C:"CORE" /C:"Requests" /C:"Updates" /C:"Ciclos" /C:"Total"
