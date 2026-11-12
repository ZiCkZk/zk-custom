#Requires -Version 5.1
<#
.SYNOPSIS
    Dibuja la galeria de orbs del boton Inicio (catalog\previews\orbs) y genera catalog\static\orbs.json.
    Estilo "premium": esfera 3D con reflejo, halo, borde luminoso e icono (musica, gaming y otros).
    Cada orb tiene tres imagenes: normal, al pasar el raton (mas clara) y pulsado (mas oscura).
#>
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot '..\modules\OrbArt.ps1')
. (Join-Path $PSScriptRoot '..\modules\OrbPremium.ps1')
$dir = Join-Path $PSScriptRoot 'previews\orbs'
if (Test-Path $dir) { Get-ChildItem $dir -File | Remove-Item -Force }   # se sustituye la galeria anterior
New-Item -ItemType Directory -Force -Path $dir | Out-Null

$colors = [ordered]@{
    azul = @('Azul', '#2563EB', '#93C5FD'); rojo = @('Rojo', '#DC2626', '#FCA5A5')
    morado = @('Morado', '#7C3AED', '#C4B5FD'); verde = @('Verde', '#16A34A', '#86EFAC')
}
# id del dibujo | nombre | grupo | descripcion
$glyphs = @(
    , @('vinyl', 'Vinilo', 'Música', 'Disco de vinilo girando con su etiqueta.')
    , @('headphones', 'Auriculares', 'Música', 'Auriculares de diadema.')
    , @('equalizer', 'Ecualizador', 'Música', 'Barras de ecualizador.')
    , @('note', 'Nota musical', 'Música', 'Dos corcheas unidas.')
    , @('cassette', 'Casete', 'Música', 'Cinta de casete retro.')
    , @('mic', 'Micrófono', 'Música', 'Micrófono de estudio.')
    , @('speaker', 'Altavoz', 'Música', 'Altavoz con ondas de sonido.')
    , @('gamepad', 'Mando', 'Gaming', 'Mando de consola.')
    , @('joystick', 'Joystick', 'Gaming', 'Palanca de recreativa.')
    , @('sword', 'Espada', 'Gaming', 'Espada de aventura.')
    , @('heart', 'Corazón', 'Gaming', 'Corazón de vida.')
    , @('coin', 'Moneda', 'Gaming', 'Moneda con estrella.')
    , @('star', 'Estrella', 'Gaming', 'Estrella de poder.')
    , @('d20', 'Dado d20', 'Gaming', 'Dado de 20 caras de rol.')
    , @('potion', 'Poción', 'Gaming', 'Frasco de poción.')
    , @('planet', 'Planeta', 'Otros', 'Planeta con anillo.')
    , @('flame', 'Llama', 'Otros', 'Llama de fuego.')
    , @('bolt', 'Rayo', 'Otros', 'Rayo de energía.')
    , @('moon', 'Luna', 'Otros', 'Luna creciente.')
    , @('leaf', 'Hoja', 'Otros', 'Hoja con su nervio.')
    , @('crystal', 'Cristal', 'Otros', 'Cristal tallado.')
    , @('windows', 'Windows', 'Otros', 'El logo de cuatro paneles dentro de la esfera.')
)
$items = @()
foreach ($g in $glyphs) {
    foreach ($ck in $colors.Keys) {
        $c = $colors[$ck]; $id = "orb-$($g[0])-$ck"
        $set = Save-PremiumOrbSet -Glyph $g[0] -Color1 $c[1] -Color2 $c[2] -Dir $dir -Name $id -Size 128
        $items += [ordered]@{ id = $id; name = "$($g[1]) · $($c[0])"; description = "$($g[3]) Esfera 3D con reflejo."; category = $g[2]
            preview = "previews/orbs/$id.png"
            apply = [ordered]@{ type = 'orb'; style = $g[0]; files = [ordered]@{ normal = "catalog/previews/orbs/$id.png"; hover = "catalog/previews/orbs/$id-hover.png"; pressed = "catalog/previews/orbs/$id-pressed.png" } } }
    }
    # Version con los colores de tu paleta: se dibuja al elegirla
    $items += [ordered]@{ id = "orb-$($g[0])-paleta"; name = "$($g[1]) · mi paleta"; description = "$($g[3]) Con los colores de tu paleta."; category = $g[2]
        apply = [ordered]@{ type = 'orb'; style = $g[0]; palette = $true; premium = $true } }
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'static\orbs.json'), (ConvertTo-Json @($items) -Depth 6), (New-Object Text.UTF8Encoding($false)))
Write-Host "$($items.Count) orbs en static\orbs.json" -ForegroundColor Green
