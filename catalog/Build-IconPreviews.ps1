#Requires -Version 5.1
<#
.SYNOPSIS
    Genera una vista previa EXACTA de cada pack de iconos: descarga el pack, extrae sus iconos reales
    (carpeta, Documentos, Imagenes, Musica, Videos, Descargas, Este equipo, discos, papelera...) y
    los dibuja en catalog\previews\icons\<pack>.png. Al final actualiza generated\icons.json.
    Los .zip se borran al terminar cada pack para no ocupar espacio (usa -KeepZips para guardarlos).
#>
param([switch]$Force, [switch]$KeepZips, [string]$Only)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
. (Join-Path $PSScriptRoot '..\modules\IconTools.ps1')
Add-Type -AssemblyName System.IO.Compression.FileSystem
$base = 'https://ramensoftware.github.io/resource-redirect-themes/'
$out = Join-Path $PSScriptRoot 'previews\icons'
$work = Join-Path $PSScriptRoot '..\cache\iconpacks'
New-Item -ItemType Directory -Force -Path $out, $work | Out-Null
$catPath = Join-Path $PSScriptRoot 'generated\icons.json'
$items = @(Get-Content $catPath -Raw -Encoding UTF8 | ConvertFrom-Json) | ForEach-Object { $_ }

# Iconos de imageres.dll: carpeta, Documentos, Imagenes, Musica, Videos, Descargas, Este equipo, disco de Windows, disco, red, papelera vacia y llena
$wanted = 3, 112, 113, 108, 189, 184, 109, 32, 30, 25, 55, 54
$wc = New-Object Net.WebClient; $wc.Headers['User-Agent'] = 'zk-custom'
$bg = [Drawing.Color]::FromArgb(30, 31, 41); $done = 0; $fail = 0

foreach ($it in $items) {
    $val = $it.apply.settings.iconTheme
    if (-not $val -or $val -notmatch '\|') { continue }
    if ($Only -and $it.id -notlike $Only) { continue }
    $rel = ($val -split '\|', 2)[1]
    $slug = ($it.id -replace '[^\w\-]+', '-').Trim('-').ToLower()
    $png = Join-Path $out "$slug.png"
    if ((Test-Path $png) -and -not $Force) { $done++; continue }
    $zip = Join-Path $work "$slug.zip"; $dir = Join-Path $work $slug
    try {
        if (-not (Test-Path $zip)) { $wc.DownloadFile($base + $rel, $zip) }
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dir)
        $dlls = @(Get-ChildItem $dir -Recurse -File -Filter *.dll | Sort-Object @{ e = { if ($_.Name -eq 'imageres.dll') { 0 } elseif ($_.Name -eq 'shell32.dll') { 1 } else { 2 } } })
        $bmps = New-Object System.Collections.Generic.List[object]
        foreach ($id in $wanted) {
            foreach ($d in $dlls) { if (Test-IconResource $d.FullName $id) { $b = Get-IconBitmap -File $d.FullName -Id $id -Size 96; if ($b) { $bmps.Add($b); break } } }
        }
        # Si el pack no trae esos iconos concretos, se toman los primeros que traiga
        foreach ($d in $dlls) { for ($i = 0; $bmps.Count -lt 12 -and $i -lt 40; $i++) { $b = Get-IconBitmap -File $d.FullName -Index $i -Size 96; if (-not $b) { break }; $bmps.Add($b) } }
        foreach ($f in (Get-ChildItem $dir -Recurse -File -Include *.ico, *.png | Where-Object { $_.Name -notmatch 'preview' } | Select-Object -First 12)) {
            if ($bmps.Count -ge 12) { break }
            try { if ($f.Extension -eq '.ico') { $bmps.Add((New-Object Drawing.Icon $f.FullName, 96, 96).ToBitmap()) } else { $bmps.Add([Drawing.Image]::FromFile($f.FullName)) } } catch { }
        }
        if (-not $bmps.Count) { throw 'el pack no trae iconos que se puedan leer' }
        # Lienzo 480x270: 6 x 2 iconos
        $canvas = New-Object Drawing.Bitmap 480, 270
        $g = [Drawing.Graphics]::FromImage($canvas); $g.Clear($bg); $g.InterpolationMode = 'HighQualityBicubic'
        $n = [Math]::Min(12, $bmps.Count); $cols = [Math]::Min(6, $n); $rows = [Math]::Ceiling($n / $cols)
        $sz = 64; $gx = (480 - $cols * $sz) / ($cols + 1); $gy = (270 - $rows * $sz) / ($rows + 1)
        for ($i = 0; $i -lt $n; $i++) { $g.DrawImage($bmps[$i], [int]($gx + ($i % $cols) * ($sz + $gx)), [int]($gy + [Math]::Floor($i / $cols) * ($sz + $gy)), $sz, $sz) }
        $g.Dispose(); $canvas.Save($png, [Drawing.Imaging.ImageFormat]::Png); $canvas.Dispose()
        foreach ($b in $bmps) { $b.Dispose() }
        $done++
        Write-Host ("[{0}/{1}] {2}: {3} iconos" -f $done, $items.Count, $it.id, $n)
    } catch { $fail++; Write-Host "[!!] $($it.id): $($_.Exception.Message)" -ForegroundColor Yellow }
    finally {
        if (Test-Path $dir) { Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue }
        if (-not $KeepZips -and (Test-Path $zip)) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
    }
}

# Enlaza las vistas en el catalogo (exactas, ya no aproximadas)
foreach ($it in $items) {
    $slug = ($it.id -replace '[^\w\-]+', '-').Trim('-').ToLower()
    if (Test-Path (Join-Path $out "$slug.png")) {
        $it.preview = "previews/icons/$slug.png"
        $it | Add-Member previewLarge "previews/icons/$slug.png" -Force
        $it.previewApprox = $false
        if ($it.description -match 'Sin captura') { $it.description = ($it.description -replace '\s*Sin captura:.*$', '') }
    }
}
[IO.File]::WriteAllText($catPath, (ConvertTo-Json @($items) -Depth 8), (New-Object Text.UTF8Encoding($false)))
Write-Host "Listo: $done packs con vista exacta, $fail con error." -ForegroundColor Green
