# Abre el proyecto en Visual Studio y captura el explorador, cada diseñador y el resultado de compilar/desplegar.
param([string]$Sln = "C:\Users\Public\dp2\vsproj\AdventureWorksCubo.sln", [string]$Out = "C:\Users\Public\dp2\shots")
. C:\Users\Public\dp2\lib.ps1
function Click-At($x,$y) { [Win]::SetCursorPos($x,$y) | Out-Null; Start-Sleep -Milliseconds 300; [Win]::mouse_event(2,0,0,0,0); [Win]::mouse_event(4,0,0,0,0); Start-Sleep 2 }
function Clear-Dialogs() {
  $w = Get-Win devenv; if (-not $w) { return }
  foreach ($x in $w.FindAll($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition $AE::ControlTypeProperty, $CT::Window))) {
    $r = $x.Current.BoundingRectangle
    if ($x.Current.Name -eq "Microsoft Visual Studio" -and (Find-El $x "conversion" $null -Contains)) { Click-At ([int]($r.X + $r.Width - 157)) ([int]($r.Y + $r.Height - 24)) }   # convertir proyecto: Yes
    elseif ($x.Current.Name -eq "Microsoft Visual Studio" -and $r.Width -lt 600) { Click-At ([int]($r.X + $r.Width - 62)) ([int]($r.Y + $r.Height - 31)) }   # "bloqueo de entrada": No
    if ($x.Current.Name -match "Feedback") { Click-At ([int]($r.X + $r.Width - 18)) ([int]($r.Y + 14)) }
  }
}
function Show-Tab($name) { Clear-Dialogs; $w = Get-Win devenv; $t = Find-El $w $name $CT::TabItem; if ($t) { Click-El $t; Start-Sleep 4 } else { "sin tab $name" } }
function Open-Item($name) { Clear-Dialogs; $w = Get-Win devenv; $it = Find-El $w $name $CT::TreeItem; DoubleClick-El $it; Start-Sleep 14 }

Get-Process devenv -ErrorAction SilentlyContinue | Stop-Process -Force; Start-Sleep 4
Start-Process "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\devenv.exe" -ArgumentList "`"$Sln`""
Start-Sleep 40
Clear-Dialogs
Start-Sleep 25
Focus-Win devenv -Maximize | Out-Null
Clear-Dialogs
$w = Get-Win devenv
$se = Find-El $w "Solution Explorer" $CT::TabItem; if ($se) { Click-El $se }; Start-Sleep 1
foreach ($n in "AdventureWorksCubo","Data Sources","Data Source Views","Cubes","Dimensions") { $e = Find-El (Get-Win devenv) $n $CT::TreeItem; if ($e) { Expand-El $e; Start-Sleep 1 } }
Start-Sleep 2
Capture "$Out\30-vs-explorador-de-soluciones.png" "devenv" @("AdventureWorksDW2022.ds","AdventureWorksDW2022 DSV.dsv","Ventas AdventureWorks.cube","Fecha.dim")
foreach ($n in "Fecha.dim","Producto.dim","Territorio de Ventas.dim","AdventureWorksDW2022 DSV.dsv","Ventas AdventureWorks.cube") { Open-Item $n }
Show-Tab "Fecha.dim [Design]";                 Capture "$Out\31-vs-dimension-fecha.png" "devenv" @("Fecha.dim [Design]","Attributes","Hierarchies","Data Source View")
Show-Tab "Producto.dim [Design]";              Capture "$Out\32-vs-dimension-producto.png" "devenv" @("Producto.dim [Design]","Attributes","Hierarchies","Data Source View")
Show-Tab "Territorio de Ventas.dim [Design]";  Capture "$Out\33-vs-dimension-territorio.png" "devenv" @("Territorio de Ventas.dim [Design]","Attributes","Hierarchies","Data Source View")
Show-Tab "AdventureWorksDW2022 DSV.dsv [Design]"; Capture "$Out\34-vs-vista-origen-datos.png" "devenv" @("AdventureWorksDW2022 DSV.dsv [Design]")
Show-Tab "Ventas AdventureWorks.cube [Design]"; Capture "$Out\35-vs-cubo-estructura.png" "devenv" @("Ventas AdventureWorks.cube [Design]")
# compilar y desplegar desde el menu Build
$w = Get-Win devenv; $mb = Find-El $w "Build" $CT::MenuItem; Expand-El $mb; Start-Sleep 1
Click-El (Find-El $w "Deploy AdventureWorksCubo" $CT::MenuItem)
Start-Sleep 20
# aviso "la base de datos ya existe, se sobrescribira": Yes (boton a la derecha del cuadro)
$w = Get-Win devenv
foreach ($x in $w.FindAll($TS::Descendants, (New-Object System.Windows.Automation.PropertyCondition $AE::ControlTypeProperty, $CT::Window))) {
  $r = $x.Current.BoundingRectangle
  if ($x.Current.Name -eq "Microsoft Visual Studio" -and (Find-El $x "already exists" $null -Contains)) { Click-At ([int]($r.X + $r.Width - 157)) ([int]($r.Y + $r.Height - 24)) }
}
Start-Sleep 60
Show-Tab "Output"
Capture "$Out\36-vs-output-despliegue-exitoso.png" "devenv" @("Output","Error List")
