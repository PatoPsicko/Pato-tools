@echo off
echo Iniciando servidor local...
echo Por favor, manten esta ventana abierta mientras usas la aplicacion.
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0start_server.ps1"

pause
