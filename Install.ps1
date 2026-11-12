#Requires -Version 5.1
<#
.SYNOPSIS
    ZK-Custom - aplica la personalizacion descrita en config.json de forma modular y reversible.
.EXAMPLE
    .\Install.ps1                     # aplica todos los modulos activos en config.json
    .\Install.ps1 -DryRun             # muestra lo que haria, sin tocar nada
    .\Install.ps1 -Only Theme,Fonts   # solo esos modulos
#>
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string[]]$Only,
    [string]$BackupDir,
    [switch]$SkipRestorePoint,
    [switch]$NoExplorerRestart,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
if (-not $ConfigPath) { $ConfigPath = Join-Path $Root 'config.json' }
if ($Only) { $Only = $Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

# --- Auto-elevacion (no hace falta en simulacion) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [System.Management.Automation.SwitchParameter]) { if ($kv.Value.IsPresent) { $argList += "-$($kv.Key)" } }
        elseif ($kv.Value -is [array]) { $argList += "-$($kv.Key)", ($kv.Value -join ',') }
        else { $argList += "-$($kv.Key)", "`"$($kv.Value)`"" }
    }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

# --- Preparacion ---
if (-not $BackupDir) { $BackupDir = Join-Path $Root ("backups\" + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
Start-Transcript -Path (Join-Path $BackupDir 'install.log') | Out-Null

try {
    Import-Module (Join-Path $Root 'modules\Core.psm1') -Force -DisableNameChecking -Global
    Import-Module (Join-Path $Root 'modules\Windhawk.psm1') -Force -DisableNameChecking -Global
    $Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Initialize-ZKCustom -Root $Root -BackupDir $BackupDir -DryRun:$DryRun

    Write-Section "ZK-Custom :: $($Config.meta.name) v$($Config.meta.version)"
    $build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
    if ($build -lt [int]$Config.meta.minBuild) { throw "Se necesita Windows 11 build $($Config.meta.minBuild) o superior (este equipo: $build)." }
    Write-Step "Windows build $build | copia de seguridad en $BackupDir" -Level Ok

    if (-not $SkipRestorePoint) { New-SafeRestorePoint -Description "ZK-Custom $($Config.meta.name)" }

    $modules = Get-ChildItem (Join-Path $Root 'modules') -Filter '*.ps1' |
               Where-Object { $_.Name -match '^\d\d-' } | Sort-Object Name
    $failed = 0
    foreach ($m in $modules) {
        $name = $m.BaseName -replace '^\d\d-', ''
        if ($Only) { if ($name -notin $Only) { continue } }
        elseif (-not $Config.modules.$name) { Write-Step "$name desactivado en config.json" -Level Skip; continue }

        Write-Section $name
        try { & $m.FullName -Config $Config -Root $Root }
        catch { $failed++; Write-Step "Fallo en el modulo $($name): $($_.Exception.Message)" -Level Error }
    }

    if (-not $NoExplorerRestart) { Restart-Explorer }
    Write-Section 'Listo'
    if ($failed) { Write-Step "$failed modulo(s) con errores; revisa el log." -Level Warn }
    Write-Step "Para deshacer: .\Restore.ps1 -BackupDir `"$BackupDir`"" -Level Ok
}
finally {
    Stop-Transcript | Out-Null
}
