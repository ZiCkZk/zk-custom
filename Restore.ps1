#Requires -Version 5.1
<#
.SYNOPSIS
    Deshace una ejecucion de Install.ps1: registro, archivos creados, mods de Windhawk, cursores y fondo.
.EXAMPLE
    .\Restore.ps1                       # usa la copia mas reciente
    .\Restore.ps1 -BackupDir .\backups\20261111-214700
#>
param([string]$BackupDir)

$Root = $PSScriptRoot
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    if ($BackupDir) { $a += '-BackupDir', "`"$BackupDir`"" }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $a
    exit
}

if (-not $BackupDir) {
    $latest = Get-ChildItem (Join-Path $Root 'backups') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
    if (-not $latest) { Write-Host 'No hay copias de seguridad en .\backups' -ForegroundColor Red; exit 1 }
    $BackupDir = $latest.FullName
}
Import-Module (Join-Path $Root 'modules\Core.psm1') -Force -DisableNameChecking -Global
Import-Module (Join-Path $Root 'modules\Windhawk.psm1') -Force -DisableNameChecking -Global
Initialize-ZKCustom -Root $Root -BackupDir $BackupDir
Write-Host "Restaurando desde $BackupDir" -ForegroundColor Magenta

# 1. Mods de Windhawk (antes que el registro, por si Windhawk guarda algo en el)
if ((Test-Path (Join-Path $BackupDir 'windhawk-before.zip')) -or (Test-Path (Join-Path $BackupDir 'windhawk-added-mods.txt'))) {
    Restore-Windhawk -BackupDir $BackupDir
}

# 2. Claves que no existian antes: se borran (solo dentro de HKCU, por seguridad)
$missing = Join-Path $BackupDir 'missing-keys.txt'
if (Test-Path $missing) {
    $allowedHklm = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'   # pantalla de bloqueo
    Get-Content $missing -Encoding UTF8 | Where-Object { $_ -like 'HKCU:\*' -or $_ -eq $allowedHklm } | ForEach-Object {
        if (Test-Path $_) { Remove-Item $_ -Recurse -Force; Write-Host "[OK] Borrada $_" -ForegroundColor Green }
    }
}

# 3. Claves modificadas: se reimporta la copia
Get-ChildItem $BackupDir -Filter '*.reg' | ForEach-Object {
    & reg.exe import $_.FullName 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "[OK] $($_.Name)" -ForegroundColor Green }
    else { Write-Host "[!!] No se pudo importar $($_.Name)" -ForegroundColor Yellow }
}

# 4. Archivos creados por ZK-Custom (fragmento de Terminal, fuentes de usuario)
$created = Join-Path $BackupDir 'created-files.txt'
if (Test-Path $created) {
    Get-Content $created -Encoding UTF8 | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object {
        try { Remove-Item $_ -Force -ErrorAction Stop; Write-Host "[OK] Borrado $_" -ForegroundColor Green }
        catch { Write-Host "[!!] $_ esta en uso; se borrara al reiniciar o puedes borrarlo a mano" -ForegroundColor Yellow }
    }
}

# 4b. Carpetas de colores: se deja el desktop.ini como estaba
$fb = Join-Path $BackupDir 'folders-before.json'
if (Test-Path $fb) {
    foreach ($e in @(Get-Content $fb -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        $ini = Join-Path $e.path 'desktop.ini'
        if (-not (Test-Path -LiteralPath $ini)) { continue }
        attrib -s -h -r "$ini" | Out-Null
        if (-not $e.hadIni) { Remove-Item -LiteralPath $ini -Force; Write-Host "[OK] Carpeta $($e.path) como antes" -ForegroundColor Green; continue }
        $lines = [IO.File]::ReadAllLines($ini, [Text.Encoding]::Default) | Where-Object { $_ -notmatch '^\s*IconResource\s*=' }
        $out = New-Object System.Collections.Generic.List[string]
        foreach ($l in $lines) { $out.Add($l); if ($e.iconLine -and $l -match '^\s*\[\.ShellClassInfo\]') { $out.Add($e.iconLine) } }
        [IO.File]::WriteAllLines($ini, $out.ToArray(), [Text.Encoding]::Unicode)
        attrib +s +h "$ini" | Out-Null
        Write-Host "[OK] Carpeta $($e.path) como antes" -ForegroundColor Green
    }
    Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden -ErrorAction SilentlyContinue
}

# 4c. Fondo animado: se cierra si lo puso esta aplicacion
if (Test-Path (Join-Path $BackupDir 'animated-set.txt')) {
    $cu = @("$env:LOCALAPPDATA\Programs\Lively Wallpaper\Livelycu.exe", "$env:ProgramFiles\Lively Wallpaper\Livelycu.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($cu) { & $cu closewp --monitor -1 2>$null | Out-Null; Write-Host '[OK] Fondo animado quitado' -ForegroundColor Green }
}

# 4d. Dia y noche: se quita la tarea programada que creo esta aplicacion
$dn = Join-Path $BackupDir 'daynight-task.txt'
if (Test-Path $dn) {
    foreach ($tn in (Get-Content $dn -Encoding UTF8 | Where-Object { $_ } | Select-Object -Unique)) {
        if (Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $tn -Confirm:$false; Write-Host "[OK] Tarea '$tn' quitada" -ForegroundColor Green }
    }
}

# 5. Avisar a Windows para que recargue cursores, fondo y fuentes
Update-SystemParameter -Action 0x57
$wall = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).Wallpaper
Update-SystemParameter -Action 0x14 -Value $wall
Send-SettingChange -Message 0x001D

Restart-Explorer
Restart-ShellHosts
Write-Host 'Restauracion completada. Algunos cambios (fuentes, Terminal) se ven al reabrir las aplicaciones.' -ForegroundColor Magenta
