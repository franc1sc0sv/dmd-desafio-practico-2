# Utilidades de UI para capturas: UI Automation + captura de monitor + coordenadas de marcas.
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class Win { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h,int c);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")] public static extern void mouse_event(int f,int dx,int dy,int d,int e); }
"@
$script:AE = [System.Windows.Automation.AutomationElement]
$script:Root = [System.Windows.Automation.AutomationElement]::RootElement
$script:TS = [System.Windows.Automation.TreeScope]
$script:CT = [System.Windows.Automation.ControlType]

function Get-Win($proc) {
  $p = Get-Process $proc -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { return $null }
  return $script:AE::FromHandle($p.MainWindowHandle)
}
function Focus-Win($proc, [switch]$Maximize) {
  $p = Get-Process $proc -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if (-not $p) { return $false }
  if ($Maximize) { [Win]::ShowWindow($p.MainWindowHandle, 3) | Out-Null } else { [Win]::ShowWindow($p.MainWindowHandle, 9) | Out-Null }
  [Win]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 700
  return $true
}
function Find-El($scope, $name, $type = $null, [switch]$Contains) {
  $all = $scope.FindAll($script:TS::Descendants, [System.Windows.Automation.Condition]::TrueCondition)
  foreach ($e in $all) {
    $n = $e.Current.Name
    $ok = if ($Contains) { $n.IndexOf($name, [StringComparison]::Ordinal) -ge 0 } else { $n -eq $name }
    if ($ok -and ((-not $type) -or $e.Current.ControlType -eq $type)) { return $e }
  }
  return $null
}
function Click-El($el) {
  try { ($el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)).Invoke(); return }
  catch { }
  try { ($el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)).Select(); return } catch { }
  $r = $el.Current.BoundingRectangle
  [Win]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  [Win]::mouse_event(2,0,0,0,0); [Win]::mouse_event(4,0,0,0,0)
}
function Expand-El($el) { try { ($el.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)).Expand() } catch { } }

# Captura el monitor que contiene la ventana $proc (o el principal). Escribe $out y $out.json con las marcas.
function Capture($out, $proc, $marks) {
  $dir = Split-Path $out; New-Item -ItemType Directory -Force $dir | Out-Null
  $scr = [System.Windows.Forms.Screen]::PrimaryScreen
  $win = $null
  if ($proc) { $win = Get-Win $proc }
  if ($win) {
    $r = $win.Current.BoundingRectangle
    $scr = [System.Windows.Forms.Screen]::FromPoint((New-Object System.Drawing.Point ([int]($r.X + $r.Width/2)), ([int]($r.Y + $r.Height/2))))
  }
  $b = $scr.Bounds
  $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png); $g.Dispose(); $bmp.Dispose()
  $found = @()
  foreach ($m in $marks) {
    $el = $null
    if ($win) { $el = Find-El $win $m -Contains }
    if (-not $el) { $el = Find-El $script:Root $m -Contains }
    if ($el) {
      $r = $el.Current.BoundingRectangle
      $found += [ordered]@{ name = $m; rect = @([int]($r.X - $b.Left), [int]($r.Y - $b.Top), [int]($r.Width), [int]($r.Height)) }
    } else { $found += [ordered]@{ name = $m; rect = $null } }
  }
  $meta = [ordered]@{ screen = @($b.Width, $b.Height); marks = $found }
  [System.IO.File]::WriteAllText("$out.json", ($meta | ConvertTo-Json -Depth 5), (New-Object System.Text.UTF8Encoding($false)))
  "captura $out ($($b.Width)x$($b.Height)) marcas: " + (($found | ForEach-Object { if ($_.rect) { "ok" } else { "FALTA:" + $_.name } }) -join ",")
}

function DoubleClick-El($el) {
  $r = $el.Current.BoundingRectangle
  [Win]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 200
  [Win]::mouse_event(2,0,0,0,0); [Win]::mouse_event(4,0,0,0,0); Start-Sleep -Milliseconds 90
  [Win]::mouse_event(2,0,0,0,0); [Win]::mouse_event(4,0,0,0,0)
}
function Names-In($scope, $minX = 0) {
  $seen=@{}
  foreach ($e in $scope.FindAll($script:TS::Descendants, [System.Windows.Automation.Condition]::TrueCondition)) {
    $t = $e.Current.ControlType.ProgrammaticName.Replace("ControlType.",""); $n=$e.Current.Name; $r=$e.Current.BoundingRectangle
    if ($n -and -not [double]::IsInfinity($r.X) -and $r.X -ge $minX -and $t -in "TabItem","TreeItem","ListItem","DataItem","Text","Button","Edit" -and -not $seen["$t$n"]) { $seen["$t$n"]=1; "  $t : $($n.Substring(0,[Math]::Min(90,$n.Length)))  @ $([int]$r.X),$([int]$r.Y)" }
  }
}
