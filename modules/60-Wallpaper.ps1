# 60-Wallpaper.ps1 - fondo de escritorio (imagen propia o de la galeria) y, opcional, pantalla de bloqueo
param($Config, $Root)

$w = $Config.wallpaper
if (-not $w -or (-not $w.file -and -not $w.url)) { Write-Step 'No hay fondo configurado' -Level Skip; return }
$ctx = Get-ZKContext

if ($w.file) {
    $src = if ([IO.Path]::IsPathRooted($w.file)) { $w.file } else { Join-Path $Root $w.file }
    if (-not (Test-Path $src)) { Write-Step "No existe $($w.file); guarda la imagen ahi o elige otra en el asistente" -Level Warn; return }
} else {
    $ext  = [IO.Path]::GetExtension(([uri]$w.url).LocalPath); if (-not $ext) { $ext = '.jpg' }
    $name = 'wallpaper-' + ([BitConverter]::ToString([Security.Cryptography.SHA1]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($w.url))) -replace '-', '').Substring(0, 12) + $ext
    $src  = Save-Download -Url $w.url -FileName $name -Size ([long]$w.size)
    if ($ctx.DryRun) { Write-Step "Descargar fondo '$($w.name)'" -Level Skip }
}

# Copia fuera de la carpeta del proyecto para que el fondo no dependa de ella
$dir = Join-Path $env:APPDATA 'ZK-Custom'
$dst = Join-Path $dir ('wallpaper' + [IO.Path]::GetExtension($src))
$styles = @{ Fill = @('10','0'); Fit = @('6','0'); Stretch = @('2','0'); Center = @('0','0'); Span = @('22','0'); Tile = @('0','1') }
$style  = if ($w.style -and $styles.ContainsKey($w.style)) { $w.style } else { 'Fill' }

$desk = 'HKCU:\Control Panel\Desktop'
Set-RegValue $desk 'WallpaperStyle' $styles[$style][0] -Type String
Set-RegValue $desk 'TileWallpaper'  $styles[$style][1] -Type String
Set-RegValue $desk 'Wallpaper'      $dst -Type String

if ($w.lockScreen) {
    # Pantalla de bloqueo con la misma imagen (clave del proveedor de personalizacion; se deshace con Restore)
    $lockFile = Join-Path $env:ProgramData ('ZK-Custom\lockscreen' + [IO.Path]::GetExtension($src))
    $csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    Set-RegValue $csp 'LockScreenImagePath'   $lockFile -Type String
    Set-RegValue $csp 'LockScreenImageUrl'    $lockFile -Type String
    Set-RegValue $csp 'LockScreenImageStatus' 1
    if (-not $ctx.DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path $lockFile) | Out-Null
        Copy-Item $src $lockFile -Force
    }
    Write-Step 'Mismo fondo en la pantalla de bloqueo' -Level Ok
}

if ($ctx.DryRun) { return }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
Copy-Item $src $dst -Force
Update-SystemParameter -Action 0x14 -Value $dst   # SPI_SETDESKWALLPAPER
Write-Step "Fondo aplicado$(if ($w.name) { ": $($w.name)" }) ($style)" -Level Ok
