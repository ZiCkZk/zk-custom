# 20-Apps.ps1 - instala aplicaciones con winget (lista en config.json -> apps)
param($Config, $Root)

$apps = @($Config.apps) | Where-Object { $_ }
if (-not $apps) { Write-Step 'No hay aplicaciones en la lista' -Level Skip; return }
foreach ($a in $apps) {
    if ($a -is [string]) { Install-App -Id $a } else { Install-App -Id $a.id -Name $a.name }
}
