# Exporta el cubo del servidor a un proyecto de Visual Studio (SSDT Multidimensional).
$ErrorActionPreference = 'Stop'
Add-Type -Path "C:\Program Files\Microsoft SQL Server\170\DTS\Binn\Microsoft.AnalysisServices.dll"
$AS = 'Microsoft.AnalysisServices'
$name = "AdventureWorksCubo"
$root = "C:\Users\Public\dp2\vsproj"
$proj = Join-Path $root $name
if (Test-Path $root) { Remove-Item $root -Recurse -Force }
New-Item -ItemType Directory -Force $proj | Out-Null
$ASSRV = "localhost"; $cfg = Join-Path $PSScriptRoot "as-server.txt"; if (Test-Path $cfg) { $ASSRV = (Get-Content $cfg -Raw).Trim() }   # servidor de Analysis Services
$srv = New-Object "$AS.Server"; $srv.Connect($ASSRV)
$db = $srv.Databases.GetByName($name)

function Save($obj, $file, $children) {
  $s = New-Object System.Xml.XmlWriterSettings
  $s.Indent = $true; $s.Encoding = New-Object System.Text.UTF8Encoding($true)
  $w = [System.Xml.XmlWriter]::Create((Join-Path $proj $file), $s)
  [Microsoft.AnalysisServices.Utils]::Serialize($w, $obj, $children)
  $w.Close()
}
$stub = New-Object "$AS.Database"; $stub.Name = $db.Name; $stub.ID = $db.ID; $stub.CompatibilityLevel = $db.CompatibilityLevel
Save $stub "$name.database" $false
$items = @{ Cubes = @(); Dimensions = @(); DataSources = @(); DataSourceViews = @() }
foreach ($o in $db.DataSources)     { Save $o "$($o.Name).ds"  $true; $items.DataSources += "$($o.Name).ds" }
foreach ($o in $db.DataSourceViews) { Save $o "$($o.Name).dsv" $true; $items.DataSourceViews += "$($o.Name).dsv" }
foreach ($o in $db.Dimensions)      { Save $o "$($o.Name).dim" $true; $items.Dimensions += "$($o.Name).dim" }
foreach ($o in $db.Cubes)           { Save $o "$($o.Name).cube" $true; $items.Cubes += "$($o.Name).cube" }
$srv.Disconnect()

function Items($tag, $files) { "  <$tag>`r`n" + (($files | ForEach-Object { "    <ProjectItem>`r`n      <Name>$_</Name>`r`n      <FullPath>$_</FullPath>`r`n    </ProjectItem>" }) -join "`r`n") + "`r`n  </$tag>" }
$dw = @"
<?xml version="1.0" encoding="utf-8"?>
<Project xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:dwd="http://schemas.microsoft.com/DataWarehouse/Designer/1.0">
  <ProductVersion>17.0</ProductVersion>
  <SchemaVersion>2.0</SchemaVersion>
  <Name>$name</Name>
  <Database>
    <FullPath>$name.database</FullPath>
  </Database>
$(Items 'Cubes' $items.Cubes)
$(Items 'Dimensions' $items.Dimensions)
$(Items 'DataSources' $items.DataSources)
$(Items 'DataSourceViews' $items.DataSourceViews)
  <DTSPackages />
  <Miscellaneous />
  <Configurations>
    <Configuration>
      <Name>Development</Name>
      <Options>
        <OutputPath>bin</OutputPath>
        <ConnectionMappings />
        <ConfigurationSpecificDataSources />
        <Drillthrough />
      </Options>
    </Configuration>
  </Configurations>
</Project>
"@
[System.IO.File]::WriteAllText("$proj\$name.dwproj", $dw, (New-Object System.Text.UTF8Encoding($true)))

$dt = @"
<?xml version="1.0" encoding="utf-8"?>
<DeploymentTarget xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Database>$name</Database>
  <Server>$ASSRV</Server>
  <ConnectionString>Data Source=$ASSRV;Timeout=0</ConnectionString>
</DeploymentTarget>
"@
[System.IO.File]::WriteAllText("$proj\$name.deploymenttargets", $dt, (New-Object System.Text.UTF8Encoding($true)))

$g = "{9E1A6A5B-3C47-4C3E-8B7D-5F2C1D0A4E21}"
$sln = @"

Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{4A0DDDB5-7A95-4FBF-97CC-616D07737A77}") = "$name", "$name\$name.dwproj", "$g"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Development|Default = Development|Default
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		$g.Development|Default.ActiveCfg = Development
		$g.Development|Default.Build.0 = Development
		$g.Development|Default.Deploy.0 = Development
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
EndGlobal
"@
[System.IO.File]::WriteAllText("$root\$name.sln", $sln, (New-Object System.Text.UTF8Encoding($true)))
Get-ChildItem $root -Recurse -File | ForEach-Object { "{0,8}  {1}" -f $_.Length, $_.FullName.Substring($root.Length) }
