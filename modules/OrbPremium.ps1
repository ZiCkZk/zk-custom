# OrbPremium.ps1 - orbs "premium" (rediseno): esfera 3D con reflejo, borde luminoso,
# halo, sombra y un icono blanco. Dibujos originales en una caja de 256x256.
# Necesita OrbArt.ps1 cargado antes (Get-OrbColor, New-OrbBrush, Add-OrbLogo).

function Add-PremiumGlyph($dc, [string]$Glyph, $c1, $c2, [switch]$Shadow) {
    $wc = if ($Shadow) { [Windows.Media.Color]::FromArgb(110, 0, 0, 0) } else { [Windows.Media.Color]::FromArgb(245, 255, 255, 255) }
    $w = New-OrbBrush $wc
    $acc = if ($Shadow) { $w } else { New-OrbBrush ([Windows.Media.Color]::FromRgb([byte]($c1.R * 0.55), [byte]($c1.G * 0.55), [byte]($c1.B * 0.55))) }
    $dark = if ($Shadow) { $w } else { New-OrbBrush ([Windows.Media.Color]::FromRgb(24, 24, 30)) }
    $P = { param($d) [Windows.Media.Geometry]::Parse($d) }
    $wp = { param($t) New-Object Windows.Media.Pen $w, $t }
    $pt = { param($x, $y) New-Object Windows.Point $x, $y }
    $rc = { param($x, $y, $ww, $hh) New-Object Windows.Rect $x, $y, $ww, $hh }
    switch ($Glyph) {
        # ---------- musica ----------
        'vinyl' {
            $dc.DrawEllipse($dark, $null, (& $pt 128 128), 66, 66)
            if (-not $Shadow) { foreach ($r in 58, 50, 42) { $dc.DrawEllipse($null, (New-Object Windows.Media.Pen (New-OrbBrush ([Windows.Media.Color]::FromArgb(60, 255, 255, 255))), 1.5), (& $pt 128 128), $r, $r) } }
            $dc.DrawEllipse($(if ($Shadow) { $w } else { New-OrbBrush $c2 }), $null, (& $pt 128 128), 24, 24)
            $dc.DrawEllipse($dark, $null, (& $pt 128 128), 5, 5)
        }
        'headphones' {
            $dc.DrawGeometry($null, (& $wp 14), (& $P 'M 74,142 L 74,124 A 54,54 0 0 1 182,124 L 182,142'))
            $dc.DrawRoundedRectangle($w, $null, (& $rc 60 128 32 54), 12, 12)
            $dc.DrawRoundedRectangle($w, $null, (& $rc 164 128 32 54), 12, 12)
        }
        'equalizer' {
            $hs = 40, 80, 58, 98, 50
            for ($i = 0; $i -lt 5; $i++) { $dc.DrawRoundedRectangle($w, $null, (& $rc (70 + $i * 24) (174 - $hs[$i]) 16 $hs[$i]), 6, 6) }
        }
        'note' {
            $dc.DrawGeometry($w, $null, (& $P 'M 102,84 L 172,66 L 172,154 A 21,16 0 1 1 160,140 L 160,98 L 114,110 L 114,168 A 21,16 0 1 1 102,154 Z'))
        }
        'cassette' {
            $dc.DrawRoundedRectangle($w, $null, (& $rc 62 86 132 86), 12, 12)
            $dc.DrawRoundedRectangle($acc, $null, (& $rc 78 100 100 36), 8, 8)
            foreach ($x in 104, 152) { $dc.DrawEllipse($w, $null, (& $pt $x 118), 11, 11); $dc.DrawEllipse($acc, $null, (& $pt $x 118), 4, 4) }
            $dc.DrawGeometry($acc, $null, (& $P 'M 92,172 L 100,152 L 156,152 L 164,172 Z'))
        }
        'mic' {
            $dc.DrawRoundedRectangle($w, $null, (& $rc 106 60 44 82), 22, 22)
            $dc.DrawGeometry($null, (& $wp 10), (& $P 'M 88,116 A 40,40 0 0 0 168,116'))
            $dc.DrawRectangle($w, $null, (& $rc 123 154 10 22)); $dc.DrawRoundedRectangle($w, $null, (& $rc 100 174 56 10), 5, 5)
        }
        'speaker' {
            $dc.DrawGeometry($w, $null, (& $P 'M 66,108 L 94,108 L 126,82 L 126,174 L 94,148 L 66,148 Z'))
            $dc.DrawGeometry($null, (& $wp 9), (& $P 'M 146,104 A 30,30 0 0 1 146,152'))
            $dc.DrawGeometry($null, (& $wp 9), (& $P 'M 162,86 A 52,52 0 0 1 162,170'))
        }
        # ---------- gaming ----------
        'gamepad' {
            $dc.DrawGeometry($w, $null, (& $P 'M 84,96 C 60,96 50,124 52,150 C 54,172 70,178 82,166 L 98,150 L 158,150 L 174,166 C 186,178 202,172 204,150 C 206,124 196,96 172,96 Z'))
            $dc.DrawRectangle($acc, $null, (& $rc 78 120 32 9)); $dc.DrawRectangle($acc, $null, (& $rc 89.5 108.5 9 32))
            foreach ($b in @(@(168, 112), @(182, 126), @(154, 126), @(168, 140))) { $dc.DrawEllipse($acc, $null, (& $pt $b[0] $b[1]), 6, 6) }
        }
        'joystick' {
            $dc.DrawRoundedRectangle($w, $null, (& $rc 72 156 112 28), 10, 10)
            $dc.DrawRectangle($w, $null, (& $rc 122 104 12 56))
            $dc.DrawEllipse($w, $null, (& $pt 128 94), 26, 26)
            $dc.DrawEllipse($acc, $null, (& $pt 164 170), 6, 6)
        }
        'sword' {
            $dc.DrawGeometry($w, $null, (& $P 'M 178,62 L 194,62 L 194,78 L 122,150 L 106,134 Z'))
            $dc.DrawGeometry($w, $null, (& $P 'M 90,130 L 102,118 L 138,154 L 126,166 Z'))
            $dc.DrawGeometry($w, $null, (& $P 'M 108,148 L 118,158 L 84,192 L 74,182 Z'))
        }
        'heart' { $dc.DrawGeometry($w, $null, (& $P 'M 128,188 C 70,148 60,120 62,100 C 64,76 86,64 104,66 C 116,68 124,76 128,88 C 132,76 140,68 152,66 C 170,64 192,76 194,100 C 196,120 186,148 128,188 Z')) }
        'coin' {
            $dc.DrawEllipse($w, $null, (& $pt 128 128), 56, 56)
            $dc.DrawEllipse($null, (New-Object Windows.Media.Pen $acc, 6), (& $pt 128 128), 42, 42)
            $dc.DrawGeometry($acc, $null, (& $P 'M 128,98 L 136,120 L 160,121 L 141,135 L 148,158 L 128,144 L 108,158 L 115,135 L 96,121 L 120,120 Z'))
        }
        'star' { $dc.DrawGeometry($w, $null, (& $P 'M 128,60 L 147,108 L 198,110 L 158,141 L 172,192 L 128,162 L 84,192 L 98,141 L 58,110 L 109,108 Z')) }
        'd20' {
            $dc.DrawGeometry($w, $null, (& $P 'M 128,60 L 188,95 L 188,161 L 128,196 L 68,161 L 68,95 Z'))
            $dc.DrawGeometry($null, (New-Object Windows.Media.Pen $acc, 4), (& $P 'M 128,86 L 164,148 L 92,148 Z M 128,60 L 128,86 M 188,95 L 164,148 M 68,95 L 92,148 M 128,196 L 164,148 M 128,196 L 92,148'))
        }
        'potion' {
            $dc.DrawGeometry($w, $null, (& $P 'M 112,64 L 144,64 L 144,98 C 172,110 186,130 182,156 C 178,186 78,186 74,156 C 70,130 84,110 112,98 Z'))
            $dc.DrawGeometry($acc, $null, (& $P 'M 80,142 C 104,130 152,152 176,142 C 178,170 78,172 80,142 Z'))
        }
        # ---------- otros ----------
        'planet' {
            $dc.DrawEllipse($w, $null, (& $pt 128 128), 40, 40)
            $ring = New-Object Windows.Media.EllipseGeometry (& $pt 128 128), 74, 20
            $ring.Transform = New-Object Windows.Media.RotateTransform -20, 128, 128
            $dc.DrawGeometry($null, (& $wp 8), $ring)
            $dc.DrawEllipse($acc, $null, (& $pt 116 118), 8, 8)
        }
        'flame' { $dc.DrawGeometry($w, $null, (& $P 'M 128,58 C 152,92 178,112 174,152 C 170,184 148,196 128,196 C 108,196 82,184 82,152 C 82,124 102,112 108,90 C 116,112 124,116 128,118 C 130,100 124,82 128,58 Z')) }
        'bolt' { $dc.DrawGeometry($w, $null, (& $P 'M 144,56 L 84,140 L 122,140 L 106,200 L 174,112 L 136,112 Z')) }
        'moon' { $dc.DrawGeometry($w, $null, (& $P 'M 150,62 A 68,68 0 1 0 194,150 A 56,56 0 1 1 150,62 Z')) }
        'leaf' {
            $dc.DrawGeometry($w, $null, (& $P 'M 72,184 C 68,110 116,66 192,64 C 192,140 148,188 72,184 Z'))
            $dc.DrawGeometry($null, (New-Object Windows.Media.Pen $acc, 5), (& $P 'M 80,176 C 112,140 146,108 178,80'))
        }
        'crystal' {
            $dc.DrawGeometry($w, $null, (& $P 'M 128,54 L 178,104 L 128,202 L 78,104 Z'))
            $dc.DrawGeometry($null, (New-Object Windows.Media.Pen $acc, 3), (& $P 'M 78,104 L 178,104 M 128,54 L 112,104 L 128,202 M 128,54 L 144,104 L 128,202'))
        }
        default { Add-OrbLogo $dc 128 128 100 $w $null }
    }
}

function New-PremiumOrb {
    param([string]$Glyph, [string]$Color1, [string]$Color2, [double]$Light = 0, [int]$Size = 256)
    $c1 = Get-OrbColor $Color1 $Light; $c2 = Get-OrbColor $Color2 $Light
    $dark = Get-OrbColor $Color1 ($Light - 0.62)
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    $dc.PushTransform((New-Object Windows.Media.ScaleTransform ($Size / 256), ($Size / 256)))
    # Halo de color y sombra
    $halo = New-Object Windows.Media.RadialGradientBrush ([Windows.Media.Color]::FromArgb(120, $c1.R, $c1.G, $c1.B)), ([Windows.Media.Color]::FromArgb(0, $c1.R, $c1.G, $c1.B))
    $dc.DrawEllipse($halo, $null, (New-Object Windows.Point 128, 128), 127, 127)
    $dc.DrawEllipse((New-OrbBrush ([Windows.Media.Color]::FromArgb(90, 0, 0, 0))), $null, (New-Object Windows.Point 128, 138), 101, 101)
    # Esfera
    $sp = New-Object Windows.Media.RadialGradientBrush
    $sp.GradientOrigin = New-Object Windows.Point 0.36, 0.28; $sp.Center = New-Object Windows.Point 0.45, 0.42; $sp.RadiusX = 0.7; $sp.RadiusY = 0.7
    $sp.GradientStops.Add((New-Object Windows.Media.GradientStop $c2, 0.0))
    $sp.GradientStops.Add((New-Object Windows.Media.GradientStop $c1, 0.5))
    $sp.GradientStops.Add((New-Object Windows.Media.GradientStop $dark, 1.0))
    $rim = New-Object Windows.Media.Pen (New-Object Windows.Media.LinearGradientBrush (Get-OrbColor $Color2 ($Light + 0.35)), $dark, 90.0), 4
    $dc.DrawEllipse($sp, $rim, (New-Object Windows.Point 128, 128), 100, 100)
    # Luz de rebote abajo
    $bounce = New-Object Windows.Media.RadialGradientBrush ([Windows.Media.Color]::FromArgb(130, $c2.R, $c2.G, $c2.B)), ([Windows.Media.Color]::FromArgb(0, $c2.R, $c2.G, $c2.B))
    $dc.DrawEllipse($bounce, $null, (New-Object Windows.Point 128, 198), 70, 24)
    # Icono con sombra suave
    $dc.PushTransform((New-Object Windows.Media.TranslateTransform 0, 5))
    Add-PremiumGlyph $dc $Glyph $c1 $c2 -Shadow
    $dc.Pop()
    Add-PremiumGlyph $dc $Glyph $c1 $c2
    # Reflejo de cristal
    $gl = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.Color]::FromArgb(185, 255, 255, 255)), ([Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 90.0
    $dc.DrawEllipse($gl, $null, (New-Object Windows.Point 128, 80), 70, 40)
    $dc.Pop(); $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb.Freeze(); $rtb
}

function ConvertTo-OrbSet {
    <# Convierte cualquier imagen en orb con 3 estados (normal / hover / pressed) a 256 px.
       - Tiras verticales de 3 o 4 estados (formato clasico de orbs de Windows 7): se separan.
       - Modo auto: si la imagen tiene fondo transparente se respeta su forma; si no, se mete en una esfera con aro y reflejo. #>
    param([string]$Source, [string]$Dir, [string]$Name, [ValidateSet('auto', 'sphere', 'plain')][string]$Mode = 'auto')
    $bi = New-Object Windows.Media.Imaging.BitmapImage
    $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.UriSource = [uri]$Source; $bi.EndInit(); $bi.Freeze()
    $src = New-Object Windows.Media.Imaging.FormatConvertedBitmap $bi, ([Windows.Media.PixelFormats]::Pbgra32), $null, 0
    $W = $src.PixelWidth; $H = $src.PixelHeight
    # Fotogramas: tira vertical de estados o imagen unica
    $frames = @()
    $n = if ($H -ge $W * 3.5 -and $H -le $W * 4.5) { 4 } elseif ($H -ge $W * 2.5 -and $H -le $W * 3.5) { 3 } else { 1 }
    for ($i = 0; $i -lt $n; $i++) { $fh = [int]($H / $n); $frames += , (New-Object Windows.Media.Imaging.CroppedBitmap $src, (New-Object Windows.Int32Rect 0, ($i * $fh), $W, $fh)) }
    # Fondo transparente? (se miran las 4 esquinas del primer fotograma)
    $f0 = $frames[0]; $fw = $f0.PixelWidth; $fh0 = $f0.PixelHeight; $px = New-Object byte[] 4; $transp = 0
    foreach ($c in @(@(0, 0), @(($fw - 1), 0), @(0, ($fh0 - 1)), @(($fw - 1), ($fh0 - 1)))) { $f0.CopyPixels((New-Object Windows.Int32Rect $c[0], $c[1], 1, 1), $px, 4, 0); if ($px[3] -lt 40) { $transp++ } }
    $style = if ($Mode -eq 'auto') { if ($transp -ge 3) { 'plain' } else { 'sphere' } } else { $Mode }
    function Draw-Frame($img, [double]$tint) {
        $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
        if ($style -eq 'sphere') {
            $halo = New-Object Windows.Media.RadialGradientBrush ([Windows.Media.Color]::FromArgb(110, 255, 255, 255)), ([Windows.Media.Color]::FromArgb(0, 255, 255, 255))
            $dc.DrawEllipse($halo, $null, (New-Object Windows.Point 128, 128), 127, 127)
            $clip = New-Object Windows.Media.EllipseGeometry (New-Object Windows.Point 128, 128), 104, 104
            $dc.PushClip($clip)
            $s = [Math]::Max(208 / $img.PixelWidth, 208 / $img.PixelHeight); $w2 = $img.PixelWidth * $s; $h2 = $img.PixelHeight * $s
            $dc.DrawImage($img, (New-Object Windows.Rect (128 - $w2 / 2), (128 - $h2 / 2), $w2, $h2))
            if ($tint -ne 0) { $dc.DrawRectangle((New-OrbBrush $(if ($tint -gt 0) { [Windows.Media.Color]::FromArgb([byte](255 * $tint), 255, 255, 255) } else { [Windows.Media.Color]::FromArgb([byte](-255 * $tint), 0, 0, 0) })), $null, (New-Object Windows.Rect 0, 0, 256, 256)) }
            $gl = New-Object Windows.Media.LinearGradientBrush ([Windows.Media.Color]::FromArgb(150, 255, 255, 255)), ([Windows.Media.Color]::FromArgb(0, 255, 255, 255)), 90.0
            $dc.DrawEllipse($gl, $null, (New-Object Windows.Point 128, 78), 72, 40)
            $dc.Pop()
            $dc.DrawEllipse($null, (New-Object Windows.Media.Pen (New-OrbBrush ([Windows.Media.Color]::FromArgb(200, 255, 255, 255))), 4), (New-Object Windows.Point 128, 128), 104, 104)
        } else {
            # Forma propia: se ajusta al cuadro con margen y se aclara/oscurece para los estados
            $s = [Math]::Min(236 / $img.PixelWidth, 236 / $img.PixelHeight); $w2 = $img.PixelWidth * $s; $h2 = $img.PixelHeight * $s
            $r = New-Object Windows.Rect (128 - $w2 / 2), (128 - $h2 / 2), $w2, $h2
            $dc.DrawImage($img, $r)
            if ($tint -ne 0) {
                $dc.PushOpacityMask((New-Object Windows.Media.ImageBrush $img -Property @{ Viewport = (New-Object Windows.Rect ($r.X / 256), ($r.Y / 256), ($r.Width / 256), ($r.Height / 256)); ViewportUnits = 'RelativeToBoundingBox'; Stretch = 'Fill' }))
                $dc.DrawRectangle((New-OrbBrush $(if ($tint -gt 0) { [Windows.Media.Color]::FromArgb([byte](255 * $tint), 255, 255, 255) } else { [Windows.Media.Color]::FromArgb([byte](-255 * $tint), 0, 0, 0) })), $null, (New-Object Windows.Rect 0, 0, 256, 256))
                $dc.Pop()
            }
        }
        $dc.Close()
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap 256, 256, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32); $rtb.Render($dv); $rtb
    }
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $out = [ordered]@{}
    $states = if ($n -ge 3) { @(@('normal', $frames[0], 0), @('hover', $frames[1], 0), @('pressed', $frames[2], 0)) } else { @(@('normal', $frames[0], 0), @('hover', $frames[0], 0.16), @('pressed', $frames[0], -0.22)) }
    foreach ($st in $states) {
        $file = Join-Path $Dir ("$Name" + $(if ($st[0] -ne 'normal') { "-$($st[0])" } else { '' }) + '.png')
        Save-OrbPng (Draw-Frame $st[1] $st[2]) $file
        $out[$st[0]] = $file
    }
    $out
}

function Save-PremiumOrbSet {
    <# Guarda normal, hover (mas claro) y pressed (mas oscuro) a 256 px. #>
    param([string]$Glyph, [string]$Color1, [string]$Color2, [string]$Dir, [string]$Name, [int]$Size = 256)
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
    $out = [ordered]@{}
    foreach ($v in @(@('normal', 0), @('hover', 0.18), @('pressed', -0.22))) {
        $file = Join-Path $Dir ("$Name" + $(if ($v[0] -ne 'normal') { "-$($v[0])" } else { '' }) + '.png')
        Save-OrbPng (New-PremiumOrb -Glyph $Glyph -Color1 $Color1 -Color2 $Color2 -Light $v[1] -Size $Size) $file
        $out[$v[0]] = $file
    }
    $out
}
