# 30-Windhawk.ps1 - estilos visuales via mods de Windhawk (barra, Inicio, notificaciones, Explorador,
# Configuracion, iconos, efectos, esquinas, bordes, menus, seleccion, reloj, estela, cursores...).
# Todo automatico y en segundo plano (windhawk-cli), sin abrir Windhawk.
param($Config, $Root)

$ctx  = Get-ZKContext
$mods = @($Config.windhawk.mods) | Where-Object { $_ -and $_.id }
# El asistente indica que mods cambiaron; Install.cmd (sin applyOnly) los aplica todos
if ($null -ne $Config.windhawk.applyOnly) {
    $only = @($Config.windhawk.applyOnly)
    $mods = @($mods | Where-Object { $_.id -in $only })
    if (-not $mods) { Write-Step 'Ningun mod de Windhawk ha cambiado' -Level Skip; return }
}
if (-not $mods) { Write-Step 'No hay mods de Windhawk configurados' -Level Skip; return }
$wanted = @($mods | Where-Object { $null -eq $_.enabled -or $_.enabled })

$info = Get-WindhawkInfo
if (-not $wanted -and -not $info.Cli) { Write-Step 'Solo hay mods desactivados y Windhawk no esta instalado; nada que hacer' -Level Skip; return }
if ($wanted) { Install-Windhawk }
if ($ctx.DryRun -and -not (Get-WindhawkInfo).Cli) {
    foreach ($m in $mods) { Write-Step "Mod $($m.id)" -Level Skip }
    return
}

# Archivos que usan los mods (por ejemplo, imagenes de orbs): se copian donde el mod los busca
foreach ($f in @($Config.windhawk.files)) {
    if (-not $f -or -not $f.from -or -not $f.to) { continue }
    $src = Join-Path $Root $f.from
    $dst = [Environment]::ExpandEnvironmentVariables($f.to)
    if (-not (Test-Path $src)) { Write-Step "No existe $($f.from)" -Level Warn; continue }
    if ($ctx.DryRun) { Write-Step "Copiar $($f.from) -> $dst" -Level Skip; continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Copy-Item $src $dst -Force
    Write-Step "Imagen lista: $([IO.Path]::GetFileName($dst))" -Level Ok
}

Backup-Windhawk -Path (Join-Path $ctx.BackupDir 'windhawk-before.zip')
$installed = if ($ctx.DryRun) { @() } else { Get-WindhawkModList }

function Invoke-ModStep($m) {
    $enabled = if ($null -ne $m.enabled) { [bool]$m.enabled } else { $true }
    try {
        if (Set-WindhawkMod -Id $m.id -Settings $m.settings -Enabled $enabled -Installed $installed) {
            Add-Content (Join-Path $ctx.BackupDir 'windhawk-added-mods.txt') $m.id -Encoding UTF8
        }
    } catch { Write-Step "Mod $($m.id): $($_.Exception.Message)" -Level Error }
}

# Todos los mods menos el de iconos
foreach ($m in ($mods | Where-Object { $_.id -ne 'icon-resource-redirect' })) { Invoke-ModStep $m }

# Iconos: el mod pregunta si vaciar la cache cuando cambia el pack con el Explorador abierto.
# Para que no pregunte: se cierra el Explorador, se cambia el pack, se vacia la cache y se vuelve a abrir.
$icon = $mods | Where-Object { $_.id -eq 'icon-resource-redirect' } | Select-Object -First 1
if ($icon) {
    $newTheme = (ConvertTo-Hashtable $icon.settings)['iconTheme']
    $enabled  = $null -eq $icon.enabled -or [bool]$icon.enabled
    $current  = if (-not $ctx.DryRun -and 'icon-resource-redirect' -in $installed) { Get-WindhawkModSetting -Id 'icon-resource-redirect' -Key 'iconTheme' } else { $null }
    $changes  = -not ('icon-resource-redirect' -in $installed) -or ($enabled -and $current -ne $newTheme) -or -not $enabled
    if ($changes -and -not $ctx.DryRun) {
        Write-Step 'Cambiando el pack de iconos (el Explorador se cierra un momento)...'
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
        Invoke-ModStep $icon
        Start-Sleep -Seconds 2   # el mod descarga el pack
        Clear-IconCache
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    } elseif ($changes) { Invoke-ModStep $icon; Clear-IconCache }
    else { Write-Step "Pack de iconos sin cambios ($(($newTheme -split '\|')[0]))" -Level Skip }
}

Hide-Windhawk
Restart-ShellHosts
