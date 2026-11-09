# Abre una consola clasica por cada consulta/script, la maximiza y captura el escritorio.
param([string]$Out = "C:\Users\Public\dp2\shots")
. C:\Users\Public\dp2\lib.ps1
Get-Process devenv,PBIDesktop,SSMS -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 3   # que no queden otras ventanas detras
$q = "C:\Users\Public\dp2\queries"
$jobs = @(
 @("05-show-entorno.ps1", "", "05-entorno-instalado.png"),
 @("42-show-mdx.ps1", "-File `"$q\q1-categorias-por-anio-trimestre.mdx`" -Titulo `"P1 - categorias por trimestre`"", "20-mdx-p1-trimestres.png"),
 @("42-show-mdx.ps1", "-File `"$q\q1b-subcategorias-por-anio.mdx`" -Titulo `"P1 - subcategorias por anio`"", "21-mdx-p1-anios.png"),
 @("42-show-mdx.ps1", "-File `"$q\q1c-subcategorias-por-trimestre.mdx`" -Titulo `"P1 - subcategorias por trimestre (2013)`"", "25-mdx-p1-subcat-trimestres.png"),
 @("42-show-mdx.ps1", "-File `"$q\q2-territorios-internet-vs-reseller.mdx`" -Titulo `"P2 - territorios: Internet vs Reseller`"", "22-mdx-p2-territorios.png"),
 @("42-show-mdx.ps1", "-File `"$q\q3-top10-productos.mdx`" -Titulo `"P3 - 10 productos mas rentables`"", "23-mdx-p3-top10.png"),
 @("42-show-mdx.ps1", "-File `"$q\q3b-top10-por-anio-trimestre.mdx`" -Titulo `"P3 - ventas de los 10 productos por trimestre`"", "24-mdx-p3-top10-trimestres.png"))
foreach ($j in $jobs) {
  $arg = "powershell.exe -NoProfile -NoExit -ExecutionPolicy Bypass -File `"C:\Users\Public\dp2\$($j[0])`" $($j[1])"
  $p = Start-Process conhost.exe -ArgumentList $arg -WorkingDirectory "C:\Users\Public\dp2" -PassThru
  Start-Sleep 14
  $win = Get-Process | Where-Object { $_.MainWindowTitle -like "*Desafio Practico 2*" -or $_.MainWindowTitle -like "*AdventureWorksCubo - MDX*" } | Select-Object -First 1
  if ($win) { [Win]::ShowWindow($win.MainWindowHandle, 3) | Out-Null; [Win]::SetForegroundWindow($win.MainWindowHandle) | Out-Null; Start-Sleep 2 }
  Capture "$Out\$($j[2])" $null @()
  Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like "*$($j[0])*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Start-Sleep 2
}
