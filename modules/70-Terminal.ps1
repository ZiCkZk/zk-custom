# 70-Terminal.ps1 - esquema de color y fuente para Windows Terminal mediante un "fragment"
# (archivo aparte que Terminal lee al arrancar; no se edita tu settings.json y se deshace borrandolo)
param($Config, $Root)

$t = $Config.terminal
if (-not $t) { Write-Step 'Terminal sin configurar' -Level Skip; return }
$p    = $Config.palette
$ansi = $p.ansi
if (-not $ansi) {
    # Sin colores ANSI definidos: se derivan de la paleta
    $ansi = [pscustomobject]@{ black = $p.surface; red = '#F7768E'; green = '#9ECE6A'; yellow = '#E0AF68'; blue = $p.primary; purple = $p.secondary; cyan = $p.highlight; white = $p.text
        brightBlack = $p.muted; brightRed = '#F7768E'; brightGreen = '#9ECE6A'; brightYellow = '#E0AF68'; brightBlue = $p.primary; brightPurple = $p.secondary; brightCyan = $p.highlight; brightWhite = $p.text }
}
$schemeName = "ZK-Custom $($Config.meta.name)"
$scheme = [ordered]@{ name = $schemeName; background = $p.base; foreground = $p.text; cursorColor = $p.primary; selectionBackground = $p.surface }
foreach ($k in 'black','red','green','yellow','blue','purple','cyan','white','brightBlack','brightRed','brightGreen','brightYellow','brightBlue','brightPurple','brightCyan','brightWhite') { $scheme[$k] = $ansi.$k }

$profileProps = [ordered]@{ colorScheme = $schemeName }
if ($t.font)    { $profileProps.font = [ordered]@{ face = $t.font; size = $(if ($t.fontSize) { $t.fontSize } else { 11 }) } }
if ($null -ne $t.opacity) { $profileProps.opacity = [int]$t.opacity; $profileProps.useAcrylic = $true }

# GUID fijos de los perfiles que crea Windows Terminal
$guids = @('{61c54bbd-c2c6-5271-96e7-009a87ff44bf}',  # Windows PowerShell
           '{0caa0dad-35be-5f56-a8ff-afceeeaa6101}',  # Simbolo del sistema
           '{574e775e-4f2a-5b96-ac1e-a2962a402336}')  # PowerShell 7
$profiles = foreach ($g in $guids) { $o = [ordered]@{ updates = $g }; foreach ($kv in $profileProps.GetEnumerator()) { $o[$kv.Key] = $kv.Value }; $o }

$fragment = [ordered]@{ '$help' = 'Generado por ZK-Custom'; schemes = @($scheme); profiles = @($profiles) }
$dir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\ZK-Custom'
$file = Join-Path $dir 'zk-custom.json'
if ((Get-ZKContext).DryRun) { Write-Step "Escribir $file (esquema '$schemeName', fuente $($t.font))" -Level Skip; return }
New-Item -ItemType Directory -Force -Path $dir | Out-Null
# El proyecto antes se llamaba WinRice: se quita su fragmento para no tener dos esquemas
$old = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\WinRice'
if (Test-Path $old) { Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path $file)) { Register-CreatedFile $file }
[IO.File]::WriteAllText($file, ($fragment | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
Write-Step "Windows Terminal: esquema '$schemeName' listo (se ve al abrir una ventana nueva)" -Level Ok
