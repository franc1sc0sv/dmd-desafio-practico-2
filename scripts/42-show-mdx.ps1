# Muestra una consulta MDX y su resultado contra el cubo, en una ventana de consola.
param([string]$File, [string]$Titulo = "")
$ErrorActionPreference = 'Stop'
try { $h = $Host.UI.RawUI; $h.BufferSize = New-Object System.Management.Automation.Host.Size(260, 3000); $h.WindowSize = New-Object System.Management.Automation.Host.Size(220, 52); $h.WindowTitle = "Cubo AdventureWorksCubo - MDX" } catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -Path "C:\Program Files\Microsoft.NET\ADOMD.NET\170\Microsoft.AnalysisServices.AdomdClient.dll"
$ASSRV = "localhost"; $cfg = Join-Path $PSScriptRoot "as-server.txt"; if (Test-Path $cfg) { $ASSRV = (Get-Content $cfg -Raw).Trim() }   # servidor de Analysis Services
$c = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection "Data Source=$ASSRV;Catalog=AdventureWorksCubo"
$c.Open()
Write-Host ("=" * 100) -ForegroundColor Cyan
Write-Host "Servidor : $($c.ServerVersion)  (Analysis Services, $ASSRV)" -ForegroundColor Cyan
Write-Host "Base     : AdventureWorksCubo   Cubo: Ventas AdventureWorks" -ForegroundColor Cyan
if ($Titulo) { Write-Host "Consulta : $Titulo" -ForegroundColor Cyan }
Write-Host ("=" * 100) -ForegroundColor Cyan
$q = Get-Content $File -Raw -Encoding UTF8
Write-Host $q -ForegroundColor Yellow
Write-Host ("-" * 100) -ForegroundColor Cyan
$cmd = $c.CreateCommand(); $cmd.CommandText = $q
$cs = $cmd.ExecuteCellSet()
$rows = $cs.Axes[1].Positions; $cols = $cs.Axes[0].Positions
$colNames = foreach ($k in 0..($cols.Count - 1)) { ($cols[$k].Members | ForEach-Object { $_.Caption }) -join "/" }
$chunk = 7
for ($start = 0; $start -lt $cols.Count; $start += $chunk) {
  $end = [Math]::Min($start + $chunk, $cols.Count) - 1
  $out = foreach ($r in 0..($rows.Count - 1)) {
    $o = [ordered]@{ Fila = (($rows[$r].Members | ForEach-Object { $_.Caption }) -join " / ") }
    foreach ($k in $start..$end) { $o[$colNames[$k]] = $cs.Cells[$k, $r].FormattedValue }
    [pscustomobject]$o
  }
  if ($cols.Count -gt $chunk) { Write-Host ("Columnas {0} a {1} de {2}" -f ($start + 1), ($end + 1), $cols.Count) -ForegroundColor Cyan }
  $out | Format-Table -AutoSize | Out-String -Width 400 | Write-Host
}
Write-Host "Filas devueltas: $($rows.Count)    Columnas: $($cols.Count)" -ForegroundColor Green
$c.Close()
