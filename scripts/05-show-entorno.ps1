# Muestra en consola el entorno instalado: versiones, servicios y estado de la base y del cubo.
try { $h = $Host.UI.RawUI; $h.BufferSize = New-Object System.Management.Automation.Host.Size(200, 1000); $h.WindowSize = New-Object System.Management.Automation.Host.Size(170, 45); $h.WindowTitle = "Entorno - Desafio Practico 2" } catch {}
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$sql = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
Write-Host ("=" * 90) -ForegroundColor Cyan; Write-Host " ENTORNO INSTALADO - Desafio Practico 2 (DMD941)" -ForegroundColor Cyan; Write-Host ("=" * 90) -ForegroundColor Cyan
$os = Get-CimInstance Win32_OperatingSystem
"Sistema operativo : {0} ({1})" -f $os.Caption, $os.Version
$v = & $sql -S localhost -E -C -h -1 -W -Q "SET NOCOUNT ON; SELECT CAST(SERVERPROPERTY('Edition') AS nvarchar(100)) + ' - ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50))"
"SQL Server         : $v"
$vs = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match "^Visual Studio Community 2022|^SQL Server Management Studio" } | Select-Object -First 2
foreach ($x in $vs) { "{0,-19}: {1} {2}" -f "Herramienta", $x.DisplayName, $x.DisplayVersion }
$pb = Get-AppxPackage Microsoft.MicrosoftPowerBIDesktop
"Power BI Desktop  : {0}" -f $pb.Version
$ext = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\SSAS" -ErrorAction SilentlyContinue
"Extension VS      : Analysis Services Projects (SSAS) - {0}" -f $(if ($ext) { "instalada" } else { "NO" })
Write-Host ""; Write-Host "Servicios" -ForegroundColor Yellow
Get-Service MSSQLSERVER, MSSQLServerOLAPService, "MSOLAP`$SSAS22" -ErrorAction SilentlyContinue | Format-Table @{n="Servicio";e={$_.DisplayName}}, Name, Status, StartType -AutoSize | Out-String | Write-Host
Write-Host "Base de datos relacional" -ForegroundColor Yellow
& $sql -S localhost -E -C -W -Q "SET NOCOUNT ON; SELECT name AS base, state_desc AS estado, compatibility_level AS compat FROM sys.databases WHERE name = 'AdventureWorksDW2022'; SELECT 'FactInternetSales' AS tabla, COUNT(*) AS filas FROM AdventureWorksDW2022.dbo.FactInternetSales UNION ALL SELECT 'FactResellerSales', COUNT(*) FROM AdventureWorksDW2022.dbo.FactResellerSales"
Write-Host "Analysis Services (cubo)" -ForegroundColor Yellow
Add-Type -Path "C:\Program Files\Microsoft SQL Server\170\DTS\Binn\Microsoft.AnalysisServices.dll"
$ASSRV = "localhost"; $cfg = Join-Path $PSScriptRoot "as-server.txt"; if (Test-Path $cfg) { $ASSRV = (Get-Content $cfg -Raw).Trim() }   # servidor de Analysis Services
$srv = New-Object Microsoft.AnalysisServices.Server; $srv.Connect($ASSRV)
foreach ($d in $srv.Databases) { foreach ($c in $d.Cubes) { "Base: {0}   Cubo: {1}   Estado: {2}   Procesado: {3}   Dimensiones: {4}   Grupos de medidas: {5}" -f $d.Name, $c.Name, $c.State, $c.LastProcessed, $c.Dimensions.Count, $c.MeasureGroups.Count } }
$srv.Disconnect()
