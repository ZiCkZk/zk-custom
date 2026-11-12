@echo off
rem Abre el asistente grafico de ZK-Custom (pide permisos de administrador)
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Wizard.ps1"
