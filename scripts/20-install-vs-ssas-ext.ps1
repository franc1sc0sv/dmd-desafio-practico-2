$ProgressPreference = 'SilentlyContinue'
$vsix = "C:\Users\Public\dp2\ssas-projects.vsix"
$url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ProBITools/vsextensions/MicrosoftAnalysisServicesModelingProjects2022/latest/vspackage"
try {
  Invoke-WebRequest $url -OutFile $vsix -UseBasicParsing
  "descargado: " + (Get-Item $vsix).Length + " bytes"
  $inst = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\resources\app\ServiceHub\Services\Microsoft.VisualStudio.Setup.Service"
  $v = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\IDE\VSIXInstaller.exe"
  "VSIXInstaller: " + $v.FullName
  Get-Process devenv -ErrorAction SilentlyContinue | Select-Object Name,Id | Format-Table -Auto | Out-String
  $p = Start-Process $v.FullName -ArgumentList "/quiet /admin `"$vsix`"" -Verb RunAs -Wait -PassThru
  "vsix exit=" + $p.ExitCode
} catch {
  "ERR: " + $_.Exception.Message
}
