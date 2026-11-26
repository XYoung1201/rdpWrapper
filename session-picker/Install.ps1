#Requires -Version 5.1
$ErrorActionPreference='Stop'
$admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if(!$admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  $process=Start-Process powershell.exe -Verb RunAs -ArgumentList ('-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $PSCommandPath) -Wait -PassThru
  exit $process.ExitCode
}
$destination=Join-Path $env:ProgramFiles 'RdpSessionPicker'
$picker=Join-Path $destination 'SessionPicker.ps1'
$taskName='RdpSessionPickerBroker'
$assets='SessionPicker.ps1','PickerUI.ps1','SharedConfig.ps1','Native.cs','Watcher.cs','Broker.ps1','BrokerNative.cs','Uninstall.ps1'
foreach($file in $assets) {
  if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))){throw "Missing package file: $file"}
}
New-Item -ItemType Directory -Force $destination|Out-Null
$snapshotPath=Join-Path $destination 'settings-before-install.json'
if(!(Test-Path -LiteralPath $snapshotPath)) {
  $snapshot=foreach($path in 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server','HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services') {
    $entry=Get-ItemProperty -Path $path -Name fSingleSessionPerUser -ErrorAction SilentlyContinue
    [pscustomobject]@{Path=$path;Present=[bool]$entry;Value=$entry.fSingleSessionPerUser}
  }
  $snapshot|ConvertTo-Json|Set-Content -LiteralPath $snapshotPath -Encoding UTF8
}
Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {$_.CommandLine -and $_.CommandLine.Contains($picker)} | ForEach-Object {Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue}
foreach($file in $assets) {
  $source=Join-Path $PSScriptRoot $file
  $target=Join-Path $destination $file
  if([IO.Path]::GetFullPath($source) -ne [IO.Path]::GetFullPath($target)) {
    [IO.File]::WriteAllText($target,[IO.File]::ReadAllText($source),[Text.UTF8Encoding]::new($true))
  }
}
$shell=New-Object -ComObject WScript.Shell
$shortcut=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'RDP Session Picker.lnk'))
$shortcut.TargetPath="$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
$shortcut.Arguments='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "'+$picker+'"'
$shortcut.Description='打开右下角的桌面切换菜单'
$shortcut.Save()
$runPath='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$oldRun=(Get-ItemProperty $runPath -Name RdpSessionPicker -ErrorAction SilentlyContinue).RdpSessionPicker
if($oldRun -and $oldRun.Contains($picker)){Remove-ItemProperty $runPath -Name RdpSessionPicker}
foreach($path in 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server','HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services') {
  if(!(Test-Path -LiteralPath $path)){New-Item -Path $path|Out-Null}
  Set-ItemProperty $path -Name fSingleSessionPerUser -Type DWord -Value 0
}
New-Item -ItemType Directory -Force (Join-Path $env:ProgramData 'RdpSessionPicker')|Out-Null
# Shared settings (multi-desktop switch, device bindings) are written by each user's tray icon
# and applied by the SYSTEM broker, so signed-in users (S-1-5-11) get modify rights here only.
$shared=Join-Path $env:ProgramData 'RdpSessionPicker\shared'
New-Item -ItemType Directory -Force $shared|Out-Null
& icacls.exe $shared /grant '*S-1-5-11:(OI)(CI)M' /Q|Out-Null
if($LASTEXITCODE){throw "icacls failed with $LASTEXITCODE"}
$argument='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $destination 'Broker.ps1')+'"'
$action=New-ScheduledTaskAction -Execute "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument $argument
$settings=New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$task=New-ScheduledTask -Action $action -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) -Settings $settings
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force|Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Output 'RDP Session Picker installed.'
