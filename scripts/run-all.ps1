# Flujo completo en Windows (PowerShell 5.1): base -> cubo -> proyecto de VS -> capturas.
# Requisitos: SQL Server 2025 + SSAS multidimensional, Visual Studio 2022 con "Analysis Services Projects",
# SSMS 22, Power BI Desktop. Copia primero los scripts, sql y mdx a C:\Users\Public\dp2 (ver README).
param([switch]$Instalar, [switch]$SinCapturas)
$ErrorActionPreference = 'Stop'
$d = "C:\Users\Public\dp2"
function Paso($t) { Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Run($f, $a = @()) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$d\$f" @a; if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) { Write-Warning "$f termino con codigo $LASTEXITCODE" } }

if ($Instalar) { Paso "Instalar SSAS y la extension de Visual Studio (piden UAC)"; Run "10-install-ssas.ps1"; Run "20-install-vs-ssas-ext.ps1" }
Paso "1. Restaurar la base (sql\01-restaurar-base.sql, ver README: SSMS o sqlcmd)"
& "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE" -S localhost -E -C -b -i "$d\01-restaurar-base.sql"
Paso "2. Construir, desplegar y procesar el cubo"; Run "30-build-cube.ps1"
Paso "3. Exportar el proyecto de Visual Studio"; Run "50-export-vs-project.ps1"
Paso "4. Consultas MDX"; Run "40-run-mdx.ps1"
if (-not $SinCapturas) {
  Paso "5. Capturas de Visual Studio"; Run "60-capture-vs.ps1"
  Paso "6. Capturas de consola (entorno y MDX)"; Run "43-capture-console.ps1"
  Paso "7. Capturas de Power BI"; Run "70-capture-powerbi.ps1"
}
Write-Host "`nListo. En Linux/WSL: python3 scripts/60-build-pbix.py ; uv run --with pillow --with numpy python scripts/annotate.py ; uv run --with weasyprint --with pillow --with numpy python scripts/90-build-pdf.py" -ForegroundColor Green
