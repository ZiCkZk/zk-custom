#Requires -Version 5.1
<#
.SYNOPSIS
    Dibuja la galeria de orbs del boton Inicio (catalog\previews\orbs) y genera catalog\static\orbs.json.
    Cada orb tiene tres imagenes: normal, al pasar el raton (mas clara) y pulsado (mas oscura).
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot '..\modules\OrbArt.ps1')
$dir = Join-Path $PSScriptRoot 'previews\orbs'

$colors = [ordered]@{
    azul = @('Azul', '#2E7BFF', '#7DD3FC'); verde = @('Verde', '#16A34A', '#86EFAC'); rojo = @('Rojo', '#DC2626', '#FCA5A5')
    morado = @('Morado', '#7C3AED', '#C4B5FD'); dorado = @('Dorado', '#D97706', '#FDE68A'); rosa = @('Rosa', '#DB2777', '#F9A8D4')
    negro = @('Negro', '#1F2937', '#9CA3AF'); cian = @('Cian', '#0891B2', '#A5F3FC')
}
$styles = [ordered]@{
    glass    = @('Esfera de cristal', 'Orb brillante tipo Windows 7, con reflejo arriba.', @('azul', 'verde', 'rojo', 'morado', 'dorado', 'rosa', 'negro', 'cian'))
    neon     = @('Anillo neón', 'Anillo luminoso con el logo dentro. Muy cyberpunk.', @('cian', 'rosa', 'verde', 'dorado'))
    flat     = @('Círculo plano', 'Círculo de color liso, moderno y limpio.', @('azul', 'morado', 'negro'))
    squircle = @('Cuadrado redondeado', 'Degradado en forma de icono de app.', @('azul', 'rosa', 'verde'))
    outline  = @('Solo contorno', 'Logo dibujado con una línea, minimalista.', @('cian', 'dorado'))
    planet   = @('Planeta', 'Esfera con anillo, como Saturno.', @('morado', 'dorado'))
}
$items = @()
foreach ($s in $styles.Keys) {
    foreach ($ck in $styles[$s][2]) {
        $col = $colors[$ck]; $id = "orb-$s-$ck"
        [void](Save-OrbSet -Style $s -Color1 $col[1] -Color2 $col[2] -Dir $dir -Name $id)
        $items += [ordered]@{ id = $id; name = "$($styles[$s][0]) · $($col[0])"; description = $styles[$s][1]
            preview = "previews/orbs/$id.png"
            apply = [ordered]@{ type = 'orb'; style = $s; files = [ordered]@{ normal = "catalog/previews/orbs/$id.png"; hover = "catalog/previews/orbs/$id-hover.png"; pressed = "catalog/previews/orbs/$id-pressed.png" } } }
    }
}
# Orbs gamer y de cómic: dibujos originales (no usan personajes ni logos de franquicias)
$fun = @(
    ,@('pixelheart', 'Corazón pixel', 'Corazón de vida en pixel art, como en los juegos retro.', @(@('rojo', 'Rojo', '#E5484D', '#9B1C1C'), @('rosa', 'Rosa', '#FF6FB5', '#B83280'), @('azul', 'Azul', '#4DA3FF', '#1E4FA8')))
    ,@('pixelsword', 'Espada pixel', 'Espada de aventura en pixel art.', @(@('acero', 'Acero', '#8B5A2B', '#C9D1D9'), @('oro', 'Oro', '#8B5A2B', '#FFD34E')))
    ,@('coin', 'Moneda', 'Moneda dorada brillante con estrella.', @(@('oro', 'Oro', '#F5B700', '#FFE680'), @('plata', 'Plata', '#A8B0BC', '#EEF2F7')))
    ,@('powerstar', 'Estrella de poder', 'Estrella brillante de power-up.', @(@('amarilla', 'Amarilla', '#FFD60A', '#FFF3A3'), @('arcoiris', 'Morada', '#B455FF', '#FFB0F0')))
    ,@('gamepad', 'Mando', 'Mando de consola con cruceta y botones de colores.', @(@('negro', 'Negro', '#2B2F3A', '#565F89'), @('blanco', 'Blanco', '#E6E9EF', '#9CA0B0'), @('morado', 'Morado', '#7C3AED', '#C4B5FD')))
    ,@('joystick', 'Joystick arcade', 'Palanca de máquina recreativa.', @(@('rojo', 'Rojo', '#E5484D', '#2B2F3A'), @('verde', 'Verde', '#30A46C', '#2B2F3A')))
    ,@('potion', 'Poción', 'Frasco de poción con burbujas.', @(@('vida', 'Vida (roja)', '#E5484D', '#FFB3B3'), @('mana', 'Maná (azul)', '#3B82F6', '#BFDBFE'), @('veneno', 'Veneno (verde)', '#22C55E', '#BBF7D0')))
    ,@('shield', 'Escudo', 'Escudo de caballero con cruz.', @(@('azul', 'Azul', '#1E40AF', '#FACC15'), @('rojo', 'Rojo', '#B91C1C', '#F5F5F5')))
    ,@('d20', 'Dado de rol', 'Dado de 20 caras para partidas de rol.', @(@('morado', 'Morado', '#7C3AED', '#C4B5FD'), @('rojo', 'Rojo', '#DC2626', '#FCA5A5')))
    ,@('shuriken', 'Shuriken', 'Estrella ninja de cuatro puntas.', @(@('acero', 'Acero', '#9CA3AF', '#4B5563'), @('neon', 'Neón', '#06B6D4', '#EC4899')))
    ,@('bolt', 'Rayo', 'Rayo de superhéroe dentro de un círculo.', @(@('amarillo', 'Amarillo', '#FFD60A', '#DC2626'), @('azul', 'Azul', '#FFD60A', '#1D4ED8')))
    ,@('pow', 'POW!', 'Viñeta de golpe de cómic.', @(@('amarillo', 'Amarillo', '#FFD60A', '#000000'), @('rojo', 'Rojo', '#EF4444', '#000000')))
    ,@('boom', 'BOOM!', 'Explosión de cómic.', @(,@('naranja', 'Naranja', '#FB923C', '#000000')))
    ,@('wow', 'WOW!', 'Exclamación de cómic.', @(@('celeste', 'Celeste', '#38BDF8', '#000000'), @('rosa', 'Rosa', '#F472B6', '#000000')))
)
foreach ($f in $fun) {
    foreach ($v in $f[3]) {
        $id = "orb-$($f[0])-$($v[0])"
        [void](Save-OrbSet -Style $f[0] -Color1 $v[2] -Color2 $v[3] -Dir $dir -Name $id)
        $items += [ordered]@{ id = $id; name = "$($f[1]) · $($v[1])"; description = "$($f[2]) Estilo juego/cómic."; category = 'Gamer y cómic'
            preview = "previews/orbs/$id.png"
            apply = [ordered]@{ type = 'orb'; style = $f[0]; files = [ordered]@{ normal = "catalog/previews/orbs/$id.png"; hover = "catalog/previews/orbs/$id-hover.png"; pressed = "catalog/previews/orbs/$id-pressed.png" } } }
    }
}
# Orbs con los colores de tu paleta: se dibujan al elegirlos
foreach ($s in 'glass', 'neon', 'squircle', 'planet') {
    $items += [ordered]@{ id = "orb-$s-paleta"; name = "$($styles[$s][0]) · mi paleta"; description = "$($styles[$s][1]) Con los colores de tu paleta."
        apply = [ordered]@{ type = 'orb'; style = $s; palette = $true } }
}
$items += [ordered]@{ id = 'orb-custom'; name = 'Mi propio orb'; description = 'Usa una imagen tuya (PNG, JPG o GIF animado). Elígela en Ajustes con «Subir mi orb...».'
    apply = [ordered]@{ type = 'orb'; custom = $true } }
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'static\orbs.json'), (ConvertTo-Json @($items) -Depth 6), (New-Object Text.UTF8Encoding($false)))
Write-Host "$($items.Count) orbs en static\orbs.json" -ForegroundColor Green
