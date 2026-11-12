# OrbArt.ps1 - dibuja orbs para el boton Inicio (PNG con transparencia).
# Lo usan catalog\Build-Orbs.ps1 (galeria fija) y Wizard.ps1 (orbs con los colores de tu paleta).
# Estilos: glass (esfera de cristal), neon (anillo luminoso), flat (circulo plano),
#          squircle (cuadrado redondeado), outline (solo contorno), planet (planeta con anillo).

function Get-OrbColor([string]$hex, [double]$amt = 0) {
    $c = [Windows.Media.ColorConverter]::ConvertFromString($hex)
    if ($amt -ne 0) {
        $f = { param($v) [byte][Math]::Max(0, [Math]::Min(255, $(if ($amt -ge 0) { $v + (255 - $v) * $amt } else { $v * (1 + $amt) }))) }
        $c = [Windows.Media.Color]::FromArgb($c.A, (& $f $c.R), (& $f $c.G), (& $f $c.B))
    }
    $c
}

function Add-OrbLogo($dc, [double]$cx, [double]$cy, [double]$s, $brush, $pen) {
    # Logo de 4 paneles, centrado
    $q = $s * 0.46; $g = $s * 0.08
    foreach ($p in @(@(0, 0), @(1, 0), @(0, 1), @(1, 1))) {
        $x = $cx - $q - $g / 2 + $p[0] * ($q + $g); $y = $cy - $q - $g / 2 + $p[1] * ($q + $g)
        $dc.DrawRoundedRectangle($brush, $pen, (New-Object Windows.Rect $x, $y, $q, $q), $q * 0.14, $q * 0.14)
    }
}

function New-OrbBrush($c) { $b = New-Object Windows.Media.SolidColorBrush $c; $b.Freeze(); $b }
function New-OrbPen($c, [double]$w) { New-Object Windows.Media.Pen (New-OrbBrush $c), $w }

function Add-PixelArt($dc, [string[]]$rows, [hashtable]$pal) {
    # Arte pixel: cada caracter es una celda ('.' = transparente)
    $n = [Math]::Max($rows.Count, ($rows | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    $cell = 112.0 / $n; $ox = (128 - $cell * $rows[0].Length) / 2; $oy = (128 - $cell * $rows.Count) / 2
    for ($y = 0; $y -lt $rows.Count; $y++) {
        for ($x = 0; $x -lt $rows[$y].Length; $x++) {
            $ch = [string]$rows[$y][$x]
            if ($pal.ContainsKey($ch)) { $dc.DrawRectangle($pal[$ch], $null, (New-Object Windows.Rect ($ox + $x * $cell), ($oy + $y * $cell), ($cell + 0.4), ($cell + 0.4))) }
        }
    }
}

function Add-Burst($dc, $fill, $edge, [string]$word, [int]$points = 14) {
    # Rafaga de comic con onomatopeya
    $g = New-Object Windows.Media.StreamGeometry; $ctx = $g.Open()
    for ($i = 0; $i -lt $points * 2; $i++) {
        $ang = [Math]::PI * 2 * $i / ($points * 2) - [Math]::PI / 2
        $r = if ($i % 2) { 40 + (($i * 7) % 5) } else { 61 - (($i * 3) % 6) }
        $pt = New-Object Windows.Point (64 + $r * [Math]::Cos($ang)), (64 + $r * [Math]::Sin($ang))
        if ($i -eq 0) { $ctx.BeginFigure($pt, $true, $true) } else { $ctx.LineTo($pt, $true, $false) }
    }
    $ctx.Close(); $g.Freeze()
    $dc.DrawGeometry($fill, (New-Object Windows.Media.Pen $edge, 5), $g)
    $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily 'Impact, Arial Black'), 'Normal', 'Normal', 'Normal'
    $size = if ($word.Length -le 3) { 40 } else { 30 }
    $ft = New-Object Windows.Media.FormattedText ($word, [Globalization.CultureInfo]::InvariantCulture, 'LeftToRight', $tf, $size, $edge, 1.0)
    $dc.PushTransform((New-Object Windows.Media.RotateTransform -10, 64, 64))
    $outline = $ft.BuildGeometry((New-Object Windows.Point ((128 - $ft.Width) / 2), ((128 - $ft.Height) / 2)))
    $dc.DrawGeometry((New-OrbBrush ([Windows.Media.Color]::FromRgb(255, 255, 255))), (New-Object Windows.Media.Pen $edge, 3), $outline)
    $dc.Pop()
}

function Add-GameArt($dc, [string]$Style, $c1, $c2, [double]$Light) {
    $k = New-OrbBrush ([Windows.Media.Color]::FromRgb(20, 20, 28)); $w = New-OrbBrush ([Windows.Media.Color]::FromRgb(255, 255, 255))
    $b1 = New-OrbBrush $c1; $b2 = New-OrbBrush $c2
    switch ($Style) {
        'pixelheart' {
            Add-PixelArt $dc @('.kkk...kkk.', 'k111k.k111k', 'k1w11k1111k', 'k1w1111112k', 'k111111112k', '.k1111112k.', '..k11112k..', '...k112k...', '....k2k....', '.....k.....') @{ k = $k; '1' = $b1; '2' = $b2; w = $w }
        }
        'pixelsword' {
            Add-PixelArt $dc @('..........kk', '.........kwk', '........kw2k', '.......kw2k.', '......kw2k..', '.k...kw2k...', '.kk.kw2k....', '..kk22k.....', '...k11k.....', '..k1kkk.....', '.k1k........', 'kkk.........') @{ k = $k; '1' = $b1; '2' = $b2; w = $w }
        }
        'coin' {
            $dc.DrawEllipse($b1, (New-OrbPen ([Windows.Media.Color]::FromRgb(90, 60, 10)) 5), (New-Object Windows.Point 64, 64), 54, 54)
            $dc.DrawEllipse($null, (New-Object Windows.Media.Pen $b2, 5), (New-Object Windows.Point 64, 64), 40, 40)
            $star = [Windows.Media.Geometry]::Parse('M64,34 L72,55 L94,55 L76,68 L83,90 L64,77 L45,90 L52,68 L34,55 L56,55 Z')
            $dc.DrawGeometry($b2, $null, $star)
            $dc.DrawEllipse((New-OrbBrush ([Windows.Media.Color]::FromArgb(150, 255, 255, 255))), $null, (New-Object Windows.Point 44, 38), 10, 6)
        }
        'powerstar' {
            $star = [Windows.Media.Geometry]::Parse('M64,6 L80,45 L122,47 L89,73 L101,114 L64,91 L27,114 L39,73 L6,47 L48,45 Z')
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 5), $star)
            $inner = [Windows.Media.Geometry]::Parse('M64,30 L72,52 L96,53 L77,67 L84,90 L64,77 L44,90 L51,67 L32,53 L56,52 Z')
            $dc.DrawGeometry($b2, $null, $inner)
            $dc.DrawEllipse((New-OrbBrush ([Windows.Media.Color]::FromArgb(170, 255, 255, 255))), $null, (New-Object Windows.Point 52, 40), 8, 5)
        }
        'gamepad' {
            $body = [Windows.Media.Geometry]::Parse('M30,40 C14,40 6,58 8,80 C10,100 22,106 32,96 L44,82 L84,82 L96,96 C106,106 118,100 120,80 C122,58 114,40 98,40 Z')
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 4), $body)
            $dc.DrawRectangle($k, $null, (New-Object Windows.Rect 26, 58, 22, 7)); $dc.DrawRectangle($k, $null, (New-Object Windows.Rect 33, 51, 8, 21))
            $btn = @(@(94, 52, '#F7768E'), @(104, 62, '#9ECE6A'), @(84, 62, '#7AA2F7'), @(94, 72, '#E0AF68'))
            foreach ($bb in $btn) { $dc.DrawEllipse((New-OrbBrush ([Windows.Media.ColorConverter]::ConvertFromString($bb[2]))), (New-Object Windows.Media.Pen $k, 2), (New-Object Windows.Point $bb[0], $bb[1]), 6, 6) }
            $dc.DrawEllipse($b2, $null, (New-Object Windows.Point 54, 74), 6, 6); $dc.DrawEllipse($b2, $null, (New-Object Windows.Point 74, 74), 6, 6)
        }
        'joystick' {
            $dc.DrawRoundedRectangle($k, $null, (New-Object Windows.Rect 18, 84, 92, 30), 10, 10)
            $dc.DrawRoundedRectangle($b2, $null, (New-Object Windows.Rect 22, 86, 84, 22), 8, 8)
            $dc.DrawRectangle($k, $null, (New-Object Windows.Rect 59, 44, 10, 46))
            $dc.DrawEllipse($b1, (New-Object Windows.Media.Pen $k, 4), (New-Object Windows.Point 64, 36), 24, 24)
            $dc.DrawEllipse($w, $null, (New-Object Windows.Point 56, 28), 7, 5)
            $dc.DrawEllipse((New-OrbBrush ([Windows.Media.ColorConverter]::ConvertFromString('#F7768E'))), (New-Object Windows.Media.Pen $k, 2), (New-Object Windows.Point 92, 97), 6, 6)
        }
        'potion' {
            $fl = [Windows.Media.Geometry]::Parse('M52,16 L76,16 L76,40 C100,50 110,70 104,92 C98,114 30,114 24,92 C18,70 28,50 52,40 Z')
            $dc.DrawGeometry((New-OrbBrush ([Windows.Media.Color]::FromArgb(70, 255, 255, 255))), (New-Object Windows.Media.Pen $k, 4), $fl)
            $dc.PushClip($fl)
            $dc.DrawRectangle($b1, $null, (New-Object Windows.Rect 0, 64, 128, 64))
            $dc.Pop()
            $dc.DrawRoundedRectangle((New-OrbBrush ([Windows.Media.Color]::FromRgb(140, 90, 50))), (New-Object Windows.Media.Pen $k, 3), (New-Object Windows.Rect 48, 6, 32, 14), 4, 4)
            foreach ($bu in @(@(52, 80, 6), @(72, 92, 4), @(80, 74, 3))) { $dc.DrawEllipse($b2, $null, (New-Object Windows.Point $bu[0], $bu[1]), $bu[2], $bu[2]) }
            $dc.DrawEllipse((New-OrbBrush ([Windows.Media.Color]::FromArgb(160, 255, 255, 255))), $null, (New-Object Windows.Point 42, 70), 5, 12)
        }
        'shield' {
            $sh = [Windows.Media.Geometry]::Parse('M64,6 L112,22 C112,70 96,104 64,122 C32,104 16,70 16,22 Z')
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 5), $sh)
            $in = [Windows.Media.Geometry]::Parse('M64,20 L98,32 C98,68 86,94 64,108 C42,94 30,68 30,32 Z')
            $dc.DrawGeometry($null, (New-Object Windows.Media.Pen $b2, 4), $in)
            $dc.DrawRectangle($b2, $null, (New-Object Windows.Rect 58, 34, 12, 60)); $dc.DrawRectangle($b2, $null, (New-Object Windows.Rect 40, 52, 48, 12))
        }
        'd20' {
            $hex = [Windows.Media.Geometry]::Parse('M64,6 L114,35 L114,93 L64,122 L14,93 L14,35 Z')
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 4), $hex)
            $tri = [Windows.Media.Geometry]::Parse('M64,30 L96,86 L32,86 Z')
            $dc.DrawGeometry($b2, (New-Object Windows.Media.Pen $k, 3), $tri)
            foreach ($ln in @('M64,6 L64,30', 'M114,35 L96,86', 'M14,35 L32,86', 'M64,122 L96,86', 'M64,122 L32,86', 'M14,35 L64,30', 'M114,35 L64,30')) { $dc.DrawGeometry($null, (New-Object Windows.Media.Pen $k, 2.5), [Windows.Media.Geometry]::Parse($ln)) }
            $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily 'Impact, Arial Black'), 'Normal', 'Normal', 'Normal'
            $ft = New-Object Windows.Media.FormattedText ('20', [Globalization.CultureInfo]::InvariantCulture, 'LeftToRight', $tf, 26, $k, 1.0)
            $dc.DrawText($ft, (New-Object Windows.Point ((128 - $ft.Width) / 2), 54))
        }
        'shuriken' {
            $sg = [Windows.Media.Geometry]::Parse('M64,4 L74,54 L124,64 L74,74 L64,124 L54,74 L4,64 L54,54 Z')
            $sg2 = $sg.Clone(); $sg2.Transform = New-Object Windows.Media.RotateTransform 45, 64, 64
            $dc.DrawGeometry($b2, (New-Object Windows.Media.Pen $k, 3), $sg2)
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 3), $sg)
            $dc.DrawEllipse($k, $null, (New-Object Windows.Point 64, 64), 9, 9); $dc.DrawEllipse($b2, $null, (New-Object Windows.Point 64, 64), 4, 4)
        }
        'bolt' {
            $dc.DrawEllipse($b2, (New-Object Windows.Media.Pen $k, 5), (New-Object Windows.Point 64, 64), 58, 58)
            $bolt = [Windows.Media.Geometry]::Parse('M74,10 L34,70 L60,70 L50,118 L96,52 L68,52 Z')
            $dc.DrawGeometry($b1, (New-Object Windows.Media.Pen $k, 4), $bolt)
        }
        'pow'   { Add-Burst $dc $b1 $k 'POW!' }
        'boom'  { Add-Burst $dc $b1 $k 'BOOM!' 16 }
        'wow'   { Add-Burst $dc $b1 $k 'WOW!' 12 }
    }
}

function New-OrbImage {
    param([string]$Style, [string]$Color1, [string]$Color2, [double]$Light = 0, [int]$Size = 128)
    $S = [double]$Size; $c = $S / 2
    $c1 = Get-OrbColor $Color1 $Light; $c2 = Get-OrbColor $Color2 $Light
    $white = New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(240, 255, 255, 255))
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    switch ($Style) {
        'glass' {
            $rg = New-Object Windows.Media.RadialGradientBrush
            $rg.GradientOrigin = New-Object Windows.Point 0.5, 0.85; $rg.Center = New-Object Windows.Point 0.5, 0.6; $rg.RadiusX = 0.75; $rg.RadiusY = 0.75
            $rg.GradientStops.Add((New-Object Windows.Media.GradientStop $c2, 0.0))
            $rg.GradientStops.Add((New-Object Windows.Media.GradientStop $c1, 0.55))
            $rg.GradientStops.Add((New-Object Windows.Media.GradientStop (Get-OrbColor $Color1 ($Light - 0.6)), 1.0))
            $dc.DrawEllipse($rg, (New-Object Windows.Media.Pen (New-Object Windows.Media.SolidColorBrush (Get-OrbColor $Color1 ($Light - 0.7))), ($S * 0.03)), (New-Object Windows.Point $c, $c), ($c * 0.94), ($c * 0.94))
            Add-OrbLogo $dc $c ($c * 1.02) ($S * 0.42) $white $null
            $hl = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.Color]::FromArgb(200, 255, 255, 255)), ([Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 90.0
            $dc.DrawEllipse($hl, $null, (New-Object Windows.Point $c, ($c * 0.52)), ($c * 0.66), ($c * 0.40))
        }
        'neon' {
            foreach ($i in 6..1) {
                $a = [byte](22 * (7 - $i)); $col = [Windows.Media.Color]::FromArgb($a, $c1.R, $c1.G, $c1.B)
                $dc.DrawEllipse($null, (New-Object Windows.Media.Pen (New-Object Windows.Media.SolidColorBrush $col), ($S * 0.02 * $i)), (New-Object Windows.Point $c, $c), ($c * 0.76), ($c * 0.76))
            }
            $dc.DrawEllipse((New-Object Windows.Media.SolidColorBrush ([Windows.Media.Color]::FromArgb(150, 10, 10, 20))), (New-Object Windows.Media.Pen (New-Object Windows.Media.SolidColorBrush $c1), ($S * 0.035)), (New-Object Windows.Point $c, $c), ($c * 0.76), ($c * 0.76))
            Add-OrbLogo $dc $c $c ($S * 0.36) (New-Object Windows.Media.SolidColorBrush $c2) $null
        }
        'flat' {
            $dc.DrawEllipse((New-Object Windows.Media.SolidColorBrush $c1), $null, (New-Object Windows.Point $c, $c), ($c * 0.92), ($c * 0.92))
            Add-OrbLogo $dc $c $c ($S * 0.40) $white $null
        }
        'squircle' {
            $lg = New-Object Windows.Media.LinearGradientBrush $c1, $c2, 45.0
            $dc.DrawRoundedRectangle($lg, $null, (New-Object Windows.Rect ($S * 0.06), ($S * 0.06), ($S * 0.88), ($S * 0.88)), ($S * 0.26), ($S * 0.26))
            Add-OrbLogo $dc $c $c ($S * 0.40) $white $null
        }
        'outline' {
            $pen = New-Object Windows.Media.Pen (New-Object Windows.Media.SolidColorBrush $c1), ($S * 0.05)
            Add-OrbLogo $dc $c $c ($S * 0.62) $null $pen
        }
        'planet' {
            $back = New-Object Windows.Media.Pen (New-Object Windows.Media.SolidColorBrush $c2), ($S * 0.05)
            $ring = New-Object Windows.Media.EllipseGeometry (New-Object Windows.Point $c, ($c * 1.05)), ($c * 0.95), ($c * 0.26)
            $ring.Transform = New-Object Windows.Media.RotateTransform -18, $c, $c
            $dc.DrawGeometry($null, $back, $ring)
            $rg = New-Object Windows.Media.RadialGradientBrush (Get-OrbColor $Color1 ($Light + 0.35)), $c1
            $rg.GradientOrigin = New-Object Windows.Point 0.35, 0.3
            $dc.DrawEllipse($rg, $null, (New-Object Windows.Point $c, $c), ($c * 0.62), ($c * 0.62))
            $dc.PushClip((New-Object Windows.Media.RectangleGeometry (New-Object Windows.Rect 0, ($c * 1.0), $S, $S)))
            $dc.DrawGeometry($null, $back, $ring); $dc.Pop()
            Add-OrbLogo $dc $c $c ($S * 0.30) $white $null
        }
        default {
            # Estilos gamer y comic (dibujos originales en una caja de 128x128)
            $dc.PushTransform((New-Object Windows.Media.ScaleTransform ($S / 128), ($S / 128)))
            Add-GameArt $dc $Style $c1 $c2 $Light
            $dc.Pop()
        }
    }
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb.Freeze(); $rtb
}

function New-FolderImage {
    # Icono de carpeta de color (pestana trasera, cuerpo con degradado y brillo)
    param([string]$Color, [int]$Size = 256)
    $S = [double]$Size; $k = $S / 256
    $c = Get-OrbColor $Color; $dark = Get-OrbColor $Color -0.28; $light = Get-OrbColor $Color 0.22
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform $k, $k))
    $back = [Windows.Media.Geometry]::Parse('M20,52 C20,42 28,34 38,34 L96,34 C104,34 108,38 114,46 L122,56 L218,56 C228,56 236,64 236,74 L236,196 C236,206 228,214 218,214 L38,214 C28,214 20,206 20,196 Z')
    $dc.DrawGeometry((New-OrbBrush $dark), $null, $back)
    $dc.DrawRoundedRectangle((New-OrbBrush ([Windows.Media.Color]::FromRgb(245, 245, 245))), $null, (New-Object Windows.Rect 40, 68, 176, 120), 6, 6)
    $front = New-Object Windows.Media.LinearGradientBrush $light, $c, 90.0
    $dc.DrawRoundedRectangle($front, $null, (New-Object Windows.Rect 14, 88, 228, 132), 16, 16)
    $dc.DrawRoundedRectangle((New-OrbBrush ([Windows.Media.Color]::FromArgb(70, 255, 255, 255))), $null, (New-Object Windows.Rect 14, 88, 228, 10), 5, 5)
    $dc.Pop(); $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb.Freeze(); $rtb
}

function Save-IcoFile {
    # Archivo .ico: PNG para 256 px y mapas de bits clasicos para 64/48/32/16
    param([scriptblock]$Draw, [string]$Path)
    $sizes = 256, 64, 48, 32, 16; $blobs = @()
    foreach ($s in $sizes) {
        $bmp = & $Draw $s
        if ($s -ge 256) {
            $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bmp))
            $ms = New-Object IO.MemoryStream; $enc.Save($ms); $blobs += , $ms.ToArray()
        } else {
            $stride = $s * 4; $px = New-Object byte[] ($stride * $s); $bmp.CopyPixels($px, $stride, 0)
            $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
            $w.Write([uint32]40); $w.Write([int32]$s); $w.Write([int32]($s * 2)); $w.Write([uint16]1); $w.Write([uint16]32)
            $w.Write([uint32]0); $w.Write([uint32]0); $w.Write([int32]0); $w.Write([int32]0); $w.Write([uint32]0); $w.Write([uint32]0)
            for ($y = $s - 1; $y -ge 0; $y--) { $w.Write($px, $y * $stride, $stride) }
            $w.Write((New-Object byte[] ([int]([Math]::Ceiling($s / 32.0) * 4) * $s))); $w.Flush(); $blobs += , $ms.ToArray()
        }
    }
    $ms = New-Object IO.MemoryStream; $bw = New-Object IO.BinaryWriter $ms
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count); $offset = 6 + 16 * $sizes.Count
    for ($i = 0; $i -lt $sizes.Count; $i++) {
        $d = [byte]$(if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] })
        $bw.Write($d); $bw.Write($d); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$blobs[$i].Length); $bw.Write([uint32]$offset); $offset += $blobs[$i].Length
    }
    foreach ($b in $blobs) { $bw.Write([byte[]]$b) }
    $bw.Flush(); [IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

function Save-OrbPng($bitmap, [string]$Path) {
    $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
    $fs = [IO.File]::Create($Path); try { $enc.Save($fs) } finally { $fs.Close() }
}

function Save-OrbSet {
    <# Guarda normal, hover (mas claro) y pressed (mas oscuro). Devuelve las tres rutas. #>
    param([string]$Style, [string]$Color1, [string]$Color2, [string]$Dir, [string]$Name)
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $out = [ordered]@{}
    foreach ($v in @(@('normal', 0), @('hover', 0.22), @('pressed', -0.25))) {
        $file = Join-Path $Dir ("$Name" + $(if ($v[0] -ne 'normal') { "-$($v[0])" } else { '' }) + '.png')
        Save-OrbPng (New-OrbImage -Style $Style -Color1 $Color1 -Color2 $Color2 -Light $v[1]) $file
        $out[$v[0]] = $file
    }
    $out
}
