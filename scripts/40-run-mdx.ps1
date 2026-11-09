$ErrorActionPreference = 'Stop'
$dll = Get-Item "C:\Program Files\Microsoft.NET\ADOMD.NET\170\Microsoft.AnalysisServices.AdomdClient.dll"
"adomd=" + $dll.FullName
Add-Type -Path $dll.FullName
$ASSRV = "localhost"; $cfg = Join-Path $PSScriptRoot "as-server.txt"; if (Test-Path $cfg) { $ASSRV = (Get-Content $cfg -Raw).Trim() }   # servidor de Analysis Services
$c = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection "Data Source=$ASSRV;Catalog=AdventureWorksCubo"
$c.Open()
foreach ($f in Get-ChildItem "C:\Users\Public\dp2\queries\*.mdx") {
  "=== " + $f.Name
  $cmd = $c.CreateCommand(); $cmd.CommandText = (Get-Content $f.FullName -Raw -Encoding UTF8)
  $cs = $cmd.ExecuteCellSet()
  $rows = $cs.Axes[1].Positions; $cols = $cs.Axes[0].Positions
  "COLUMNAS: " + (($cols | ForEach-Object { ($_.Members | ForEach-Object { $_.Caption }) -join "/" }) -join " | ")
  $n = 0
  for ($r = 0; $r -lt $rows.Count -and $n -lt 12; $r++, $n++) {
    $label = ($rows[$r].Members | ForEach-Object { $_.Caption }) -join " / "
    $vals = for ($k = 0; $k -lt $cols.Count; $k++) { $cs.Cells[$k, $r].FormattedValue }
    "{0} | {1}" -f $label, ($vals -join " | ")
  }
  "filas=" + $rows.Count
}
$c.Close()
