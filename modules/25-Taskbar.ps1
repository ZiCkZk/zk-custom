# 25-Taskbar.ps1 - ajustes nativos de la barra de tareas (los estilos visuales van en 30-Windhawk)
param($Config, $Root)

$t   = $Config.taskbar
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

function Set-Safe($Path, $Name, $Value, $Label) {
    try { Set-RegValue $Path $Name $Value; Write-Step $Label -Level Ok }
    catch { Write-Step "$($Label): Windows no permite cambiarlo por registro en esta version ($($_.Exception.Message))" -Level Warn }
}

if ($null -ne $t.alignment) {
    $v = if ($t.alignment -eq 'left') { 0 } else { 1 }
    Set-Safe $adv 'TaskbarAl' $v "Iconos alineados: $($t.alignment)"
}
if ($null -ne $t.hideSearch) {
    $v = if ($t.hideSearch) { 0 } else { 1 }
    Set-Safe 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' $v "Busqueda $(if ($t.hideSearch) { 'oculta' } else { 'como icono' })"
}
if ($null -ne $t.hideTaskView) {
    Set-Safe $adv 'ShowTaskViewButton' ([int](-not $t.hideTaskView)) "Vista de tareas $(if ($t.hideTaskView) { 'oculta' } else { 'visible' })"
}
if ($null -ne $t.hideWidgets) {
    Set-Safe $adv 'TaskbarDa' ([int](-not $t.hideWidgets)) "Widgets $(if ($t.hideWidgets) { 'ocultos' } else { 'visibles' })"
}
