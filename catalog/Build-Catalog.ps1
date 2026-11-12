#Requires -Version 5.1
<#
.SYNOPSIS
    Regenera los catalogos de opciones de ZK-Custom a partir de los repositorios oficiales de Windhawk
    y de colecciones publicas de fondos de pantalla.
    Lee las opciones de cada mod (su bloque de ajustes), busca la captura de cada tema en las guias de
    estilos y lista los fondos con miniatura.
.EXAMPLE
    .\catalog\Build-Catalog.ps1
#>
param([string]$OutDir = (Join-Path $PSScriptRoot 'generated'))

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$h = @{ 'User-Agent' = 'zk-custom' }
$cdn = 'https://cdn.jsdelivr.net/gh'

function Get-Text($url) { (Invoke-WebRequest $url -UseBasicParsing -Headers $h).Content }
function Get-TreeItems($repo, $branch = 'main') { (Invoke-RestMethod "https://api.github.com/repos/$repo/git/trees/$($branch)?recursive=1" -Headers $h).tree }
function Get-Tree($repo, $branch = 'main') { (Get-TreeItems $repo $branch).path }
function Get-EscapedPath($p) { ($p -split '/' | ForEach-Object { [uri]::EscapeDataString($_) }) -join '/' }
# Texto con acentos escrito con escapes para que este script siga siendo ASCII (PowerShell 5.1 lee los .ps1 como ANSI)
function U([string]$s) { [regex]::Unescape($s) }

function Get-ModOptions {
    <# Devuelve nombre del mod y las opciones ($options) del ajuste indicado. #>
    param([string]$ModId, [string]$SettingKey)
    $src = Get-Text "https://raw.githubusercontent.com/ramensoftware/windhawk-mods/main/mods/$ModId.wh.cpp"
    $name = [regex]::Match($src, '//\s*@name\s+(.+)').Groups[1].Value.Trim()
    $a = $src.IndexOf('// ==WindhawkModSettings=='); $b = $src.IndexOf('// ==/WindhawkModSettings==')
    $lines = $src.Substring($a, $b - $a) -split "`r?`n"
    $opts = New-Object System.Collections.Generic.List[object]
    $inSetting = $false; $inOptions = $false
    foreach ($l in $lines) {
        if ($l -match '^- (\w+):') { $inSetting = ($Matches[1] -eq $SettingKey); $inOptions = $false; continue }
        if (-not $inSetting) { continue }
        if ($l -match '^\s+\$options:\s*$') { $inOptions = $true; continue }
        if ($inOptions -and $l -match '^\s+- (.+?): (.+)$') {
            $key = $Matches[1].Trim().Trim('"').Trim("'"); $label = $Matches[2].Trim().Trim("'").Trim('"'); if ($label -match '^[>|]-?$') { $label = $key }   # etiqueta multilinea de YAML
            $opts.Add([pscustomobject]@{ Key = $key; Label = $label }); continue
        }
        if ($inOptions -and $l -notmatch '^\s+- ') { $inOptions = $false }
    }
    [pscustomobject]@{ Name = $name; Options = $opts }
}

function Get-Thumb($url, [int]$w) {
    # Miniatura ligera via wsrv.nl (redimensiona la imagen publica al vuelo)
    if (-not $url) { return $null }
    if ($url -notmatch '^https?://') { return $url }   # vistas locales generadas (previews\...)
    'https://wsrv.nl/?url=' + [uri]::EscapeDataString(($url -replace '^https://', '')) + "&w=$w&output=jpg&q=82"
}

function New-Entry($id, $name, $desc, $preview, $approx, $apply, $reference = $null) {
    # La tarjeta usa una miniatura de 480 px; la vista grande, una de 1280 px
    [ordered]@{ id = $id; name = $name; description = $desc; preview = (Get-Thumb $preview 480); previewLarge = (Get-Thumb $preview 1280)
                previewApprox = [bool]$approx; reference = $reference; apply = $apply }
}

function ConvertTo-Title([string]$s) {
    # "TranslucentTaskbar" -> "Translucent Taskbar"; "bubbles_dark" -> "Bubbles dark"
    $s = ($s -creplace '([a-z])([A-Z])', '$1 $2') -replace '_', ' ' -replace '\s+', ' '
    if ($s) { $s.Substring(0, 1).ToUpper() + $s.Substring(1) } else { $s }
}

function Build-StylerCatalog {
    param([string]$ModId, [string]$GuideRepo, [string]$Label)
    Write-Host "Catalogo $ModId..." -ForegroundColor Cyan
    $mod  = Get-ModOptions -ModId $ModId -SettingKey 'theme'
    $shots = @{}; $folders = @{}
    foreach ($p in (Get-Tree "ramensoftware/$GuideRepo")) {
        if ($p -match '^Themes/([^/]+)/screenshot\.(png|jpg|gif)$') { $shots[$Matches[1]] = $p }
        if ($p -match '^Themes/([^/]+)/') { $folders[$Matches[1]] = $true }
    }
    $guide = "https://github.com/ramensoftware/$GuideRepo"
    $items = @(New-Entry 'none' 'Sin estilo' "Se deja $Label como viene en Windows." $null $false ([ordered]@{ type = 'windhawk-remove'; mod = $ModId; modName = $mod.Name }))
    foreach ($o in $mod.Options) {
        if (-not $o.Key) { continue }
        $base = $o.Key -replace '_variant_.*$', ''
        $prev = if ($shots.ContainsKey($base)) { "$cdn/ramensoftware/$GuideRepo@main/" + (Get-EscapedPath $shots[$base]) } else { $null }
        $ref  = if ($folders.ContainsKey($base)) { "$guide/tree/main/Themes/$base" } else { $guide }
        $isVariant = $o.Key -ne $base
        $desc = "Tema de la comunidad para $Label."
        if ($isVariant) { $desc += ' Es una variante: la captura es la del tema original.' }
        if (-not $prev) { $desc += (U ' Sin captura oficial: pulsa «Ver ejemplos» para buscar imágenes.') }
        $items += New-Entry $o.Key (ConvertTo-Title $o.Label) $desc $prev $isVariant ([ordered]@{ type = 'windhawk'; mod = $ModId; modName = $mod.Name; settings = [ordered]@{ theme = $o.Key } }) $ref
    }
    Write-Host "  $($items.Count - 1) temas, $(@($items | Where-Object { $_.preview }).Count) con captura"
    $items
}

function Build-IconCatalog {
    Write-Host 'Catalogo de iconos (icon-resource-redirect)...' -ForegroundColor Cyan
    $mod = Get-ModOptions -ModId 'icon-resource-redirect' -SettingKey 'iconTheme'
    $previews = Get-Tree 'niivu/resource-redirect-icon-themes' | Where-Object { $_ -match '^Previews/.+\.(png|jpg)$' }
    $stop = 'by', 'niivu', 'for', 'the', 'and', 'new', 'dark', 'light', 'mode', 'alt'
    $items = @(New-Entry 'none' 'Iconos de Windows' 'Se mantienen los iconos originales.' $null $false ([ordered]@{ type = 'windhawk-remove'; mod = 'icon-resource-redirect'; modName = $mod.Name }))
    foreach ($o in $mod.Options) {
        if (-not $o.Key) { continue }
        $display = ($o.Key -split '\|')[0]
        $author = [regex]::Match($o.Label, '\(by ([^,)]+)').Groups[1].Value
        $prev = $null; $approx = $false; $exact = $false
        $words = ($display.ToLower() -replace '[^a-z0-9 ]', ' ') -split '\s+' | Where-Object { $_.Length -gt 2 -and $_ -notin $stop }
        foreach ($w in $words) {
            $hit = $previews | Where-Object { ([IO.Path]::GetFileNameWithoutExtension($_)).ToLower() -match "(^|[^a-z])$([regex]::Escape($w))" } | Select-Object -First 1
            if ($hit) { $prev = "$cdn/niivu/resource-redirect-icon-themes@main/" + (Get-EscapedPath $hit); $exact = ($w -eq $words[0]); break }
        }
        if ($prev -and -not ($exact -and $words.Count -eq 1)) { $approx = $true }
        # Vista exacta generada por Build-IconPreviews.ps1 (iconos reales del pack)
        $slug = ($display -replace '[^\w\-]+', '-').Trim('-').ToLower()
        if (Test-Path (Join-Path $PSScriptRoot "previews\icons\$slug.png")) { $prev = "previews/icons/$slug.png"; $approx = $false }
        $desc = "Pack de iconos para carpetas, unidades y programas$(if ($author) { " (autor: $author)" })."
        if (-not $prev) { $desc += (U ' Sin captura: pulsa «Ver ejemplos».') }
        $items += New-Entry $display $display $desc $prev $approx ([ordered]@{ type = 'windhawk'; mod = 'icon-resource-redirect'; modName = $mod.Name; settings = [ordered]@{ iconTheme = $o.Key } })
    }
    Write-Host "  $($items.Count - 1) temas, $(@($items | Where-Object { $_.preview }).Count) con captura (algunas aproximadas)"
    $items
}

function Build-CursorModCatalog {
    Write-Host 'Catalogo de cursores (mouse-cursor-themes)...' -ForegroundColor Cyan
    $mod = Get-ModOptions -ModId 'mouse-cursor-themes' -SettingKey 'theme'
    foreach ($o in $mod.Options) {
        if (-not $o.Key -or $o.Key -eq 'custom') { continue }
        $lp = if (Test-Path (Join-Path $PSScriptRoot "previews\cursors\wh-$($o.Key).png")) { "previews/cursors/wh-$($o.Key).png" } else { $null }
        if ($lp) { New-Entry "wh-$($o.Key)" "$($o.Label) (dibujado)" 'Cursor vectorial dibujado por el mod Mouse Cursor Themes. Vista recreada con sus colores, contorno y brillo.' $lp $false ([ordered]@{ type = 'windhawk'; mod = 'mouse-cursor-themes'; modName = $mod.Name; settings = [ordered]@{ theme = $o.Key } }) 'https://windhawk.net/mods/mouse-cursor-themes'; continue }
        New-Entry "wh-$($o.Key)" "$($o.Label) (dibujado)" (U 'Cursor vectorial dibujado por el mod Mouse Cursor Themes, con brillo configurable. Sin captura: es una forma generada, nítida a cualquier tamaño.') $null $false ([ordered]@{ type = 'windhawk'; mod = 'mouse-cursor-themes'; modName = $mod.Name; settings = [ordered]@{ theme = $o.Key } }) 'https://windhawk.net/mods/mouse-cursor-themes'
    }
}

function Build-WallpaperCatalog {
    <# Fondos de colecciones publicas de GitHub. Miniatura via wsrv.nl (redimensiona al vuelo, sin cuenta). #>
    Write-Host 'Catalogo de fondos...' -ForegroundColor Cyan
    $thumb = { param($raw, $w) 'https://wsrv.nl/?url=' + [uri]::EscapeDataString(($raw -replace '^https://', '')) + "&w=$w&h=$([int]($w * 9 / 16))&fit=cover&output=jpg&q=80" }
    $add = {
        param($repo, $branch, $path, $size, $cat, $name)
        $raw = "https://raw.githubusercontent.com/$repo/$branch/" + (Get-EscapedPath $path)
        [ordered]@{ id = "$repo/$path"; name = $name; category = $cat; description = "$cat - github.com/$repo"
            preview = (& $thumb $raw 400); previewLarge = (& $thumb $raw 1280); reference = "https://github.com/$repo/blob/$branch/" + (Get-EscapedPath $path)
            apply = [ordered]@{ type = 'wallpaper'; url = $raw; size = $size; name = $name } }
    }
    $items = @()
    # Tokyo Night oficiales (ligeros, a 2560x1440)
    foreach ($t in (Get-TreeItems 'tokyo-night/wallpapers') | Where-Object { $_.path -match '^(night|storm)/(abstract|minimal|os/(windows|penguin|arch_00)).*2560x1440\.png$' }) {
        $parts = $t.path -split '/'
        $items += & $add 'tokyo-night/wallpapers' 'main' $t.path $t.size 'Tokyo Night' (ConvertTo-Title ("$($parts[0]) " + ($parts[-1] -replace '_2560x1440\.png$', '')))
    }
    # dharmx/walls, por categorias
    $cats = [ordered]@{ outrun = 'Synthwave / Outrun'; digital = 'Arte digital'; abstract = 'Abstracto'; minimal = 'Minimalista'; nature = 'Naturaleza'
        mountain = (U 'Montañas'); cold = (U 'Frío'); calm = 'Calma'; fogsmoke = 'Niebla'; aerial = (U 'Vistas aéreas'); architecture = 'Arquitectura'
        monochrome = 'Blanco y negro'; anime = 'Anime'; manga = 'Manga'; retro = 'Retro'; pixel = 'Pixel art'; apocalypse = (U 'Postapocalíptico')
        stalenhag = (U 'Simon Stålenhag'); painting = 'Pintura'; flowers = 'Flores'; cherry = 'Cerezos'; 'm-26.jp' = (U 'Japón'); chillop = 'Lo-fi'
        dreamcore = 'Dreamcore'; nord = (U 'Nórdico (Nord)'); gruvbox = (U 'Cálido (Gruvbox)'); solarized = 'Solarized'; poly = 'Low poly'; evangelion = 'Evangelion' }
    $walls = Get-TreeItems 'dharmx/walls' | Where-Object { $_.path -match '\.(png|jpe?g)$' -and $_.size -lt 15MB }
    foreach ($c in $cats.Keys) {
        $sel = @($walls | Where-Object { $_.path -like "$c/*" } | Sort-Object path | Select-Object -First 24)
        foreach ($t in $sel) {
            $n = ConvertTo-Title ([IO.Path]::GetFileNameWithoutExtension($t.path) -replace '^(a|an|the)_', '')
            $items += & $add 'dharmx/walls' 'main' $t.path $t.size $cats[$c] $n
        }
    }
    # Catppuccin Mocha
    foreach ($t in (Get-TreeItems 'orangci/walls-catppuccin-mocha' 'master') | Where-Object { $_.path -match '^[^/]+\.(png|jpe?g)$' -and $_.size -lt 15MB } | Select-Object -First 30) {
        $items += & $add 'orangci/walls-catppuccin-mocha' 'master' $t.path $t.size 'Catppuccin' (ConvertTo-Title ([IO.Path]::GetFileNameWithoutExtension($t.path) -replace '-', ' '))
    }
    Write-Host "  $($items.Count) fondos en $(@($items | ForEach-Object { $_.category } | Select-Object -Unique).Count) categorias"
    $items
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$utf8 = New-Object Text.UTF8Encoding($false)
$out = [ordered]@{
    taskbar       = Build-StylerCatalog 'windows-11-taskbar-styler'             'windows-11-taskbar-styling-guide'             'la barra de tareas'
    startmenu     = Build-StylerCatalog 'windows-11-start-menu-styler'          'windows-11-start-menu-styling-guide'          (U 'el menú Inicio')
    explorer      = Build-StylerCatalog 'windows-11-file-explorer-styler'       'windows-11-file-explorer-styling-guide'       'el Explorador'
    notifications = Build-StylerCatalog 'windows-11-notification-center-styler' 'windows-11-notification-center-styling-guide' 'el centro de notificaciones y el calendario'
    settings      = Build-StylerCatalog 'windows-11-settings-styler'            'windows-11-settings-styling-guide'            (U 'la app Configuración')
    icons         = Build-IconCatalog
    cursorsmod    = @(Build-CursorModCatalog)
    wallpapers    = Build-WallpaperCatalog
}
foreach ($k in $out.Keys) {
    [IO.File]::WriteAllText((Join-Path $OutDir "$k.json"), (ConvertTo-Json @($out[$k]) -Depth 8), $utf8)
}
[IO.File]::WriteAllText((Join-Path $OutDir '_built.txt'), (Get-Date -Format 'yyyy-MM-dd HH:mm'), $utf8)
Write-Host "Catalogos guardados en $OutDir" -ForegroundColor Green
