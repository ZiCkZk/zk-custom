@echo off
rem Doble clic para instalar ZK-Custom. Pasa cualquier argumento a Install.ps1 (ej: Install.cmd -DryRun)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
