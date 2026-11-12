#Requires -Version 5.1
<#
.SYNOPSIS
    ZK-Custom: personalizador visual de Windows 11 con vista previa en vivo.
    Eliges temas completos o cada detalle, ves el resultado en un escritorio simulado y lo aplicas
    a tu PC de una vez. Todo queda en config.json para repetirlo en otro equipo con Install.cmd.
.PARAMETER SelfTest
    Construye la ventana y recorre todos los pasos sin mostrarla ni aplicar nada.
.PARAMETER Snapshot
    Con -SelfTest, guarda capturas PNG de varios pasos en esa carpeta.
#>
param([switch]$SelfTest, [string]$Snapshot)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# --- Solo Windows 11 ---
$Build = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild
if ($Build -lt 22000) {
    [Windows.MessageBox]::Show("ZK-Custom es solo para Windows 11.`nEste equipo tiene la compilación $Build (Windows 10 o anterior).", 'ZK-Custom', 'OK', 'Warning') | Out-Null
    exit 1
}

# --- Elevación: aplicar cambios toca el registro e instala Windhawk ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $SelfTest) {
    Start-Process powershell.exe -Verb RunAs -WindowStyle Hidden -ArgumentList @('-NoProfile', '-STA', '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Tarjeta de opción: clase .NET real para que WPF muestre imágenes y pinceles (un PSCustomObject los envolvería)
if (-not ('ZK.Card' -as [type])) {
    Add-Type -TypeDefinition @'
namespace ZK {
    public class Card : System.ComponentModel.INotifyPropertyChanged {
        public event System.ComponentModel.PropertyChangedEventHandler PropertyChanged;
        object _preview;
        public object Preview { get { return _preview; } set { _preview = value; if (PropertyChanged != null) PropertyChanged(this, new System.ComponentModel.PropertyChangedEventArgs("Preview")); } }
        public string Id { get; set; }
        public string Name { get; set; }
        public string Description { get; set; }
        public string Category { get; set; }
        public object PreviewLarge { get; set; }
        public object Swatches { get; set; }
        public string ImgStretch { get; set; }
        public string Placeholder { get; set; }
        public string Badge { get; set; }
        public string Reference { get; set; }
        public string RefVis { get; set; }
        public string GlassVis { get; set; }
        public double GlassOpacity { get; set; }
        public string TrailVis { get; set; }
        public object TrailBrush { get; set; }
        public string TrailDash { get; set; }
        public object Raw { get; set; }
    }
}
'@
}
Import-Module (Join-Path $Root 'modules\Core.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $Root 'modules\Windhawk.psm1') -Force -DisableNameChecking
. (Join-Path $Root 'modules\OrbArt.ps1')

# ======================================================================================
#  Datos
# ======================================================================================

function ConvertTo-Plain($o) {
    if ($null -eq $o) { return $null }
    if ($o -is [System.Management.Automation.PSCustomObject]) { $h = [ordered]@{}; foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Plain $p.Value }; return $h }
    if ($o -is [System.Collections.IDictionary]) { $h = [ordered]@{}; foreach ($k in @($o.Keys)) { $h[$k] = ConvertTo-Plain $o[$k] }; return $h }
    if ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) { return ,@($o | ForEach-Object { ConvertTo-Plain $_ }) }
    $o
}
function Read-Json($path) { ConvertTo-Plain (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json) }
function Write-Json($obj, $path) { [IO.File]::WriteAllText($path, (ConvertTo-Json $obj -Depth 12), (New-Object Text.UTF8Encoding($false))) }

$CatalogDir = Join-Path $Root 'catalog'
$CacheDir = Join-Path $Root 'cache'
$ThumbDir = Join-Path $CacheDir 'thumbs'
New-Item -ItemType Directory -Force -Path $ThumbDir | Out-Null
if (-not (Test-Path (Join-Path $CatalogDir 'generated\wallpapers.json'))) {
    Write-Host 'Generando catálogos por primera vez (necesita internet)...' -ForegroundColor Cyan
    & (Join-Path $CatalogDir 'Build-Catalog.ps1')
}

# Region = dónde se dibuja la captura del estilo en la vista previa
$Steps = @(
    @{ Key = 'themes';        Title = 'Temas listos';          Group = 'Inicio';     Kind = 'themes';  Help = 'Combinaciones completas hechas a mano. Elige una y luego ajusta lo que quieras en las demás secciones.'; Catalog = @('static\themes.json') }
    @{ Key = 'palette';       Title = 'Paleta de colores';     Group = 'Colores';    Help = 'Color de acento, bordes y colores de la terminal. Las paletas "(claro)" activan el modo claro.'; Catalog = @('static\palettes.json'); Modules = @('Theme', 'Terminal'); Restart = $true }
    @{ Key = 'daynight';      Title = 'Día y noche';           Group = 'Colores';    Help = 'Cambia tu paleta y el modo claro/oscuro solo según la hora. En Ajustes eliges a qué hora empieza el día y la noche.'; Catalog = @('static\daynight.json'); Modules = @('DayNight'); Opts = 'daynight' }
    @{ Key = 'wallpaper';     Title = 'Fondo de pantalla';     Group = 'Escritorio'; Help = 'Galería por categorías o una imagen de tu equipo (en Ajustes).'; Catalog = @('generated\wallpapers.json'); Modules = @('Wallpaper'); Opts = 'wallpaper' }
    @{ Key = 'animated';      Title = 'Fondo animado';         Group = 'Escritorio'; Help = 'Fondos en movimiento con Lively Wallpaper (gratuito, se instala solo). Los dibujados usan los colores de tu paleta; también puedes usar un vídeo o GIF tuyo.'; Catalog = @('static\animated.json'); Modules = @('Animated'); Opts = 'animated' }
    @{ Key = 'taskbar';       Title = 'Barra de tareas';       Group = 'Escritorio'; Help = 'Estilo de la barra. En Ajustes puedes teñirla con tu paleta, cambiar transparencia y redondeo.'; Catalog = @('generated\taskbar.json'); Modules = @('Taskbar', 'Windhawk'); Restart = $true; Opts = 'styler'; Region = 'taskbar'; Hint = 'windows 11 taskbar styler theme' }
    @{ Key = 'tbsize';        Title = 'Tamaño de la barra';    Group = 'Escritorio'; Help = 'Altura de la barra y tamaño de sus iconos.'; Catalog = @('static\taskbarsize.json'); Modules = @('Windhawk'); Opts = 'tbsize' }
    @{ Key = 'startbtn';      Title = 'Botón Inicio';          Group = 'Escritorio'; Help = 'Orbs (esferas, neón, planetas...), orbs con tu paleta, tu propia imagen o solo cambiar el color del logo.'; Catalog = @('static\startbutton.json', 'static\orbs.json'); Modules = @('Windhawk'); Opts = 'startbtn' }
    @{ Key = 'clock';         Title = 'Reloj de la barra';     Group = 'Escritorio'; Help = 'Qué muestra el reloj de la barra de tareas.'; Catalog = @('static\clock.json'); Modules = @('Windhawk') }
    @{ Key = 'startmenu';     Title = 'Menú Inicio';           Group = 'Escritorio'; Help = 'Aspecto del menú Inicio.'; Catalog = @('generated\startmenu.json'); Modules = @('Windhawk'); Opts = 'styler'; Region = 'start'; Hint = 'windows 11 start menu styler theme' }
    @{ Key = 'notifications'; Title = 'Notificaciones';        Group = 'Escritorio'; Help = 'Centro de notificaciones, calendario y ajustes rápidos.'; Catalog = @('generated\notifications.json'); Modules = @('Windhawk'); Opts = 'styler'; Region = 'notif'; Hint = 'windows 11 notification center styler theme' }
    @{ Key = 'explorer';      Title = 'Explorador';            Group = 'Ventanas';   Help = 'Estilo de las ventanas del Explorador de archivos.'; Catalog = @('generated\explorer.json'); Modules = @('Windhawk'); Restart = $true; Opts = 'styler'; Region = 'window'; Hint = 'windows 11 file explorer styler theme' }
    @{ Key = 'settingsapp';   Title = 'App Configuración';     Group = 'Ventanas';   Help = 'Estilo de la aplicación Configuración de Windows.'; Catalog = @('generated\settings.json'); Modules = @('Windhawk'); Opts = 'styler'; Region = 'window'; Hint = 'windows 11 settings styler theme' }
    @{ Key = 'effects';       Title = 'Efectos de ventana';    Group = 'Ventanas';   Help = 'Transparencia y desenfoque en las ventanas clásicas. La animación muestra cómo se ve lo de detrás.'; Catalog = @('static\effects.json'); Modules = @('Windhawk') }
    @{ Key = 'corners';       Title = 'Esquinas';              Group = 'Ventanas';   Help = 'Cuánto se redondean las esquinas de ventanas y menús.'; Catalog = @('static\corners.json'); Modules = @('Windhawk'); Opts = 'corners' }
    @{ Key = 'borders';       Title = 'Bordes de ventana';     Group = 'Ventanas';   Help = 'Línea alrededor de las ventanas: normal, de color o invisible.'; Catalog = @('static\borders.json'); Modules = @('Windhawk') }
    @{ Key = 'menus';         Title = 'Menús contextuales';    Group = 'Ventanas';   Help = 'Fondo de los menús del clic derecho.'; Catalog = @('static\menus.json'); Modules = @('Windhawk'); Opts = 'menus'; Region = 'menu' }
    @{ Key = 'icons';         Title = 'Iconos';                Group = 'Iconos y ratón'; Help = 'Pack de iconos de carpetas, discos y programas. La caché de iconos se limpia sola, sin preguntar.'; Catalog = @('generated\icons.json'); Modules = @('Windhawk'); Restart = $true; Region = 'icons'; Hint = 'icon theme windows 11 niivu' }
    @{ Key = 'cursors';       Title = 'Cursores';              Group = 'Iconos y ratón'; Help = 'Packs de cursores o cursores dibujados con brillo.'; Catalog = @('static\cursors.json', 'generated\cursorsmod.json'); Modules = @('Cursors', 'Windhawk'); Region = 'cursor'; Hint = 'cursor pack windows' }
    @{ Key = 'folders';       Title = 'Carpetas de colores';   Group = 'Iconos y ratón'; Kind = 'folders'; Help = 'Dale un color a carpetas concretas (Documentos, Descargas, tus proyectos...). Se guarda en la propia carpeta y se puede quitar cuando quieras.'; Modules = @('Folders') }
    @{ Key = 'trail';         Title = 'Estela del ratón';      Group = 'Iconos y ratón'; Help = 'Un rastro de color que sigue al puntero. En Ajustes: largo, grosor y colores.'; Catalog = @('static\trail.json'); Modules = @('Windhawk'); Opts = 'trail' }
    @{ Key = 'selection';     Title = 'Rectángulo de selección'; Group = 'Iconos y ratón'; Help = 'El recuadro que aparece al arrastrar el ratón para seleccionar.'; Catalog = @('static\selection.json'); Modules = @('Windhawk'); Opts = 'selection' }
    @{ Key = 'lockclock';     Title = 'Reloj de bloqueo';      Group = 'Pantalla de bloqueo'; Help = 'Estilo del reloj de la pantalla de bloqueo.'; Catalog = @('static\lockclock.json'); Modules = @('Windhawk'); Opts = 'lockclock'; Region = 'lock' }
    @{ Key = 'fonts';         Title = 'Fuente de la terminal'; Group = 'Terminal';   Help = 'Cada muestra está dibujada con la fuente real. Se instala solo para tu usuario.'; Catalog = @('static\fonts.json'); Modules = @('Fonts', 'Terminal'); Opts = 'terminal'; Region = 'terminal' }
    @{ Key = 'tweaks';        Title = 'Detalles visuales';     Group = 'Detalles';   Kind = 'tweaks'; Help = 'Ajustes nativos de Windows que cambian lo que ves. Desmarcar algo aplicado lo deja como viene en Windows.'; Modules = @('Tweaks'); Restart = $true }
    @{ Key = 'summary';       Title = 'Resumen';               Group = '';           Kind = 'summary'; Help = 'Tus elecciones. Guárdalas en config.json para repetirlas en otro equipo con Install.cmd.' }
)
$StepByKey = @{}; foreach ($s in $Steps) { $StepByKey[$s.Key] = $s }

$State = @{
    Config = Read-Json (Join-Path $Root 'config.json')
    Index = 0; Items = @(); AllItems = @{}; Proc = $null; LogPath = $null; LastBackup = $null
    RestorePointDone = $false; Loading = $false; Dirty = $false; Hover = $null; Category = 'Tokyo Night'
    Advanced = $false; Pending = New-Object System.Collections.Generic.HashSet[string]; PendingRestart = $false
}
foreach ($k in 'wizard', 'windhawk', 'modules', 'taskbar', 'terminal', 'wallpaper', 'theme', 'tweaks', 'meta') { if (-not $State.Config[$k]) { $State.Config[$k] = [ordered]@{} } }
foreach ($k in 'selections', 'options') { if (-not $State.Config.wizard[$k]) { $State.Config.wizard[$k] = [ordered]@{} } }
if ($null -eq $State.Config.windhawk.mods) { $State.Config.windhawk.mods = @() }
$State.Config.windhawk.Remove('channel')

# ======================================================================================
#  Imágenes: caché en disco + descarga en segundo plano
# ======================================================================================

$Sha = [Security.Cryptography.SHA1]::Create()
function Get-ThumbPath([string]$url) {
    $hash = ([BitConverter]::ToString($Sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($url))) -replace '-', '').Substring(0, 20)
    Join-Path $ThumbDir "$hash.img"
}
$DlQueue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$DlPriority = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
$DlQueued = New-Object 'System.Collections.Generic.HashSet[string]'
function Add-Download([string]$url, [switch]$Priority) {
    if (-not $url -or $url -notmatch '^https?://') { return }
    if (-not $DlQueued.Add($url)) { return }
    $p = Get-ThumbPath $url
    if (Test-Path $p) { return }
    if ($Priority) { $DlPriority.Enqueue("$url`t$p") } else { $DlQueue.Enqueue("$url`t$p") }
}
function Resolve-Img([string]$src) {
    # Ruta local si ya está en caché (o es un archivo del proyecto); si no, la URL y se encola la descarga
    if (-not $src) { return $null }
    if ($src -notmatch '^https?://') { $p = Join-Path $CatalogDir $src; if (Test-Path $p) { return $p } else { return $null } }
    $p = Get-ThumbPath $src
    if (Test-Path $p) { return $p }
    Add-Download $src
    $src
}

$Downloader = $null
function Start-Downloader {
    $pool = [runspacefactory]::CreateRunspacePool(1, 6); $pool.Open()
    $code = {
        param($q, $pq)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $wc = New-Object Net.WebClient; $wc.Headers['User-Agent'] = 'zk-custom'
        $item = $null
        while ($true) {
            if ($pq.TryDequeue([ref]$item) -or $q.TryDequeue([ref]$item)) {
                $u, $p = $item -split "`t"
                if (-not (Test-Path $p)) {
                    try { $wc.DownloadFile($u, "$p.part"); Move-Item "$p.part" $p -Force } catch { Remove-Item "$p.part" -Force -ErrorAction SilentlyContinue }
                }
            } else { Start-Sleep -Milliseconds 250 }
        }
    }
    $ps = foreach ($i in 1..6) { $x = [powershell]::Create(); $x.RunspacePool = $pool; [void]$x.AddScript($code).AddArgument($DlQueue).AddArgument($DlPriority); [void]$x.BeginInvoke(); $x }
    @{ Pool = $pool; Shells = $ps }
}

$BmpCache = @{}
function Get-Bitmap($src, [int]$decode = 0) {
    # Devuelve un BitmapSource listo para dibujar, o $null si aún se está descargando
    if (-not $src) { return $null }
    if ($src -is [Windows.Media.ImageSource]) { return $src }
    $key = "$src|$decode"
    if ($BmpCache.ContainsKey($key)) { $b = $BmpCache[$key]; if ($b.IsDownloading) { return $null } else { return $b } }
    $local = if ($src -match '^https?://') { Get-ThumbPath $src } elseif (Test-Path $src) { $src } else { Join-Path $CatalogDir $src }
    $b = New-Object Windows.Media.Imaging.BitmapImage
    try {
        $b.BeginInit(); $b.CacheOption = 'OnLoad'
        if ($decode) { $b.DecodePixelWidth = $decode }
        if (Test-Path $local) { $b.UriSource = [uri]$local } else {
            $b.UriSource = [uri]$src
            $b.Add_DownloadCompleted({ $RenderTimer.Stop(); $RenderTimer.Start() })
            $b.Add_DownloadFailed({ param($s) foreach ($k in @($BmpCache.Keys)) { if ([object]::ReferenceEquals($BmpCache[$k], $s)) { $BmpCache.Remove($k) } } })
            Add-Download $src -Priority
        }
        $b.EndInit()
    } catch { return $null }
    $BmpCache[$key] = $b
    if ($b.IsDownloading) { return $null }
    $b
}

# ======================================================================================
#  Colores y dibujo
# ======================================================================================

$BrushCache = @{}
function Get-Col([string]$hex) { [Windows.Media.ColorConverter]::ConvertFromString($hex) }
function B([string]$hex, [double]$a = 1.0) {
    $k = "$hex|$a"
    if (-not $BrushCache.ContainsKey($k)) {
        $c = Get-Col $hex; if ($a -lt 1) { $c.A = [byte]([Math]::Round($c.A * $a)) }
        $br = New-Object Windows.Media.SolidColorBrush $c; $br.Freeze(); $BrushCache[$k] = $br
    }
    $BrushCache[$k]
}
function Rc([double]$x, [double]$y, [double]$w, [double]$h) { New-Object Windows.Rect $x, $y, $w, $h }
function Pt([double]$x, [double]$y) { New-Object Windows.Point $x, $y }
function Pn([string]$hex, [double]$t, [double]$a = 1.0) { $p = New-Object Windows.Media.Pen (B $hex $a), $t; $p.Freeze(); $p }
function Txt($dc, [string]$s, [double]$x, [double]$y, [double]$size, [string]$hex, [string]$font = 'Segoe UI Variable Text, Segoe UI', [string]$weight = 'Normal', [string]$align = 'Left') {
    $tf = New-Object Windows.Media.Typeface (New-Object Windows.Media.FontFamily $font), 'Normal', $weight, 'Normal'
    $ft = New-Object Windows.Media.FormattedText ($s, [Globalization.CultureInfo]::CurrentCulture, 'LeftToRight', $tf, $size, (B $hex), 1.0)
    if ($align -eq 'Right') { $x -= $ft.Width } elseif ($align -eq 'Center') { $x -= $ft.Width / 2 }
    $dc.DrawText($ft, (Pt $x $y))
}
function Draw-Image($dc, $bmp, $rect, [string]$mode = 'Uniform') {
    # Dibuja ajustando la imagen al rectángulo (Uniform = cabe entera, Fill = cubre recortando)
    if (-not $bmp) { return $null }
    $iw = $bmp.PixelWidth; $ih = $bmp.PixelHeight; if (-not $iw -or -not $ih) { return $null }
    $s = if ($mode -eq 'Fill') { [Math]::Max($rect.Width / $iw, $rect.Height / $ih) } else { [Math]::Min($rect.Width / $iw, $rect.Height / $ih) }
    $w = $iw * $s; $h = $ih * $s
    $r = Rc ($rect.X + ($rect.Width - $w) / 2) ($rect.Y + ($rect.Height - $h) / 2) $w $h
    if ($mode -eq 'Fill') { $dc.PushClip((New-Object Windows.Media.RectangleGeometry $rect)) }
    $dc.DrawImage($bmp, $r)
    if ($mode -eq 'Fill') { $dc.Pop() }
    $r
}
function Get-Shade([string]$hex, [double]$amt) {
    $c = Get-Col $hex
    $f = { param($v) [byte][Math]::Max(0, [Math]::Min(255, $(if ($amt -ge 0) { $v + (255 - $v) * $amt } else { $v * (1 + $amt) }))) }
    '#{0:X2}{1:X2}{2:X2}' -f (& $f $c.R), (& $f $c.G), (& $f $c.B)
}

$BlurCache = @{}
function Get-Blurred($bmp) {
    if (-not $bmp) { return $null }
    $k = $bmp.GetHashCode()
    if ($BlurCache.ContainsKey($k)) { return $BlurCache[$k] }
    $img = New-Object Windows.Controls.Image -Property @{ Source = $bmp; Stretch = 'UniformToFill'; Width = 480; Height = 270 }
    $img.Effect = New-Object Windows.Media.Effects.BlurEffect -Property @{ Radius = 18 }
    $img.Measure((New-Object Windows.Size 480, 270)); $img.Arrange((Rc 0 0 480 270))
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap 480, 270, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($img); $rtb.Freeze()
    $BlurCache[$k] = $rtb
    $rtb
}

# ======================================================================================
#  Elementos de cada paso
# ======================================================================================

function Get-Palette($sel) {
    $p = if ($sel -and $sel.palette) { $sel.palette.Raw.apply.palette } else { $State.Config.palette }
    if (-not $p -or -not $p.base) { $p = @{ base = '#1A1B26'; surface = '#24283B'; primary = '#7AA2F7'; secondary = '#BB9AF7'; highlight = '#7DCFFF'; text = '#C0CAF5'; muted = '#565F89' } }
    $p
}
function Resolve-ColorToken($v, $p) {
    switch ($v) { 'primary' { $p.primary } 'secondary' { $p.secondary } 'highlight' { $p.highlight } 'accent' { $p.primary } default { $v } }
}

function New-Brush([string[]]$colors) {
    $b = New-Object Windows.Media.LinearGradientBrush
    $b.StartPoint = (Pt 1 0.5); $b.EndPoint = (Pt 0 0.5)   # la cabeza (primer color) va junto al puntero
    for ($i = 0; $i -lt $colors.Count; $i++) {
        $b.GradientStops.Add((New-Object Windows.Media.GradientStop (Get-Col $colors[$i]), ($i / [Math]::Max(1, $colors.Count - 1))))
    }
    $b
}

function Render-Mock($m, $p) {
    # Tarjetas sin captura: se dibuja una vista simulada fiel a la opción (400x225)
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    $W = 400; $H = 225
    $bg = New-Object Windows.Media.LinearGradientBrush ((Get-Col (Get-Shade $p.primary -0.55)), (Get-Col (Get-Shade $p.secondary -0.35)), 35.0)
    $dc.DrawRectangle($bg, $null, (Rc 0 0 $W $H))
    switch ($m.kind) {
        'tbsize' {
            $h = $m.height * 1.2; $ic = $m.icon * 1.2
            $dc.DrawRectangle((B $p.base 0.92), $null, (Rc 0 ($H - $h) $W $h))
            $n = 6; $gap = $ic * 0.55; $tot = $n * $ic + ($n - 1) * $gap; $x = ($W - $tot) / 2
            $cols = @($p.primary, $p.secondary, $p.highlight, $p.text, $p.primary, $p.secondary)
            for ($i = 0; $i -lt $n; $i++) { $dc.DrawRoundedRectangle((B $cols[$i]), $null, (Rc ($x + $i * ($ic + $gap)) ($H - $h / 2 - $ic / 2) $ic $ic), $ic * 0.22, $ic * 0.22) }
            Txt $dc "$($m.height) px" 14 12 16 '#FFFFFF' -weight 'SemiBold'
        }
        'startbtn' {
            $c = if ($m.color -eq 'accent') { $p.primary } else { $m.color }
            $dc.DrawRoundedRectangle((B $p.base 0.9), $null, (Rc 120 72 160 80), 14, 14)
            $s = 22; $g = 4; $x0 = 200 - $s - $g / 2; $y0 = 112 - $s - $g / 2
            foreach ($q in @(@(0, 0), @(1, 0), @(0, 1), @(1, 1))) { $dc.DrawRoundedRectangle((B $c), $null, (Rc ($x0 + $q[0] * ($s + $g)) ($y0 + $q[1] * ($s + $g)) $s $s), 3, 3) }
        }
        'menu' {
            $op = [double]$m.opacity; $fill = if ($m.palette) { $p.surface } else { '#2B2B2B' }
            $dc.DrawEllipse((B $p.highlight), $null, (Pt 150 90), 50, 50); $dc.DrawEllipse((B '#F7768E'), $null, (Pt 260 150), 60, 60)
            $r = Rc 110 30 190 165
            if ($m.blur) { $dc.PushClip((New-Object Windows.Media.RectangleGeometry $r, 10, 10)); $dc.DrawRectangle((B (Get-Shade $p.primary -0.3) 0.85), $null, $r); $dc.Pop() }
            $dc.DrawRoundedRectangle((B $fill $op), (Pn '#FFFFFF' 1 0.15), $r, 10, 10)
            $labels = 'Abrir', 'Copiar', 'Cambiar nombre', 'Compartir', 'Propiedades'
            for ($i = 0; $i -lt $labels.Count; $i++) {
                if ($i -eq 1) { $dc.DrawRoundedRectangle((B $p.primary 0.35), $null, (Rc 116 (40 + $i * 30) 178 26), 6, 6) }
                Txt $dc $labels[$i] 130 (44 + $i * 30) 14 '#FFFFFF'
            }
        }
        'selection' {
            $c = Resolve-ColorToken $m.color $p; $bw = if ($m.border) { [double]$m.border } else { 1.0 }
            for ($i = 0; $i -lt 3; $i++) { $dc.DrawRoundedRectangle((B '#FFFFFF' 0.85), $null, (Rc (90 + $i * 80) 70 50 50), 6, 6) }
            $dc.DrawRoundedRectangle((B $c ([double]$m.opacity)), (Pn $c $bw), (Rc 70 50 210 120), $m.radius, $m.radius)
            $arrow = [Windows.Media.Geometry]::Parse('M 280,170 L 280,192 L 286,186 L 291,196 L 294,194 L 289,184 L 297,184 Z')
            $dc.DrawGeometry((B '#FFFFFF'), (Pn '#000000' 1), $arrow)
        }
        'border' {
            $pen = switch ($m.color) { 'none' { $null } 'primary' { Pn $p.primary 2.5 } default { Pn $m.color 1 } }
            $dc.DrawRoundedRectangle((B $p.base), $pen, (Rc 70 35 260 155), 8, 8)
            $dc.DrawRoundedRectangle((B $p.surface), $null, (Rc 70 35 260 28), 8, 8)
        }
        'corner' {
            $r = [double]$m.radius * 1.3
            $dc.DrawRoundedRectangle((B $p.base), (Pn $p.primary 1.5), (Rc 70 35 260 155), $r, $r)
            $dc.PushClip((New-Object Windows.Media.RectangleGeometry (Rc 70 35 260 155), $r, $r)); $dc.DrawRectangle((B $p.surface), $null, (Rc 70 35 260 30)); $dc.Pop()
            Txt $dc "$($m.radius) px" 200 100 22 $p.text -weight 'SemiBold' -align 'Center'
        }
        'clock' {
            $dc.DrawRectangle((B $p.base 0.92), $null, (Rc 0 ($H - 70) $W 70))
            $lines = @("$($m.text)" -split "`n")
            $y = $H - 35 - $lines.Count * 11
            foreach ($l in $lines) { Txt $dc $l ($W - 20) $y 17 '#FFFFFF' -align 'Right'; $y += 22 }
        }
        'anim' {
            # Fotograma representativo de cada fondo animado, con los colores de la paleta
            $dc.DrawRectangle((B $p.base), $null, (Rc 0 0 $W $H))
            switch ($m.style) {
                'none' { $dc.DrawRectangle($bg, $null, (Rc 0 0 $W $H)); Txt $dc 'Fondo normal' 200 98 20 '#FFFFFF' -align 'Center' }
                'aurora' { foreach ($c in @(@($p.primary, 120, 80, 150), @($p.secondary, 270, 120, 170), @($p.highlight, 190, 170, 130))) {
                        $c0 = Get-Col $c[0]; $c1 = Get-Col $c[0]; $c1.A = 0
                        $rg = New-Object Windows.Media.RadialGradientBrush $c0, $c1; $rg.Opacity = 0.7
                        $dc.DrawEllipse($rg, $null, (Pt $c[1] $c[2]), $c[3], $c[3]) } }
                'constellation' { $r = New-Object Random 7; $pts = @(1..28 | ForEach-Object { Pt ($r.Next(10, 390)) ($r.Next(10, 215)) })
                    foreach ($a1 in $pts) { foreach ($b1 in $pts) { $d = ($a1 - $b1).Length; if ($d -lt 70 -and $d -gt 0) { $dc.DrawLine((Pn $p.primary 1 (0.6 * (1 - $d / 70))), $a1, $b1) } } }
                    foreach ($q in $pts) { $dc.DrawEllipse((B $p.highlight), $null, $q, 2.5, 2.5) } }
                'coderain' { $r = New-Object Random 3; $ch = '0123456789ABCDEF<>{}=+*'
                    for ($cx = 6; $cx -lt 400; $cx += 16) { $len = $r.Next(3, 12); $y0 = $r.Next(-60, 120); for ($k = 0; $k -lt $len; $k++) { Txt $dc ([string]$ch[$r.Next($ch.Length)]) $cx ($y0 + $k * 16) 13 $(if ($k -eq $len - 1) { $p.text } else { $p.primary }) -font 'Consolas' } } }
                'synthgrid' { $sky = New-Object Windows.Media.LinearGradientBrush ((Get-Col $p.base)), ((Get-Col $p.secondary)), 90.0; $dc.DrawRectangle($sky, $null, (Rc 0 0 $W 130))
                    $sun = New-Object Windows.Media.LinearGradientBrush ((Get-Col $p.highlight)), ((Get-Col $p.primary)), 90.0; $dc.DrawEllipse($sun, $null, (Pt 200 112), 52, 52)
                    foreach ($i in 0..4) { $dc.DrawRectangle((B $p.base), $null, (Rc 140 (110 + $i * 9) 120 (2 + $i))) }
                    $dc.DrawRectangle((B $p.base), $null, (Rc 0 130 $W 95))
                    foreach ($i in -10..10) { $dc.DrawLine((Pn $p.primary 1.2), (Pt (200 + $i * 8) 130), (Pt (200 + $i * 80) 225)) }
                    foreach ($i in 1..7) { $yy = 130 + [Math]::Pow($i / 7, 2) * 95; $dc.DrawLine((Pn $p.primary 1.2), (Pt 0 $yy), (Pt $W $yy)) } }
                'waves' { $cols = @($p.primary, $p.secondary, $p.highlight, $p.surface)
                    for ($i = 0; $i -lt 4; $i++) { $g = New-Object Windows.Media.StreamGeometry; $cx2 = $g.Open(); $cx2.BeginFigure((Pt 0 $H), $true, $true)
                        for ($xx = 0; $xx -le $W; $xx += 8) { $cx2.LineTo((Pt $xx ($H * (0.5 + $i * 0.11) + [Math]::Sin($xx * 0.03 + $i) * 12)), $true, $false) }
                        $cx2.LineTo((Pt $W $H), $true, $false); $cx2.Close(); $dc.DrawGeometry((B $cols[$i] 0.5), $null, $g) } }
                'starfield' { $r = New-Object Random 5; foreach ($i in 1..120) { $ang = $r.NextDouble() * 6.28; $dist = $r.NextDouble() * 200; $sz = 0.5 + $dist / 70
                        $dc.DrawEllipse((B $(if ($dist -gt 140) { $p.highlight } else { $p.text })), $null, (Pt (200 + [Math]::Cos($ang) * $dist) (112 + [Math]::Sin($ang) * $dist * 0.6)), $sz, $sz) } }
                'video' { $dc.DrawRectangle($bg, $null, (Rc 0 0 $W $H)); $dc.DrawGeometry((B '#FFFFFF' 0.9), $null, [Windows.Media.Geometry]::Parse('M 180,80 L 230,112 L 180,144 Z')); Txt $dc 'Tu vídeo o GIF' 200 160 15 '#FFFFFF' -align 'Center' }
            }
        }
        'daynight' {
            $pd = $null; $pn = $null
            foreach ($pp in (Get-StepItems $StepByKey.palette)) { if ($pp.Id -eq $m.day) { $pd = $pp.Raw.apply.palette }; if ($pp.Id -eq $m.night) { $pn = $pp.Raw.apply.palette } }
            if ($m.night -eq 'current') { $pn = $p }
            if (-not $pd -or -not $pn) { $dc.DrawRectangle((B $p.surface), $null, (Rc 0 0 $W $H)); Txt $dc 'Siempre igual' 200 98 20 $p.text -align 'Center' }
            else {
                $dc.DrawRectangle((B $pd.base), $null, (Rc 0 0 200 $H)); $dc.DrawRectangle((B $pn.base), $null, (Rc 200 0 200 $H))
                $dc.DrawEllipse((B '#FFC93C'), $null, (Pt 100 70), 26, 26)
                $dc.DrawEllipse((B '#F5F3CE'), $null, (Pt 300 70), 24, 24); $dc.DrawEllipse((B $pn.base), $null, (Pt 312 62), 22, 22)
                foreach ($side in @(@(0, $pd), @(200, $pn))) { $i = 0
                    foreach ($c in @($side[1].primary, $side[1].secondary, $side[1].highlight, $side[1].text)) { $dc.DrawRoundedRectangle((B $c), (Pn '#000000' 1 0.15), (Rc ($side[0] + 30 + $i * 36) 130 28 60), 5, 5); $i++ } }
                Txt $dc 'Día' 100 200 13 $pd.text -align 'Center'; Txt $dc 'Noche' 300 200 13 $pn.text -align 'Center'
            }
        }
        'lockclock' {
            $dc.DrawRectangle((B '#000000' 0.35), $null, (Rc 0 0 $W $H))
            if ($m.style -eq 'aura') {
                $dc.DrawEllipse((B $p.primary 0.25), $null, (Pt 200 105), 110, 70)
                Txt $dc '21:45' 200 62 64 '#FFFFFF' -font 'Segoe UI Variable Display, Segoe UI' -weight 'Light' -align 'Center'
            } else { Txt $dc '21:45' 200 60 64 '#FFFFFF' -align 'Center' }
            Txt $dc 'miércoles, 12 de noviembre' 200 150 15 '#FFFFFF' -align 'Center'
        }
    }
    $dc.Close()
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap $W, $H, 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb.Freeze(); $rtb
}

function Get-TrailDash($len) {
    # Patrón de trazo para la animación: la estela siempre termina en el puntero (cabeza en 0)
    $lu = [Math]::Max(3, [Math]::Min(38, (20 + [double]$len / 8) / 5))
    "0 $([Math]::Round(40 - $lu, 2)) $([Math]::Round($lu, 2)) 400"
}

function Get-StepItems($step) {
    if ($State.AllItems.ContainsKey($step.Key)) { return $State.AllItems[$step.Key] }
    $p = Get-Palette $null
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $step.Catalog) {
        $path = Join-Path $CatalogDir $rel
        if (-not (Test-Path $path)) { continue }
        $data = Read-Json $path   # PS 5.1 entrega la lista como un único objeto: se recorre aquí
        foreach ($it in $data) { $list.Add((New-CardItem $step $it $p)) }
        # «Mis orbs» va justo después de las opciones de color del logo
        if ($step.Key -eq 'startbtn' -and $rel -like '*startbutton.json') { foreach ($lo in (Get-LibraryOrbItems)) { $list.Add((New-CardItem $step $lo $p)) } }
    }
    $State.AllItems[$step.Key] = $list
    $list
}

function New-CardItem($step, $it, $p) {
    $sw = $null; $m = $it.mock; $prev = Resolve-Img $it.preview
    if ($it.apply.type -eq 'orb') {
        if ($it.apply.palette) { $prev = New-OrbImage -Style $it.apply.style -Color1 $p.primary -Color2 $p.highlight }
        elseif ($it.apply.custom) { $cf = @($State.Config.wizard.options.startbtn.customFiles); if ($cf.Count -and (Test-Path (Join-Path $Root $cf[0]))) { $prev = Join-Path $Root $cf[0] } }
    }
    if ($it.apply.type -eq 'palette') { $pl = $it.apply.palette; $sw = @($pl.base, $pl.surface, $pl.primary, $pl.secondary, $pl.highlight, $pl.text) }
    if (-not $prev -and $m -and $m.kind -notin 'glass', 'trail') { $prev = Render-Mock $m $p }
    $trailBrush = $null; $dash = '0 1 0 400'
    if ($m.kind -eq 'trail') {
        $o = Get-Opts $step
        $cols = @($m.colors); if ($o.usePalette -and $cols.Count) { $cols = @($p.primary, $p.secondary) }
        if ($cols.Count) { $trailBrush = New-Brush $cols; $dash = Get-TrailDash $o.length }
    }
    $ref = $it.reference
    if (-not $ref -and $step.Hint -and $it.id -ne 'none') { $ref = 'https://www.google.com/search?tbm=isch&q=' + [uri]::EscapeDataString("$($it.name) $($step.Hint)") }
    $hasVisual = $prev -or $sw -or $m
    New-Object ZK.Card -Property @{
        Id = $it.id; Name = $it.name; Description = $it.description; Category = $it.category
        Preview = $prev; PreviewLarge = $(if ($it.previewLarge) { $it.previewLarge } else { $it.preview })
        Swatches = $sw
        ImgStretch = $(if ($step.Key -in 'wallpaper', 'themes', 'fonts' -or ($m -and -not $it.preview)) { 'UniformToFill' } else { 'Uniform' })
        Placeholder = $(if (-not $hasVisual -and $step.Kind -ne 'themes') { 'Sin captura' } else { '' })
        Badge = $(if ($it.previewApprox) { 'Vista aproximada' } elseif ($it.apply.mode -eq 'light') { 'Modo claro' } elseif ($it.category) { $it.category } else { '' })
        Reference = $ref; RefVis = $(if ($ref) { 'Visible' } else { 'Collapsed' })
        GlassVis = $(if ($m.kind -eq 'glass') { 'Visible' } else { 'Collapsed' }); GlassOpacity = $(if ($m.kind -eq 'glass') { [double]$m.opacity } else { 1.0 })
        TrailVis = $(if ($m.kind -eq 'trail' -and $trailBrush) { 'Visible' } else { 'Collapsed' }); TrailBrush = $trailBrush; TrailDash = $dash
        Raw = $it
    }
}

function Find-Item([string]$key, $id) {
    if ($null -eq $id -or -not $StepByKey.ContainsKey($key)) { return $null }
    if ($key -eq 'wallpaper' -and $id -eq 'local') { if (-not $State.LocalWall) { $State.LocalWall = Get-LocalWallItem }; return $State.LocalWall }
    Get-StepItems $StepByKey[$key] | Where-Object { $_.Id -eq $id } | Select-Object -First 1
}

# ======================================================================================
#  Opciones (modo básico / avanzado)
# ======================================================================================

$OptSpecs = @{
    styler = @(
        @{ K = 'usePalette'; L = 'Usar los colores de mi paleta'; T = 'toggle'; D = $false }
        @{ K = 'accent';     L = 'Color de acento';             T = 'color';  D = '' }
        @{ K = 'transp';     L = 'Transparencia';               T = 'slider'; D = 25; Min = 0; Max = 90; U = '%' }
        @{ K = 'radius';     L = 'Redondeo (-1 = el del tema)';  T = 'slider'; D = -1; Min = -1; Max = 24; U = ' px' }
        @{ K = 'bg';         L = 'Color de fondo';              T = 'color';  D = ''; Adv = $true }
        @{ K = 'border';     L = 'Color del borde';             T = 'color';  D = ''; Adv = $true }
        @{ K = 'text';       L = 'Color del texto e iconos';    T = 'color';  D = ''; Adv = $true }
    )
    taskbarNative = @(
        @{ K = 'taskbar.alignment';    L = 'Iconos centrados';        T = 'toggle'; Cfg = $true; On = 'center'; Off = 'left' }
        @{ K = 'taskbar.hideSearch';   L = 'Ocultar búsqueda';        T = 'toggle'; Cfg = $true }
        @{ K = 'taskbar.hideTaskView'; L = 'Ocultar vista de tareas'; T = 'toggle'; Cfg = $true }
        @{ K = 'taskbar.hideWidgets';  L = 'Ocultar widgets';         T = 'toggle'; Cfg = $true }
    )
    tbsize = @(
        @{ K = 'height'; L = 'Altura de la barra'; T = 'slider'; D = 48; Min = 32; Max = 96; U = ' px' }
        @{ K = 'icon';   L = 'Tamaño de iconos';   T = 'slider'; D = 24; Min = 16; Max = 48; U = ' px' }
    )
    startbtn = @(
        @{ K = 'searchOrbs';    L = 'Buscar orbs en internet';             T = 'search' }
        @{ K = 'importOrbs';    L = 'Añadir orbs a mi biblioteca...';      T = 'button' }
        @{ K = 'removeOrb';      L = 'Quitar el orb elegido de mi biblioteca'; T = 'button' }
        @{ K = 'uploadOrb';     L = 'Crear un orb con estados...';         T = 'button'; Adv = $true }
        @{ K = 'orbSize';       L = 'Tamaño del orb';                      T = 'slider'; D = 34; Min = 16; Max = 64; U = ' px' }
        @{ K = 'size';          L = 'Tamaño del logo (solo color)';        T = 'slider'; D = 100; Min = 50; Max = 150; U = '%' }
        @{ K = 'hoverScale';    L = 'Crecer al pasar el ratón';            T = 'slider'; D = 115; Min = 100; Max = 140; U = '%'; Adv = $true }
        @{ K = 'hoverRotation'; L = 'Girar al pasar el ratón';             T = 'slider'; D = 4; Min = -30; Max = 30; U = '°'; Adv = $true }
        @{ K = 'gifPlayback';   L = 'Animación (orbs GIF)';                T = 'choice'; D = 'hover'; Choices = @('hover', 'always', 'pressed', 'stopped'); Adv = $true }
    )
    animated = @( @{ K = 'pickVideo'; L = 'Elegir vídeo o GIF de mi equipo...'; T = 'button' } )
    daynight = @(
        @{ K = 'dayHour';   L = 'Empieza el día a las';   T = 'slider'; D = 7;  Min = 4;  Max = 12; U = ':00' }
        @{ K = 'nightHour'; L = 'Empieza la noche a las'; T = 'slider'; D = 19; Min = 15; Max = 23; U = ':00' }
    )
    corners = @( @{ K = 'custom'; L = 'Radio exacto (-1 = el de la opción)'; T = 'slider'; D = -1; Min = -1; Max = 24; U = ' px'; Adv = $true } )
    menus = @(
        @{ K = 'usePalette'; L = 'Teñir con mi paleta';       T = 'toggle'; D = $true }
        @{ K = 'tint';       L = 'Intensidad del tinte';      T = 'slider'; D = 35; Min = 0; Max = 100; U = '%' }
        @{ K = 'rounded';    L = 'Esquinas redondeadas';      T = 'toggle'; D = $true }
    )
    trail = @(
        @{ K = 'length';     L = 'Largo de la estela';        T = 'slider'; D = 500; Min = 100; Max = 2000; U = ' ms'; Step = 50 }
        @{ K = 'width';      L = 'Grosor';                    T = 'slider'; D = 3; Min = 1; Max = 10; U = ' px' }
        @{ K = 'usePalette'; L = 'Usar los colores de mi paleta'; T = 'toggle'; D = $false }
    )
    selection = @(
        @{ K = 'radius';  L = 'Redondeo';            T = 'slider'; D = 8;  Min = 0; Max = 24; U = ' px' }
        @{ K = 'opacity'; L = 'Opacidad del relleno'; T = 'slider'; D = 25; Min = 0; Max = 100; U = '%' }
        @{ K = 'border';  L = 'Grosor del borde';    T = 'slider'; D = 1;  Min = 0; Max = 4; U = ' px'; Adv = $true }
    )
    lockclock = @(
        @{ K = 'seconds'; L = 'Mostrar segundos';        T = 'toggle'; D = $true }
        @{ K = 'h24';     L = 'Formato 24 horas';        T = 'toggle'; D = $true }
        @{ K = 'glass';   L = 'Opacidad del cristal';    T = 'slider'; D = 45; Min = 0; Max = 100; U = '%'; Adv = $true }
    )
    terminal = @(
        @{ K = 'terminal.fontSize'; L = 'Tamaño de letra';        T = 'slider'; Cfg = $true; D = 11; Min = 8; Max = 20; U = ' pt' }
        @{ K = 'terminal.opacity';  L = 'Opacidad de la terminal'; T = 'slider'; Cfg = $true; D = 92; Min = 40; Max = 100; U = '%' }
    )
    wallpaper = @(
        @{ K = 'category';              L = 'Categoría';                       T = 'category' }
        @{ K = 'pick';                  L = 'Elegir imagen de mi equipo...';   T = 'button' }
        @{ K = 'wallpaper.style';       L = 'Ajuste de la imagen';             T = 'choice'; Cfg = $true; D = 'Fill'; Choices = @('Fill', 'Fit', 'Stretch', 'Center', 'Span', 'Tile') }
        @{ K = 'wallpaper.lockScreen';  L = 'Usar también en la pantalla de bloqueo'; T = 'toggle'; Cfg = $true }
    )
}
$StylerTargets = @{
    taskbar       = @{ Bg = @('Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill'); Rect = $true; Blur = $true
                       Border = 'Rectangle#BackgroundStroke'; Text = 'SystemTray.TextIconContent > Grid > SystemTray.AdaptiveTextBlock#InnerTextBlock' }
    startmenu     = @{ Bg = @('Border#AcrylicBorder'); Border = 'Border#AcrylicBorder' }
    notifications = @{ Bg = @('Grid#NotificationCenterGrid', 'Grid#CalendarCenterGrid', 'ContentPresenter#PageContent > Grid > Border') }
    explorer      = @{ Bg = @('Grid#NavigationBarControlGrid', 'FileExplorerExtensions.CommandBarControl_Wave1 > Grid, Grid#CommandBarControlRootGrid'); NoRadius = $true }
    settingsapp   = @{ Bg = @('SplitView#RootSplitView > Grid > Grid#ContentRoot > Border > Grid#ContentGrid'); NoRadius = $true }
}

function Get-Opts($step) {
    $o = $State.Config.wizard.options[$step.Key]
    if (-not $o) { $o = [ordered]@{}; $State.Config.wizard.options[$step.Key] = $o }
    $out = @{}
    $specs = @(); if ($step.Opts) { $specs += $OptSpecs[$step.Opts] }
    foreach ($s in $specs) { if (-not $s.Cfg -and $s.K) { $out[$s.K] = $(if ($o.Contains($s.K)) { $o[$s.K] } else { $s.D }) } }
    $out
}
function Get-CfgValue([string]$path) { $a, $b = $path -split '\.', 2; $State.Config[$a][$b] }
function Set-CfgValue([string]$path, $v) { $a, $b = $path -split '\.', 2; $State.Config[$a][$b] = $v }

function ConvertTo-Argb([string]$hex, [double]$alpha = 1.0) { $c = Get-Col $hex; '#{0:X2}{1:X2}{2:X2}{3:X2}' -f [int][Math]::Round(255 * $alpha), $c.R, $c.G, $c.B }

function Get-StylerSettings($step, $o, $p) {
    # Traduce los ajustes básicos/avanzados a estilos de Windhawk (se suman a los del tema elegido)
    $t = $StylerTargets[$step.Key]; $out = [ordered]@{}; $cs = 0; $rv = 0
    $bgHex = if ($o.bg) { $o.bg } elseif ($o.usePalette) { $p.base } else { $null }
    $alpha = 1 - [double]$o.transp / 100
    $rad = [int]$o.radius
    foreach ($target in $t.Bg) {
        $styles = @()
        if ($bgHex) {
            $prop = if ($t.Rect) { 'Fill' } else { 'Background' }
            $c = Get-Col $bgHex; $rgb = '#{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B
            if ($alpha -ge 0.999) { $styles += "$prop=$(ConvertTo-Argb $bgHex 1)" }
            elseif ($t.Blur) { $styles += "$($prop):=<WindhawkBlur BlurAmount=`"18`" TintColor=`"$(ConvertTo-Argb $bgHex $alpha)`"/>" }
            else { $styles += "$($prop):=<AcrylicBrush TintColor=`"$rgb`" TintOpacity=`"$([Math]::Round($alpha, 2))`" FallbackColor=`"$rgb`"/>" }
        }
        if ($rad -ge 0 -and -not $t.NoRadius) { if ($t.Rect) { $styles += "RadiusX=$rad", "RadiusY=$rad" } else { $styles += "CornerRadius=$rad" } }
        if ($o.border -and $t.Border -eq $target) { $styles += "BorderBrush=$(ConvertTo-Argb $o.border 1)", 'BorderThickness=1' }
        if ($styles) { $out["controlStyles[$cs].target"] = $target; for ($i = 0; $i -lt $styles.Count; $i++) { $out["controlStyles[$cs].styles[$i]"] = $styles[$i] }; $cs++ }
    }
    if ($o.border -and $t.Rect -and $t.Border) { $out["controlStyles[$cs].target"] = $t.Border; $out["controlStyles[$cs].styles[0]"] = "Fill=$(ConvertTo-Argb $o.border 1)"; $cs++ }
    if ($o.text) {
        if ($t.Text) { $out["controlStyles[$cs].target"] = $t.Text; $out["controlStyles[$cs].styles[0]"] = "Foreground=$(ConvertTo-Argb $o.text 1)"; $cs++ }
        else { $out["themeResourceVariables[$rv]"] = "TextFillColorPrimary=$(ConvertTo-Argb $o.text 1)"; $rv++ }
    }
    $acc = if ($o.accent) { $o.accent } elseif ($o.usePalette) { $p.primary } else { $null }
    if ($acc) {
        $out["themeResourceVariables[$rv]"] = "SystemAccentColor=$(ConvertTo-Argb $acc 1)"; $rv++
        foreach ($n in 1..3) {
            $out["themeResourceVariables[$rv]"] = "SystemAccentColorLight$n=$(ConvertTo-Argb (Get-Shade $acc (0.18 * $n)) 1)"; $rv++
            $out["themeResourceVariables[$rv]"] = "SystemAccentColorDark$n=$(ConvertTo-Argb (Get-Shade $acc (-0.18 * $n)) 1)"; $rv++
        }
    }
    $out
}

function Get-ModSettings($step, $item, $p) {
    $s = [ordered]@{}
    if ($item.Raw.apply.settings) { foreach ($k in $item.Raw.apply.settings.Keys) { $v = $item.Raw.apply.settings[$k]; if ($v -is [string] -and $v -match '^\{(\w+)\}$') { $v = Resolve-ColorToken $Matches[1] $p }; $s[$k] = $v } }
    $o = Get-Opts $step
    switch ($step.Opts) {
        'styler'    { foreach ($kv in (Get-StylerSettings $step $o $p).GetEnumerator()) { $s[$kv.Key] = $kv.Value } }
        'tbsize'    { if ($item.Id -ne 'none') { $s.TaskbarHeight = [int]$o.height; $s.IconSize = [int]$o.icon; $s.TaskbarButtonWidth = [int]([int]$o.icon * 1.6 + 6) } }
        'startbtn'  { if ($item.Id -ne 'none') { $s.size = [int]$o.size } }
        'corners'   { if ([int]$o.custom -ge 0 -and $item.Id -ne 'none') { $s.radius = [int]$o.custom; $s.smallRadius = [int]([int]$o.custom / 2) } }
        'menus'     { $s.tintOpacity = [int]$o.tint; $s.roundedCorners = [bool]$o.rounded; if ($o.usePalette) { $s.darkTint = $p.base; $s.lightTint = $p.surface } }
        'trail'     { if ($s.style -eq 'simple_line') {
                          $s['simpleLineOptions.timeBased.tail_duration'] = [int]$o.length; $s['simpleLineOptions.width.values'] = "$([int]$o.width),1"
                          if ($o.usePalette) { $s['simpleLineOptions.color.values'] = ($p.primary.TrimStart('#') + ',' + $p.secondary.TrimStart('#')) } } }
        'selection' { if ($item.Id -ne 'none') { $s.CornerRadius = [int]$o.radius; $s.FillOpacity = [int]$o.opacity; $s.BorderWidth = [int]$o.border } }
        'lockclock' { if ($item.Id -ne 'none') { $s.showSeconds = [bool]$o.seconds; $s.timeFormat = $(if ($o.h24) { '24h' } else { '12h' }); $s.glassOpacity = [int]$o.glass } }
    }
    $s
}

function Set-OptsFromItem($step, $item) {
    # Al elegir una opción, los deslizadores toman sus valores (altura, redondeo...)
    $o = $State.Config.wizard.options[$step.Key]; if (-not $o) { $o = [ordered]@{}; $State.Config.wizard.options[$step.Key] = $o }
    $m = $item.Raw.mock
    switch ($step.Opts) {
        'tbsize'    { if ($m) { $o.height = [int]$m.height; $o.icon = [int]$m.icon } }
        'selection' { if ($m) { $o.radius = [int]$m.radius; $o.opacity = [int]([double]$m.opacity * 100); $o.border = $(if ($m.border) { [int]$m.border } else { 1 }) } }
        'corners'   { $o.custom = -1 }
    }
}

# ======================================================================================
#  Elección -> config.json
# ======================================================================================

function Set-WindhawkEntry($mod, $name, $settings, [bool]$enabled = $true) {
    $mods = @($State.Config.windhawk.mods | Where-Object { $_.id -ne $mod })
    $e = [ordered]@{ id = $mod; name = $name; enabled = $enabled }
    if ($settings -and $settings.Count) { $e.settings = $settings }
    $State.Config.windhawk.mods = @($mods + $e)
    $State.Config.modules.Windhawk = $true
}
function Add-Pending($step) {
    foreach ($m in @($step.Modules)) { if ($m) { [void]$State.Pending.Add($m) } }
    if ($step.Restart) { $State.PendingRestart = $true }
    $State.Dirty = $true
}

function Set-Selection($step, $item, [switch]$FromUser) {
    if ($FromUser) { Set-OptsFromItem $step $item }
    $a = $item.Raw.apply; $cfg = $State.Config; $p = Get-Palette (Get-CurrentSel)
    switch ($a.type) {
        'palette'         { $cfg.palette = $a.palette; $cfg.meta.name = $item.Name; $cfg.theme.darkMode = ($a.mode -ne 'light'); $cfg.modules.Theme = $true; $cfg.modules.Terminal = $true }
        'windhawk'        { Set-WindhawkEntry $a.mod $a.modName (Get-ModSettings $step $item $p) $true
                            if ($step.Key -eq 'cursors') { $cfg.cursors = $null } }
        'windhawk-remove' { $custom = if ($step.Opts -eq 'styler') { Get-ModSettings $step $item $p } else { $null }
                            if ($custom -and $custom.Count) { $custom.theme = ''; Set-WindhawkEntry $a.mod $a.modName $custom $true }   # sin tema pero con mis colores
                            else { Set-WindhawkEntry $a.mod $a.modName $null $false } }
        'windhawk-multi'  { foreach ($m in $a.mods) { Set-WindhawkEntry $m.mod $m.modName $m.settings ([bool]$m.enabled) } }
        'cursor-none'     { $cfg.cursors = $null
                            if ($cfg.windhawk.mods | Where-Object { $_.id -eq 'mouse-cursor-themes' }) { Set-WindhawkEntry 'mouse-cursor-themes' 'Mouse Cursor Themes' $null $false } }
        'cursor-pack'     { $c = [ordered]@{}; foreach ($k in $a.Keys) { if ($k -ne 'type') { $c[$k] = $a[$k] } }; $cfg.cursors = $c; $cfg.modules.Cursors = $true
                            if ($cfg.windhawk.mods | Where-Object { $_.id -eq 'mouse-cursor-themes' }) { Set-WindhawkEntry 'mouse-cursor-themes' 'Mouse Cursor Themes' $null $false } }
        'font-none'       { $cfg.fonts = @() }
        'font'            { $f = [ordered]@{}; foreach ($k in $a.Keys) { if ($k -ne 'type') { $f[$k] = $a[$k] } }
                            $cfg.fonts = @($f); $cfg.terminal.font = $a.family; $cfg.modules.Fonts = $true; $cfg.modules.Terminal = $true }
        'wallpaper'       { $cfg.wallpaper.file = $null; $cfg.wallpaper.url = $a.url; $cfg.wallpaper.size = $a.size; $cfg.wallpaper.name = $a.name; $cfg.modules.Wallpaper = $true }
        'wallpaper-local' { $cfg.modules.Wallpaper = $true }
        'animated'        { $old = $cfg.animated; $cfg.animated = [ordered]@{ style = $a.style; file = $(if ($old -and $a.style -eq 'video') { $old.file } else { $null }) }; $cfg.modules.Animated = $true }
        'daynight'        { $o = Get-Opts $step
                            $cfg.daynight = [ordered]@{ enabled = [bool]$a.enabled; day = $a.day; night = $a.night; dayHour = [int]$o.dayHour; nightHour = [int]$o.nightHour }; $cfg.modules.DayNight = $true }
        'orb'             { $files = Get-OrbFiles $item $p
                            if (-not $files.normal) { Set-Status 'Sube tu imagen con «Subir mi orb...» en el panel Ajustes.'; return }
                            Set-OrbEntry $files (Get-Opts $step) }
    }
    if ($step.Key -eq 'startbtn' -and $a.type -ne 'orb' -and ($cfg.windhawk.mods | Where-Object { $_.id -eq 'start-button-replacer' })) {
        Set-WindhawkEntry 'start-button-replacer' 'Start Button Replacer' $null $false
    }
    $cfg.wizard.selections[$step.Key] = $item.Id
    Add-Pending $step
}

function Get-OrbFiles($item, $p) {
    # Rutas (relativas al proyecto) de las imágenes normal / al pasar el ratón / pulsado
    $a = $item.Raw.apply; $out = [ordered]@{ normal = $null; hover = $null; pressed = $null }
    if ($a.files) { foreach ($k in 'normal', 'hover', 'pressed') { $out[$k] = $a.files[$k] } }
    elseif ($a.palette) {
        $name = "paleta-$($a.style)-$($p.primary.TrimStart('#'))$($p.highlight.TrimStart('#'))"
        $set = Save-OrbSet -Style $a.style -Color1 $p.primary -Color2 $p.highlight -Dir (Join-Path $Root 'assets\orbs') -Name $name
        foreach ($k in 'normal', 'hover', 'pressed') { $out[$k] = "assets/orbs/" + [IO.Path]::GetFileName($set[$k]) }
    }
    elseif ($a.custom) {
        $cf = @($State.Config.wizard.options.startbtn.customFiles)
        for ($i = 0; $i -lt [Math]::Min(3, $cf.Count); $i++) { $out[@('normal', 'hover', 'pressed')[$i]] = $cf[$i] }
    }
    $out
}

function Set-OrbEntry($files, $o) {
    # Las imágenes se copian a %APPDATA%\ZK-Custom\orbs al aplicar; el mod las lee desde ahí
    $copy = @(); $to = @{}
    foreach ($k in 'normal', 'hover', 'pressed') {
        if ($files[$k]) { $dest = '%APPDATA%\ZK-Custom\orbs\' + [IO.Path]::GetFileName($files[$k]); $copy += [ordered]@{ from = $files[$k]; to = $dest }; $to[$k] = $dest } else { $to[$k] = '' }
    }
    $State.Config.windhawk.files = @(@($State.Config.windhawk.files | Where-Object { $_ -and $_.to -notlike '*\ZK-Custom\orbs\*' }) + $copy)
    $s = [ordered]@{
        'images.imageSource' = $to.normal; 'images.hoverImageSource' = $to.hover; 'images.pressedImageSource' = $to.pressed
        'images.activatedImageSource' = $(if ($to.pressed) { $to.pressed } else { $to.hover })
        'images.iconSize' = [int]$o.orbSize; 'imageAnimation.gifPlayback' = [string]$o.gifPlayback
        'hoverEffects.hoverScale' = [int]$o.hoverScale; 'hoverEffects.hoverRotation' = [int]$o.hoverRotation
    }
    Set-WindhawkEntry 'start-button-replacer' 'Start Button Replacer' $s $true
    Set-WindhawkEntry 'taskbar-start-button-colorizer' 'Start button colorizer' $null $false
}

$OrbLibrary = Join-Path $Root 'assets\orbs\library'
function Get-LibraryOrbItems {
    # Cada imagen de assets\orbs\library es un orb de «Mis orbs»
    if (-not (Test-Path $OrbLibrary)) { return @() }
    foreach ($f in (Get-ChildItem $OrbLibrary -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|gif|webp)$' } | Sort-Object Name)) {
        $nice = ($f.BaseName -replace '[-_]+', ' ').Trim()
        [ordered]@{ id = "lib-$($f.Name)"; name = $(if ($nice) { $nice.Substring(0, 1).ToUpper() + $nice.Substring(1) } else { $f.Name }); description = "De tu biblioteca ($($f.Extension.TrimStart('.').ToUpper()))"
            category = 'Mis orbs'; preview = "..\assets\orbs\library\$($f.Name)"
            apply = [ordered]@{ type = 'orb'; files = [ordered]@{ normal = "assets/orbs/library/$($f.Name)" } } }
    }
}
function Import-OrbLibrary {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Multiselect = $true; Filter = 'Imágenes|*.png;*.jpg;*.jpeg;*.gif;*.webp' }
    if (-not $dlg.ShowDialog($Window)) { return }
    New-Item -ItemType Directory -Force -Path $OrbLibrary | Out-Null
    $n = 0
    foreach ($f in $dlg.FileNames) {
        $base = ([IO.Path]::GetFileNameWithoutExtension($f) -replace '[^\w\- ]', '').Trim(); if (-not $base) { $base = 'orb' }
        $ext = [IO.Path]::GetExtension($f).ToLower(); $dest = Join-Path $OrbLibrary "$base$ext"; $i = 2
        while (Test-Path $dest) { $dest = Join-Path $OrbLibrary "$base-$i$ext"; $i++ }
        Copy-Item $f $dest; $n++
    }
    $State.AllItems.Remove('startbtn'); $UI.Search.Text = ''; Update-Items
    Set-Status "$n orb(s) añadidos a «Mis orbs». Elige uno y pulsa ""Aplicar a mi PC""."
}
function Remove-LibraryOrb {
    $id = "$($State.Config.wizard.selections.startbtn)"
    if ($id -notlike 'lib-*') { return }
    $file = Join-Path $OrbLibrary ($id.Substring(4))
    $r = [Windows.MessageBox]::Show("¿Quitar «$($id.Substring(4))» de tu biblioteca?", 'ZK-Custom', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    Remove-Item $file -Force -ErrorAction SilentlyContinue
    $State.Config.wizard.selections.Remove('startbtn')
    $State.AllItems.Remove('startbtn'); Update-Items; Build-Options; Update-StepList; Request-Render
    Set-Status 'Orb quitado de tu biblioteca.'
}

function Select-AnimatedVideo {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Filter = 'Vídeos y GIF|*.mp4;*.webm;*.mkv;*.mov;*.gif' }
    if (-not $dlg.ShowDialog($Window)) { return }
    $dir = Join-Path $Root 'assets\animated'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $name = [IO.Path]::GetFileName($dlg.FileName); Copy-Item $dlg.FileName (Join-Path $dir $name) -Force
    $State.Config.animated = [ordered]@{ style = 'video'; file = "assets/animated/$name" }
    $State.Config.modules.Animated = $true; $State.Config.wizard.selections.animated = 'video'
    Add-Pending $StepByKey.animated; Update-Items; Update-StepList; Request-Render
    Set-Status "Vídeo «$name» listo como fondo animado. Pulsa ""Aplicar a mi PC""."
}

# ---------------- Carpetas de colores ----------------

$FolderColors = @('#E5484D', '#F76B15', '#FFD60A', '#30A46C', '#12A594', '#0090FF', '#8E4EC6', '#E93D82', '#6B7280', '#1F2937')
$FolderImgCache = @{}
function Get-FolderPreview([string]$hex) {
    $k = if ($hex -and $hex -ne 'none') { $hex } else { '#E8B84A' }
    if (-not $FolderImgCache.ContainsKey($k)) { $FolderImgCache[$k] = New-FolderImage -Color $k -Size 64 }
    $FolderImgCache[$k]
}
function Build-Folders {
    $UI.TweaksList.Children.Clear()
    if (-not $State.Config.folders) { $State.Config.folders = [ordered]@{} }
    $known = [ordered]@{}
    foreach ($f in @(@('Desktop', 'Escritorio'), @('MyDocuments', 'Documentos'), @('MyPictures', 'Imágenes'), @('MyMusic', 'Música'), @('MyVideos', 'Vídeos'))) {
        $known[[Environment]::GetFolderPath($f[0])] = $f[1]
    }
    $known[(Join-Path $env:USERPROFILE 'Downloads')] = 'Descargas'
    foreach ($k in $State.Config.folders.Keys) { if (-not $known.Contains($k)) { $known[$k] = Split-Path $k -Leaf } }
    $p = Get-Palette (Get-CurrentSel)
    $choices = @('none', $p.primary, $p.secondary, $p.highlight) + $FolderColors
    foreach ($path in $known.Keys) {
        $cur = [string]$State.Config.folders[$path]
        $row = New-Object Windows.Controls.DockPanel -Property @{ Margin = '0,6,0,6' }
        $img = New-Object Windows.Controls.Image -Property @{ Source = (Get-FolderPreview $cur); Width = 44; Height = 44; Margin = '0,0,12,0' }
        [Windows.Controls.DockPanel]::SetDock($img, 'Left'); [void]$row.Children.Add($img)
        $info = New-Object Windows.Controls.StackPanel -Property @{ Width = 210; VerticalAlignment = 'Center' }
        [Windows.Controls.DockPanel]::SetDock($info, 'Left')
        [void]$info.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $known[$path]; FontWeight = 'SemiBold'; Foreground = (UiB 'C_Text') }))
        [void]$info.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $path; FontSize = 10; Foreground = (UiB 'C_Muted'); TextTrimming = 'CharacterEllipsis'; ToolTip = $path }))
        [void]$row.Children.Add($info)
        $wp = New-Object Windows.Controls.WrapPanel -Property @{ VerticalAlignment = 'Center' }
        foreach ($hex in $choices) {
            $btn = New-Object Windows.Controls.Button -Property @{ Width = 24; Height = 24; Padding = '0'; Margin = '0,0,4,0'; Tag = @{ P = $path; H = $hex }; ToolTip = $(if ($hex -eq 'none') { 'Sin color (como Windows)' } else { $hex }) }
            if ($hex -eq 'none') { $btn.Content = '×'; $btn.Background = (UiB 'C_Surface') } else { $btn.Background = (B $hex) }
            if ($cur -eq $hex -or (-not $cur -and $hex -eq 'none')) { $btn.BorderBrush = (UiB 'C_Text'); $btn.BorderThickness = '2' }
            $btn.Add_Click({ param($c) $State.Config.folders[$c.Tag.P] = $c.Tag.H; $State.Config.modules.Folders = $true; Add-Pending $StepByKey.folders; Build-Folders; Update-StepList; Request-Render })
            [void]$wp.Children.Add($btn)
        }
        [void]$row.Children.Add($wp)
        [void]$UI.TweaksList.Children.Add($row)
    }
    $add = New-Object Windows.Controls.Button -Property @{ Content = 'Añadir otra carpeta...'; HorizontalAlignment = 'Left'; Margin = '0,12,0,0' }
    $add.Add_Click({
        Add-Type -AssemblyName System.Windows.Forms
        $fb = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ Description = 'Elige la carpeta a la que quieres dar color' }
        if ($fb.ShowDialog() -eq 'OK') { $State.Config.folders[$fb.SelectedPath] = $FolderColors[5]; $State.Config.modules.Folders = $true; Add-Pending $StepByKey.folders; Build-Folders; Update-StepList; Request-Render }
    })
    [void]$UI.TweaksList.Children.Add($add)
}

function Select-CustomOrb {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog -Property @{ Multiselect = $true; Filter = 'Imágenes|*.png;*.jpg;*.jpeg;*.gif;*.webp' }
    if (-not $dlg.ShowDialog($Window)) { return }
    $dir = Join-Path $Root 'assets\orbs'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMddHHmmss'; $rel = @(); $n = 0
    foreach ($f in ($dlg.FileNames | Select-Object -First 3)) {
        $name = "mio-$stamp-$n" + [IO.Path]::GetExtension($f).ToLower(); Copy-Item $f (Join-Path $dir $name) -Force
        $rel += "assets/orbs/$name"; $n++
    }
    $step = $StepByKey.startbtn
    [void](Get-Opts $step); $State.Config.wizard.options.startbtn.customFiles = $rel
    $State.AllItems.Remove('startbtn')
    $it = Find-Item 'startbtn' 'orb-custom'
    if ($it) { Set-Selection $step $it }
    Update-Items; Update-StepList; Request-Render
    Set-Status "Orb propio listo ($($rel.Count) imagen(es)). Pulsa ""Aplicar a mi PC"" para verlo en la barra."
}

function Update-DependentSteps {
    # Al cambiar la paleta, se recalculan los estilos que usan sus colores
    $State.AllItems.Remove('startbtn')
    foreach ($k in 'taskbar', 'startmenu', 'notifications', 'explorer', 'settingsapp', 'trail', 'menus', 'selection', 'startbtn') {
        $it = Find-Item $k $State.Config.wizard.selections[$k]
        if ($it) { Set-Selection $StepByKey[$k] $it }
    }
    foreach ($k in 'trail', 'tbsize', 'startbtn', 'menus', 'selection', 'borders', 'corners', 'clock', 'lockclock', 'effects', 'animated', 'daynight') { $State.AllItems.Remove($k) }
}

function Get-CurrentSel([hashtable]$override) {
    $sel = @{}
    foreach ($s in $Steps) {
        if ($s.Kind) { continue }
        $id = $State.Config.wizard.selections[$s.Key]
        if ($null -ne $id) { $sel[$s.Key] = Find-Item $s.Key $id }
    }
    if ($override) { foreach ($k in $override.Keys) { $sel[$k] = $override[$k] } }
    $sel
}

function Get-SelectionName($step) {
    if ($step.Key -eq 'wallpaper') {
        $w = $State.Config.wallpaper
        if ($w.file) { return "Tu imagen" } elseif ($w.url) { return $w.name } else { return '(sin elegir)' }
    }
    if ($step.Key -eq 'tweaks') {
        $n = @($State.Config.tweaks.Keys | Where-Object { $State.Config.tweaks[$_] }).Count
        return $(if ($n) { "$n activados" } else { '(ninguno)' })
    }
    if ($step.Key -eq 'themes') { $t = $State.Config.wizard.selections.themes; if ($t) { $it = Find-Item 'themes' $t; if ($it) { return $it.Name } }; return '' }
    $id = $State.Config.wizard.selections[$step.Key]
    if ($null -eq $id) { return '(sin elegir)' }
    $it = Find-Item $step.Key $id
    if ($it) { $it.Name } else { $id }
}

# ======================================================================================
#  Vista previa: escritorio simulado
# ======================================================================================

function Get-Look([string]$key, $p, [string]$defHex, [double]$defAlpha, [double]$defRad) {
    # Aspecto de un elemento según los ajustes básicos/avanzados de su sección
    $o = Get-Opts $StepByKey[$key]
    $custom = [bool]($o.bg -or $o.usePalette)
    @{
        Custom = $custom
        Hex    = $(if ($o.bg) { $o.bg } elseif ($o.usePalette) { $p.base } else { $defHex })
        Alpha  = $(if ($custom) { 1 - [double]$o.transp / 100 } else { $defAlpha })
        Radius = $(if ([int]$o.radius -ge 0) { [double]$o.radius } else { $defRad })
        Border = $o.border
        Text   = $(if ($o.text) { $o.text } elseif ($o.usePalette) { $p.text } else { '#FFFFFF' })
        Accent = $(if ($o.accent) { $o.accent } elseif ($o.usePalette) { $p.primary } else { '#4CC2FF' })
    }
}
function Draw-Panel($dc, $r, $look, $blur) {
    $dc.PushClip((New-Object Windows.Media.RectangleGeometry $r, $look.Radius, $look.Radius))
    if ($look.Alpha -lt 1 -and $blur) { [void](Draw-Image $dc $blur (Rc 0 0 960 540) 'Fill') }
    $dc.DrawRectangle((B $look.Hex $look.Alpha), $null, $r)
    $dc.Pop()
    $dc.DrawRoundedRectangle($null, $(if ($look.Border) { Pn $look.Border 1.5 } else { Pn '#FFFFFF' 1 0.12 }), $r, $look.Radius, $look.Radius)
}

function Render-Desktop($sel, [string]$focus, [double]$scale = 1.0) {
    $W = 960; $H = 540
    $p = Get-Palette $sel
    $dv = New-Object Windows.Media.DrawingVisual; $dc = $dv.RenderOpen()
    if ($scale -ne 1) { $dc.PushTransform((New-Object Windows.Media.ScaleTransform $scale, $scale)) }

    # --- Fondo ---
    $wall = $null
    if ($sel.wallpaper) { $wall = Get-Bitmap ($(if ($sel.wallpaper.Id -eq 'local') { $sel.wallpaper.Preview } else { $sel.wallpaper.PreviewLarge })) }
    $grad = New-Object Windows.Media.LinearGradientBrush ((Get-Col (Get-Shade $p.primary -0.6)), (Get-Col (Get-Shade $p.secondary -0.4)), 30.0)
    $dc.DrawRectangle($grad, $null, (Rc 0 0 $W $H))
    if ($wall) { [void](Draw-Image $dc $wall (Rc 0 0 $W $H) 'Fill') }
    if ($sel.animated -and $sel.animated.Id -ne 'none' -and $sel.animated.Raw.mock) {
        # Fondo animado: se muestra un fotograma con tus colores
        $an = Render-Mock $sel.animated.Raw.mock $p; $dc.DrawImage($an, (Rc 0 0 $W $H)); $wall = $an
    }
    $blur = Get-Blurred $wall

    $o = @{}; foreach ($k in 'taskbar', 'tbsize', 'startbtn', 'trail', 'selection', 'menus', 'corners', 'lockclock', 'startmenu', 'notifications', 'explorer', 'settingsapp') { $o[$k] = Get-Opts $StepByKey[$k] }

    if ($focus -eq 'lock') {
        $dc.DrawRectangle((B '#000000' 0.25), $null, (Rc 0 0 $W $H))
        $lc = $sel.lockclock
        $img = if ($lc) { Get-Bitmap $lc.PreviewLarge } else { $null }
        if ($img) { [void](Draw-Image $dc $img (Rc 120 50 720 440)) }
        else { Txt $dc '21:45' 480 150 120 '#FFFFFF' -font 'Segoe UI Variable Display, Segoe UI' -weight 'SemiBold' -align 'Center'; Txt $dc 'miércoles, 12 de noviembre' 480 300 26 '#FFFFFF' -align 'Center' }
        $dc.Close(); return (Complete-Render $dv $W $H $scale)
    }

    # --- Esquinas, efecto, bordes ---
    $rad = 8.0
    if ($sel.corners -and $sel.corners.Raw.mock) { $rad = [double]$sel.corners.Raw.mock.radius }
    if ([int]$o.corners.custom -ge 0 -and $sel.corners -and $sel.corners.Id -ne 'none') { $rad = [double]$o.corners.custom }
    $rad = $rad * 0.75
    $op = 1.0; if ($sel.effects -and $sel.effects.Raw.mock) { $op = [double]$sel.effects.Raw.mock.opacity }
    $bpen = Pn '#FFFFFF' 1 0.12
    if ($sel.borders) { switch ($sel.borders.Id) { 'accent' { $bpen = Pn $p.primary 2 } 'invisible' { $bpen = $null } } }

    # --- Terminal ---
    $tr = Rc 590 70 330 200
    $dc.DrawRoundedRectangle((B $p.base 0.97), $bpen, $tr, $rad, $rad)
    $fontImg = if ($sel.fonts -and $sel.fonts.Preview) { Get-Bitmap $sel.fonts.Preview } else { $null }
    $dc.PushClip((New-Object Windows.Media.RectangleGeometry $tr, $rad, $rad))
    if ($fontImg) { [void](Draw-Image $dc $fontImg (Rc 596 76 318 188) 'Uniform') }
    else {
        $y = 90; foreach ($c in @($p.primary, $p.text, $p.secondary, $p.highlight, $p.muted)) { $dc.DrawRoundedRectangle((B $c), $null, (Rc 606 $y (80 + ($y % 7) * 22) 7), 3, 3); $y += 22 }
    }
    $dc.Pop()

    # --- Ventana principal (Explorador) ---
    $wr = Rc 110 60 500 310
    $geo = New-Object Windows.Media.RectangleGeometry $wr, $rad, $rad
    $dc.PushClip($geo)
    if ($op -lt 1 -and $blur) { [void](Draw-Image $dc $blur (Rc 0 0 $W $H) 'Fill') }
    $dc.DrawRectangle((B $p.base $op), $null, $wr)
    $dc.DrawRectangle((B $p.surface ([Math]::Min(1, $op + 0.1))), $null, (Rc 110 60 500 34))
    $dc.DrawRectangle((B $p.surface ([Math]::Min(1, $op * 0.8))), $null, (Rc 110 94 120 276))
    # Estilo del Explorador (barra de navegación y de comandos) según los ajustes
    $ex = Get-Look 'explorer' $p $p.surface ([Math]::Min(1, $op + 0.1)) 8
    if ($ex.Custom) {
        $dc.DrawRectangle((B $ex.Hex $ex.Alpha), $null, (Rc 110 60 500 34))
        $dc.DrawRectangle((B $ex.Hex ([Math]::Min(1, $ex.Alpha + 0.05))), $null, (Rc 230 94 380 26))
        foreach ($i in 0..4) { $dc.DrawRoundedRectangle((B $ex.Text 0.7), $null, (Rc (242 + $i * 46) 104 30 6), 3, 3) }
    }
    $winImg = $null
    if ($focus -eq 'window' -and $State.Hover -and $State.HoverStep -and $sel[$State.HoverStep]) { $winImg = Get-Bitmap $sel[$State.HoverStep].PreviewLarge }
    elseif ($focus -eq 'icons' -and $sel.icons) { $winImg = Get-Bitmap $sel.icons.PreviewLarge }
    if ($winImg) { $dc.DrawRectangle((B '#000000' 0.35), $null, (Rc 110 94 500 276)); [void](Draw-Image $dc $winImg (Rc 116 98 488 268)) }
    elseif ($focus -eq 'window' -and $State.HoverStep -eq 'settingsapp') {
        # App Configuración simulada con sus ajustes
        $st = Get-Look 'settingsapp' $p $p.base $op 8
        $dc.DrawRectangle((B $st.Hex $st.Alpha), $null, (Rc 110 94 500 276))
        $labels = 'Sistema', 'Bluetooth', 'Red', 'Personalización', 'Aplicaciones', 'Cuentas'
        for ($i = 0; $i -lt $labels.Count; $i++) {
            if ($i -eq 3) { $dc.DrawRoundedRectangle((B $st.Accent 0.25), $null, (Rc 116 (104 + $i * 30) 118 26), 5, 5); $dc.DrawRoundedRectangle((B $st.Accent), $null, (Rc 118 (111 + $i * 30) 3 12), 1.5, 1.5) }
            Txt $dc $labels[$i] 128 (108 + $i * 30) 12 $st.Text
        }
        Txt $dc 'Personalización' 250 102 18 $st.Text -weight 'SemiBold'
        for ($i = 0; $i -lt 4; $i++) {
            $r = Rc 250 (136 + $i * 56) 346 48
            $dc.DrawRoundedRectangle((B (Get-Shade $st.Hex 0.08) ([Math]::Min(1, $st.Alpha + 0.1))), $(if ($st.Border) { Pn $st.Border 1 } else { $null }), $r, $st.Radius, $st.Radius)
            Txt $dc (@('Fondo', 'Colores', 'Temas', 'Pantalla de bloqueo')[$i]) 264 (146 + $i * 56) 12 $st.Text
            $dc.DrawRoundedRectangle((B $(if ($i -eq 1) { $st.Accent } else { $p.muted })), $null, (Rc 556 (154 + $i * 56) 28 12), 6, 6)
        }
    }
    else {
        for ($i = 0; $i -lt 5; $i++) { $dc.DrawRoundedRectangle((B $p.muted 0.6), $null, (Rc 124 (110 + $i * 26) 90 8), 4, 4) }
        for ($r = 0; $r -lt 2; $r++) { for ($c = 0; $c -lt 4; $c++) {
            $x = 250 + $c * 88; $y = 112 + $r * 110
            $fc = @($State.Config.folders.Values | Where-Object { $_ -and $_ -ne 'none' }); $fcol = if ($fc.Count) { $fc[($r * 4 + $c) % $fc.Count] } else { $p.secondary }
            $dc.DrawRoundedRectangle((B $fcol 0.9), $null, (Rc $x $y 56 42), 6, 6)
            $dc.DrawRectangle((B (Get-Shade $fcol 0.25)), $null, (Rc $x ($y - 6) 24 10))
            $dc.DrawRoundedRectangle((B $p.text 0.7), $null, (Rc ($x - 4) ($y + 52) 64 7), 3, 3)
        } }
    }
    Txt $dc 'Explorador' 126 68 14 $p.text
    Txt $dc ([string][char]0x2014 + '   ' + [char]0x25A1 + '   ' + [char]0x2715) 596 66 14 $p.text -align 'Right'
    $dc.Pop()
    if ($bpen) { $dc.DrawRoundedRectangle($null, $bpen, $wr, $rad, $rad) }

    # --- Menú contextual ---
    $mi = $sel.menus
    if ($focus -eq 'menu' -or ($mi -and $mi.Id -ne 'none')) {
        $mm = if ($mi) { $mi.Raw.mock } else { $null }
        $mop = if ($mm) { [double]$mm.opacity } else { 1.0 }
        $mr = Rc 640 300 180 150; $mrad = if ($o.menus.rounded) { 8 } else { 2 }
        $mfill = if ($o.menus.usePalette -or ($mm -and $mm.palette)) { $p.surface } else { '#2B2B2B' }
        $dc.PushClip((New-Object Windows.Media.RectangleGeometry $mr, $mrad, $mrad))
        if ($mm -and $mm.blur -and $blur) { [void](Draw-Image $dc $blur (Rc 0 0 $W $H) 'Fill') }
        $dc.DrawRectangle((B $mfill $mop), $null, $mr)
        $labels = 'Abrir', 'Copiar', 'Cambiar nombre', 'Compartir', 'Propiedades'
        for ($i = 0; $i -lt 5; $i++) { if ($i -eq 1) { $dc.DrawRoundedRectangle((B $p.primary 0.35), $null, (Rc 645 (306 + $i * 28) 170 24), 5, 5) }; Txt $dc $labels[$i] 660 (309 + $i * 28) 13 '#FFFFFF' }
        $dc.Pop(); $dc.DrawRoundedRectangle($null, (Pn '#FFFFFF' 1 0.15), $mr, $mrad, $mrad)
    }

    # --- Rectángulo de selección ---
    $si = $sel.selection
    if ($si -and $si.Raw.mock) {
        $sm = $si.Raw.mock; $c = Resolve-ColorToken $sm.color $p
        $sr = if ($si.Id -eq 'none') { 0 } else { [double]$o.selection.radius }
        $sop = if ($si.Id -eq 'none') { [double]$sm.opacity } else { [double]$o.selection.opacity / 100 }
        $sbw = if ($si.Id -eq 'none') { 1 } else { [Math]::Max(0.5, [double]$o.selection.border) }
        foreach ($i in 0..1) { $dc.DrawRoundedRectangle((B '#FFFFFF' 0.85), $null, (Rc (40 + $i * 0) (90 + $i * 70) 40 40), 6, 6) }
        $dc.DrawRoundedRectangle((B $c $sop), (Pn $c $sbw), (Rc 26 78 70 140), $sr, $sr)
    }

    # --- Barra de tareas ---
    $tbH = 48.0; $icon = 24.0
    if ($sel.tbsize -and $sel.tbsize.Id -ne 'none') { $tbH = [double]$o.tbsize.height; $icon = [double]$o.tbsize.icon }
    $tbH = $tbH * 0.75; $icon = $icon * 0.75
    $to = $o.taskbar
    $tbHex = if ($to.bg) { $to.bg } elseif ($to.usePalette) { $p.base } else { '#1C1C1C' }
    $tbAlpha = if ($to.bg -or $to.usePalette) { 1 - [double]$to.transp / 100 } else { 0.85 }
    $tbRad = [Math]::Max(0, [int]$to.radius) * 0.75
    $float = $tbRad -gt 0
    $tbr = if ($float) { Rc 150 ($H - $tbH - 8) ($W - 300) $tbH } else { Rc 0 ($H - $tbH) $W $tbH }
    $dc.PushClip((New-Object Windows.Media.RectangleGeometry $tbr, $tbRad, $tbRad))
    if ($tbAlpha -lt 1 -and $blur) { [void](Draw-Image $dc $blur (Rc 0 0 $W $H) 'Fill') }
    $dc.DrawRectangle((B $tbHex $tbAlpha), $null, $tbr); $dc.Pop()
    if ($to.border) { $dc.DrawRoundedRectangle($null, (Pn $to.border 1), $tbr, $tbRad, $tbRad) }
    $n = 6; $gap = $icon * 0.6; $tot = ($n + 1) * $icon + $n * $gap
    $x = if ($State.Config.taskbar.alignment -eq 'left') { $tbr.X + 14 } else { $tbr.X + ($tbr.Width - $tot) / 2 }
    $cy = $tbr.Y + $tbH / 2
    $sbColor = '#4CC2FF'; $sbScale = 1.0
    if ($sel.startbtn -and $sel.startbtn.Id -ne 'none') { $sbColor = Resolve-ColorToken $sel.startbtn.Raw.mock.color $p; $sbScale = [double]$o.startbtn.size / 100 }
    $orb = $null
    if ($sel.startbtn -and $sel.startbtn.Raw.apply.type -eq 'orb') { $orb = Get-Bitmap $sel.startbtn.Preview }
    if ($orb) {
        $os = [double]$o.startbtn.orbSize * 0.75
        $dc.DrawImage($orb, (Rc ($x + $icon / 2 - $os / 2) ($cy - $os / 2) $os $os))
    } else {
        $q = $icon * 0.42 * $sbScale; $g = $icon * 0.08
        foreach ($qq in @(@(0, 0), @(1, 0), @(0, 1), @(1, 1))) { $dc.DrawRectangle((B $sbColor), $null, (Rc ($x + $icon / 2 - $q - $g / 2 + $qq[0] * ($q + $g)) ($cy - $q - $g / 2 + $qq[1] * ($q + $g)) $q $q)) }
    }
    $cols = @($p.primary, $p.secondary, $p.highlight, '#E0AF68', '#9ECE6A', $p.text)
    for ($i = 0; $i -lt $n; $i++) {
        $ix = $x + ($i + 1) * ($icon + $gap)
        $dc.DrawRoundedRectangle((B $cols[$i]), $null, (Rc $ix ($cy - $icon / 2) $icon $icon), $icon * 0.22, $icon * 0.22)
        if ($i -eq 1) { $dc.DrawRoundedRectangle((B $(if ($to.accent) { $to.accent } else { $p.primary })), $null, (Rc ($ix + $icon * 0.3) ($cy + $icon / 2 + 2) ($icon * 0.4) 3), 1.5, 1.5) }
    }
    $clockLines = @('21:45', '12/11/2026')
    if ($sel.clock -and $sel.clock.Raw.mock) { $clockLines = @("$($sel.clock.Raw.mock.text)" -split "`n") }
    $txtCol = if ($to.text) { $to.text } else { '#FFFFFF' }
    $ly = $cy - $clockLines.Count * 8
    foreach ($l in $clockLines) { Txt $dc $l ($tbr.Right - 14) $ly 12 $txtCol -align 'Right'; $ly += 16 }
    Txt $dc ([string][char]0xE701 + '  ' + [char]0xE767 + '  ' + [char]0xE83F) ($tbr.Right - 100) ($cy - 8) 12 $txtCol -font 'Segoe Fluent Icons, Segoe MDL2 Assets' -align 'Right'

    # --- Menú Inicio y notificaciones simulados con sus ajustes ---
    if ($focus -eq 'start' -and -not $State.Hover) {
        $sm = Get-Look 'startmenu' $p '#202020' 0.88 8
        $r = Rc 290 46 380 ($H - $tbH - 64)
        Draw-Panel $dc $r $sm $blur
        $dc.DrawRoundedRectangle((B '#FFFFFF' 0.08), $(Pn $sm.Accent 1.5 0.9), (Rc 306 60 348 30), 15, 15)
        Txt $dc 'Buscar aplicaciones, configuración y documentos' 322 67 11 $sm.Text
        Txt $dc 'Anclado' 308 104 13 $sm.Text -weight 'SemiBold'
        $cols = @($sm.Accent, $p.secondary, $p.highlight, '#E0AF68', '#9ECE6A', '#F7768E')
        for ($i = 0; $i -lt 18; $i++) { $cx = 322 + ($i % 6) * 56; $cy2 = 132 + [Math]::Floor($i / 6) * 58
            $dc.DrawRoundedRectangle((B $cols[$i % 6]), $null, (Rc $cx $cy2 26 26), 6, 6); $dc.DrawRoundedRectangle((B $sm.Text 0.55), $null, (Rc ($cx - 6) ($cy2 + 32) 38 5), 2, 2) }
        Txt $dc 'Recomendado' 308 312 13 $sm.Text -weight 'SemiBold'
        for ($i = 0; $i -lt 2; $i++) { $dc.DrawRoundedRectangle((B $sm.Text 0.4), $null, (Rc (308 + $i * 172) 340 150 8), 4, 4) }
        $dc.DrawEllipse((B $sm.Accent), $null, (Pt 318 ($r.Bottom - 22)), 10, 10); Txt $dc 'Usuario' 336 ($r.Bottom - 30) 12 $sm.Text
    }
    if ($focus -eq 'notif' -and -not $State.Hover) {
        $nl = Get-Look 'notifications' $p '#202020' 0.88 8
        $r1 = Rc 620 40 320 130; $r2 = Rc 620 180 320 ($H - $tbH - 200)
        Draw-Panel $dc $r1 $nl $blur; Draw-Panel $dc $r2 $nl $blur
        Txt $dc 'Notificaciones' 636 52 13 $nl.Text -weight 'SemiBold'
        $dc.DrawRoundedRectangle((B $nl.Accent), $null, (Rc 636 84 30 30), 6, 6)
        Txt $dc 'Descarga completada' 676 84 12 $nl.Text; Txt $dc 'wallpaper.png · hace 2 min' 676 102 11 $nl.Text
        Txt $dc 'miércoles, 12 de noviembre' 636 192 13 $nl.Text -weight 'SemiBold'
        for ($d = 0; $d -lt 35; $d++) { $cx = 650 + ($d % 7) * 42; $cy2 = 236 + [Math]::Floor($d / 7) * 34
            if ($d -eq 16) { $dc.DrawEllipse((B $nl.Accent), $null, (Pt ($cx + 6) ($cy2 + 8)), 13, 13) }
            Txt $dc ([string](($d % 30) + 1)) ($cx + 6) $cy2 12 $nl.Text -align 'Center' }
    }
    if ($focus -eq 'terminal') {
        # Terminal grande con la fuente elegida, su tamaño y la opacidad
        $tOp = [double]$State.Config.terminal.opacity / 100; if (-not $tOp) { $tOp = 0.92 }
        $tr2 = Rc 170 50 620 ($H - $tbH - 80)
        $dc.PushClip((New-Object Windows.Media.RectangleGeometry $tr2, $rad, $rad))
        if ($tOp -lt 1 -and $blur) { [void](Draw-Image $dc $blur (Rc 0 0 $W $H) 'Fill') }
        $dc.DrawRectangle((B $p.base $tOp), $null, $tr2)
        $dc.DrawRectangle((B $p.surface), $null, (Rc 170 50 620 30)); Txt $dc 'Windows PowerShell' 186 56 12 $p.text
        $fi = $null; $fit = if ($State.Hover -and $State.Hover.Preview) { $State.Hover } else { $sel.fonts }
        if ($fit -and $fit.Preview) { $fi = Get-Bitmap $fit.Preview }
        if ($fi) { $k = [double]$State.Config.terminal.fontSize / 11; if (-not $k) { $k = 1 }
            $iw = 600 * $k; $ih = $iw * $fi.PixelHeight / $fi.PixelWidth; $dc.DrawImage($fi, (Rc 180 84 $iw $ih)) }
        $dc.Pop(); $dc.DrawRoundedRectangle($null, $bpen, $tr2, $rad, $rad)
    }

    # --- Tema elegido en miniatura (sin pasar el ratón) ---
    if ($focus -in 'taskbar', 'start', 'notif', 'window' -and -not $State.Hover -and $State.HoverStep -and $sel[$State.HoverStep] -and $sel[$State.HoverStep].Id -ne 'none') {
        $ti0 = Get-Bitmap $sel[$State.HoverStep].Preview
        if ($ti0) {
            $ir = Rc 12 12 230 140
            $dc.DrawRoundedRectangle((B '#16161E' 0.92), (Pn $p.primary 1.5), $ir, 8, 8)
            [void](Draw-Image $dc $ti0 (Rc 18 30 218 116))
            Txt $dc "Tema: $($sel[$State.HoverStep].Name)" 20 14 11 '#FFFFFF'
        }
    }

    # --- Capturas de los estilos en su sitio ---
    # La captura del tema solo tapa la vista mientras pasas el ratón por una tarjeta; sin ratón se ve la simulación con tus ajustes
    if ($focus -in 'taskbar', 'start', 'notif', 'cursor' -and $State.Hover) {
        $it = if ($State.HoverStep -and $sel[$State.HoverStep]) { $sel[$State.HoverStep] } else { $null }
        $img = if ($it) { Get-Bitmap $it.PreviewLarge } else { $null }
        if ($img) {
            $dc.DrawRectangle((B '#000000' 0.35), $null, (Rc 0 0 $W $H))
            $area = switch ($focus) { 'taskbar' { Rc 20 ($H - 230) ($W - 40) 220 } 'start' { Rc 250 20 460 ($H - $tbH - 30) } 'notif' { Rc ($W - 400) 20 380 ($H - $tbH - 30) } 'cursor' { Rc 200 80 560 330 } }
            $r = Draw-Image $dc $img $area
            if ($r) { $dc.DrawRoundedRectangle($null, (Pn $p.primary 2), $r, 6, 6) }
            if (($to.usePalette -or $to.bg) -and $focus -eq 'taskbar' -and $r) { $dc.DrawRectangle((B $tbHex 0.18), $null, $r) }
        }
    }

    # --- Puntero y estela ---
    $ti = $sel.trail
    if ($ti -and $ti.Raw.mock -and @($ti.Raw.mock.colors).Count) {
        $tc = @($ti.Raw.mock.colors); if ($o.trail.usePalette) { $tc = @($p.primary, $p.secondary) }
        $br = New-Object Windows.Media.LinearGradientBrush
        $br.StartPoint = (Pt 1 0.5); $br.EndPoint = (Pt 0 0.5)   # el puntero está en el extremo derecho de la curva
        $len = [Math]::Min(1, [double]$o.trail.length / 1500)
        for ($i = 0; $i -lt $tc.Count; $i++) { $br.GradientStops.Add((New-Object Windows.Media.GradientStop (Get-Col $tc[$i]), ($i / [Math]::Max(1, $tc.Count - 1) * $len))) }
        $tCol = Get-Col $tc[-1]; $tCol.A = 0; $br.GradientStops.Add((New-Object Windows.Media.GradientStop $tCol, ([Math]::Min(1, $len + 0.05))))
        $pen = New-Object Windows.Media.Pen $br, ([double]$o.trail.width * 1.6); $pen.StartLineCap = 'Round'; $pen.EndLineCap = 'Round'
        $dc.DrawGeometry($null, $pen, [Windows.Media.Geometry]::Parse('M 470,470 C 400,520 330,380 260,440'))
    }
    $dark = $sel.cursors -and ($sel.cursors.Name -match 'Classic|Dark|negro|Black')
    $arrow = [Windows.Media.Geometry]::Parse('M 470,470 L 470,494 L 476,488 L 481,499 L 485,497 L 480,486 L 488,486 Z')
    $dc.DrawGeometry((B $(if ($dark) { '#111111' } else { '#FFFFFF' })), (Pn $(if ($dark) { '#FFFFFF' } else { '#000000' }) 1.2), $arrow)

    if ($scale -ne 1) { $dc.Pop() }
    $dc.Close()
    Complete-Render $dv $W $H $scale
}
function Complete-Render($dv, $W, $H, $scale) {
    $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap ([int]($W * $scale)), ([int]($H * $scale)), 96, 96, ([Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($dv); $rtb.Freeze(); $rtb
}

# ======================================================================================
#  Interfaz
# ======================================================================================

$XamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ZK-Custom" Width="1480" Height="920" MinWidth="1180" MinHeight="720"
        Background="#1A1B26" Foreground="#C0CAF5" FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" WindowStartupLocation="CenterScreen">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#24283B"/><Setter Property="Foreground" Value="#C0CAF5"/><Setter Property="BorderBrush" Value="#3B4261"/>
      <Setter Property="Padding" Value="14,7"/><Setter Property="Margin" Value="6,0,0,0"/><Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <Border x:Name="b" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="1" CornerRadius="8" Padding="{TemplateBinding Padding}">
          <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#7AA2F7"/></Trigger>
          <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.45"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="#7AA2F7"/><Setter Property="Foreground" Value="#1A1B26"/><Setter Property="BorderBrush" Value="#7AA2F7"/><Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="Seg" TargetType="ToggleButton">
      <Setter Property="Foreground" Value="#9AA5CE"/><Setter Property="Cursor" Value="Hand"/><Setter Property="Padding" Value="12,5"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ToggleButton">
        <Border x:Name="b" Background="Transparent" CornerRadius="6" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center"/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsChecked" Value="True"><Setter TargetName="b" Property="Background" Value="#3B4261"/><Setter Property="Foreground" Value="#C0CAF5"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="Link" TargetType="Button">
      <Setter Property="Foreground" Value="#7DCFFF"/><Setter Property="Cursor" Value="Hand"/><Setter Property="FontSize" Value="11"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
        <TextBlock x:Name="t" Text="{TemplateBinding Content}" Foreground="{TemplateBinding Foreground}"/>
        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="t" Property="TextDecorations" Value="Underline"/></Trigger></ControlTemplate.Triggers>
      </ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style TargetType="CheckBox"><Setter Property="Foreground" Value="#C0CAF5"/><Setter Property="VerticalAlignment" Value="Center"/></Style>
    <Style TargetType="TextBox"><Setter Property="Background" Value="#24283B"/><Setter Property="Foreground" Value="#C0CAF5"/><Setter Property="BorderBrush" Value="#3B4261"/><Setter Property="Padding" Value="6,4"/><Setter Property="CaretBrush" Value="#C0CAF5"/></Style>
    <Style x:Key="Card" TargetType="ListBoxItem">
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem">
        <Border x:Name="bd" Margin="5" CornerRadius="10" BorderThickness="2" BorderBrush="Transparent" Background="#24283B" Cursor="Hand">
          <ContentPresenter/></Border>
        <ControlTemplate.Triggers>
          <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#565F89"/></Trigger>
          <Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="BorderBrush" Value="#7AA2F7"/><Setter TargetName="bd" Property="Background" Value="#2A3050"/></Trigger>
        </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
    </Style>
    <Style x:Key="ScrollPage" TargetType="RepeatButton">
      <Setter Property="Focusable" Value="False"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="RepeatButton"><Border Background="Transparent"/></ControlTemplate></Setter.Value></Setter>
    </Style>
    <ControlTemplate x:Key="ScrollThumb" TargetType="Thumb"><Border CornerRadius="4" Background="#3B4261"/></ControlTemplate>
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/><Setter Property="MinWidth" Value="8"/><Setter Property="Margin" Value="2,0,0,0"/>
      <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
        <Track x:Name="PART_Track" IsDirectionReversed="True">
          <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="ScrollBar.PageUpCommand"/></Track.DecreaseRepeatButton>
          <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="ScrollBar.PageDownCommand"/></Track.IncreaseRepeatButton>
          <Track.Thumb><Thumb Template="{StaticResource ScrollThumb}"/></Track.Thumb>
        </Track>
      </ControlTemplate></Setter.Value></Setter>
      <Style.Triggers>
        <Trigger Property="Orientation" Value="Horizontal">
          <Setter Property="Width" Value="Auto"/><Setter Property="MinWidth" Value="0"/><Setter Property="Height" Value="8"/><Setter Property="MinHeight" Value="8"/>
          <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track">
              <Track.DecreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="ScrollBar.PageLeftCommand"/></Track.DecreaseRepeatButton>
              <Track.IncreaseRepeatButton><RepeatButton Style="{StaticResource ScrollPage}" Command="ScrollBar.PageRightCommand"/></Track.IncreaseRepeatButton>
              <Track.Thumb><Thumb Template="{StaticResource ScrollThumb}"/></Track.Thumb>
            </Track>
          </ControlTemplate></Setter.Value></Setter>
        </Trigger>
      </Style.Triggers>
    </Style>
    <LinearGradientBrush x:Key="Wall" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#3D59A1" Offset="0"/><GradientStop Color="#9D7CD8" Offset="0.5"/><GradientStop Color="#FF9E64" Offset="1"/>
    </LinearGradientBrush>
    <PathGeometry x:Key="TrailPath" Figures="M 12,98 C 60,10 120,112 186,26"/>
  </Window.Resources>
  <Grid>
    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
    <Grid.ColumnDefinitions><ColumnDefinition Width="230"/><ColumnDefinition Width="*"/><ColumnDefinition Width="340"/></Grid.ColumnDefinitions>

    <!-- Cabecera -->
    <Border Grid.ColumnSpan="3" Background="#16161E" Padding="18,10">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal" VerticalAlignment="Center">
          <Button x:Name="BtnCatalog" Content="Actualizar catálogo"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal">
          <TextBlock FontSize="22" FontWeight="SemiBold" VerticalAlignment="Center"><Run Text="ZK" Foreground="#7AA2F7"/><Run Text="-Custom" Foreground="#BB9AF7"/></TextBlock>
          <TextBlock x:Name="WhStatus" Foreground="#565F89" FontSize="12" VerticalAlignment="Center" Margin="16,4,0,0"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- Navegación -->
    <ListBox x:Name="StepList" Grid.Row="1" Background="#16161E" BorderThickness="0" Padding="8,6" Foreground="#C0CAF5" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
      <ListBox.ItemContainerStyle><Style TargetType="ListBoxItem">
        <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="ListBoxItem">
          <Border x:Name="bd" CornerRadius="6" Margin="0,1" Background="Transparent" BorderThickness="3,0,0,0" BorderBrush="Transparent" Cursor="Hand"><ContentPresenter/></Border>
          <ControlTemplate.Triggers>
            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="bd" Property="Background" Value="#1F2335"/></Trigger>
            <Trigger Property="IsSelected" Value="True"><Setter TargetName="bd" Property="Background" Value="#24283B"/><Setter TargetName="bd" Property="BorderBrush" Value="#7AA2F7"/></Trigger>
          </ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
      </Style></ListBox.ItemContainerStyle>
      <ListBox.ItemTemplate><DataTemplate>
        <StackPanel Margin="6,1">
          <TextBlock Text="{Binding Group}" Foreground="#BB9AF7" FontSize="10" Visibility="{Binding GroupVis}" Margin="0,6,0,1"/>
          <DockPanel>
            <Ellipse DockPanel.Dock="Right" Width="7" Height="7" Fill="#E0AF68" Visibility="{Binding PendVis}" ToolTip="Cambio sin aplicar"/>
            <TextBlock Text="{Binding Title}" FontWeight="SemiBold"/>
          </DockPanel>
          <TextBlock Text="{Binding Choice}" Foreground="#565F89" FontSize="11" TextTrimming="CharacterEllipsis"/>
        </StackPanel>
      </DataTemplate></ListBox.ItemTemplate>
    </ListBox>

    <!-- Centro: vista previa + opciones -->
    <Grid Grid.Row="1" Grid.Column="1" Margin="18,12,12,6">
      <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
      <Border Background="#16161E" CornerRadius="12" Padding="8" HorizontalAlignment="Center">
        <Grid>
          <Image x:Name="Preview" MaxHeight="400" Stretch="Uniform" RenderOptions.BitmapScalingMode="HighQuality"/>
          <Border HorizontalAlignment="Left" VerticalAlignment="Top" Margin="10" Background="#CC16161E" CornerRadius="6" Padding="8,3">
            <TextBlock x:Name="PreviewLabel" Foreground="#C0CAF5" FontSize="11" Text="Vista previa"/>
          </Border>
        </Grid>
      </Border>
      <StackPanel Grid.Row="1" Margin="2,12,0,4">
        <TextBlock x:Name="StepTitle" FontSize="20" FontWeight="SemiBold"/>
        <TextBlock x:Name="StepHelp" Foreground="#9AA5CE" TextWrapping="Wrap" Margin="0,2,0,0"/>
      </StackPanel>
      <DockPanel x:Name="SearchRow" Grid.Row="2" Margin="2,4,0,4">
        <TextBlock Text="Buscar:" VerticalAlignment="Center" Foreground="#565F89" Margin="0,0,8,0"/>
        <TextBox x:Name="Search" Width="240" HorizontalAlignment="Left"/>
        <TextBlock x:Name="Count" VerticalAlignment="Center" Foreground="#565F89" Margin="12,0,0,0"/>
      </DockPanel>
      <Grid Grid.Row="3">
        <ListBox x:Name="Items" Background="Transparent" BorderThickness="0" ItemContainerStyle="{StaticResource Card}" Foreground="#C0CAF5"
                 ScrollViewer.HorizontalScrollBarVisibility="Disabled" VirtualizingPanel.IsVirtualizing="False">
          <ListBox.ItemsPanel><ItemsPanelTemplate><WrapPanel/></ItemsPanelTemplate></ListBox.ItemsPanel>
          <ListBox.ItemTemplate><DataTemplate>
            <StackPanel Width="200" Margin="8">
              <Grid Height="112" Background="#1A1B26" ClipToBounds="True">
                <Image Source="{Binding Preview}" Stretch="{Binding ImgStretch}" RenderOptions.BitmapScalingMode="HighQuality"/>
                <ItemsControl ItemsSource="{Binding Swatches}" HorizontalAlignment="Center" VerticalAlignment="Center">
                  <ItemsControl.ItemsPanel><ItemsPanelTemplate><StackPanel Orientation="Horizontal"/></ItemsPanelTemplate></ItemsControl.ItemsPanel>
                  <ItemsControl.ItemTemplate><DataTemplate><Border Width="26" Height="74" Margin="2" CornerRadius="5" Background="{Binding}"/></DataTemplate></ItemsControl.ItemTemplate>
                </ItemsControl>
                <!-- Efecto de ventana animado: la ventana se desliza y deja ver el fondo desenfocado -->
                <Grid Visibility="{Binding GlassVis}" Background="{StaticResource Wall}">
                  <Ellipse Width="60" Height="60" Fill="#F7768E" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="30,14,0,0"/>
                  <Ellipse Width="76" Height="76" Fill="#9ECE6A" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,24,4"/>
                  <Rectangle Width="14" Height="70" Fill="#FFFFFF" HorizontalAlignment="Center" Margin="0,0,0,0"/>
                  <Grid x:Name="Win" Width="128" Height="78" ClipToBounds="True">
                    <Grid.RenderTransform><TranslateTransform/></Grid.RenderTransform>
                    <Grid x:Name="Inner" Width="200" Height="112">
                      <Grid.RenderTransform><TranslateTransform/></Grid.RenderTransform>
                      <Grid.Effect><BlurEffect Radius="12"/></Grid.Effect>
                      <Rectangle Fill="{StaticResource Wall}"/>
                      <Ellipse Width="60" Height="60" Fill="#F7768E" HorizontalAlignment="Left" VerticalAlignment="Top" Margin="30,14,0,0"/>
                      <Ellipse Width="76" Height="76" Fill="#9ECE6A" HorizontalAlignment="Right" VerticalAlignment="Bottom" Margin="0,0,24,4"/>
                      <Rectangle Width="14" Height="70" Fill="#FFFFFF" HorizontalAlignment="Center"/>
                    </Grid>
                    <Border Background="#1A1B26" Opacity="{Binding GlassOpacity}"/>
                    <Border Height="14" VerticalAlignment="Top" Background="#24283B" Opacity="0.85"/>
                    <StackPanel Margin="8,22,8,0"><Border Height="4" Width="90" Background="#C0CAF5" CornerRadius="2" HorizontalAlignment="Left"/>
                      <Border Height="4" Width="70" Background="#A9B1D6" CornerRadius="2" HorizontalAlignment="Left" Margin="0,7,0,0"/></StackPanel>
                    <Border BorderBrush="#7AA2F7" BorderThickness="1" CornerRadius="6"/>
                  </Grid>
                </Grid>
                <!-- Estela animada: el puntero recorre la curva y la estela lo sigue -->
                <Canvas Visibility="{Binding TrailVis}" Background="#1A1B26">
                  <Path x:Name="TrailLine" Data="{StaticResource TrailPath}" Stroke="{Binding TrailBrush}" StrokeThickness="5" StrokeDashArray="{Binding TrailDash}"
                        StrokeDashCap="Round" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
                  <Path x:Name="Cursor" Data="M 0,0 L 0,16 L 4,12 L 7,19 L 10,18 L 7,11 L 12,11 Z" Fill="White" Stroke="Black" StrokeThickness="1">
                    <Path.RenderTransform><MatrixTransform/></Path.RenderTransform>
                  </Path>
                </Canvas>
                <TextBlock Text="{Binding Placeholder}" Foreground="#565F89" HorizontalAlignment="Center" VerticalAlignment="Center"/>
              </Grid>
              <TextBlock Text="{Binding Name}" FontWeight="SemiBold" Margin="0,7,0,1" TextTrimming="CharacterEllipsis"/>
              <TextBlock Text="{Binding Description}" Foreground="#9AA5CE" FontSize="11" TextWrapping="Wrap" MaxHeight="30" TextTrimming="CharacterEllipsis" ToolTip="{Binding Description}"/>
              <DockPanel Margin="0,3,0,0">
                <Button DockPanel.Dock="Right" Style="{StaticResource Link}" Content="Ver ejemplos ↗" Tag="{Binding Reference}" Visibility="{Binding RefVis}"/>
                <TextBlock Text="{Binding Badge}" Foreground="#E0AF68" FontSize="10" VerticalAlignment="Center"/>
              </DockPanel>
            </StackPanel>
            <DataTemplate.Triggers>
              <EventTrigger RoutedEvent="FrameworkElement.Loaded">
                <BeginStoryboard><Storyboard RepeatBehavior="Forever">
                  <DoubleAnimation Storyboard.TargetName="Win" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" From="-34" To="34" Duration="0:0:2.4" AutoReverse="True"/>
                  <DoubleAnimation Storyboard.TargetName="Inner" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" From="34" To="-34" Duration="0:0:2.4" AutoReverse="True"/>
                </Storyboard></BeginStoryboard>
                <BeginStoryboard><Storyboard RepeatBehavior="Forever" Duration="0:0:1.8">
                  <DoubleAnimationUsingKeyFrames Storyboard.TargetName="TrailLine" Storyboard.TargetProperty="StrokeDashOffset">
                    <LinearDoubleKeyFrame KeyTime="0:0:0" Value="40"/>
                    <LinearDoubleKeyFrame KeyTime="0:0:0.9" Value="-0.6"/>
                    <LinearDoubleKeyFrame KeyTime="0:0:1.4" Value="-40"/>
                  </DoubleAnimationUsingKeyFrames>
                  <MatrixAnimationUsingPath Storyboard.TargetName="Cursor" Storyboard.TargetProperty="(UIElement.RenderTransform).(MatrixTransform.Matrix)" PathGeometry="{StaticResource TrailPath}" Duration="0:0:0.9"/>
                </Storyboard></BeginStoryboard>
              </EventTrigger>
            </DataTemplate.Triggers>
          </DataTemplate></ListBox.ItemTemplate>
        </ListBox>
        <ScrollViewer x:Name="TweaksPanel" Visibility="Collapsed" VerticalScrollBarVisibility="Auto"><StackPanel x:Name="TweaksList"/></ScrollViewer>
        <TextBox x:Name="Summary" Visibility="Collapsed" IsReadOnly="True" FontFamily="Cascadia Mono, Consolas" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
      </Grid>
    </Grid>

    <!-- Panel derecho: Ajustes / Registro -->
    <Border Grid.Row="1" Grid.Column="2" Background="#16161E" BorderBrush="#24283B" BorderThickness="1,0,0,0">
      <DockPanel Margin="14,12">
        <Border DockPanel.Dock="Top" Background="#1A1B26" CornerRadius="8" Padding="3" Margin="0,0,0,12">
          <UniformGrid Columns="2">
            <ToggleButton x:Name="TabOpts" Style="{StaticResource Seg}" Content="Ajustes" IsChecked="True"/>
            <ToggleButton x:Name="TabLog" Style="{StaticResource Seg}" Content="Registro"/>
          </UniformGrid>
        </Border>
        <Grid>
          <DockPanel x:Name="OptsPane">
            <Border x:Name="ModeBar" DockPanel.Dock="Top" Background="#1A1B26" CornerRadius="8" Padding="3" Margin="0,0,0,12">
              <UniformGrid Columns="2">
                <ToggleButton x:Name="ModeBasic" Style="{StaticResource Seg}" Content="Básico" IsChecked="True"/>
                <ToggleButton x:Name="ModeAdv" Style="{StaticResource Seg}" Content="Avanzado"/>
              </UniformGrid>
            </Border>
            <ScrollViewer VerticalScrollBarVisibility="Auto"><StackPanel x:Name="OptsList"/></ScrollViewer>
          </DockPanel>
          <DockPanel x:Name="LogPane" Visibility="Collapsed">
            <TextBlock DockPanel.Dock="Bottom" Foreground="#565F89" FontSize="11" TextWrapping="Wrap" Margin="0,6,0,0" Text="[OK] hecho · [--] sin cambios · [!!] aviso · [XX] error"/>
            <TextBox x:Name="Log" IsReadOnly="True" FontFamily="Cascadia Mono, Consolas" FontSize="11" Background="#1A1B26" BorderThickness="0" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"/>
          </DockPanel>
        </Grid>
      </DockPanel>
    </Border>

    <!-- Pie -->
    <Border Grid.Row="2" Grid.ColumnSpan="3" Background="#16161E" Padding="18,10">
      <DockPanel>
        <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
          <Button x:Name="BtnUndo" Content="Deshacer último cambio" IsEnabled="False"/>
          <Button x:Name="BtnSave" Content="Guardar en config.json"/>
          <Button x:Name="BtnApply" Content="Aplicar a mi PC" Style="{StaticResource Primary}" Padding="20,8"/>
        </StackPanel>
        <TextBlock x:Name="Status" VerticalAlignment="Center" Foreground="#9AA5CE" TextTrimming="CharacterEllipsis"/>
      </DockPanel>
    </Border>
  </Grid>
</Window>
'@

# Los colores de la interfaz son recursos dinámicos: siguen tu paleta (o los de Windows)
$UiKeys = [ordered]@{ '#1A1B26' = 'C_Bg'; '#16161E' = 'C_Panel'; '#24283B' = 'C_Surface'; '#C0CAF5' = 'C_Text'; '#9AA5CE' = 'C_Sub'; '#565F89' = 'C_Muted'
                      '#7AA2F7' = 'C_Accent'; '#BB9AF7' = 'C_Accent2'; '#3B4261' = 'C_Border'; '#1F2335' = 'C_Hover'; '#2A3050' = 'C_Sel'; '#7DCFFF' = 'C_Link'; '#E0AF68' = 'C_Warn'; '#CC16161E' = 'C_Glass' }
foreach ($kv in $UiKeys.GetEnumerator()) { $XamlText = $XamlText.Replace("`"$($kv.Key)`"", "`"{DynamicResource $($kv.Value)}`"") }
$res = ($UiKeys.Values | ForEach-Object { "<SolidColorBrush x:Key=`"$_`" Color=`"#000000`"/>" }) -join ''
$XamlText = $XamlText.Replace('<Window.Resources>', "<Window.Resources>$res")
[xml]$xaml = $XamlText
$Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

function Get-WindowsPalette {
    # Colores de Windows: acento del sistema y modo claro/oscuro
    $light = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -ErrorAction SilentlyContinue).AppsUseLightTheme -eq 1
    $acc = '#4CC2FF'
    $dw = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\DWM' -ErrorAction SilentlyContinue).AccentColor
    if ($null -ne $dw) { $v = [uint32]([int64]$dw -band 0xFFFFFFFF); $acc = '#{0:X2}{1:X2}{2:X2}' -f ($v -band 0xFF), (($v -shr 8) -band 0xFF), (($v -shr 16) -band 0xFF) }
    if ($light) { @{ base = '#F3F3F3'; surface = '#FFFFFF'; text = '#1B1B1B'; muted = '#6B6B6B'; primary = $acc; secondary = (Get-Shade $acc -0.25); highlight = (Get-Shade $acc 0.3) } }
    else { @{ base = '#202020'; surface = '#2B2B2B'; text = '#FFFFFF'; muted = '#9A9A9A'; primary = $acc; secondary = (Get-Shade $acc 0.25); highlight = (Get-Shade $acc 0.45) } }
}

function Set-UiTheme($p) {
    # Recalcula los colores de la ventana a partir de una paleta (base, superficie, texto, acentos)
    if (-not $p -or -not $p.base) { $p = Get-WindowsPalette }
    $isLight = (Get-Col $p.base).R -gt 160
    $sh = { param($hex, $a) Get-Shade $hex $(if ($isLight) { -$a } else { $a }) }
    $map = @{
        C_Bg = $p.base; C_Panel = (& $sh $p.base -0.25); C_Surface = $p.surface; C_Text = $p.text; C_Muted = $p.muted
        C_Sub = $(if ($isLight) { Get-Shade $p.text 0.3 } else { Get-Shade $p.text -0.18 }); C_Accent = $p.primary; C_Accent2 = $p.secondary
        C_Border = (& $sh $p.surface 0.18); C_Hover = (& $sh $p.base 0.06); C_Link = $p.highlight; C_Warn = $(if ($p.ansi -and $p.ansi.yellow) { $p.ansi.yellow } else { '#E0AF68' })
    }
    $sc = Get-Col $map.C_Surface; $ac = Get-Col $p.primary
    $map.C_Sel = '#{0:X2}{1:X2}{2:X2}' -f [int](($sc.R * 0.75) + ($ac.R * 0.25)), [int](($sc.G * 0.75) + ($ac.G * 0.25)), [int](($sc.B * 0.75) + ($ac.B * 0.25))
    # Se cambia el color de los pinceles existentes (los controles que los usan se repintan solos)
    $g = Get-Col $map.C_Panel; $g.A = 0xCC
    foreach ($k in @($map.Keys) + 'C_Glass') {
        $c = if ($k -eq 'C_Glass') { $g } else { Get-Col $map[$k] }
        # Las plantillas de WPF exigen pinceles congelados: se sustituye el recurso por uno nuevo congelado
        $nb = New-Object Windows.Media.SolidColorBrush $c; $nb.Freeze()
        $Window.Resources[$k] = $nb.PSObject.BaseObject   # sin el envoltorio de PowerShell
    }
    $Window.Background = $Window.Resources['C_Bg']; $Window.Foreground = $Window.Resources['C_Text']
    $State.UiOnAccent = $(if (((Get-Col $p.primary).R * 0.3 + (Get-Col $p.primary).G * 0.59 + (Get-Col $p.primary).B * 0.11) -gt 150) { '#111111' } else { '#FFFFFF' })
}
function Update-UiTheme { Set-UiTheme $(if ($State.Config.wizard.selections.palette) { $State.Config.palette } else { $null }) }
function Set-Res($el, $prop, [string]$key) { $el.SetResourceReference($prop, $key) }
function UiB([string]$key) { $Window.Resources[$key] }
$UI = @{}
foreach ($n in 'BtnCatalog','WhStatus','StepList','Preview','PreviewLabel','StepTitle','StepHelp','SearchRow','Search','Count','Items','TweaksPanel','TweaksList','Summary',
               'TabOpts','TabLog','OptsPane','ModeBar','ModeBasic','ModeAdv','OptsList','LogPane','Log','BtnUndo','BtnSave','BtnApply','Status') { $UI[$n] = $Window.FindName($n) }

function Set-Status($text) { $UI.Status.Text = $text }
function Show-Tab([string]$t) {
    $UI.TabOpts.IsChecked = ($t -eq 'opts'); $UI.TabLog.IsChecked = ($t -eq 'log')
    $UI.OptsPane.Visibility = $(if ($t -eq 'opts') { 'Visible' } else { 'Collapsed' })
    $UI.LogPane.Visibility = $(if ($t -eq 'log') { 'Visible' } else { 'Collapsed' })
}
function Update-ApplyButton {
    $n = $State.Pending.Count
    $UI.BtnApply.Content = $(if ($n) { "Aplicar a mi PC ($n)" } else { 'Aplicar a mi PC' })
}
function Update-WindhawkStatus {
    $i = Get-WindhawkInfo
    $UI.WhStatus.Text = "Windows 11 · compilación $Build · " + $(if ($i.Cli) { "Windhawk $($i.Version) oculto" } else { 'Windhawk se instalará solo y oculto al aplicar' })
}

# ---------------- Vista previa ----------------

$RenderTimer = New-Object Windows.Threading.DispatcherTimer
$RenderTimer.Interval = [TimeSpan]::FromMilliseconds(90)
$RenderTimer.Add_Tick({
    $RenderTimer.Stop()
    try { Update-Preview; if ($Steps[$State.Index].Kind -eq 'themes') { Update-ThemeCards } }
    catch { Set-Status "No se pudo dibujar la vista previa: $($_.Exception.Message)" }
})
function Request-Render { $RenderTimer.Stop(); $RenderTimer.Start() }

function Update-Preview {
    $step = $Steps[$State.Index]
    $ov = @{}
    $State.HoverStep = $null
    if ($State.Hover -and $step.Kind -ne 'themes') { $ov[$step.Key] = $State.Hover }
    if ($step.Kind -eq 'themes') {
        $t = if ($State.Hover) { $State.Hover } else { Find-Item 'themes' $State.Config.wizard.selections.themes }
        if ($t) { foreach ($k in $t.Raw.selections.Keys) { $it = Find-Item $k $t.Raw.selections[$k]; if ($it) { $ov[$k] = $it } } }
    }
    $sel = Get-CurrentSel $ov
    if ($step.Region) { $State.HoverStep = $step.Key }
    $focus = if ($step.Region) { $step.Region } else { '' }
    $UI.Preview.Source = Render-Desktop $sel $focus
    $what = if ($State.Hover) { $State.Hover.Name } else { Get-SelectionName $step }
    $UI.PreviewLabel.Text = "Vista previa" + $(if ($what -and $step.Kind -ne 'summary') { "  ·  $what" } else { '' })
}

$ThemeImgs = @{}
function Update-ThemeCards {
    # Cada tema se dibuja con el mismo escritorio simulado; se crean tarjetas nuevas para que WPF las repinte
    foreach ($it in (Get-StepItems $StepByKey.themes)) {
        $ov = @{}; foreach ($k in $it.Raw.selections.Keys) { $x = Find-Item $k $it.Raw.selections[$k]; if ($x) { $ov[$k] = $x } }
        $it.Preview = Render-Desktop (Get-CurrentSel $ov) '' 0.5
    }
}

# ---------------- Lista de pasos y tarjetas ----------------

function Update-StepList {
    $sel = $UI.StepList.SelectedIndex; $last = ''
    $UI.StepList.ItemsSource = @($Steps | ForEach-Object {
        $g = $_.Group; $show = ($g -and $g -ne $last); $last = $g
        $pend = @($_.Modules | Where-Object { $_ -and $State.Pending.Contains($_) }).Count -gt 0 -and ($State.Config.wizard.selections.Contains($_.Key) -or $_.Kind -eq 'tweaks')
        [pscustomobject]@{ Title = $_.Title; Group = $g.ToUpper(); GroupVis = $(if ($show) { 'Visible' } else { 'Collapsed' })
                           Choice = $(if ($_.Key -eq 'summary') { '' } else { Get-SelectionName $_ }); PendVis = $(if ($pend) { 'Visible' } else { 'Collapsed' }) }
    })
    $UI.StepList.SelectedIndex = $(if ($sel -ge 0) { $sel } else { $State.Index })
    Update-ApplyButton
}

function Get-LocalWallItem {
    $w = $State.Config.wallpaper
    if (-not $w.file) { return $null }
    $p = Join-Path $Root $w.file
    if (-not (Test-Path $p)) { return $null }
    $bmp = New-Object Windows.Media.Imaging.BitmapImage
    $bmp.BeginInit(); $bmp.CacheOption = 'OnLoad'; $bmp.UriSource = [uri]$p; $bmp.DecodePixelWidth = 1280; $bmp.EndInit(); $bmp.Freeze()
    New-Object ZK.Card -Property @{ Id = 'local'; Name = 'Tu imagen'; Description = [IO.Path]::GetFileName($p); Category = '*'; Preview = $bmp; PreviewLarge = $bmp
        Swatches = $null; Placeholder = ''; Badge = 'De tu equipo'; Reference = $null; RefVis = 'Collapsed'
        ImgStretch = 'UniformToFill'; GlassVis = 'Collapsed'; GlassOpacity = 1.0; TrailVis = 'Collapsed'; TrailBrush = $null; TrailDash = '0 1 0 400'; Raw = @{ apply = @{ type = 'wallpaper-local' } } }
}

function Update-Items {
    $step = $Steps[$State.Index]
    $q = $UI.Search.Text.Trim()
    $all = @(Get-StepItems $step)
    $view = $all
    if ($step.Key -eq 'wallpaper' -and -not $q) { $view = @($all | Where-Object { $_.Category -eq $State.Category }) }
    if ($q) { $view = @($all | Where-Object { $_.Name -like "*$q*" -or $_.Description -like "*$q*" -or $_.Category -like "*$q*" }) }
    if ($step.Key -eq 'wallpaper') { $view = @($view | Select-Object -First 80); $loc = Get-LocalWallItem; if ($loc) { $view = @($loc) + $view } }
    $State.Items = $view
    $State.Loading = $true
    $UI.Items.ItemsSource = $State.Items
    $id = $State.Config.wizard.selections[$step.Key]
    $UI.Items.SelectedItem = $State.Items | Where-Object { $_.Id -eq $id } | Select-Object -First 1
    $State.Loading = $false
    $UI.Count.Text = "$($State.Items.Count) de $($all.Count) opciones"
    # Pre-carga de las imágenes grandes de lo que se ve
    foreach ($it in ($view | Select-Object -First 40)) { if ($it.PreviewLarge -is [string]) { Add-Download $it.PreviewLarge -Priority } }
}

function Build-Tweaks {
    $UI.TweaksList.Children.Clear()
    $cat = Read-Json (Join-Path $CatalogDir 'static\tweaks.json')
    $last = ''
    foreach ($t in $cat) {
        if ($t.group -ne $last) {
            [void]$UI.TweaksList.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.group; Foreground = (UiB 'C_Accent2'); FontWeight = 'SemiBold'; FontSize = 14; Margin = '0,12,0,6' }))
            $last = $t.group
        }
        $sp = New-Object Windows.Controls.StackPanel
        [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.name; FontWeight = 'SemiBold'; Foreground = (UiB 'C_Text') }))
        [void]$sp.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = $t.description; Foreground = (UiB 'C_Sub'); FontSize = 11; TextWrapping = 'Wrap'; MaxWidth = 700 }))
        $cb = New-Object Windows.Controls.CheckBox -Property @{ Content = $sp; Tag = $t.id; Margin = '4,4,0,6'; VerticalContentAlignment = 'Top' }
        $cb.IsChecked = [bool]$State.Config.tweaks[$t.id]
        $cb.Add_Click({ param($s) $State.Config.tweaks[$s.Tag] = [bool]$s.IsChecked; $State.Config.modules.Tweaks = $true; Add-Pending $StepByKey.tweaks; Update-StepList })
        [void]$UI.TweaksList.Children.Add($cb)
    }
}

# ---------------- Panel de ajustes ----------------

function New-Label([string]$t) { New-Object Windows.Controls.TextBlock -Property @{ Text = $t; Foreground = (UiB 'C_Sub'); Margin = '0,10,0,4'; TextWrapping = 'Wrap' } }

function On-OptionChanged($step) {
    $id = $State.Config.wizard.selections[$step.Key]
    $it = Find-Item $step.Key $id
    if ($it) { Set-Selection $step $it }
    elseif ($step.Opts -eq 'styler') { $none = Find-Item $step.Key 'none'; if ($none) { Set-Selection $step $none } }
    else { Add-Pending $step }
    if ($step.Key -in 'trail') { $State.AllItems.Remove($step.Key); Update-Items }
    Update-StepList; Request-Render
}

function Build-Options {
    $step = $Steps[$State.Index]
    $UI.OptsList.Children.Clear()
    $specs = @()
    if ($step.Key -eq 'taskbar') { $specs += $OptSpecs.taskbarNative }
    if ($step.Opts) { $specs += $OptSpecs[$step.Opts] }
    $hasAdv = @($specs | Where-Object { $_.Adv }).Count -gt 0
    $UI.ModeBar.Visibility = $(if ($hasAdv) { 'Visible' } else { 'Collapsed' })
    if (-not $specs) {
        [void]$UI.OptsList.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = 'Esta sección no tiene ajustes extra. Elige una opción y mira la vista previa.'; Foreground = (UiB 'C_Muted'); TextWrapping = 'Wrap' }))
        return
    }
    if ($step.Opts -eq 'styler') {
        [void]$UI.OptsList.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = 'Se suman al tema elegido. Algunos temas usan sus propios colores y pueden ignorar parte de estos ajustes.'; Foreground = (UiB 'C_Muted'); FontSize = 11; TextWrapping = 'Wrap'; Margin = '0,0,0,4' }))
    }
    $o = Get-Opts $step
    $p = Get-Palette (Get-CurrentSel)
    foreach ($s in $specs) {
        if ($s.Adv -and -not $State.Advanced) { continue }
        $val = if ($s.Cfg) { Get-CfgValue $s.K } else { $o[$s.K] }
        switch ($s.T) {
            'toggle' {
                $cb = New-Object Windows.Controls.CheckBox -Property @{ Content = $s.L; Margin = '0,10,0,0'; Tag = $s }
                $cb.IsChecked = $(if ($s.On) { $val -ne $s.Off } else { [bool]$val })
                $cb.Add_Click({ param($c) $sp = $c.Tag; $st = $Steps[$State.Index]
                    $v = if ($sp.On) { $(if ($c.IsChecked) { $sp.On } else { $sp.Off }) } else { [bool]$c.IsChecked }
                    if ($sp.Cfg) { Set-CfgValue $sp.K $v; Add-Pending $st; Update-StepList; Request-Render } else { $State.Config.wizard.options[$st.Key][$sp.K] = $v; On-OptionChanged $st } })
                [void]$UI.OptsList.Children.Add($cb)
            }
            'slider' {
                if ($null -eq $val) { $val = $s.D }
                $lbl = New-Label "$($s.L): $val$($s.U)"
                $sl = New-Object Windows.Controls.Slider -Property @{ Minimum = $s.Min; Maximum = $s.Max; Value = [double]$val; IsSnapToTickEnabled = $true; TickFrequency = $(if ($s.Step) { $s.Step } else { 1 }); Tag = @{ S = $s; L = $lbl } }
                $sl.Add_ValueChanged({ param($c) $sp = $c.Tag.S; $v = [int]$c.Value; $c.Tag.L.Text = "$($sp.L): $v$($sp.U)"; $st = $Steps[$State.Index]
                    if ($sp.Cfg) { Set-CfgValue $sp.K $v; Add-Pending $st; $State.OptTimerStep = $null } else { $State.Config.wizard.options[$st.Key][$sp.K] = $v; $State.OptTimerStep = $st }
                    $OptTimer.Stop(); $OptTimer.Start() })
                [void]$UI.OptsList.Children.Add($lbl); [void]$UI.OptsList.Children.Add($sl)
            }
            'color' {
                [void]$UI.OptsList.Children.Add((New-Label $s.L))
                $wp = New-Object Windows.Controls.WrapPanel
                $tb = New-Object Windows.Controls.TextBox -Property @{ Text = $val; Width = 74; Margin = '0,0,6,4'; ToolTip = 'Color en hexadecimal, por ejemplo #7AA2F7. Vacío = automático'; Tag = $s }
                $tb.Add_LostFocus({ param($c) $t = $c.Text.Trim(); if ($t -and $t -notmatch '^#[0-9A-Fa-f]{6}$') { $c.Text = ''; $t = '' }
                    $st = $Steps[$State.Index]; $State.Config.wizard.options[$st.Key][$c.Tag.K] = $t; On-OptionChanged $st })
                [void]$wp.Children.Add($tb)
                foreach ($hex in @('', $p.primary, $p.secondary, $p.highlight, $p.base, $p.surface, $p.text, '#FFFFFF', '#000000')) {
                    $btn = New-Object Windows.Controls.Button -Property @{ Width = 20; Height = 20; Padding = '0'; Margin = '0,0,3,4'; Tag = @{ S = $s; H = $hex; T = $tb }; ToolTip = $(if ($hex) { $hex } else { 'Automático (el del tema)' }) }
                    $btn.Background = $(if ($hex) { B $hex } else { UiB 'C_Surface' }); if (-not $hex) { $btn.Content = 'A'; $btn.FontSize = 10 }
                    if ($val -eq $hex -and $hex) { $btn.BorderBrush = UiB 'C_Text' }
                    $btn.Add_Click({ param($c) $st = $Steps[$State.Index]; $c.Tag.T.Text = $c.Tag.H; $State.Config.wizard.options[$st.Key][$c.Tag.S.K] = $c.Tag.H; On-OptionChanged $st; Build-Options })
                    [void]$wp.Children.Add($btn)
                }
                [void]$UI.OptsList.Children.Add($wp)
            }
            'choice' {
                [void]$UI.OptsList.Children.Add((New-Label $s.L))
                $cmb = New-Object Windows.Controls.ComboBox -Property @{ ItemsSource = $s.Choices; Tag = $s; Foreground = '#1A1B26' }
                $cmb.SelectedItem = $(if ($val) { $val } else { $s.D })
                $cmb.Add_SelectionChanged({ param($c) if ($State.Loading) { return }; $st = $Steps[$State.Index]
                    if ($c.Tag.Cfg) { Set-CfgValue $c.Tag.K $c.SelectedItem; Add-Pending $st; Update-StepList } else { $State.Config.wizard.options[$st.Key][$c.Tag.K] = $c.SelectedItem; On-OptionChanged $st } })
                [void]$UI.OptsList.Children.Add($cmb)
            }
            'search' {
                [void]$UI.OptsList.Children.Add((New-Label 'Buscar orbs de un personaje o juego'))
                $dp = New-Object Windows.Controls.DockPanel
                $go = New-Object Windows.Controls.Button -Property @{ Content = 'Buscar'; Padding = '10,4' }
                [Windows.Controls.DockPanel]::SetDock($go, 'Right'); [void]$dp.Children.Add($go)
                $q = New-Object Windows.Controls.TextBox -Property @{ Text = $State.OrbQuery; ToolTip = 'Por ejemplo: Zelda, Halo, Sonic, Hollow Knight' }
                [void]$dp.Children.Add($q); $go.Tag = $q
                $go.Add_Click({ param($c) $txt = $c.Tag.Text.Trim(); if (-not $txt) { return }; $State.OrbQuery = $txt
                    # Imágenes con fondo transparente (Google) y la comunidad de orbs de DeviantArt
                    Start-Process ('https://www.google.com/search?tbm=isch&tbs=ic:trans&q=' + [uri]::EscapeDataString("$txt start orb png"))
                    Start-Process ('https://www.deviantart.com/search?q=' + [uri]::EscapeDataString("$txt start orb")) })
                [void]$UI.OptsList.Children.Add($dp)
                [void]$UI.OptsList.Children.Add((New-Object Windows.Controls.TextBlock -Property @{ Text = 'Descarga los que te gusten (mejor PNG cuadrado con fondo transparente) y añádelos con el botón de abajo. Quedan guardados en «Mis orbs».'; Foreground = (UiB 'C_Muted'); FontSize = 11; TextWrapping = 'Wrap'; Margin = '0,4,0,0' }))
            }
            'category' {
                [void]$UI.OptsList.Children.Add((New-Label $s.L))
                $cmb = New-Object Windows.Controls.ComboBox -Property @{ MaxDropDownHeight = 460; Foreground = '#1A1B26' }
                $cmb.ItemsSource = @(Get-StepItems $step | ForEach-Object { $_.Category } | Select-Object -Unique)
                $State.Loading = $true; $cmb.SelectedItem = $State.Category; $State.Loading = $false
                $cmb.Add_SelectionChanged({ param($c) if ($State.Loading -or -not $c.SelectedItem) { return }; $State.Category = $c.SelectedItem; $UI.Search.Text = ''; Update-Items })
                [void]$UI.OptsList.Children.Add($cmb)
            }
            'button' {
                $btn = New-Object Windows.Controls.Button -Property @{ Content = $s.L; Margin = '0,14,0,0'; HorizontalAlignment = 'Left'; Tag = $s.K }
                $btn.Add_Click({ param($c) switch ($c.Tag) { 'uploadOrb' { Select-CustomOrb } 'importOrbs' { Import-OrbLibrary } 'removeOrb' { Remove-LibraryOrb } 'pickVideo' { Select-AnimatedVideo } default { Select-LocalWallpaper } } })
                if ($s.K -eq 'removeOrb' -and "$($State.Config.wizard.selections.startbtn)" -notlike 'lib-*') { continue }
                if ($s.K -eq 'uploadOrb') {
                    [void]$UI.OptsList.Children.Add($btn)
                    $btn = New-Object Windows.Controls.TextBlock -Property @{ Text = 'Puedes elegir 1, 2 o 3 imágenes (PNG, JPG o GIF animado): la primera es la normal, la segunda al pasar el ratón y la tercera al pulsar.'; Foreground = (UiB 'C_Muted'); FontSize = 11; TextWrapping = 'Wrap'; Margin = '0,4,0,0' }
                }
                [void]$UI.OptsList.Children.Add($btn)
            }
        }
    }
}

$OptTimer = New-Object Windows.Threading.DispatcherTimer
$OptTimer.Interval = [TimeSpan]::FromMilliseconds(220)
$OptTimer.Add_Tick({ $OptTimer.Stop(); if ($State.OptTimerStep) { On-OptionChanged $State.OptTimerStep } else { Update-StepList; Request-Render } })

function Select-LocalWallpaper {
    $dlg = New-Object Microsoft.Win32.OpenFileDialog
    $dlg.Filter = 'Imágenes|*.png;*.jpg;*.jpeg;*.bmp;*.webp'
    if ($dlg.ShowDialog($Window)) {
        $dir = Join-Path $Root 'assets\wallpapers'; New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $ext = [IO.Path]::GetExtension($dlg.FileName).ToLower()
        Get-ChildItem $dir -Filter 'main.*' | Remove-Item -Force -ErrorAction SilentlyContinue
        Copy-Item $dlg.FileName (Join-Path $dir "main$ext") -Force
        $w = $State.Config.wallpaper
        $w.file = "assets/wallpapers/main$ext"; $w.url = $null; $w.name = $null
        $State.Config.modules.Wallpaper = $true; $State.Config.wizard.selections.wallpaper = 'local'; $State.LocalWall = $null
        Add-Pending $StepByKey.wallpaper
        Update-Items; Update-StepList; Request-Render
        Set-Status 'Imagen elegida. Pulsa "Aplicar a mi PC" para ponerla de fondo.'
    }
}

# ---------------- Mostrar un paso ----------------

function Show-Step([int]$i) {
    $State.Index = [Math]::Max(0, [Math]::Min($i, $Steps.Count - 1))
    $step = $Steps[$State.Index]
    $State.Hover = $null
    $UI.StepTitle.Text = $step.Title
    $UI.StepHelp.Text = $step.Help
    $isList = $step.Kind -notin 'tweaks', 'summary', 'folders'
    $UI.Items.Visibility       = $(if ($isList) { 'Visible' } else { 'Collapsed' })
    $UI.SearchRow.Visibility   = $(if ($isList -and $step.Kind -ne 'themes') { 'Visible' } else { 'Collapsed' })
    $UI.TweaksPanel.Visibility = $(if ($step.Kind -in 'tweaks', 'folders') { 'Visible' } else { 'Collapsed' })
    $UI.Summary.Visibility     = $(if ($step.Kind -eq 'summary') { 'Visible' } else { 'Collapsed' })
    if ($isList) { $UI.Search.Text = ''; if ($step.Kind -eq 'themes') { Update-ThemeCards }; Update-Items }
    if ($step.Kind -eq 'tweaks') { Build-Tweaks }
    if ($step.Kind -eq 'folders') { Build-Folders }
    if ($step.Kind -eq 'summary') { Update-Summary }
    Build-Options
    if ($UI.StepList.SelectedIndex -ne $State.Index) { $UI.StepList.SelectedIndex = $State.Index }
    Request-Render
}

function Update-Summary {
    $lines = @('TUS ELECCIONES', '==============', '')
    foreach ($s in $Steps) { if ($s.Key -notin 'summary', 'themes') { $lines += ('{0,-26} {1}' -f $s.Title, (Get-SelectionName $s)) } }
    $t = $State.Config.taskbar
    $lines += '', ('Barra: centrada={0}  sin búsqueda={1}  sin vista de tareas={2}  sin widgets={3}' -f ($t.alignment -ne 'left'), [bool]$t.hideSearch, [bool]$t.hideTaskView, [bool]$t.hideWidgets)
    $lines += ('Windhawk (oculto): {0} mods' -f @($State.Config.windhawk.mods).Count)
    foreach ($m in @($State.Config.windhawk.mods)) {
        $n = if ($m.settings) { @($m.settings.Keys).Count } else { 0 }
        $lines += ('  - {0} [{1}] {2} ajustes' -f $m.id, $(if ($m.enabled) { 'activo' } else { 'desactivado' }), $n)
    }
    $lines += '', $(if ($State.Pending.Count) { "Pendiente de aplicar: $(@($State.Pending) -join ', ')" } else { 'Todo aplicado.' })
    $lines += $(if ($State.Dirty) { 'Hay cambios sin guardar en config.json.' } else { 'config.json está al día.' })
    $UI.Summary.Text = $lines -join "`r`n"
}

# ---------------- Aplicar / deshacer ----------------

$Timer = New-Object Windows.Threading.DispatcherTimer
$Timer.Interval = [TimeSpan]::FromMilliseconds(600)
$Timer.Add_Tick({
    if ($State.LogPath -and (Test-Path $State.LogPath)) {
        try {
            $fs = [IO.File]::Open($State.LogPath, 'Open', 'Read', 'ReadWrite'); $sr = New-Object IO.StreamReader($fs)
            $txt = $sr.ReadToEnd(); $sr.Close()
            $txt = ($txt -split "`r?`n" | Where-Object { $_ -match '^(\[|===|\s*$)' }) -join "`r`n"
            $txt = ($txt -replace "(`r`n){3,}", "`r`n`r`n").Trim()
            if ($UI.Log.Text -ne $txt) { $UI.Log.Text = $txt; $UI.Log.ScrollToEnd() }
        } catch { }
    }
    if ($State.Proc -and $State.Proc.HasExited) {
        $Timer.Stop()
        $code = $State.Proc.ExitCode; $State.Proc = $null
        $failed = $UI.Log.Text -match '\[XX\]'
        if (-not $State.Undoing -and $code -eq 0) { $State.Pending.Clear(); $State.PendingRestart = $false }
        $State.Undoing = $false
        Set-Status $(if ($code -ne 0 -or $failed) { 'Terminado con errores: revisa el Registro (líneas [XX]).' } else { 'Listo. Si algo no te gusta, pulsa "Deshacer último cambio".' })
        foreach ($b in 'BtnApply', 'BtnCatalog') { $UI[$b].IsEnabled = $true }
        $UI.BtnUndo.IsEnabled = [bool]$State.LastBackup
        Update-WindhawkStatus; Update-StepList
    }
})

function Start-Run([string[]]$Modules, [bool]$Restart, [string]$Label) {
    if ($State.Proc) { return }
    if (-not $Modules) { Set-Status 'No hay cambios pendientes.'; return }
    $tmp = Join-Path $CacheDir 'wizard-config.json'
    Write-Json $State.Config $tmp
    $bd = Join-Path $Root ("backups\" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-$Label")
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\Install.ps1`"", '-ConfigPath', "`"$tmp`"", '-BackupDir', "`"$bd`"", '-Only', ($Modules -join ','))
    if ($State.RestorePointDone) { $a += '-SkipRestorePoint' } else { $State.RestorePointDone = $true }
    if (-not $Restart) { $a += '-NoExplorerRestart' }
    $State.LastBackup = $bd; $State.LogPath = Join-Path $bd 'install.log'
    $UI.Log.Text = ''
    $State.Proc = Start-Process powershell.exe -ArgumentList $a -PassThru -WindowStyle Hidden
    foreach ($b in 'BtnApply', 'BtnUndo', 'BtnCatalog') { $UI[$b].IsEnabled = $false }
    Show-Tab 'log'
    Set-Status "Aplicando: $($Modules -join ', ')..."
    $Timer.Start()
}

function Start-Undo {
    if ($State.Proc -or -not $State.LastBackup) { return }
    $log = Join-Path $State.LastBackup 'restore.log'
    $State.LogPath = $log; $UI.Log.Text = ''; $State.Undoing = $true
    $State.Proc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Root\Restore.ps1`"", '-BackupDir', "`"$($State.LastBackup)`"") `
                  -PassThru -WindowStyle Hidden -RedirectStandardOutput $log
    foreach ($b in 'BtnApply', 'BtnUndo', 'BtnCatalog') { $UI[$b].IsEnabled = $false }
    Show-Tab 'log'
    Set-Status "Deshaciendo $([IO.Path]::GetFileName($State.LastBackup))..."
    $State.LastBackup = $null
    $Timer.Start()
}

# ---------------- Eventos ----------------

$UI.StepList.Add_SelectionChanged({ if ($UI.StepList.SelectedIndex -ge 0 -and $UI.StepList.SelectedIndex -ne $State.Index) { Show-Step $UI.StepList.SelectedIndex } })
$UI.Search.Add_TextChanged({ Update-Items })
$UI.TabOpts.Add_Click({ Show-Tab 'opts' })
$UI.TabLog.Add_Click({ Show-Tab 'log' })
$UI.ModeBasic.Add_Click({ $State.Advanced = $false; $UI.ModeBasic.IsChecked = $true; $UI.ModeAdv.IsChecked = $false; Build-Options })
$UI.ModeAdv.Add_Click({ $State.Advanced = $true; $UI.ModeBasic.IsChecked = $false; $UI.ModeAdv.IsChecked = $true; Build-Options })

$UI.Items.Add_SelectionChanged({
    if ($State.Loading -or -not $UI.Items.SelectedItem) { return }
    $step = $Steps[$State.Index]; $it = $UI.Items.SelectedItem
    if ($step.Kind -eq 'themes') {
        foreach ($k in $it.Raw.selections.Keys) { $x = Find-Item $k $it.Raw.selections[$k]; if ($x) { Set-Selection $StepByKey[$k] $x -FromUser } }
        $State.Config.wizard.selections.themes = $it.Id
        Update-DependentSteps; Update-UiTheme; $UI.TweaksList.Children.Clear()
        Set-Status "Tema «$($it.Name)» elegido. Ajusta lo que quieras en las secciones o pulsa ""Aplicar a mi PC""."
    } else {
        Set-Selection $step $it -FromUser
        if ($step.Key -eq 'palette') { Update-DependentSteps; Update-UiTheme; $UI.TweaksList.Children.Clear() }
        Set-Status "Elegido: $($it.Name). La vista previa muestra cómo quedará; pulsa ""Aplicar a mi PC"" cuando te guste."
        Build-Options
    }
    $State.Hover = $null
    Update-StepList; Request-Render
})
# Pasar el ratón por una tarjeta la muestra en la vista previa grande
$UI.Items.Add_MouseMove({
    param($s, $e)
    $fe = $e.OriginalSource
    $dc = if ($fe -is [Windows.FrameworkElement] -or $fe -is [Windows.FrameworkContentElement]) { $fe.DataContext } else { $null }
    if ($dc -is [ZK.Card]) {
        if (-not [object]::ReferenceEquals($dc, $State.Hover)) { $State.Hover = $dc; Request-Render }
    }
})
$UI.Items.Add_MouseLeave({ if ($State.Hover) { $State.Hover = $null; Request-Render } })
$UI.Items.AddHandler([Windows.Controls.Primitives.ButtonBase]::ClickEvent, [Windows.RoutedEventHandler]{
    param($s, $e)
    $url = $e.OriginalSource.Tag
    if ($url -and $url -match '^https://') { Start-Process $url }
    $e.Handled = $true
})
$UI.BtnApply.Add_Click({
    $mods = @($State.Pending)
    Start-Run $mods ([bool]$State.PendingRestart) 'aplicar'
})
$UI.BtnUndo.Add_Click({ Start-Undo })
$UI.BtnSave.Add_Click({
    $cfgPath = Join-Path $Root 'config.json'
    if (Test-Path $cfgPath) { Copy-Item $cfgPath (Join-Path $CacheDir 'config.anterior.json') -Force }
    $State.Config.meta.version = (Get-Date -Format 'yyyy.MM.dd')
    Write-Json $State.Config $cfgPath
    $State.Dirty = $false; if ($Steps[$State.Index].Kind -eq 'summary') { Update-Summary }
    Set-Status 'Guardado en config.json (la versión anterior está en cache\config.anterior.json).'
})
$UI.BtnCatalog.Add_Click({
    Set-Status 'Actualizando catálogos desde GitHub...'
    $Window.Dispatcher.Invoke([Action]{}, 'Render')
    try { & (Join-Path $CatalogDir 'Build-Catalog.ps1') | Out-Null; $State.AllItems = @{}; Show-Step $State.Index; Set-Status 'Catálogos actualizados.' }
    catch { Set-Status "No se pudo actualizar (GitHub limita las consultas; prueba en una hora): $($_.Exception.Message)" }
})
$Window.Add_Closing({
    param($s, $e)
    if ($State.Proc) { [Windows.MessageBox]::Show('Espera a que termine lo que se está aplicando.', 'ZK-Custom') | Out-Null; $e.Cancel = $true; return }
    if ($State.Pending.Count) {
        $r = [Windows.MessageBox]::Show('Tienes cambios elegidos que aún no has aplicado a tu PC. ¿Salir igualmente?', 'ZK-Custom', 'YesNo', 'Question')
        if ($r -ne 'Yes') { $e.Cancel = $true; return }
    }
    if ($State.Dirty) {
        $r = [Windows.MessageBox]::Show('¿Guardar tus elecciones en config.json antes de salir?', 'ZK-Custom', 'YesNoCancel', 'Question')
        if ($r -eq 'Cancel') { $e.Cancel = $true } elseif ($r -eq 'Yes') { $UI.BtnSave.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent))) }
    }
})
$Window.Add_Closed({ if ($Downloader) { try { $Downloader.Pool.Close(); $Downloader.Pool.Dispose() } catch { } } })

# ======================================================================================
#  Arranque
# ======================================================================================

$Downloader = Start-Downloader
# Miniaturas de todos los catálogos en segundo plano (la segunda vez cargan al instante desde disco)
foreach ($s in $Steps) { if ($s.Catalog -and $s.Key -ne 'themes') { foreach ($it in (Get-StepItems $s)) { if ($it.Preview -is [string]) { [void](Resolve-Img $it.Raw.preview) } } } }

$State.Dirty = $false; $State.Pending.Clear()
Update-UiTheme
Update-WindhawkStatus
Update-StepList
Show-Step 0
Set-Status 'Elige un tema listo o ve sección por sección. La vista previa cambia al pasar el ratón por cada opción.'

if ($SelfTest -and $Snapshot) {
    New-Item -ItemType Directory -Force -Path $Snapshot | Out-Null
    $Window.Left = -3000; $Window.ShowActivated = $false; $Window.Show()
    $shots = @{}; foreach ($k in 'themes', 'daynight', 'animated', 'startbtn', 'folders') { $shots[[array]::IndexOf(@($Steps | ForEach-Object { $_.Key }), $k)] = $k }
    foreach ($i in ($shots.Keys | Sort-Object)) {
        Show-Step $i
        if ($i -eq 3) { $State.Advanced = $true; $State.Config.wizard.options.taskbar = [ordered]@{ usePalette = $true; transp = 30; radius = 12 }; Build-Options; $State.Hover = Find-Item 'taskbar' 'Bubbles'; Request-Render }
        if ($shots[$i] -eq 'animated') { $UI.Items.SelectedItem = Find-Item 'animated' 'synthgrid' }
        if ($shots[$i] -eq 'daynight') { $UI.Items.SelectedItem = Find-Item 'daynight' 'nord' }
        if ($shots[$i] -eq 'folders') { $State.Config.folders = [ordered]@{ ([Environment]::GetFolderPath('MyDocuments')) = '#0090FF'; (Join-Path $env:USERPROFILE 'Downloads') = '#30A46C' }; Build-Folders; Request-Render }
        if ($i -eq 5) { $UI.Items.SelectedItem = Find-Item 'startbtn' 'orb-planet-morado' }
        if ($i -eq 7) { $State.Config.wizard.options.startmenu = [ordered]@{ usePalette = $true; transp = 35; radius = 16; accent = '#BB9AF7' }; $UI.Items.SelectedItem = Find-Item 'startmenu' 'WindowGlass'; Build-Options; Request-Render }
        if ($i -eq 10) { $State.Config.wizard.options.settingsapp = [ordered]@{ usePalette = $true; transp = 10; radius = 12; border = '#7AA2F7' }; Build-Options; Request-Render }
        if ($i -eq 20) { $UI.Items.SelectedItem = Find-Item 'fonts' 'departure-mono-nf' }
        $until = (Get-Date).AddSeconds(9)
        while ((Get-Date) -lt $until) { $Window.Dispatcher.Invoke([Action]{}, 'Background'); Start-Sleep -Milliseconds 100 }
        $w = [int]$Window.ActualWidth; $h = [int]$Window.ActualHeight
        $rtb = New-Object Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [Windows.Media.PixelFormats]::Pbgra32)
        $rtb.Render($Window)
        $enc = New-Object Windows.Media.Imaging.PngBitmapEncoder; $enc.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($rtb))
        $fs = [IO.File]::Create((Join-Path $Snapshot ('{0:00}-{1}.png' -f ($i + 1), $shots[$i]))); $enc.Save($fs); $fs.Close()
    }
    $State.Dirty = $false; $State.Pending.Clear(); $Window.Close()
    return
}
if ($SelfTest) {
    $report = foreach ($i in 0..($Steps.Count - 1)) {
        Show-Step $i
        $s = $Steps[$i]
        if ($s.Catalog) {
            $n = @(Get-StepItems $s).Count
            $pick = Get-StepItems $s | Select-Object -Skip 1 -First 1
            if ($pick) { $UI.Items.SelectedItem = $null; $UI.Items.SelectedItem = $pick }
            '{0,-26} {1,4} opciones  -> prueba: {2}' -f $s.Title, $n, $(if ($pick) { $pick.Name } else { '-' })
        } else { '{0,-26} (panel {1})' -f $s.Title, $s.Kind }
    }
    $report
    Show-Step ($Steps.Count - 1)
    '--- resumen ---'; $UI.Summary.Text
    Write-Json $State.Config (Join-Path $CacheDir 'selftest-config.json')
    '--- config de prueba guardada en cache\selftest-config.json ---'
    $State.Pending.Clear(); $State.Dirty = $false
    return
}
[void]$Window.ShowDialog()
