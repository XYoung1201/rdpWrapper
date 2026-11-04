$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs')
Add-Type -Path (Join-Path $PSScriptRoot 'BrokerNative.cs')
$exe="$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
$script=Join-Path $PSScriptRoot 'SessionPicker.ps1'
$command='"'+$exe+'" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "'+$script+'"'
$log=Join-Path $env:ProgramData 'RdpSessionPicker\broker.log'
while($true) {
  try {
    $processes=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -and $_.CommandLine.Contains($script) -and $_.CommandLine -notlike '*-ShowOnce*'})
    foreach($session in [SessionNative]::List()) {
      if($session.Id -gt 0 -and $session.User -and $session.State -in 0,4 -and $session.Id -notin $processes.SessionId) {
        try {
          [SessionProcess]::Start($session.Id,$exe,$command,$PSScriptRoot)
          Add-Content $log "$(Get-Date -Format o) Started picker in session $($session.Id)"
        } catch {Add-Content $log "$(Get-Date -Format o) Session $($session.Id): $_"}
      }
    }
  } catch {Add-Content $log "$(Get-Date -Format o) $_"}
  Start-Sleep -Seconds 5
}
