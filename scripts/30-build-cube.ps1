# Crea, despliega y procesa el cubo "AdventureWorksCubo" en el SSAS local con AMO.
$ErrorActionPreference = 'Stop'
$sqlcmd = "C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\180\Tools\Binn\SQLCMD.EXE"
$ASSRV = "localhost"; $cfg = Join-Path $PSScriptRoot "as-server.txt"; if (Test-Path $cfg) { $ASSRV = (Get-Content $cfg -Raw).Trim() }   # servidor de Analysis Services
$svc = if ($ASSRV -match '\\(.+)$') { 'NT Service\MSOLAP$' + $Matches[1] } else { 'NT Service\MSSQLServerOLAPService' }   # cuenta de servicio de SSAS

# 1. Permiso de lectura para que SSAS lea AdventureWorksDW2022
$grant = "IF SUSER_ID('$svc') IS NULL CREATE LOGIN [$svc] FROM WINDOWS; USE AdventureWorksDW2022; IF USER_ID('$svc') IS NULL CREATE USER [$svc] FOR LOGIN [$svc]; ALTER ROLE db_datareader ADD MEMBER [$svc];"
& $sqlcmd -S localhost -E -C -b -Q $grant
if ($LASTEXITCODE -ne 0) { throw "No se pudo dar permiso a SSAS" }
"1. permiso de lectura OK"

Add-Type -Path "C:\Program Files\Microsoft SQL Server\170\DTS\Binn\Microsoft.AnalysisServices.dll"
$AS = 'Microsoft.AnalysisServices'
$int = [System.Data.OleDb.OleDbType]::Integer
$str = [System.Data.OleDb.OleDbType]::WChar
$cur = [System.Data.OleDb.OleDbType]::Currency

function DI($t, $c, $ty) { New-Object "$AS.DataItem" ($t, $c, $ty) }

$srv = New-Object "$AS.Server"
$srv.Connect($ASSRV)
$dbName = "AdventureWorksCubo"
if ($srv.Databases.ContainsName($dbName)) { $srv.Databases.GetByName($dbName).Drop() }
$db = New-Object "$AS.Database"
$db.Name = $dbName; $db.ID = $dbName
[void]$srv.Databases.Add($db)
$db.Update()
"2. base SSAS creada"

# 2. Origen de datos
$ds = New-Object "$AS.RelationalDataSource"
$ds.Name = "AdventureWorksDW2022"; $ds.ID = "AdventureWorksDW2022"
$ds.ConnectionString = "Provider=MSOLEDBSQL19;Data Source=localhost;Integrated Security=SSPI;Initial Catalog=AdventureWorksDW2022;Use Encryption for Data=Optional;Trust Server Certificate=True"
$ds.ImpersonationInfo = New-Object "$AS.ImpersonationInfo" ([Microsoft.AnalysisServices.ImpersonationMode]::ImpersonateServiceAccount)
[void]$db.DataSources.Add($ds)
$db.Update()
"3. origen de datos OK"

# 3. Vista del origen de datos (tablas, columnas y relaciones)
$tables = [ordered]@{
  DimDate               = "DateKey,CalendarYear,CalendarQuarter,MonthNumberOfYear,EnglishMonthName"
  DimProduct            = "ProductKey,EnglishProductName,ProductSubcategoryKey"
  DimProductSubcategory = "ProductSubcategoryKey,EnglishProductSubcategoryName,ProductCategoryKey"
  DimProductCategory    = "ProductCategoryKey,EnglishProductCategoryName"
  DimSalesTerritory     = "SalesTerritoryKey,SalesTerritoryRegion,SalesTerritoryCountry,SalesTerritoryGroup"
  FactInternetSales     = "SalesOrderNumber,SalesOrderLineNumber,ProductKey,OrderDateKey,SalesTerritoryKey,OrderQuantity,SalesAmount,TotalProductCost"
  FactResellerSales     = "SalesOrderNumber,SalesOrderLineNumber,ProductKey,OrderDateKey,SalesTerritoryKey,OrderQuantity,SalesAmount,TotalProductCost"
}
$conn = New-Object System.Data.SqlClient.SqlConnection "Server=localhost;Database=AdventureWorksDW2022;Integrated Security=True;TrustServerCertificate=True;Encrypt=False"
$conn.Open()
$set = New-Object System.Data.DataSet
foreach ($t in $tables.Keys) {
  $a = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT $($tables[$t]) FROM dbo.$t", $conn)
  $a.FillSchema($set, [System.Data.SchemaType]::Source, $t) | Out-Null
  $tb = $set.Tables[$t]
  $tb.ExtendedProperties["TableType"] = "Table"
  $tb.ExtendedProperties["DbSchemaName"] = "dbo"
  $tb.ExtendedProperties["DbTableName"] = $t
  $tb.ExtendedProperties["FriendlyName"] = $t
  foreach ($c in $tb.Columns) { $c.ExtendedProperties["DbColumnName"] = $c.ColumnName; $c.ExtendedProperties["FriendlyName"] = $c.ColumnName }
}
$conn.Close()
# Columna calculada (named calculation) con anio y trimestre ("2013 T1"), que ordena cronologicamente como texto
$nc = $set.Tables["DimDate"].Columns.Add("NombreTrimestre", [string])
$nc.ExtendedProperties["ComputedColumnExpression"] = "CAST(CalendarYear AS varchar(4)) + ' T' + CAST(CalendarQuarter AS varchar(1))"
$nc.ExtendedProperties["DbColumnName"] = "NombreTrimestre"
$nc.ExtendedProperties["FriendlyName"] = "NombreTrimestre"
function Rel($name, $parent, $child, $col) {
  $set.Relations.Add($name, $set.Tables[$parent].Columns[$col], $set.Tables[$child].Columns[$col]) | Out-Null
}
Rel "Product_Subcat"   "DimProductSubcategory" "DimProduct"        "ProductSubcategoryKey"
Rel "Subcat_Category"  "DimProductCategory"    "DimProductSubcategory" "ProductCategoryKey"
foreach ($f in "FactInternetSales","FactResellerSales") {
  $set.Relations.Add("${f}_Product",   $set.Tables["DimProduct"].Columns["ProductKey"],         $set.Tables[$f].Columns["ProductKey"]) | Out-Null
  $set.Relations.Add("${f}_Date",      $set.Tables["DimDate"].Columns["DateKey"],               $set.Tables[$f].Columns["OrderDateKey"]) | Out-Null
  $set.Relations.Add("${f}_Territory", $set.Tables["DimSalesTerritory"].Columns["SalesTerritoryKey"], $set.Tables[$f].Columns["SalesTerritoryKey"]) | Out-Null
}
$dsv = New-Object "$AS.DataSourceView"
$dsv.Name = "AdventureWorksDW2022 DSV"; $dsv.ID = "AdventureWorksDW2022DSV"
$dsv.DataSourceID = $ds.ID
$dsv.Schema = $set
[void]$db.DataSourceViews.Add($dsv)
$db.Update()
"4. vista del origen OK"

# 4. Dimensiones
function NewDim($name, $id) {
  $d = New-Object "$AS.Dimension"
  $d.Name = $name; $d.ID = $id
  $d.Source = New-Object "$AS.DataSourceViewBinding" ($dsv.ID)
  $d.StorageMode = [Microsoft.AnalysisServices.DimensionStorageMode]::Molap
  return $d
}
function Attr($dim, $name, $id, $usage, $keys, $nameCol) {
  $a = $dim.Attributes.Add($name, $id)
  $a.Usage = [Microsoft.AnalysisServices.AttributeUsage]::$usage
  foreach ($k in $keys) { [void]$a.KeyColumns.Add($k) }
  if ($nameCol) { $a.NameColumn = $nameCol }
  return $a
}
function Relate($from, $toId) {
  $r = New-Object "$AS.AttributeRelationship"
  $r.AttributeID = $toId
  $from.AttributeRelationships.Add($r) | Out-Null
}

# 4a. Fecha: Año > Trimestre > Mes
$dDate = NewDim "Fecha" "Fecha"
$aKey = Attr $dDate "Date Key" "DateKey" "Key" @((DI "DimDate" "DateKey" $int)) $null
$aKey.AttributeHierarchyVisible = $false
$aYear = Attr $dDate "Año" "Anio" "Regular" @((DI "DimDate" "CalendarYear" $int)) (DI "DimDate" "CalendarYear" $str)
$aQtr = Attr $dDate "Trimestre" "Trimestre" "Regular" @((DI "DimDate" "CalendarYear" $int),(DI "DimDate" "CalendarQuarter" $int)) (DI "DimDate" "NombreTrimestre" $str)
$aMon = Attr $dDate "Mes" "Mes" "Regular" @((DI "DimDate" "CalendarYear" $int),(DI "DimDate" "MonthNumberOfYear" $int)) (DI "DimDate" "EnglishMonthName" $str)
Relate $aKey "Mes"; Relate $aMon "Trimestre"; Relate $aQtr "Anio"
$h = $dDate.Hierarchies.Add("Año-Trimestre-Mes")
$h.Levels.Add("Año").SourceAttributeID = "Anio"
$h.Levels.Add("Trimestre").SourceAttributeID = "Trimestre"
$h.Levels.Add("Mes").SourceAttributeID = "Mes"
[void]$db.Dimensions.Add($dDate)

# 4b. Producto: Categoría > Subcategoría > Producto
$dProd = NewDim "Producto" "Producto"
$pKey = Attr $dProd "Product Key" "ProductKey" "Key" @((DI "DimProduct" "ProductKey" $int)) (DI "DimProduct" "EnglishProductName" $str)
$pKey.AttributeHierarchyVisible = $false
$pName = Attr $dProd "Nombre del Producto" "NombreProducto" "Regular" @((DI "DimProduct" "EnglishProductName" $str)) (DI "DimProduct" "EnglishProductName" $str)
$pSub = Attr $dProd "Subcategoría" "Subcategoria" "Regular" @((DI "DimProductSubcategory" "ProductSubcategoryKey" $int)) (DI "DimProductSubcategory" "EnglishProductSubcategoryName" $str)
$pCat = Attr $dProd "Categoría" "Categoria" "Regular" @((DI "DimProductCategory" "ProductCategoryKey" $int)) (DI "DimProductCategory" "EnglishProductCategoryName" $str)
Relate $pKey "NombreProducto"; Relate $pName "Subcategoria"; Relate $pSub "Categoria"
$h = $dProd.Hierarchies.Add("Categoría-Subcategoría-Producto")
$h.Levels.Add("Categoría").SourceAttributeID = "Categoria"
$h.Levels.Add("Subcategoría").SourceAttributeID = "Subcategoria"
$h.Levels.Add("Producto").SourceAttributeID = "NombreProducto"
# Productos sin subcategoria/categoria (nulos) van a un miembro "Sin asignar"
$pSub.KeyColumns[0].NullProcessing = [Microsoft.AnalysisServices.NullProcessing]::UnknownMember
$pCat.KeyColumns[0].NullProcessing = [Microsoft.AnalysisServices.NullProcessing]::UnknownMember
$dProd.UnknownMember = [Microsoft.AnalysisServices.UnknownMemberBehavior]::Visible
$dProd.UnknownMemberName = "Sin asignar"
[void]$db.Dimensions.Add($dProd)

# 4c. Territorio: Grupo > País > Región
$dTer = NewDim "Territorio de Ventas" "Territorio"
$tKey = Attr $dTer "Territory Key" "TerritoryKey" "Key" @((DI "DimSalesTerritory" "SalesTerritoryKey" $int)) (DI "DimSalesTerritory" "SalesTerritoryRegion" $str)
$tReg = Attr $dTer "Región" "Region" "Regular" @((DI "DimSalesTerritory" "SalesTerritoryRegion" $str)) (DI "DimSalesTerritory" "SalesTerritoryRegion" $str)
$tCty = Attr $dTer "País" "Pais" "Regular" @((DI "DimSalesTerritory" "SalesTerritoryCountry" $str)) (DI "DimSalesTerritory" "SalesTerritoryCountry" $str)
$tGrp = Attr $dTer "Grupo" "Grupo" "Regular" @((DI "DimSalesTerritory" "SalesTerritoryGroup" $str)) (DI "DimSalesTerritory" "SalesTerritoryGroup" $str)
Relate $tKey "Region"; Relate $tReg "Pais"; Relate $tCty "Grupo"
$h = $dTer.Hierarchies.Add("Grupo-País-Región")
$h.Levels.Add("Grupo").SourceAttributeID = "Grupo"
$h.Levels.Add("País").SourceAttributeID = "Pais"
$h.Levels.Add("Región").SourceAttributeID = "Region"
[void]$db.Dimensions.Add($dTer)
$db.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
"5. dimensiones OK"

# 5. Cubo con dos grupos de medidas
$cube = $db.Cubes.Add("Ventas AdventureWorks", "VentasAW")
$cube.Source = New-Object "$AS.DataSourceViewBinding" ($dsv.ID)
$cube.StorageMode = [Microsoft.AnalysisServices.StorageMode]::Molap
foreach ($d in $db.Dimensions) { $cube.Dimensions.Add($d.ID) | Out-Null }

function AddMG($cube, $name, $id, $table, $prefix) {
  $mg = $cube.MeasureGroups.Add($name, $id)
  $mg.StorageMode = [Microsoft.AnalysisServices.StorageMode]::Molap
  $m1 = $mg.Measures.Add("$prefix Monto de Ventas", "${id}Monto");  $m1.AggregateFunction = "Sum"; $m1.Source = DI $table "SalesAmount" $cur;      $m1.FormatString = "Currency"
  $m2 = $mg.Measures.Add("$prefix Costo del Producto", "${id}Costo"); $m2.AggregateFunction = "Sum"; $m2.Source = DI $table "TotalProductCost" $cur; $m2.FormatString = "Currency"
  $m3 = $mg.Measures.Add("$prefix Cantidad", "${id}Cant");           $m3.AggregateFunction = "Sum"; $m3.Source = DI $table "OrderQuantity" $int;    $m3.FormatString = "#,#"
  $links = @(@("Fecha","DateKey","OrderDateKey"), @("Producto","ProductKey","ProductKey"), @("Territorio","TerritoryKey","SalesTerritoryKey"))
  foreach ($l in $links) {
    $mgd = New-Object "$AS.RegularMeasureGroupDimension" ($l[0])
    $mga = New-Object "$AS.MeasureGroupAttribute" ($l[1])
    $mga.Type = [Microsoft.AnalysisServices.MeasureGroupAttributeType]::Granularity
    $mga.KeyColumns.Add((DI $table $l[2] $int))
    $mgd.Attributes.Add($mga) | Out-Null
    $mg.Dimensions.Add($mgd) | Out-Null
  }
  $p = $mg.Partitions.Add($name, $id)
  $p.StorageMode = [Microsoft.AnalysisServices.StorageMode]::Molap
  $p.Source = New-Object "$AS.TableBinding" ($ds.ID, "dbo", $table)
}
AddMG $cube "Ventas por Internet" "VentasInternet" "FactInternetSales" "Internet"
AddMG $cube "Ventas por Revendedor" "VentasReseller" "FactResellerSales" "Reseller"

# 6. Cálculos (rentabilidad = monto - costo)
$mdx = @"
CALCULATE;
CREATE MEMBER CURRENTCUBE.[Measures].[Internet Utilidad] AS [Measures].[Internet Monto de Ventas] - [Measures].[Internet Costo del Producto], FORMAT_STRING = "Currency", VISIBLE = 1;
CREATE MEMBER CURRENTCUBE.[Measures].[Reseller Utilidad] AS [Measures].[Reseller Monto de Ventas] - [Measures].[Reseller Costo del Producto], FORMAT_STRING = "Currency", VISIBLE = 1;
CREATE MEMBER CURRENTCUBE.[Measures].[Total Ventas] AS [Measures].[Internet Monto de Ventas] + [Measures].[Reseller Monto de Ventas], FORMAT_STRING = "Currency", VISIBLE = 1;
CREATE MEMBER CURRENTCUBE.[Measures].[Utilidad Total] AS [Measures].[Internet Utilidad] + [Measures].[Reseller Utilidad], FORMAT_STRING = "Currency", VISIBLE = 1;
CREATE SET CURRENTCUBE.[Top 10 Productos] AS TOPCOUNT([Producto].[Nombre del Producto].[Nombre del Producto].MEMBERS, 10, [Measures].[Utilidad Total]);
CREATE MEMBER CURRENTCUBE.[Measures].[Utilidad Top 10] AS IIF(COUNT(INTERSECT({[Producto].[Nombre del Producto].CurrentMember}, [Top 10 Productos])) > 0, [Measures].[Utilidad Total], NULL), FORMAT_STRING = "Currency", VISIBLE = 1;
CREATE MEMBER CURRENTCUBE.[Measures].[Ventas Top 10] AS IIF(COUNT(INTERSECT({[Producto].[Nombre del Producto].CurrentMember}, [Top 10 Productos])) > 0, [Measures].[Total Ventas], NULL), FORMAT_STRING = "Currency", VISIBLE = 1;
"@
$script = $cube.MdxScripts.Add("MdxScript", "MdxScript")
$script.Commands.Add((New-Object "$AS.Command" ($mdx))) | Out-Null
$db.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
"6. cubo desplegado OK"

# 7. Procesar
$db.Process([Microsoft.AnalysisServices.ProcessType]::ProcessFull)
$srv.Refresh()
$cb = $srv.Databases.GetByName($dbName).Cubes[0]
"7. PROCESADO: base=$dbName cubo=$($cb.Name) estado=$($cb.State) ultimo=$($cb.LastProcessed)"
$srv.Disconnect()
