#Requires -Version 5.1
<#
.SYNOPSIS
    Vistas previas EXACTAS de cursores:
    - Packs (static\cursors.json): descarga cada pack y dibuja sus punteros reales (.cur/.ani) sobre fondo oscuro y claro.
    - Dibujados por el mod Mouse Cursor Themes (generated\cursorsmod.json): se recrean con sus colores, contorno y brillo.
    Guarda catalog\previews\cursors\<id>.png y actualiza los catalogos.
#>
param([switch]$Force)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot '..\modules\IconTools.ps1')
Import-Module (Join-Path $PSScriptRoot '..\modules\Core.psm1') -Force -DisableNameChecking
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$out = Join-Path $PSScriptRoot 'previews\cursors'; New-Item -ItemType Directory -Force -Path $out | Out-Null
$dl = Join-Path $root 'cache\downloads'; $work = Join-Path $root 'cache\cursorprev'
New-Item -ItemType Directory -Force -Path $dl, $work | Out-Null
$wc = New-Object Net.WebClient; $wc.Headers['User-Agent'] = 'zk-custom'

# ---------- Packs ----------
$packPath = Join-Path $PSScriptRoot 'static\cursors.json'
$packs = @(Get-Content $packPath -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ }
$show = 'Arrow', 'Hand', 'IBeam', 'Wait', 'AppStarting', 'Help', 'Crosshair', 'No', 'SizeAll', 'SizeNWSE'
foreach ($c in $packs) {
    $a = $c.apply
    if ($a.type -ne 'cursor-pack') { continue }
    $png = Join-Path $out "$($c.id).png"
    if ((Test-Path $png) -and -not $Force) { continue }
    try {
        if ($a.source -eq 'github') {
            $name = ($a.asset -replace '^\^', '' -replace '\$$', '') -replace '\\', ''
            $url = "https://github.com/$($a.repo)/releases/latest/download/$name"
        } else { $name = $a.fileName; $url = $a.url }
        $zip = Join-Path $dl $name
        if (-not (Test-Path $zip)) { Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -Headers @{ 'User-Agent' = 'Mozilla/5.0 zk-custom' } }
        $dir = Join-Path $work ([IO.Path]::GetFileNameWithoutExtension($name))
        if (-not (Test-Path $dir)) { [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir) }
        $infs = @(Get-ChildItem $dir -Recurse -Filter *.inf)
        $variant = if ($a.variant) { $a.variant } else { 'Regular' }
        $pick = @($infs | Where-Object { $_.Directory.Name -like "*$variant*" }); if (-not $pick) { $pick = $infs }
        $inf = $pick | Sort-Object { $_.Directory.Name.Length } | Select-Object -First 1
        $s = Read-CursorInf -Path $inf.FullName
        $files = @()
        foreach ($k in $show) {
            $v = $s.Values[$k]; if (-not $v) { continue }
            $f = Join-Path $inf.Directory.FullName ([IO.Path]::GetFileName(($v -replace '"', '')))
            if (Test-Path $f) { $files += $f }
        }
        if (-not $files) { $files = @(Get-ChildItem $inf.Directory.FullName -File | Where-Object { $_.Extension -in '.cur', '.ani' } | Select-Object -First 8 | ForEach-Object FullName) }
        $files = @($files | Select-Object -First 6)
        # Fila de arriba sobre oscuro, fila de abajo sobre claro: se ve bien sea el cursor blanco o negro
        $canvas = New-Object Drawing.Bitmap 480, 270; $g = [Drawing.Graphics]::FromImage($canvas)
        $dark = [Drawing.Color]::FromArgb(30, 31, 41); $light = [Drawing.Color]::FromArgb(230, 233, 239)
        $g.Clear($dark); $g.FillRectangle((New-Object Drawing.SolidBrush $light), 0, 135, 480, 135)
        $gap = (480 - $files.Count * 64) / ($files.Count + 1)
        for ($i = 0; $i -lt $files.Count; $i++) {
            foreach ($row in @(@(35, $dark), @(170, $light))) {
                $b = Get-CursorBitmap -File $files[$i] -Size 64 -Back $row[1]
                if ($b) { $g.DrawImage($b, [int]($gap + $i * (64 + $gap)), $row[0], 64, 64); $b.Dispose() }
            }
        }
        $g.Dispose(); $canvas.Save($png, [Drawing.Imaging.ImageFormat]::Png); $canvas.Dispose()
        Write-Host "  $($c.id): $($files.Count) punteros" -ForegroundColor Green
    } catch { Write-Host "  [!!] $($c.id): $($_.Exception.Message)" -ForegroundColor Yellow }
}

# ---------- Cursores dibujados por el mod (colores segun su descripcion) ----------
$styles = @{
    classic_white = @('#FFFFFF', '#FFFFFF', '#000000', $null);  classic_black = @('#111111', '#111111', '#FFFFFF', $null)
    neon_blue  = @('#0B1020', '#0B1020', '#00B4FF', '#00B4FF');  neon_pink = @('#1A0B14', '#1A0B14', '#FF2E97', '#FF2E97')
    neon_green = @('#08140B', '#08140B', '#39FF14', '#39FF14');  sunset = @('#FF9A3C', '#FF3CAC', '#5A1A2E', '#FF7A59')
    ocean = @('#5EE7DF', '#1E6FD9', '#0B2A4A', '#2EA8FF');      gold = @('#FFE08A', '#D4A017', '#5A3A0A', $null)
    rainbow = @('#FF4D4D', '#8A5CFF', '#FFFFFF', '#FFB13D');     crimson = @('#DC143C', '#A00D2A', '#FFFFFF', '#FF2A4F')
    silver = @('#F5F5F5', '#9AA0A6', '#3A3F44', $null);         forest = @('#9BE15D', '#1E6B30', '#0F3D1E', $null)
    lava = @('#FFE259', '#FF4E00', '#4A1200', '#FF7A00');       lavender = @('#E6D7FF', '#9B7BEA', '#3F2A6B', '#B79CFF')
    aurora = @('#7CFFCB', '#8A5CFF', '#1B2340', '#7CC8FF');     ice = @('#FFFFFF', '#9AD8FF', '#2E7BFF', '#9AD8FF')
    candy = @('#FF9AD5', '#7CC8FF', '#FFFFFF', '#FF9AD5');      midnight = @('#0B1E3F', '#0B1E3F', '#F5C542', '#F5C542')
    ghost = @($null, $null, '#FFFFFF', $null)
}
$arrowPath = 'M 0,0 L 0,34 L 8,26 L 14,40 L 20,37 L 14,24 L 25,24 Z'
function New-DrawnCursor($st, [string]$backHex) {
    $grid = New-Object Windows.Controls.Grid -Property @{ Width = 240; Height = 270; Background = (New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($backHex))) }
    $path = New-Object Windows.Shapes.Path -Property @{ Data = [Windows.Media.Geometry]::Parse($arrowPath); StrokeThickness = 2.4; StrokeLineJoin = 'Round'; Stretch = 'None' }
    if ($st[0]) {
        $fill = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.ColorConverter]::ConvertFromString($st[0])), ([Windows.Media.ColorConverter]::ConvertFromString($st[1])), 70.0
        $path.Fill = $fill
    }
    $path.Stroke = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($st[2]))
    if ($st[3]) { $path.Effect = New-Object Windows.Media.Effects.DropShadowEffect -Property @{ Color = [Windows.Media.ColorConverter]::ConvertFromString($st[3]); BlurRadius = 14; ShadowDepth = 0; Opacity = 1 } }
    $path.LayoutTransform = New-Object Windows.Media.ScaleTransform 3.4, 3.4
    $path.HorizontalAlignment = 'Center'; $path.VerticalAlignment = 'Center'
    [void]$grid.Children.Add($path)
    $grid.Measure((New-Object Windows.Size 240, 270)); $grid.Arrange((New-Object Windows.Rect 0, 0, 240, 270)); $grid.UpdateLayout()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap 240, 270, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32); $rtb.Render($grid); $rtb
}
$modPath = Join-Path $PSScriptRoot 'generated\cursorsmod.json'
$mods = @(Get-Content $modPath -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ }
foreach ($c in $mods) {
    $key = $c.id -replace '^wh-', ''; $st = $styles[$key]; if (-not $st) { continue }
    $png = Join-Path $out "$($c.id).png"
    if (-not (Test-Path $png) -or $Force) {
        $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
        $dc.DrawImage((New-DrawnCursor $st '#1E1F29'), (New-Object Windows.Rect 0, 0, 240, 270))
        $dc.DrawImage((New-DrawnCursor $st '#E6E9EF'), (New-Object Windows.Rect 240, 0, 240, 270)); $dc.Close()
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap 480, 270, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32); $rtb.Render($dv)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create($png); $enc.Save($fs); $fs.Close()
    }
    $c.preview = "previews/cursors/$($c.id).png"; $c | Add-Member previewLarge $c.preview -Force
    $c.description = ($c.description -replace '\s*Sin captura:.*$', '') + ' Vista recreada con sus colores, contorno y brillo.'
}
[IO.File]::WriteAllText($modPath, (ConvertTo-Json @($mods) -Depth 8), (New-Object Text.UTF8Encoding($false)))

foreach ($c in $packs) {
    if (Test-Path (Join-Path $out "$($c.id).png")) {
        $c | Add-Member preview "previews/cursors/$($c.id).png" -Force; $c | Add-Member previewLarge "previews/cursors/$($c.id).png" -Force
        $c | Add-Member previewApprox $false -Force
        if ($c.description -match 'Sin captura') { $c.description = ($c.description -replace "\s*Sin captura:.*$", '') }
    }
}
[IO.File]::WriteAllText($packPath, (ConvertTo-Json @($packs) -Depth 8), (New-Object Text.UTF8Encoding($false)))
if (Test-Path $work) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host 'Vistas de cursores listas.' -ForegroundColor Green
