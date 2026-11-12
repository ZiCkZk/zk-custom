# 55-Folders.ps1 - carpetas de colores: cada carpeta elegida lleva un icono de carpeta de su color.
# Se hace con el desktop.ini de la carpeta (IconResource), que es lo que usa Windows; no toca el sistema.
# config.json -> folders: { "C:\\Users\\yo\\Documents": "#7AA2F7", "D:\\Juegos": "none" }
param($Config, $Root)

$folders = ConvertTo-Hashtable $Config.folders
if (-not $folders.Count) { Write-Step 'No hay carpetas de colores elegidas' -Level Skip; return }
$ctx = Get-ZKContext
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $Root 'modules\OrbArt.ps1')
if (-not ('ZKCustom.Shell' -as [type])) {
    Add-Type -Namespace ZKCustom -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, uint f, System.IntPtr a, System.IntPtr b);'
}
$iconDir = Join-Path $env:APPDATA 'ZK-Custom\folders'
$before = @()

foreach ($path in $folders.Keys) {
    $hex = [string]$folders[$path]
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { Write-Step "No existe la carpeta $path" -Level Warn; continue }
    $ini = Join-Path $path 'desktop.ini'
    # ReadAllLines detecta la codificacion por la marca BOM (los desktop.ini de Windows suelen ser UTF-16)
    $lines = if (Test-Path -LiteralPath $ini) { @([IO.File]::ReadAllLines($ini, [Text.Encoding]::Default)) } else { @() }
    $old = $lines | Where-Object { $_ -match '^\s*IconResource\s*=' } | Select-Object -First 1
    $before += [ordered]@{ path = $path; hadIni = (Test-Path -LiteralPath $ini); iconLine = $old }
    if ($ctx.DryRun) { Write-Step "Carpeta $path -> $hex" -Level Skip; continue }

    # Nueva linea IconResource (o ninguna si se quita el color)
    $newLine = $null
    if ($hex -and $hex -ne 'none') {
        New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
        $ico = Join-Path $iconDir ("carpeta-" + $hex.TrimStart('#') + '.ico')
        if (-not (Test-Path $ico)) { Save-IcoFile -Path $ico -Draw { param($s) New-FolderImage -Color $hex -Size $s } }
        $newLine = "IconResource=$ico,0"
    }
    $out = New-Object System.Collections.Generic.List[string]
    $inShell = $false; $done = $false; $hasShell = $false
    foreach ($l in $lines) {
        if ($l -match '^\s*\[') {
            if ($inShell -and -not $done -and $newLine) { $out.Add($newLine); $done = $true }
            $inShell = $l -match '^\s*\[\.ShellClassInfo\]'; if ($inShell) { $hasShell = $true }
            $out.Add($l); continue
        }
        if ($inShell -and $l -match '^\s*IconResource\s*=') { if ($newLine -and -not $done) { $out.Add($newLine); $done = $true }; continue }
        $out.Add($l)
    }
    if ($newLine -and -not $done) { if (-not $hasShell) { $out.Insert(0, '[.ShellClassInfo]') ; $out.Insert(1, $newLine) } else { $out.Add($newLine) } }

    if (Test-Path -LiteralPath $ini) { attrib -s -h -r "$ini" | Out-Null }
    [IO.File]::WriteAllLines($ini, $out.ToArray(), [Text.Encoding]::Unicode)
    attrib +s +h "$ini" | Out-Null
    attrib +r "$path" | Out-Null   # marca la carpeta como personalizada
    [ZKCustom.Shell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
    Write-Step "$(Split-Path $path -Leaf): $(if ($newLine) { "carpeta $hex" } else { 'color quitado' })" -Level Ok
}
if (-not $ctx.DryRun) {
    [IO.File]::WriteAllText((Join-Path $ctx.BackupDir 'folders-before.json'), (ConvertTo-Json @($before) -Depth 3), (New-Object Text.UTF8Encoding($false)))
    Start-Process ie4uinit.exe -ArgumentList '-show' -WindowStyle Hidden -ErrorAction SilentlyContinue
}
