#Requires -Version 5.1
$ErrorActionPreference='Stop'
$admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $process=Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) -Wait -PassThru
  exit $process.ExitCode
}
$destination=Join-Path $env:ProgramFiles 'RdpSessionPicker'
$picker=Join-Path $destination 'SessionPicker.ps1'
Stop-ScheduledTask -TaskName RdpSessionPickerBroker -ErrorAction SilentlyContinue
Unregister-ScheduledTask -TaskName RdpSessionPickerBroker -Confirm:$false -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains($picker)} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue}
$snapshotPath=Join-Path $destination 'settings-before-install.json'
if(Test-Path -LiteralPath $snapshotPath) {
  foreach($entry in (Get-Content -LiteralPath $snapshotPath -Raw|ConvertFrom-Json)) {
    if($entry.Present){Set-ItemProperty $entry.Path -Name fSingleSessionPerUser -Type DWord -Value ([int]$entry.Value)}
    else {Remove-ItemProperty $entry.Path -Name fSingleSessionPerUser -ErrorAction SilentlyContinue}
  }
}
$shortcut=Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'RDP Session Picker.lnk'
Remove-Item -LiteralPath $shortcut -ErrorAction SilentlyContinue
$runPath='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$run=(Get-ItemProperty $runPath -Name RdpSessionPicker -ErrorAction SilentlyContinue).RdpSessionPicker
if($run -and $run.Contains($picker)){Remove-ItemProperty $runPath -Name RdpSessionPicker}
foreach($file in 'SessionPicker.ps1','PickerUI.ps1','SharedConfig.ps1','Native.cs','Watcher.cs','Broker.ps1','BrokerNative.cs','Uninstall.ps1','settings-before-install.json') {
  Remove-Item -LiteralPath (Join-Path $destination $file) -ErrorAction SilentlyContinue
}
Write-Output 'RDP Session Picker uninstalled. Per-user history remains in LocalAppData; shared settings remain in ProgramData.'
