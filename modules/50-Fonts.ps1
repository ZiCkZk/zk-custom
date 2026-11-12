# 50-Fonts.ps1 - instala fuentes solo para tu usuario (no toca C:\Windows\Fonts)
param($Config, $Root)

$fonts = @($Config.fonts) | Where-Object { $_ -and $_.source }
if (-not $fonts) { Write-Step 'No hay fuentes configuradas' -Level Skip; return }
$ctx     = Get-ZKContext
$destDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$regKey  = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'

foreach ($f in $fonts) {
    $zip = Get-Resource -Spec $f
    if ($ctx.DryRun) { Write-Step "Instalar $($f.family) desde $([IO.Path]::GetFileName($zip))" -Level Skip; continue }
    $files = if ($zip -match '\.zip$') { Get-ChildItem (Expand-ToCache -ZipPath $zip -Name $f.family) -Recurse -Include '*.ttf', '*.otf' } else { Get-Item $zip }
    $all = @($files)
    if ($f.filter) { $files = @($all | Where-Object { $_.Name -match $f.filter }) }
    # Si el pack cambio de nombres, se toman las variantes normales (no Mono/Propo) de Nerd Font
    if (-not $files) { $files = @($all | Where-Object { $_.Name -match 'NerdFont-' -and $_.Name -notmatch 'NerdFont(Mono|Propo)-' }) }
    if (-not $files) { Write-Step "$($f.family): ningun archivo coincide con el filtro '$($f.filter)'" -Level Warn; continue }
    # El nombre real de la familia se lee del archivo, para que la terminal la encuentre siempre
    try {
        Add-Type -AssemblyName System.Drawing
        $pfc = New-Object Drawing.Text.PrivateFontCollection; $pfc.AddFontFile(($files | Select-Object -First 1).FullName)
        $real = $pfc.Families[0].Name
        if ($real -and $real -ne $f.family) { Write-Step "Familia detectada: $real" -Level Ok; if ($Config.terminal.font -eq $f.family) { $Config.terminal.font = $real } }
        $pfc.Dispose()
    } catch { }
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    foreach ($file in $files) {
        $target = Join-Path $destDir $file.Name
        if (-not (Test-Path $target)) { Copy-Item $file.FullName $target; Register-CreatedFile $target }
        $kind = if ($file.Extension -eq '.otf') { 'OpenType' } else { 'TrueType' }
        Set-RegValue $regKey "$($file.BaseName) ($kind)" $target -Type String
        [void][ZKCustom.Native]::AddFontResource($target)
    }
    Write-Step "$($f.family): $(@($files).Count) archivos instalados" -Level Ok
}
Send-SettingChange -Message 0x001D   # WM_FONTCHANGE
