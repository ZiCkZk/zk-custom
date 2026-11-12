# 15-Tweaks.ps1 - ajustes nativos de Windows (menu contextual, Explorador, barra, Inicio...)
# config.json -> tweaks: { "id": true | false }. true aplica el ajuste, false vuelve al valor de Windows.
param($Config, $Root)

$wanted = ConvertTo-Hashtable $Config.tweaks
if (-not $wanted.Count) { Write-Step 'No hay ajustes del sistema elegidos' -Level Skip; return }
$catalog = Get-Content (Join-Path $Root 'catalog\static\tweaks.json') -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($id in $wanted.Keys) {
    $t = $catalog | Where-Object { $_.id -eq $id } | Select-Object -First 1
    if (-not $t) { Write-Step "Ajuste desconocido: $id" -Level Warn; continue }
    $on = [bool]$wanted[$id]
    try {
        foreach ($op in $t.ops) {
            $type = if ($op.type) { $op.type } else { 'DWord' }
            $v = if ($on) { $op.on } else { $op.off }
            if ($null -eq $v) {
                if ($op.offDeletesKey) { Remove-RegValue -Path $op.path } else { Remove-RegValue -Path $op.path -Name $op.name }
            } else { Set-RegValue $op.path $op.name $v -Type $type }
        }
        Write-Step "$($t.name): $(if ($on) { 'activado' } else { 'como viene en Windows' })" -Level Ok
    } catch { Write-Step "$($t.name): $($_.Exception.Message)" -Level Warn }
}
Send-SettingChange
