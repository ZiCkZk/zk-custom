#Requires -Version 5.1
<#
.SYNOPSIS
    Genera una imagen de muestra de cada fuente de catalog\static\fonts.json con su letra real.
    Descarga solo un archivo .ttf por fuente (el Regular) del repositorio de Nerd Fonts y dibuja la muestra.
    Las imagenes quedan en catalog\previews\fonts\<id>.png y se incluyen en el proyecto.
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$h = @{ 'User-Agent' = 'zk-custom' }
$root = $PSScriptRoot
$out = Join-Path $root 'previews\fonts'
$tmp = Join-Path $root '..\cache\fontsrc'
New-Item -ItemType Directory -Force -Path $out, $tmp | Out-Null

$fonts = (Get-Content (Join-Path $root 'static\fonts.json') -Raw -Encoding UTF8 | ConvertFrom-Json) | Where-Object { $_.apply.type -eq 'font' }
$top = (Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/git/trees/master' -Headers $h).tree | Where-Object { $_.path -eq 'patched-fonts' }
$folders = (Invoke-RestMethod "https://api.github.com/repos/ryanoasis/nerd-fonts/git/trees/$($top.sha)" -Headers $h).tree

function Get-Color($hex) { New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString($hex)) }

foreach ($f in $fonts) {
    $png = Join-Path $out "$($f.id).png"
    if ((Test-Path $png) -and -not $Force) { Write-Host "  $($f.id): ya existe"; continue }
    $folderName = $f.apply.asset -replace '^\^', '' -replace '\\\.zip\$$', '' -replace '\\', ''
    $folder = $folders | Where-Object { $_.path -eq $folderName } | Select-Object -First 1
    if (-not $folder) { Write-Host "  $($f.id): no encuentro la carpeta $folderName" -ForegroundColor Yellow; continue }
    $files = (Invoke-RestMethod "https://api.github.com/repos/ryanoasis/nerd-fonts/git/trees/$($folder.sha)?recursive=1" -Headers $h).tree |
             Where-Object { $_.path -match '\.(ttf|otf)$' -and ([IO.Path]::GetFileName($_.path)) -match $f.apply.filter }
    $pick = $files | Sort-Object @{ e = { if ($_.path -match 'NerdFont-Regular\.') { 0 } elseif ($_.path -match 'Regular') { 1 } else { 2 } } }, @{ e = { $_.path.Length } } | Select-Object -First 1
    $local = $null
    if (-not $pick) {
        # Algunas fuentes solo se publican en el .zip de la release: se baja una vez y se extrae el Regular
        $rel = (Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -Headers $h).assets | Where-Object { $_.name -match $f.apply.asset } | Select-Object -First 1
        if (-not $rel) { Write-Host "  $($f.id): sin archivo que cumpla $($f.apply.filter)" -ForegroundColor Yellow; continue }
        $zip = Join-Path $tmp $rel.name
        if (-not (Test-Path $zip)) { Invoke-WebRequest $rel.browser_download_url -OutFile $zip -UseBasicParsing -Headers $h }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $za = [IO.Compression.ZipFile]::OpenRead($zip)
        $entry = $za.Entries | Where-Object { $_.Name -match $f.apply.filter } | Sort-Object @{ e = { if ($_.Name -match 'NerdFont-Regular\.') { 0 } elseif ($_.Name -match 'Regular') { 1 } else { 2 } } }, @{ e = { $_.Name.Length } } | Select-Object -First 1
        if ($entry) { $local = Join-Path $tmp $entry.Name; if (-not (Test-Path $local)) { [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $local) } }
        $za.Dispose()
        if (-not $local) { Write-Host "  $($f.id): el zip no trae $($f.apply.filter)" -ForegroundColor Yellow; continue }
    } else { $local = Join-Path $tmp ([IO.Path]::GetFileName($pick.path)) }
    if (-not (Test-Path $local)) {
        $url = "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/master/patched-fonts/$folderName/" + (($pick.path -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/')
        Invoke-WebRequest $url -OutFile $local -UseBasicParsing -Headers $h
    }
    try {
        $gt = New-Object Windows.Media.GlyphTypeface ([uri]$local)
        $family = $gt.FamilyNames[[Globalization.CultureInfo]::GetCultureInfo('en-US')]
    } catch {
        Add-Type -AssemblyName System.Drawing
        $pfc = New-Object Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($local); $family = $pfc.Families[0].Name; $pfc.Dispose()
    }
    $ff = [Windows.Media.Fonts]::GetFontFamilies($local) | Select-Object -First 1
    if (-not $ff) { Write-Host "  $($f.id): WPF no puede leer $local" -ForegroundColor Yellow; continue }

    # Muestra: prompt, ligaduras, caracteres confundibles, acentos e iconos Nerd Font
    $PW = 960; $PH = 540
    $dv = New-Object Windows.Media.DrawingVisual
    $dc = $dv.RenderOpen()
    $dc.DrawRoundedRectangle((Get-Color '#1A1B26'), $null, (New-Object Windows.Rect 0, 0, $PW, $PH), 0, 0)
    $dc.DrawRectangle((Get-Color '#16161E'), $null, (New-Object Windows.Rect 0, 0, $PW, 46))
    $dots = '#F7768E', '#E0AF68', '#9ECE6A'
    foreach ($i in 0..2) { $dc.DrawEllipse((Get-Color $dots[$i]), $null, (New-Object Windows.Point (28 + $i * 24), 23), 7, 7) }
    $tf = New-Object Windows.Media.Typeface $ff, 'Normal', 'Normal', 'Normal'
    # Letras grandes: la diferencia entre fuentes se nota incluso en la miniatura de la tarjeta
    $y = 58
    $lines = @(
        @(150, @('#C0CAF5', 'Aa Gg'), @('#E0AF68', ' 0O')),
        @(96,  @('#7AA2F7', '1lI {} '), @('#BB9AF7', '=> !=')),
        @(70,  @('#9ECE6A', [string][char]0xF07C + ' ' + [char]0xE0A0 + ' ' + [char]0xF120 + '  '), @('#F7768E', 'Ñandú ¿?'))
    )
    foreach ($ln in $lines) {
        $x = 34.0; $size = [double]$ln[0]; $hmax = 0
        foreach ($seg in ($ln | Select-Object -Skip 1)) {
            $ft = New-Object Windows.Media.FormattedText ($seg[1], [Globalization.CultureInfo]::InvariantCulture, 'LeftToRight', $tf, $size, (Get-Color $seg[0]), 1.0)
            $dc.DrawText($ft, (New-Object Windows.Point $x, $y)); $x += $ft.WidthIncludingTrailingWhitespace
            $hmax = [Math]::Max($hmax, $ft.Height)
        }
        $y += $hmax * 0.98
    }
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $PW, $PH, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($png); $enc.Save($fs); $fs.Close()
    Write-Host "  $($f.id): $family" -ForegroundColor Green
}
