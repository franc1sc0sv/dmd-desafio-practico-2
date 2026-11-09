# Abre el dashboard en Power BI Desktop y captura cada pagina (escritorio completo).
param([string]$Pbix = "C:\Users\Public\dp2\powerbi\Dashboard-AdventureWorks.pbix", [string]$Out = "C:\Users\Public\dp2\shots", [string]$Prefix = "40-powerbi")
. C:\Users\Public\dp2\lib.ps1
Get-Process PBIDesktop -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 4
$pkg = Get-AppxPackage Microsoft.MicrosoftPowerBIDesktop
Start-Process (Join-Path $pkg.InstallLocation "bin\PBIDesktop.exe") -ArgumentList "`"$Pbix`""
Start-Sleep 55
Focus-Win PBIDesktop -Maximize | Out-Null
$w = Get-Win PBIDesktop
# cerrar el aviso verde de "Live Edit" (coach mark: no lo expone UIA; su X esta arriba a la izquierda)
foreach ($k in 1..2) { [Win]::SetCursorPos(640, 32) | Out-Null; Start-Sleep -Milliseconds 300; [Win]::mouse_event(2,0,0,0,0); [Win]::mouse_event(4,0,0,0,0); Start-Sleep 2 }
$names = @{ 1 = "pagina1-categorias-trimestres"; 2 = "pagina2-territorios"; 3 = "pagina3-top10-productos" }
foreach ($i in 1..3) {
  $tab = $null
  foreach ($try in 1..10) {
    $w = Get-Win PBIDesktop
    foreach ($e in $w.FindAll($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition $AE::ControlTypeProperty, $CT::TabItem))) { if ($e.Current.Name -like "P$i*" -and $e.Current.BoundingRectangle.Y -gt 1300) { $tab = $e; break } }
    if ($tab) { break }; Start-Sleep 3
  }
  if (-not $tab) { "sin pestana P$i"; continue }
  Click-El $tab; Start-Sleep 16
  Capture "$Out\$Prefix-$i-$($names[$i]).png" "PBIDesktop" @("P$i")
}
