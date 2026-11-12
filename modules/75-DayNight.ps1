# 75-DayNight.ps1 - cambia paleta y modo claro/oscuro segun la hora (tarea programada de tu usuario).
# config.json -> daynight: { "enabled": true, "day": "catppuccin-latte", "night": "tokyo-night", "dayHour": 7, "nightHour": 19 }
param($Config, $Root)

$d = $Config.daynight
$ctx = Get-ZKContext
$task = 'ZK-Custom Dia y noche'
if (-not $d) { Write-Step 'Dia y noche no configurado' -Level Skip; return }

if (-not $d.enabled) {
    if ($ctx.DryRun) { Write-Step "Quitar la tarea '$task'" -Level Skip; return }
    if (Get-ScheduledTask -TaskName $task -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $task -Confirm:$false; Write-Step 'Dia y noche desactivado' -Level Ok }
    else { Write-Step 'Dia y noche desactivado' -Level Skip }
    return
}

$pal = @(Get-Content (Join-Path $Root 'catalog\static\palettes.json') -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ }
function Get-Pal($id) {
    if ($id -eq 'current') { return @{ palette = $Config.palette; light = -not $Config.theme.darkMode } }
    $p = $pal | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $p) { throw "Paleta desconocida: $id" }
    @{ palette = $p.apply.palette; light = ($p.apply.mode -eq 'light') }
}
$day = Get-Pal $d.day; $night = Get-Pal $d.night
$dayHour = if ($d.dayHour) { [int]$d.dayHour } else { 7 }
$nightHour = if ($d.nightHour) { [int]$d.nightHour } else { 19 }

$state = [ordered]@{ root = $Root; dayHour = $dayHour; nightHour = $nightHour; theme = $Config.theme; day = $day; night = $night }
$dir = Join-Path $env:APPDATA 'ZK-Custom'
if ($ctx.DryRun) { Write-Step "Tarea '$task': dia $dayHour`:00 ($($d.day)), noche $nightHour`:00 ($($d.night))" -Level Skip; return }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
[IO.File]::WriteAllText((Join-Path $dir 'daynight.json'), (ConvertTo-Json $state -Depth 6), (New-Object Text.UTF8Encoding($false)))

$script = Join-Path $Root 'tools\Switch-DayNight.ps1'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""
$triggers = @(
    (New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($dayHour))),
    (New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours($nightHour))),
    (New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME")
)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
Register-ScheduledTask -TaskName $task -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description 'ZK-Custom: paleta de dia y de noche' -Force | Out-Null
Add-Content -Path (Join-Path $ctx.BackupDir 'daynight-task.txt') -Value $task -Encoding UTF8
Write-Step "Dia y noche: $($d.day) desde las $dayHour`:00, $($d.night) desde las $nightHour`:00" -Level Ok
Start-ScheduledTask -TaskName $task   # aplica ya el que toca a esta hora
