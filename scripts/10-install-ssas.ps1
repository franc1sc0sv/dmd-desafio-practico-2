# Instala Analysis Services (multidimensional) en la instancia existente. Pide UAC.
$me = "$env:USERDOMAIN\$env:USERNAME"
$a = "/Q /ACTION=Install /FEATURES=AS /INSTANCENAME=MSSQLSERVER /ASSERVERMODE=MULTIDIMENSIONAL /ASSYSADMINACCOUNTS=`"$me`" /ASSVCACCOUNT=`"NT Service\MSSQLServerOLAPService`" /IACCEPTSQLSERVERLICENSETERMS /SUPPRESSPRIVACYSTATEMENTNOTICE"
"admin=$me"
try {
  $p = Start-Process "C:\SQL2025\StdDev_ENU\SETUP.EXE" -ArgumentList $a -Verb RunAs -Wait -PassThru
  "exit=$($p.ExitCode)"
} catch {
  "ERR: $($_.Exception.Message)"
}
Get-Service | Where-Object { $_.Name -match "OLAP" } | Format-Table Name,Status -Auto | Out-String
