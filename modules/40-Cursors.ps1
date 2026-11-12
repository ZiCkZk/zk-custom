# 40-Cursors.ps1 - instala un pack de cursores (.cur/.ani + install.inf) sin ejecutar el .inf
# Se lee el .inf (Read-CursorInf) para saber que archivo va a cada puntero, se copian a
# %SystemRoot%\Cursors\<esquema> y se escriben las claves de HKCU\Control Panel\Cursors (con copia de seguridad).
param($Config, $Root)

$c = $Config.cursors
if (-not $c -or -not $c.source) { Write-Step 'No hay pack de cursores configurado' -Level Skip; return }
$ctx = Get-ZKContext

$zip  = Get-Resource -Spec $c
$name = [IO.Path]::GetFileNameWithoutExtension($zip)
if ($ctx.DryRun) { Write-Step "Extraer $name, leer su .inf$(if ($c.variant) { " (variante $($c.variant))" }) y aplicar el esquema" -Level Skip; return }
$dir = Expand-ToCache -ZipPath $zip -Name $name

$infs = @(Get-ChildItem -LiteralPath $dir -Recurse -Filter '*.inf')
$variant = if ($c.variant) { $c.variant } elseif ($infs | Where-Object { $_.Directory.Name -like '*Regular*' }) { 'Regular' } else { $null }
if ($variant) { $infs = @($infs | Where-Object { $_.Directory.Name -like "*$variant*" }) }
$inf = $infs | Sort-Object { $_.Directory.Name.Length }, { if ($_.Name -ieq 'install.inf') { 0 } else { 1 } } | Select-Object -First 1   # el install.inf principal antes que variantes (_1x)
if (-not $inf) { throw "No se encontro ningun .inf$(if ($c.variant) { " de la variante '$($c.variant)'" }) en $name." }

$s = Read-CursorInf -Path $inf.FullName
if (-not $s.Values.Count) { throw "El .inf de $name no tiene entradas de cursores reconocibles." }
$destRel = if ($s.DestRel) { $s.DestRel -replace '^%SystemRoot%\\?', '' } else { "Cursors\$($inf.Directory.Name)" }
$dest = Join-Path $env:SystemRoot $destRel
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Get-ChildItem -LiteralPath $inf.Directory.FullName -File | Where-Object { $_.Extension -in '.cur', '.ani' } | Copy-Item -Destination $dest -Force
Write-Step "Cursores copiados a $dest" -Level Ok

$key = 'HKCU:\Control Panel\Cursors'
if ($s.Scheme) {
    Set-RegValue $key '' $s.Scheme -Type String
    if ($s.SchemeList) { Set-RegValue "$key\Schemes" $s.Scheme $s.SchemeList -Type ExpandString }
}
foreach ($kv in $s.Values.GetEnumerator()) { Set-RegValue $key $kv.Key $kv.Value -Type ExpandString }
Set-RegValue $key 'Scheme Source' 1
Update-SystemParameter -Action 0x57   # SPI_SETCURSORS
Write-Step "Esquema '$($s.Scheme)' aplicado ($($s.Values.Count) punteros)" -Level Ok
