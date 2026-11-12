# Core.psm1 - utilidades compartidas por todos los modulos de ZK-Custom

$script:Ctx = @{ Root = $null; BackupDir = $null; CacheDir = $null; DryRun = $false }
$script:BackedUp = New-Object System.Collections.Generic.HashSet[string]

function Initialize-ZKCustom {
    param([Parameter(Mandatory)][string]$Root, [Parameter(Mandatory)][string]$BackupDir, [switch]$DryRun)
    $script:Ctx.Root      = $Root
    $script:Ctx.BackupDir = $BackupDir
    $script:Ctx.CacheDir  = Join-Path $Root 'cache'
    $script:Ctx.DryRun    = [bool]$DryRun
    $script:BackedUp.Clear()
    New-Item -ItemType Directory -Force -Path $script:Ctx.CacheDir | Out-Null
}

function Get-ZKContext { [pscustomobject]$script:Ctx }

function Write-Section {
    param([string]$Title)
    Write-Host ''
    Write-Host ("=== {0} " -f $Title).PadRight(60, '=') -ForegroundColor Magenta
}

function Write-Step {
    param([string]$Message, [ValidateSet('Info','Ok','Skip','Warn','Error')][string]$Level = 'Info')
    $map = @{ Info = @('[..]','Cyan'); Ok = @('[OK]','Green'); Skip = @('[--]','DarkGray'); Warn = @('[!!]','Yellow'); Error = @('[XX]','Red') }
    $prefix = $map[$Level][0]; if ($script:Ctx.DryRun) { $prefix = "$prefix[sim]" }
    Write-Host "$prefix $Message" -ForegroundColor $map[$Level][1]
}

function ConvertTo-Hashtable {
    # ConvertFrom-Json devuelve PSCustomObject; los modulos prefieren hashtables.
    param($InputObject)
    $h = [ordered]@{}
    if ($null -eq $InputObject) { return $h }
    foreach ($p in $InputObject.PSObject.Properties) { $h[$p.Name] = $p.Value }
    $h
}

# ---------- Registro ----------

function ConvertTo-RegExePath {
    param([string]$Path)
    $Path -replace '^HKCU:\\', 'HKEY_CURRENT_USER\' -replace '^HKLM:\\', 'HKEY_LOCAL_MACHINE\'
}

function Backup-RegistryKey {
    <# Exporta la clave a .reg una sola vez por ejecucion. Si no existia, la apunta en missing-keys.txt
       para que Restore.ps1 pueda borrarla. #>
    param([Parameter(Mandatory)][string]$Path)
    if (-not $script:BackedUp.Add($Path)) { return }
    if ($script:Ctx.DryRun) { return }
    if (Test-Path $Path) {
        $file = Join-Path $script:Ctx.BackupDir (($Path -replace '[:\\ ]', '_') + '.reg')
        & reg.exe export (ConvertTo-RegExePath $Path) $file /y | Out-Null
    } else {
        Add-Content -Path (Join-Path $script:Ctx.BackupDir 'missing-keys.txt') -Value $Path -Encoding UTF8
    }
}

function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()]$Value,
        [ValidateSet('DWord','QWord','String','ExpandString','Binary','MultiString')][string]$Type = 'DWord'
    )
    Backup-RegistryKey -Path $Path
    $shown = if ($Value -is [byte[]]) { "[$($Value.Length) bytes]" } else { $Value }
    $label = if ($Name) { $Name } else { '(predeterminado)' }
    if ($script:Ctx.DryRun) { Write-Step "$Path\$label = $shown ($Type)" -Level Skip; return }
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    if ($Name) {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
    } else {
        Set-Item -Path $Path -Value $Value -ErrorAction Stop
    }
}

function Remove-RegValue {
    <# Borra un valor (o la clave entera si no se indica nombre), con copia de seguridad previa. #>
    param([Parameter(Mandatory)][string]$Path, [string]$Name)
    if (-not (Test-Path $Path)) { return }
    if ($Name -and $null -eq (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue)) { return }
    Backup-RegistryKey -Path $Path
    if ($script:Ctx.DryRun) { Write-Step "Borrar $Path$(if ($Name) { "\$Name" })" -Level Skip; return }
    if ($Name) { Remove-ItemProperty -Path $Path -Name $Name -Force -ErrorAction Stop }
    else { Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop }
}

function Register-CreatedFile {
    # Apunta archivos creados por ZK-Custom para que Restore.ps1 los borre.
    param([Parameter(Mandatory)][string]$Path)
    if ($script:Ctx.DryRun) { return }
    Add-Content -Path (Join-Path $script:Ctx.BackupDir 'created-files.txt') -Value $Path -Encoding UTF8
}

# ---------- Colores ----------

function ConvertFrom-Hex {
    param([Parameter(Mandatory)][string]$Hex)
    $h = $Hex.TrimStart('#')
    [pscustomobject]@{
        R = [Convert]::ToByte($h.Substring(0,2),16)
        G = [Convert]::ToByte($h.Substring(2,2),16)
        B = [Convert]::ToByte($h.Substring(4,2),16)
    }
}

function ConvertTo-Int32Bits {
    # El registro guarda DWORD con signo en PowerShell; reinterpreta un uint32 sin perder bits.
    param([uint32]$Value)
    [BitConverter]::ToInt32([BitConverter]::GetBytes($Value), 0)
}

function Get-ColorDword {
    <# Devuelve el color como DWORD en formato ABGR (AccentColor, AccentColorMenu)
       o ARGB (ColorizationColor). #>
    param([Parameter(Mandatory)][string]$Hex, [ValidateSet('ABGR','ARGB')][string]$Format = 'ABGR', [byte]$Alpha = 0xFF)
    $c = ConvertFrom-Hex $Hex
    if ($Format -eq 'ABGR') { $u = ([uint32]$Alpha -shl 24) -bor ([uint32]$c.B -shl 16) -bor ([uint32]$c.G -shl 8) -bor [uint32]$c.R }
    else                    { $u = ([uint32]$Alpha -shl 24) -bor ([uint32]$c.R -shl 16) -bor ([uint32]$c.G -shl 8) -bor [uint32]$c.B }
    ConvertTo-Int32Bits $u
}

function Get-ShadeHex {
    # Factor > 0 aclara hacia blanco, < 0 oscurece hacia negro.
    param([Parameter(Mandatory)][string]$Hex, [double]$Factor)
    $c = ConvertFrom-Hex $Hex
    $f = { param($v) if ($Factor -ge 0) { [int]($v + (255 - $v) * $Factor) } else { [int]($v * (1 + $Factor)) } }
    '#{0:X2}{1:X2}{2:X2}' -f (& $f $c.R), (& $f $c.G), (& $f $c.B)
}

function Get-AccentPalette {
    <# 8 tonos x 4 bytes (R,G,B,0) que Windows usa para menus, hover y botones. #>
    param([Parameter(Mandatory)][string]$Hex)
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($f in 0.6, 0.4, 0.2, 0.0, -0.25, -0.45, -0.65, -0.8) {
        $c = ConvertFrom-Hex (Get-ShadeHex $Hex $f)
        $bytes.AddRange([byte[]]@($c.R, $c.G, $c.B, 0))
    }
    ,$bytes.ToArray()
}

# ---------- Descargas ----------

function Get-GitHubReleaseAsset {
    <# Busca un archivo en una release de GitHub. Devuelve URL, tamano y SHA-256 (si GitHub lo publica). #>
    param(
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Pattern,
        [string]$Tag = 'latest',
        [switch]$IncludePrerelease
    )
    $h = @{ 'User-Agent' = 'zk-custom'; 'Accept' = 'application/vnd.github+json' }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = if ($IncludePrerelease) { "https://api.github.com/repos/$Repo/releases?per_page=5" } elseif ($Tag -eq 'latest') { "https://api.github.com/repos/$Repo/releases/latest" } else { "https://api.github.com/repos/$Repo/releases/tags/$Tag" }
    # La API de GitHub permite 60 consultas por hora: la respuesta se guarda 24 h en cache\github
    $cacheDir = Join-Path $script:Ctx.CacheDir 'github'; New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    $cacheFile = Join-Path $cacheDir (($url -replace '^https://api\.github\.com/repos/', '' -replace '[^\w.-]', '_') + '.json')
    $rel = $null
    if ((Test-Path $cacheFile) -and ((Get-Date) - (Get-Item $cacheFile).LastWriteTime).TotalHours -lt 24) { $rel = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json }
    if (-not $rel) {
        try {
            $raw = (Invoke-WebRequest $url -Headers $h -UseBasicParsing).Content
            [IO.File]::WriteAllText($cacheFile, $raw, (New-Object Text.UTF8Encoding($false)))
            $rel = $raw | ConvertFrom-Json
        } catch {
            if (Test-Path $cacheFile) { $rel = Get-Content $cacheFile -Raw -Encoding UTF8 | ConvertFrom-Json }
            elseif ($Tag -eq 'latest' -and -not $IncludePrerelease -and $Pattern -match '^\^?([\w.\\-]+?)\$?$') {
                # Sin API (limite alcanzado): enlace directo a la ultima release. Se verifica solo al descargar.
                $name = $Matches[1] -replace '\\', ''
                Write-Step "GitHub limita las consultas; se descarga $name por enlace directo" -Level Warn
                return [pscustomobject]@{ Repo = $Repo; Tag = 'latest'; Name = $name; Url = "https://github.com/$Repo/releases/latest/download/$name"; Size = 0; Sha256 = $null }
            } else { throw }
        }
    }
    if ($rel -is [array]) { $rel = $rel[0] }
    $asset = $rel.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    if (-not $asset) { throw "No hay ningun archivo que coincida con '$Pattern' en $Repo ($($rel.tag_name))." }
    $sha = $null
    if ($asset.digest -and $asset.digest -match '^sha256:([0-9a-fA-F]{64})$') { $sha = $Matches[1] }
    [pscustomobject]@{ Repo = $Repo; Tag = $rel.tag_name; Name = $asset.name; Url = $asset.browser_download_url; Size = [long]$asset.size; Sha256 = $sha }
}

function Save-Download {
    <# Descarga a cache\downloads y verifica SHA-256 o tamano. Si ya esta en cache y es valido, no descarga. #>
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$FileName,
        [string]$Sha256,
        [long]$Size = 0
    )
    $dir = Join-Path $script:Ctx.CacheDir 'downloads'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $out = Join-Path $dir ($FileName -replace '[\\/:*?"<>|]', '_')
    $valid = {
        param($p)
        if (-not (Test-Path $p)) { return $false }
        if ($Sha256) { return ((Get-FileHash $p -Algorithm SHA256).Hash -eq $Sha256.ToUpper()) }
        if ($Size -gt 0) { return ((Get-Item $p).Length -eq $Size) }
        return ((Get-Item $p).Length -gt 0)
    }
    if (& $valid $out) { Write-Step "En cache: $FileName" -Level Skip; return $out }
    if ($script:Ctx.DryRun) { Write-Step "Descargar $Url" -Level Skip; return $out }
    Write-Step "Descargando $FileName..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
    try { Invoke-WebRequest -Uri $Url -OutFile $out -UseBasicParsing -Headers @{ 'User-Agent' = 'zk-custom' } }
    finally { $ProgressPreference = $old }
    if (-not (& $valid $out)) {
        Remove-Item $out -Force -ErrorAction SilentlyContinue
        throw "La descarga de $FileName no supera la verificacion (hash o tamano distinto). Se ha borrado."
    }
    if (-not $Sha256) { Write-Step "$FileName verificado solo por tamano (el origen no publica hash)" -Level Warn }
    $out
}

function Expand-ToCache {
    # Descomprime un .zip en cache\extracted\<nombre> (limpio en cada uso).
    param([Parameter(Mandatory)][string]$ZipPath, [Parameter(Mandatory)][string]$Name)
    $dest = Join-Path $script:Ctx.CacheDir ("extracted\" + ($Name -replace '[\\/:*?"<>|]', '_'))
    if ($script:Ctx.DryRun) { return $dest }
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $dest -Force
    $dest
}

function Get-Resource {
    <# Resuelve una fuente de recurso de config.json y devuelve la ruta local del archivo descargado.
       Formatos: @{ source='github'; repo; asset }  |  @{ source='url'; url; fileName; sha256 } #>
    param([Parameter(Mandatory)]$Spec)
    switch ($Spec.source) {
        'github' {
            $a = Get-GitHubReleaseAsset -Repo $Spec.repo -Pattern $Spec.asset
            return Save-Download -Url $a.Url -FileName $a.Name -Sha256 $a.Sha256 -Size $a.Size
        }
        'url' {
            $name = if ($Spec.fileName) { $Spec.fileName } else { [IO.Path]::GetFileName(([uri]$Spec.url).LocalPath) }
            return Save-Download -Url $Spec.url -FileName $name -Sha256 $Spec.sha256
        }
        default { throw "Origen de recurso desconocido: '$($Spec.source)'" }
    }
}

# ---------- Cursores ----------

function Read-CursorInf {
    <# Interpreta el install.inf de un pack de cursores SIN ejecutarlo.
       Devuelve el nombre del esquema, la carpeta de destino (relativa a %SystemRoot%) y el valor de cada puntero.
       Admite los dos formatos habituales: lineas por puntero (Bibata/clickgen) o solo la lista del esquema (Posy). #>
    param([Parameter(Mandatory)][string]$Path)
    $sec = @{}; $cur = $null
    foreach ($raw in Get-Content -LiteralPath $Path -Encoding Default) {
        $line = ($raw -replace '^\s*;.*$', '').Trim()
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') { $cur = $Matches[1].Trim(); $sec[$cur] = New-Object System.Collections.Generic.List[string]; continue }
        if ($cur) { $sec[$cur].Add($line) }
    }
    $strings = @{}   # las claves de [Strings] no distinguen mayusculas
    foreach ($l in $sec['Strings']) { if ($l -match '^([^=]+?)\s*=\s*"?(.*?)"?\s*$') { $strings[$Matches[1].Trim()] = $Matches[2] } }
    $expand = {
        param([string]$s)
        for ($i = 0; $i -lt 5 -and $s -match '%[^%]+%'; $i++) {
            $out = New-Object System.Text.StringBuilder; $pos = 0
            foreach ($m in [regex]::Matches($s, '%([^%]+)%')) {
                [void]$out.Append($s.Substring($pos, $m.Index - $pos))
                $k = $m.Groups[1].Value
                if ($k -eq '10') { [void]$out.Append('%SystemRoot%') } elseif ($strings.ContainsKey($k)) { [void]$out.Append($strings[$k]) } else { [void]$out.Append($m.Value) }
                $pos = $m.Index + $m.Length
            }
            [void]$out.Append($s.Substring($pos)); $s = $out.ToString()
            if ($s -notmatch '%(?!SystemRoot%)[^%]+%') { break }
        }
        $s
    }
    $destRel = $null
    foreach ($l in $sec['DestinationDirs']) { if ($l -match '=\s*10\s*,\s*"?([^"]+)"?') { $destRel = & $expand $Matches[1]; break } }

    $regSections = @()
    foreach ($l in $sec['DefaultInstall']) { if ($l -match '^AddReg\s*=\s*(.+)$') { $regSections += $Matches[1] -split '\s*,\s*' } }
    $values = [ordered]@{}; $scheme = $null; $schemeList = $null
    foreach ($s in $regSections) {
        foreach ($l in $sec[$s]) {
            if ($l -notmatch '^HKCU\s*,\s*"([^"]+)"\s*,\s*"?([^",]*)"?\s*,\s*([^,]*)\s*,\s*"(.*)"\s*$') { continue }
            $key = $Matches[1]; $name = & $expand $Matches[2]; $value = & $expand $Matches[4]
            if ($key -eq 'Control Panel\Cursors\Schemes') { $scheme = $name; $schemeList = $value; continue }
            if ($key -ne 'Control Panel\Cursors') { continue }
            if ($name) { $values[$name] = $value } else { $scheme = $value }
        }
    }
    # Orden estandar de Windows para la lista de un esquema
    $order = 'Arrow','Help','AppStarting','Wait','Crosshair','IBeam','NWPen','No','SizeNS','SizeWE','SizeNWSE','SizeNESW','SizeAll','UpArrow','Hand','Pin','Person'
    if ($schemeList) {
        $parts = $schemeList -split ','
        for ($i = 0; $i -lt [Math]::Min($parts.Count, $order.Count); $i++) {
            if ($parts[$i] -and -not $values.Contains($order[$i])) { $values[$order[$i]] = $parts[$i] }
        }
    }
    [pscustomobject]@{ Scheme = $scheme; DestRel = $destRel; SchemeList = $schemeList; Values = $values }
}

# ---------- Sistema ----------

if (-not ('ZKCustom.Native' -as [type])) {
    Add-Type -Namespace ZKCustom -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll", CharSet = CharSet.Unicode)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
}

function Update-SystemParameter {
    # SPI_SETCURSORS = 0x57, SPI_SETDESKWALLPAPER = 0x14. Flags 3 = guardar + notificar.
    param([Parameter(Mandatory)][uint32]$Action, [string]$Value = $null)
    if ($script:Ctx.DryRun) { return }
    [void][ZKCustom.Native]::SystemParametersInfo($Action, 0, $Value, 3)
}

function Send-SettingChange {
    # Avisa a las apps de que han cambiado fuentes (WM_FONTCHANGE) o ajustes (WM_SETTINGCHANGE).
    param([uint32]$Message = 0x001A, [string]$Area = $null)
    if ($script:Ctx.DryRun) { return }
    $r = [UIntPtr]::Zero
    [void][ZKCustom.Native]::SendMessageTimeout([IntPtr]0xffff, $Message, [UIntPtr]::Zero, $Area, 2, 3000, [ref]$r)
}

function New-SafeRestorePoint {
    param([string]$Description = 'ZK-Custom')
    if ($script:Ctx.DryRun) { Write-Step "Punto de restauracion '$Description'" -Level Skip; return }
    try {
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Step "Punto de restauracion creado" -Level Ok
    } catch {
        Write-Step "No se pudo crear el punto de restauracion (proteccion del sistema desactivada o ya hay uno de las ultimas 24 h). Se continua con la copia del registro." -Level Warn
    }
}

function Install-App {
    param([Parameter(Mandatory)][string]$Id, [string]$Name = $Id, [string]$Source = 'winget')
    $installed = winget list --id $Id -e --source $Source --accept-source-agreements 2>$null | Select-String -SimpleMatch $Id
    if ($installed) { Write-Step "$Name ya esta instalado" -Level Skip; return }
    if ($script:Ctx.DryRun) { Write-Step "winget install $Id" -Level Skip; return }
    Write-Step "Instalando $Name..."
    winget install --id $Id -e --source $Source --silent --accept-package-agreements --accept-source-agreements | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Step "$Name instalado" -Level Ok } else { Write-Step "winget devolvio $LASTEXITCODE al instalar $Name" -Level Warn }
}

function Restart-Explorer {
    if ($script:Ctx.DryRun) { Write-Step 'Reiniciar explorer.exe' -Level Skip; return }
    Write-Step 'Reiniciando el Explorador para aplicar cambios...'
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

Export-ModuleMember -Function *
