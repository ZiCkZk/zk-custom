# Windhawk.psm1 - instalar Windhawk y gestionar sus mods de forma automatica y oculta.
# Se usa Windhawk 2.x porque incluye windhawk-cli.exe: los mods se instalan, configuran,
# respaldan y deshacen por script, sin abrir la ventana de Windhawk.

function Get-WindhawkInfo {
    $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    $u = Get-ItemProperty $keys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like 'Windhawk*' } | Select-Object -First 1
    $dirs = @()
    if ($u -and $u.InstallLocation) { $dirs += $u.InstallLocation.Trim('"') }
    if ($u -and $u.UninstallString)  { $dirs += Split-Path ($u.UninstallString.Trim('"') -replace '"\s.*$', '') -Parent }
    $dirs += "$env:ProgramFiles\Windhawk", "${env:ProgramFiles(x86)}\Windhawk"
    $cli = $null; $exe = $null
    foreach ($d in ($dirs | Where-Object { $_ } | Select-Object -Unique)) {
        if (-not $cli -and (Test-Path (Join-Path $d 'windhawk-cli.exe'))) { $cli = Join-Path $d 'windhawk-cli.exe' }
        if (-not $exe -and (Test-Path (Join-Path $d 'windhawk.exe')))     { $exe = Join-Path $d 'windhawk.exe' }
    }
    $ver = if ($u) { $u.DisplayVersion } else { $null }
    if (-not $ver -and $cli) { try { $ver = ((& $cli --version 2>$null) -replace '^\S+\s+', '').Trim() } catch { } }
    [pscustomobject]@{ Installed = [bool]($u -or $exe); Version = $ver; Exe = $exe; Cli = $cli }
}

function Install-Windhawk {
    <# Instala (o actualiza a) la ultima Windhawk 2.x de GitHub, que trae la CLI. Se verifica por SHA-256. #>
    $info = Get-WindhawkInfo
    if ($info.Cli) { Write-Step "Windhawk $($info.Version) ya esta instalado" -Level Skip; return }
    $a = Get-GitHubReleaseAsset -Repo 'ramensoftware/windhawk' -Pattern '^windhawk_setup\.exe$' -IncludePrerelease
    if (-not $a.Sha256) { throw "GitHub no publica el hash de Windhawk $($a.Tag); no se instala sin verificar." }
    $file = Save-Download -Url $a.Url -FileName "windhawk-$($a.Tag)-setup.exe" -Sha256 $a.Sha256 -Size $a.Size
    if ((Get-ZKContext).DryRun) { Write-Step "Instalar Windhawk $($a.Tag) en silencio" -Level Skip; return }
    $sig = Get-AuthenticodeSignature $file
    if ($sig.Status -ne 'Valid') { Write-Step "El instalador no tiene firma digital valida ($($sig.Status)); el SHA-256 si coincide con el publicado en GitHub." -Level Warn }
    Write-Step "Instalando Windhawk $($a.Tag) en segundo plano..."
    $p = Start-Process -FilePath $file -ArgumentList '/S', '/STANDARD' -Wait -PassThru -WindowStyle Hidden
    if ($p.ExitCode -ne 0) { throw "El instalador de Windhawk devolvio $($p.ExitCode)." }
    for ($i = 0; $i -lt 20 -and -not (Get-WindhawkInfo).Cli; $i++) { Start-Sleep -Milliseconds 500 }
    if (-not (Get-WindhawkInfo).Cli) { throw 'Windhawk se instalo pero no aparece windhawk-cli.exe.' }
    Write-Step "Windhawk $($a.Tag) instalado" -Level Ok
}

function Invoke-WindhawkCli {
    param([Parameter(Mandatory)][string[]]$Arguments, [switch]$AllowFailure)
    $cli = (Get-WindhawkInfo).Cli
    if (-not $cli) { throw 'windhawk-cli.exe no esta disponible.' }
    $out = & $cli @Arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) { throw "windhawk-cli $($Arguments -join ' ') fallo ($LASTEXITCODE): $out" }
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Hide-Windhawk {
    <# Quita el icono de la bandeja, evita que se abran ventanas y cierra la interfaz si se abrio. #>
    if ((Get-ZKContext).DryRun) { Write-Step 'Ocultar Windhawk (sin icono ni ventanas)' -Level Skip; return }
    $failed = @()
    foreach ($kv in @(@('hideTrayIcon', 'true'), @('dontAutoShowToolkit', 'true'), @('disableToolkitHotkey', 'true'), @('disableUpdateCheck', 'true'))) {
        $r = Invoke-WindhawkCli -Arguments @('app', 'settings', 'set', $kv[0], $kv[1], '--quiet') -AllowFailure
        if ($r.ExitCode -ne 0) { $failed += $kv[0] }
    }
    if ($failed) { Write-Step "No se pudo ocultar Windhawk ($($failed -join ', ')): ejecuta ZK-Custom como administrador" -Level Warn }
    Get-Process windhawk-ui -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    # El proceso de bandeja (no el servicio) se cierra para que desaparezca el icono; los mods siguen activos
    $tray = Get-CimInstance Win32_Process -Filter "Name='windhawk.exe'" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -match 'tray-only' }
    foreach ($t in $tray) { Stop-Process -Id $t.ProcessId -Force -ErrorAction SilentlyContinue }
    Write-Step 'Windhawk trabaja oculto (sin icono en la bandeja)' -Level Ok
}

function Get-WindhawkModList {
    $r = Invoke-WindhawkCli -Arguments @('mod', 'list') -AllowFailure
    @($r.Output -split "`r?`n" | Where-Object { $_ -match '\S' } | ForEach-Object { ($_ -split "`t")[0].Trim() })
}

function Set-WindhawkMod {
    <# Instala (si falta) un mod, aplica sus ajustes y lo activa. Devuelve $true si lo ha instalado ahora. #>
    param([Parameter(Mandatory)][string]$Id, $Settings, [bool]$Enabled = $true, [string[]]$Installed = @())
    $ctx = Get-ZKContext
    $pairs = @()
    foreach ($p in (ConvertTo-Hashtable $Settings).GetEnumerator()) {
        $v = if ($p.Value -is [bool]) { $p.Value.ToString().ToLower() } else { [string]$p.Value }
        $pairs += "$($p.Key)=$v"
    }
    if (-not $Enabled) {
        # "Sin estilo": se desactiva si esta instalado; nunca se instala para desactivarlo
        if ($ctx.DryRun) { Write-Step "Desactivar mod $Id (si esta instalado)" -Level Skip; return $false }
        if ($Id -in $Installed) {
            Invoke-WindhawkCli -Arguments @('mod', 'disable', $Id, '--quiet') -AllowFailure | Out-Null
            Write-Step "Mod $Id desactivado" -Level Ok
        } else { Write-Step "Mod $Id no esta instalado; nada que desactivar" -Level Skip }
        return $false
    }
    if ($ctx.DryRun) { Write-Step "Mod $Id$(if ($pairs) { ': ' + ($pairs -join ', ') })" -Level Skip; return $false }
    $added = $false
    if ($Id -notin $Installed) {
        Write-Step "Instalando mod $Id..."
        Invoke-WindhawkCli -Arguments @('mod', 'install', $Id, '--quiet') | Out-Null
        $added = $true
    }
    if ($pairs) { Write-WindhawkModSettings -Id $Id -Settings $Settings }
    Invoke-WindhawkCli -Arguments @('mod', 'enable', $Id, '--quiet') -AllowFailure | Out-Null
    $shown = @($pairs | Where-Object { $_ -notmatch '^(controlStyles|themeResourceVariables)\[' })
    $extra = @($pairs).Count - $shown.Count
    Write-Step "Mod $Id activo$(if ($shown) { ': ' + ($shown -join ', ') })$(if ($extra) { " (+$extra ajustes de color/forma)" })" -Level Ok
    $added
}

function Write-WindhawkModSettings {
    <# Escribe TODOS los ajustes del mod: los valores por defecto + los elegidos. Asi no quedan restos
       de una personalizacion anterior (por ejemplo, colores que ya no se usan). #>
    param([Parameter(Mandatory)][string]$Id, $Settings)
    $wanted = ConvertTo-Hashtable $Settings
    $all = [ordered]@{}
    $r = Invoke-WindhawkCli -Arguments @('mod', 'settings', 'defaults', $Id, '--json') -AllowFailure
    try { $def = ($r.Output | ConvertFrom-Json).data.settings; foreach ($p in $def.PSObject.Properties) { $all[$p.Name] = $p.Value } } catch { }
    # Las listas por defecto traen una entrada vacia [0]; si se rellena la lista, se quitan
    foreach ($list in 'controlStyles', 'themeResourceVariables', 'styleConstants') {
        if (@($wanted.Keys | Where-Object { $_ -like "$list[[]*" }).Count) {
            foreach ($k in @($all.Keys | Where-Object { $_ -like "$list[[]*" })) { $all.Remove($k) }
        }
    }
    foreach ($k in $wanted.Keys) {
        $v = $wanted[$k]
        if ($v -is [bool]) { $v = [int]$v }
        $all[$k] = $v
    }
    $tmp = Join-Path $env:TEMP "zk-wh-$Id.json"
    [IO.File]::WriteAllText($tmp, (ConvertTo-Json $all -Depth 4), (New-Object Text.UTF8Encoding($false)))
    try { Invoke-WindhawkCli -Arguments @('mod', 'settings', 'write', $Id, $tmp, '--quiet') | Out-Null }
    finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

function Get-WindhawkModSetting {
    param([Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$Key)
    $r = Invoke-WindhawkCli -Arguments @('mod', 'settings', 'get', $Id, '--json') -AllowFailure
    try { ($r.Output | ConvertFrom-Json).data.settings.$Key } catch { $null }
}

function Clear-IconCache {
    <# Los iconos nuevos no se ven hasta vaciar la cache de iconos del Explorador. #>
    if ((Get-ZKContext).DryRun) { Write-Step 'Vaciar la cache de iconos' -Level Skip; return }
    Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
    $dir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer'
    Get-ChildItem $dir -Filter 'iconcache_*.db' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    Write-Step 'Cache de iconos vaciada (se regenera al reiniciar el Explorador)' -Level Ok
}

function Restart-ShellHosts {
    <# Reinicia menu Inicio, busqueda, notificaciones y Configuracion para que carguen los estilos nuevos. #>
    if ((Get-ZKContext).DryRun) { return }
    'StartMenuExperienceHost', 'SearchHost', 'ShellExperienceHost', 'SystemSettings' | ForEach-Object {
        Get-Process $_ -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

function Backup-Windhawk {
    param([Parameter(Mandatory)][string]$Path)
    if ((Get-ZKContext).DryRun) { Write-Step 'Copia de seguridad de Windhawk' -Level Skip; return }
    Invoke-WindhawkCli -Arguments @('data', 'export', '--out', $Path, '--force', '--quiet') | Out-Null
    Write-Step 'Copia de seguridad de Windhawk exportada' -Level Ok
}

function Restore-Windhawk {
    param([Parameter(Mandatory)][string]$BackupDir)
    if (-not (Get-WindhawkInfo).Cli) { return }
    $added = Join-Path $BackupDir 'windhawk-added-mods.txt'
    if (Test-Path $added) {
        Get-Content $added -Encoding UTF8 | Where-Object { $_ } | ForEach-Object {
            Invoke-WindhawkCli -Arguments @('mod', 'remove', $_, '--yes', '--quiet') -AllowFailure | Out-Null
            Write-Host "[OK] Mod $_ desinstalado" -ForegroundColor Green
        }
    }
    $zip = Join-Path $BackupDir 'windhawk-before.zip'
    if (Test-Path $zip) {
        # Con el Explorador cerrado, el mod de iconos no pregunta por la cache al cambiar de pack
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Invoke-WindhawkCli -Arguments @('data', 'import', $zip, '--on-conflict', 'overwrite', '--yes', '--confirm-app-restart', '--quiet') -AllowFailure | Out-Null
        Write-Host '[OK] Ajustes de Windhawk restaurados' -ForegroundColor Green
        Clear-IconCache
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    }
    Hide-Windhawk
}

Export-ModuleMember -Function *
