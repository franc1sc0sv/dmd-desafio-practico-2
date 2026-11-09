# Hace que Visual Studio use las librerias cliente de Analysis Services del SERVIDOR (SQL Server 2025, build 250918)
# en lugar de las de la extension 4.0.0 (build 250903), que el servidor rechaza ("edition ... not supported by the client").
# Reversible: guarda copias en C:\Users\Public\dp2\vs-amo-backup. Uso: -Modo aplicar | revertir   (pide UAC)
param([ValidateSet("aplicar","revertir")][string]$Modo = "aplicar")
$ErrorActionPreference = 'Stop'
$vs = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$dirs = @{ ext = "$vs\Common7\IDE\CommonExtensions\Microsoft\SSAS"; msb = "$vs\MSBuild\Business Intelligence Semantic Model\1.0" }
$src = "C:\Program Files\Microsoft SQL Server\170\DTS\Binn"
$names = "Microsoft.AnalysisServices.dll","Microsoft.AnalysisServices.Core.dll","Microsoft.AnalysisServices.Tabular.dll","Microsoft.AnalysisServices.Tabular.Json.dll"
$cfg = "$vs\Common7\IDE\devenv.exe.config"
$bk = "C:\Users\Public\dp2\vs-amo-backup"
if ($Modo -eq "aplicar") {
  if (-not (Test-Path $bk)) {
    foreach ($k in $dirs.Keys) { New-Item -ItemType Directory -Force "$bk\$k" | Out-Null; foreach ($n in $names) { Copy-Item "$($dirs[$k])\$n" "$bk\$k\$n" } }
    Copy-Item $cfg "$bk\devenv.exe.config"
    "respaldo creado en $bk"
  } else { "respaldo ya existia (no se sobrescribe)" }
  foreach ($k in $dirs.Keys) { foreach ($n in $names) { Copy-Item "$src\$n" "$($dirs[$k])\$n" -Force } }
  "librerias del servidor copiadas"
  [xml]$x = Get-Content $cfg
  $ab = $x.configuration.runtime.assemblyBinding | Select-Object -First 1
  $ns = $ab.NamespaceURI
  foreach ($n in $names) {
    $id = $n -replace "\.dll$",""
    if ($ab.dependentAssembly | Where-Object { $_.assemblyIdentity.name -eq $id -and $_.Comment -ne $null -and $_.OuterXml -match "amo-swap" }) { continue }
    $da = $x.CreateElement("dependentAssembly", $ns)
    $ai = $x.CreateElement("assemblyIdentity", $ns); $ai.SetAttribute("name",$id); $ai.SetAttribute("publicKeyToken","89845dcd8080cc91"); $ai.SetAttribute("culture","neutral")
    $br = $x.CreateElement("bindingRedirect", $ns); $br.SetAttribute("oldVersion","0.0.0.0-19.104.1.0"); $br.SetAttribute("newVersion","19.98.0.0")
    $da.AppendChild($ai) | Out-Null; $da.AppendChild($br) | Out-Null; $da.AppendChild($x.CreateComment(" amo-swap ")) | Out-Null
    $ab.AppendChild($da) | Out-Null
  }
  $x.Save($cfg); "devenv.exe.config con redirecciones a 19.98.0.0"
} else {
  if (-not (Test-Path $bk)) { throw "no hay respaldo en $bk" }
  foreach ($k in $dirs.Keys) { foreach ($n in $names) { Copy-Item "$bk\$k\$n" "$($dirs[$k])\$n" -Force } }
  Copy-Item "$bk\devenv.exe.config" $cfg -Force
  "REVERTIDO: librerias y configuracion originales restauradas"
}
