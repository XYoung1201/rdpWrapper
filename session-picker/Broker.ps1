﻿$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs')
Add-Type -Path (Join-Path $PSScriptRoot 'BrokerNative.cs')
$exe="$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
$script=Join-Path $PSScriptRoot 'SessionPicker.ps1'
$command='"'+$exe+'" -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "'+$script+'"'
$log=Join-Path $env:ProgramData 'RdpSessionPicker\broker.log'
$sharedFolder=Join-Path $env:ProgramData 'RdpSessionPicker\shared'
New-Item -ItemType Directory -Force $sharedFolder|Out-Null
. (Join-Path $PSScriptRoot 'SharedConfig.ps1')

function Write-BrokerLog {
  param([string]$Text)
  try {Add-Content $log "$(Get-Date -Format o) $Text"} catch {}
}

# Applies the tray's "启用多桌面" choice to the single-session registry values.
function Sync-MultiDesktopRegistry {
  param($Config)
  $wanted=if($Config.MultiDesktop){0}else{1}
  foreach($path in $script:SessionPolicyPaths) {
    $value=(Get-ItemProperty -Path $path -Name fSingleSessionPerUser -ErrorAction SilentlyContinue).fSingleSessionPerUser
    if($null -eq $value -or [int]$value -ne $wanted) {
      if(!(Test-Path -LiteralPath $path)){New-Item -Path $path|Out-Null}
      Set-ItemProperty $path -Name fSingleSessionPerUser -Type DWord -Value $wanted
      Write-BrokerLog "fSingleSessionPerUser=$wanted at $path"
    }
  }
}

$previous=@{}   # session id -> "state|client|user" from the last pass
$hadUser=@{}    # session ids that were already a signed-in desktop (active or disconnected) in an earlier pass
$pending=@{}    # session id -> redirect attempts for a bound device that just connected
$firstPass=$true
$tick=0

# Moves a bound device that just connected into its desktop. A session created only for this
# connection is logged off afterwards; a reconnected older desktop is left disconnected as it was.
function Invoke-DeviceBindings {
  param($Config,[object[]]$Sessions)
  $changed=$false
  foreach($session in $Sessions) {
    if($session.State -ne 0 -or $session.Protocol -ne 2 -or !$session.User -or !$session.Client) {
      $pending.Remove($session.Id); continue
    }
    $arrived=$previous[$session.Id] -ne "0|$($session.Client)|$($session.User)"
    if(!$arrived -and !$pending.ContainsKey($session.Id)){continue}
    if($arrived) {
      if(Test-SwitchMarker $session.Id){Write-BrokerLog "Session $($session.Id): manual switch, binding not applied"; continue}
      $pending[$session.Id]=[pscustomobject]@{Attempts=0;Fresh=!$hadUser.ContainsKey($session.Id)}
    }
    $binding=Find-DeviceBinding $Config $session.User $session.Domain $session.Client
    if(!$binding){$pending.Remove($session.Id); continue}
    $target=$Sessions|Where-Object {$_.Id -eq $binding.SessionId -and $_.User -eq $session.User -and $_.Domain -eq $session.Domain -and $_.State -in 0,4}|Select-Object -First 1
    if(!$target) {
      # The bound desktop was logged off: the desktop this device just opened becomes its new home.
      $binding.SessionId=$session.Id
      $changed=$true
      $pending.Remove($session.Id)
      Write-BrokerLog "Device '$($session.Client)' rebound to session $($session.Id)"
      continue
    }
    if($target.Id -eq $session.Id){$pending.Remove($session.Id); continue}
    $attempt=$pending[$session.Id]
    $attempt.Attempts++
    if([SessionNative]::WTSConnectSessionW($target.Id,$session.Id,'',$true)) {
      Write-BrokerLog "Device '$($session.Client)' moved from session $($session.Id) to bound session $($target.Id)"
      $pending.Remove($session.Id)
      if($attempt.Fresh) {
        if(![SessionNative]::WTSLogoffSession([IntPtr]::Zero,$session.Id,$false)) {
          Write-BrokerLog "Session $($session.Id): log off failed with $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
      }
    } else {
      $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
      # A new session can refuse the move while its sign-in is still running, so retry for a while.
      if($attempt.Attempts -ge 15) {
        Write-BrokerLog "Device '$($session.Client)': moving session $($session.Id) to $($target.Id) failed with $code, giving up"
        $pending.Remove($session.Id)
      }
    }
  }
  if($changed){Save-SharedConfig $Config}
}

while($true) {
  try {
    $config=Read-SharedConfig
    Sync-MultiDesktopRegistry $config
    $sessions=@([SessionNative]::List())
    if($config.MultiDesktop -and !$firstPass){Invoke-DeviceBindings $config $sessions}
    elseif(!$config.MultiDesktop){$pending.Clear()}
    $previous=@{}
    foreach($session in $sessions) {
      $previous[$session.Id]="$($session.State)|$($session.Client)|$($session.User)"
      if($session.User -and $session.State -in 0,4){$hadUser[$session.Id]=$true}
    }
    foreach($id in @($hadUser.Keys)){if(!$previous.ContainsKey($id)){$hadUser.Remove($id)}}
    $firstPass=$false
    if($tick % 5 -eq 0) {
      $processes=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object {$_.CommandLine -and $_.CommandLine.Contains($script) -and $_.CommandLine -notlike '*-ShowOnce*'})
      foreach($session in $sessions) {
        if($session.Id -gt 0 -and $session.User -and $session.State -in 0,4 -and $session.Id -notin $processes.SessionId) {
          try {
            [SessionProcess]::Start($session.Id,$exe,$command,$PSScriptRoot)
            Write-BrokerLog "Started picker in session $($session.Id)"
          } catch {Write-BrokerLog "Session $($session.Id): $_"}
        }
      }
    }
  } catch {Write-BrokerLog "$_"}
  $tick++
  Start-Sleep -Seconds 1
}
