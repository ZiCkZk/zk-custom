# IconArt.ps1 - dibuja el icono de ZK-Custom (fusion: marco naranja + ZK + trazo de pincel con los colores de la paleta)
# New-ZKIconBitmap -Size 256 devuelve un RenderTargetBitmap. Por debajo de 48 px se simplifica (sin punta del pincel).
function New-ZKIconBitmap([int]$Size) {
    $inv = [Globalization.CultureInfo]::InvariantCulture
    function C($h) { [Windows.Media.ColorConverter]::ConvertFromString($h) }
    $s = [double]$Size; $r = $s * 0.22
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    # Marco degradado naranja-coral y fondo oscuro
    $frame = New-Object Windows.Media.LinearGradientBrush (C '#FFB347'), (C '#FF5E62'), 45.0
    $dc.DrawRoundedRectangle($frame, $null, (New-Object Windows.Rect 0, 0, $s, $s), $r, $r)
    $m = [Math]::Max(1.5, $s * 0.06)
    $bg = New-Object Windows.Media.LinearGradientBrush (C '#24283B'), (C '#16161E'), 90.0
    $dc.DrawRoundedRectangle($bg, $null, (New-Object Windows.Rect $m, $m, ($s - 2 * $m), ($s - 2 * $m)), ($r * 0.8), ($r * 0.8))
    # Trazo de pincel con los colores de la paleta (azul, morado, verde, naranja)
    $stops = New-Object Windows.Media.GradientStopCollection
    foreach ($st in @(@('#7AA2F7', 0.0), @('#BB9AF7', 0.35), @('#9ECE6A', 0.68), @('#FF9E3D', 1.0))) { $stops.Add((New-Object Windows.Media.GradientStop (C $st[0]), $st[1])) }
    $paint = New-Object Windows.Media.LinearGradientBrush $stops, 0.0
    $pen = New-Object Windows.Media.Pen $paint, ($s * 0.11); $pen.StartLineCap = 'Round'; $pen.EndLineCap = 'Round'
    $geo = [Windows.Media.Geometry]::Parse([string]::Format($inv, 'M {0},{1} C {2},{3} {4},{5} {6},{7}', ($s * 0.22), ($s * 0.78), ($s * 0.40), ($s * 0.64), ($s * 0.56), ($s * 0.88), ($s * 0.76), ($s * 0.72)))
    $dc.DrawGeometry($null, $pen, $geo)
    # Letras ZK
    $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily 'Segoe UI'), 'Normal', 'Black', 'Normal'
    $txt = New-Object Windows.Media.LinearGradientBrush (C '#FFC46B'), (C '#FF5E62'), 90.0
    $ft = New-Object Windows.Media.FormattedText ('ZK', $inv, 'LeftToRight', $tf, ($s * 0.44), $txt, 1.0)
    $dc.DrawText($ft, (New-Object Windows.Point (($s - $ft.Width) / 2), ($s * 0.40 - $ft.Height / 2)))
    # Punta del pincel al final del trazo (solo en tamanos grandes)
    if ($Size -ge 48) {
        $dc.PushClip((New-Object Windows.Media.RectangleGeometry (New-Object Windows.Rect $m, $m, ($s - 2 * $m), ($s - 2 * $m)), ($r * 0.8), ($r * 0.8)))
        $dc.PushTransform((New-Object Windows.Media.RotateTransform 40, ($s * 0.80), ($s * 0.70)))
        $dc.DrawRoundedRectangle((New-Object Windows.Media.SolidColorBrush (C '#FF9E3D')), $null, (New-Object Windows.Rect ($s * 0.755), ($s * 0.57), ($s * 0.09), ($s * 0.12)), ($s * 0.035), ($s * 0.035))
        $dc.DrawRectangle((New-Object Windows.Media.SolidColorBrush (C '#565F89')), $null, (New-Object Windows.Rect ($s * 0.75), ($s * 0.52), ($s * 0.10), ($s * 0.055)))
        $dc.DrawRoundedRectangle((New-Object Windows.Media.SolidColorBrush (C '#C0CAF5')), $null, (New-Object Windows.Rect ($s * 0.76), ($s * 0.30), ($s * 0.08), ($s * 0.23)), ($s * 0.035), ($s * 0.035))
        $dc.Pop(); $dc.Pop()
    }
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $Size, $Size, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb
}
