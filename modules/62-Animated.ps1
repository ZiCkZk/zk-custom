# 62-Animated.ps1 - fondos animados y salvapantallas con Lively Wallpaper (libre, GPL-3.0), en segundo plano.
# Los fondos "aurora", "constelacion"... son paginas HTML propias que toman los colores de tu paleta.
# config.json -> animated: { "style": "aurora" | "none" | "video", "file": "assets/animated/mi-video.mp4",
#                            "hideLively": true, "screensaver": true, "saverMinutes": 10 }
param($Config, $Root)

$a = $Config.animated
if (-not $a -or -not $a.style) { Write-Step 'No hay fondo animado elegido' -Level Skip; return }
$ctx = Get-ZKContext
$desk = 'HKCU:\Control Panel\Desktop'

function Get-LivelyCu {
    @("$env:LOCALAPPDATA\Programs\Lively Wallpaper\Livelycu.exe", "$env:ProgramFiles\Lively Wallpaper\Livelycu.exe", "${env:ProgramFiles(x86)}\Lively Wallpaper\Livelycu.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Set-LivelyScreensaver([bool]$On) {
    # Salvapantallas de Lively: archivo .scr oficial en C:\Windows + ajustes de salvapantallas de Windows
    $scr = Join-Path $env:WINDIR 'Lively.scr'
    $cur = (Get-ItemProperty $desk -ErrorAction SilentlyContinue).'SCRNSAVE.EXE'
    if (-not $On) {
        if ($cur -and $cur -like '*Lively*') { Remove-RegValue -Path $desk -Name 'SCRNSAVE.EXE'; Set-RegValue $desk 'ScreenSaveActive' '0' -Type String; Write-Step 'Salvapantallas de Lively desactivado' -Level Ok }
        return
    }
    if ($ctx.DryRun) { Write-Step "Salvapantallas animado tras $($a.saverMinutes) min" -Level Skip; return }
    if (-not (Test-Path $scr)) {
        $zip = Save-Download -Url 'https://github.com/rocksdanister/lively/releases/latest/download/lively_utility_screensaver.zip' -FileName 'lively_utility_screensaver.zip'
        $tmp = Join-Path $ctx.CacheDir 'lively-scr'; if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive $zip $tmp -Force
        $file = Get-ChildItem $tmp -Recurse -Filter *.scr | Select-Object -First 1
        if (-not $file) { throw 'El paquete del salvapantallas de Lively no trae ningun .scr' }
        Copy-Item $file.FullName $scr -Force; Register-CreatedFile $scr
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    $min = if ($a.saverMinutes) { [int]$a.saverMinutes } else { 10 }
    Set-RegValue $desk 'SCRNSAVE.EXE' $scr -Type String
    Set-RegValue $desk 'ScreenSaveActive' '1' -Type String
    Set-RegValue $desk 'ScreenSaveTimeOut' ([string]($min * 60)) -Type String
    Update-SystemParameter -Action 0x0011   # SPI_SETSCREENSAVEACTIVE: Windows relee el ajuste
    Write-Step "Salvapantallas animado tras $min min de inactividad" -Level Ok
}

$cu = Get-LivelyCu
if ($a.style -eq 'none') {
    if ($cu -and -not $ctx.DryRun) { & $cu closewp --monitor -1 2>$null | Out-Null; Write-Step 'Fondo animado quitado' -Level Ok }
    else { Write-Step 'Sin fondo animado' -Level Skip }
    Set-LivelyScreensaver $false
    return
}

if (-not $cu) {
    Install-App -Id 'rocksdanister.LivelyWallpaper' -Name 'Lively Wallpaper'
    $cu = Get-LivelyCu
}
if ($ctx.DryRun) { Write-Step "Fondo animado '$($a.style)' con Lively (en segundo plano)" -Level Skip; Set-LivelyScreensaver ([bool]$a.screensaver); return }
if (-not $cu) { throw 'Lively Wallpaper no se ha podido instalar (no aparece Livelycu.exe).' }

# Lively se abre sin permisos de administrador (a traves del Explorador) y arranca con Windows
$exe = Join-Path (Split-Path $cu) 'Lively.exe'
if (-not (Get-Process Lively -ErrorAction SilentlyContinue) -and (Test-Path $exe)) {
    Start-Process explorer.exe -ArgumentList "`"$exe`""
    for ($i = 0; $i -lt 30 -and -not (Get-Process Lively -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 3
}
if (Test-Path $exe) { Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'ZK-Custom Lively' "`"$exe`"" -Type String }

$dir = Join-Path $env:LOCALAPPDATA 'ZK-Custom\animated'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
if ($a.style -eq 'video') {
    if (-not $a.file) { Write-Step 'Elige un video o GIF en el asistente (Fondo animado > Ajustes)' -Level Warn; return }
    $src = Join-Path $Root $a.file
    if (-not (Test-Path $src)) { Write-Step "No existe $($a.file)" -Level Warn; return }
    $target = Join-Path $dir ([IO.Path]::GetFileName($src))
    Copy-Item $src $target -Force
} else {
    # Pagina HTML con los colores de la paleta
    $p = $Config.palette
    $html = Get-Content (Join-Path $Root 'catalog\animated\template.html') -Raw -Encoding UTF8
    foreach ($kv in @(@('%BASE%', $p.base), @('%SURFACE%', $p.surface), @('%PRIMARY%', $p.primary), @('%SECONDARY%', $p.secondary), @('%HIGHLIGHT%', $p.highlight), @('%TEXT%', $p.text), @('%STYLE%', $a.style))) {
        $html = $html.Replace($kv[0], [string]$kv[1])
    }
    $wdir = Join-Path $dir ("$($a.style)-" + ($p.primary.TrimStart('#')))
    New-Item -ItemType Directory -Force -Path $wdir | Out-Null
    [IO.File]::WriteAllText((Join-Path $wdir 'index.html'), $html, (New-Object Text.UTF8Encoding($false)))
    $info = [ordered]@{ AppVersion = '1.0.0.0'; Title = "ZK-Custom $($a.style)"; Desc = 'Fondo animado de ZK-Custom'; Author = 'ZK-Custom'; License = ''; Contact = ''; Type = 1; FileName = 'index.html'; Arguments = $null; IsAbsolutePath = $false }
    [IO.File]::WriteAllText((Join-Path $wdir 'LivelyInfo.json'), (ConvertTo-Json $info), (New-Object Text.UTF8Encoding($false)))
    $target = Join-Path $wdir 'index.html'
}
& $cu setwp --file "$target" 2>&1 | Out-Null
Set-Content -Path (Join-Path $ctx.BackupDir 'animated-set.txt') -Value $target -Encoding UTF8
# En segundo plano: se oculta la ventana de Lively (sigue en la bandeja como servicio del fondo)
if ($a.hideLively -ne $false) { Start-Sleep -Seconds 2; & $cu app --showApp false 2>&1 | Out-Null }
Write-Step "Fondo animado: $($a.style) (Lively en segundo plano)" -Level Ok
Set-LivelyScreensaver ([bool]$a.screensaver)
