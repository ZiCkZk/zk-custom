#Requires -Version 5.1
<#
.SYNOPSIS
    Genera el icono y compila ZK-Custom.exe con el compilador de C# que trae Windows (.NET Framework 4).
    No necesita instalar nada. El .exe queda en la raiz del proyecto.
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$here = $PSScriptRoot
$root = Resolve-Path (Join-Path $here '..\..')
$ico = Join-Path $here 'zk-custom.ico'

function New-IconPng([int]$size) {
    # Cuadrado redondeado con degradado azul-lavanda y las letras ZK
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    $c1 = [Windows.Media.ColorConverter]::ConvertFromString('#7AA2F7'); $c2 = [Windows.Media.ColorConverter]::ConvertFromString('#BB9AF7')
    $bg = New-Object Windows.Media.LinearGradientBrush $c1, $c2, 45.0
    $r = $size * 0.22
    $dc.DrawRoundedRectangle($bg, $null, (New-Object Windows.Rect 0, 0, $size, $size), $r, $r)
    $inner = New-Object Windows.Media.SolidColorBrush ([Windows.Media.ColorConverter]::ConvertFromString('#1A1B26'))
    $m = $size * 0.08
    $dc.DrawRoundedRectangle($inner, $null, (New-Object Windows.Rect $m, $m, ($size - 2 * $m), ($size - 2 * $m)), $r * 0.75, $r * 0.75)
    $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily 'Segoe UI'), 'Normal', 'Bold', 'Normal'
    $ft = New-Object Windows.Media.FormattedText ('ZK', [Globalization.CultureInfo]::InvariantCulture, 'LeftToRight', $tf, ($size * 0.42), $bg, 1.0)
    $dc.DrawText($ft, (New-Object Windows.Point (($size - $ft.Width) / 2), (($size - $ft.Height) / 2)))
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $size, $size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv)
    if ($size -ge 256) {
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $ms = New-Object IO.MemoryStream; $enc.Save($ms); return , $ms.ToArray()
    }
    # Tamanos pequenos: mapa de bits clasico (BITMAPINFOHEADER + BGRA de abajo arriba + mascara AND)
    $stride = $size * 4; $px = New-Object byte[] ($stride * $size); $rtb.CopyPixels($px, $stride, 0)
    $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
    $w.Write([uint32]40); $w.Write([int32]$size); $w.Write([int32]($size * 2)); $w.Write([uint16]1); $w.Write([uint16]32)
    $w.Write([uint32]0); $w.Write([uint32]0); $w.Write([int32]0); $w.Write([int32]0); $w.Write([uint32]0); $w.Write([uint32]0)
    for ($y = $size - 1; $y -ge 0; $y--) { $w.Write($px, $y * $stride, $stride) }
    $maskStride = [int]([Math]::Ceiling($size / 32.0) * 4)
    $w.Write((New-Object byte[] ($maskStride * $size)))
    $w.Flush(); , $ms.ToArray()
}

# Archivo .ico: PNG para 256 px y mapas de bits para el resto
$sizes = 256, 64, 48, 32, 16
$pngs = foreach ($s in $sizes) { , [byte[]](New-IconPng $s) }
$ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $d = [byte]$(if ($s -ge 256) { 0 } else { $s })
    $bw.Write($d); $bw.Write($d); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
    $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $bw.Write([byte[]]$p) }
$bw.Flush(); [IO.File]::WriteAllBytes($ico, $ms.ToArray())

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
$out = Join-Path $root 'ZK-Custom.exe'
& $csc /nologo /optimize+ /target:winexe /platform:anycpu "/win32icon:$ico" "/win32manifest:$(Join-Path $here 'app.manifest')" "/out:$out" /r:System.Windows.Forms.dll (Join-Path $here 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw "csc devolvio $LASTEXITCODE" }
Write-Host "Creado $out" -ForegroundColor Green
