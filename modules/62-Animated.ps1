# 62-Animated.ps1 - fondos animados con Lively Wallpaper (libre, GPL-3.0).
# Los fondos "aurora", "constelacion"... son paginas HTML propias que toman los colores de tu paleta.
# config.json -> animated: { "style": "aurora" | "none" | "video", "file": "assets/animated/mi-video.mp4" }
param($Config, $Root)

$a = $Config.animated
if (-not $a -or -not $a.style) { Write-Step 'No hay fondo animado elegido' -Level Skip; return }
$ctx = Get-ZKContext

function Get-LivelyCu {
    @("$env:LOCALAPPDATA\Programs\Lively Wallpaper\Livelycu.exe", "$env:ProgramFiles\Lively Wallpaper\Livelycu.exe", "${env:ProgramFiles(x86)}\Lively Wallpaper\Livelycu.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
}

$cu = Get-LivelyCu
if ($a.style -eq 'none') {
    if ($cu -and -not $ctx.DryRun) { & $cu closewp --monitor -1 2>$null | Out-Null; Write-Step 'Fondo animado quitado' -Level Ok }
    else { Write-Step 'Sin fondo animado' -Level Skip }
    return
}

if (-not $cu) {
    Install-App -Id 'rocksdanister.LivelyWallpaper' -Name 'Lively Wallpaper'
    $cu = Get-LivelyCu
}
if ($ctx.DryRun) { Write-Step "Fondo animado '$($a.style)' con Lively" -Level Skip; return }
if (-not $cu) { throw 'Lively Wallpaper no se ha podido instalar (no aparece Livelycu.exe).' }

# Lively debe estar abierto; se abre sin permisos de administrador (a traves del Explorador)
$exe = Join-Path (Split-Path $cu) 'Lively.exe'
if (-not (Get-Process Lively -ErrorAction SilentlyContinue) -and (Test-Path $exe)) {
    Start-Process explorer.exe -ArgumentList "`"$exe`""
    for ($i = 0; $i -lt 30 -and -not (Get-Process Lively -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
    Start-Sleep -Seconds 3
}

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
Write-Step "Fondo animado: $($a.style) (Lively Wallpaper)" -Level Ok
