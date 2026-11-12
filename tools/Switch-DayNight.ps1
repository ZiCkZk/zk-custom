#Requires -Version 5.1
<#
.SYNOPSIS
    Lo ejecuta la tarea programada "ZK-Custom Dia y noche": aplica la paleta de dia o de noche segun la hora.
    Solo toca colores y modo claro/oscuro de tu usuario (no necesita permisos de administrador).
#>
$ErrorActionPreference = 'Stop'
$file = Join-Path $env:APPDATA 'ZK-Custom\daynight.json'
if (-not (Test-Path $file)) { exit 0 }
$s = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
$h = (Get-Date).Hour
$isDay = if ($s.dayHour -lt $s.nightHour) { $h -ge $s.dayHour -and $h -lt $s.nightHour } else { $h -ge $s.dayHour -or $h -lt $s.nightHour }
$pick = if ($isDay) { $s.day } else { $s.night }

Import-Module (Join-Path $s.root 'modules\Core.psm1') -Force -DisableNameChecking
$bd = Join-Path $env:TEMP 'zk-custom-daynight'
New-Item -ItemType Directory -Force -Path $bd | Out-Null
Initialize-ZKCustom -Root $s.root -BackupDir $bd

$theme = [pscustomobject]@{
    darkMode = -not $pick.light; transparency = $s.theme.transparency
    accentOnTitleBars = $s.theme.accentOnTitleBars; accentOnStartAndTaskbar = $s.theme.accentOnStartAndTaskbar
}
$cfg = [pscustomobject]@{ palette = $pick.palette; theme = $theme }
& (Join-Path $s.root 'modules\10-Theme.ps1') -Config $cfg -Root $s.root
Send-SettingChange -Message 0x001A -Area 'ImmersiveColorSet'
