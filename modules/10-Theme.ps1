# 10-Theme.ps1 - modo oscuro, transparencias y color de acento neon
param($Config, $Root)

$p     = $Config.palette
$t     = $Config.theme
$accent = $p.primary
$bool  = { param($v) if ($v) { 1 } else { 0 } }

$personalize = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$dwm         = 'HKCU:\Software\Microsoft\Windows\DWM'
$explAccent  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
$desktop     = 'HKCU:\Control Panel\Desktop'

# Modo oscuro y transparencias
$light = if ($t.darkMode) { 0 } else { 1 }
Set-RegValue $personalize 'AppsUseLightTheme'    $light
Set-RegValue $personalize 'SystemUsesLightTheme' $light
Set-RegValue $personalize 'EnableTransparency'   (& $bool $t.transparency)
Set-RegValue $personalize 'ColorPrevalence'      (& $bool $t.accentOnStartAndTaskbar)
Write-Step "Modo oscuro y transparencias" -Level Ok

# Acento fijo (desactiva que Windows lo saque del fondo de pantalla)
Set-RegValue $desktop 'AutoColorization' 0 -Type String

# Paleta de acento: menus, hover, botones, enlaces de Configuracion
Set-RegValue $explAccent 'AccentPalette'   (Get-AccentPalette $accent) -Type Binary
Set-RegValue $explAccent 'AccentColorMenu' (Get-ColorDword $accent -Format ABGR)
Set-RegValue $explAccent 'StartColorMenu'  (Get-ColorDword (Get-ShadeHex $accent -0.45) -Format ABGR)

# Barras de titulo y bordes de ventana
Set-RegValue $dwm 'AccentColor'           (Get-ColorDword $accent -Format ABGR)
Set-RegValue $dwm 'ColorizationColor'     (Get-ColorDword $accent -Format ARGB -Alpha 0xC4)
Set-RegValue $dwm 'ColorizationAfterglow' (Get-ColorDword $accent -Format ARGB -Alpha 0xC4)
Set-RegValue $dwm 'AccentColorInactive'   (Get-ColorDword $p.surface -Format ABGR)
Set-RegValue $dwm 'ColorPrevalence'       (& $bool $t.accentOnTitleBars)
Set-RegValue $dwm 'EnableWindowColorization' (& $bool $t.accentOnTitleBars)
Write-Step "Acento $accent aplicado a menus, bordes y barras de titulo" -Level Ok
