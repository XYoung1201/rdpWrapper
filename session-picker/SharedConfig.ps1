# Machine-wide settings shared by the tray icon (runs as the user) and the broker (runs as SYSTEM).
# Dot-sourced by SessionPicker.ps1, Broker.ps1 and the UI test. Expects $sharedFolder.
# The installer gives signed-in users modify rights on $sharedFolder; the broker applies the
# settings that need administrator rights (the single-session registry values).

$script:SessionPolicyPaths=@(
  'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services',
  'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
)

# True when Windows currently allows several sessions per user. The policy key wins when present.
function Get-MultiDesktopRegistry {
  foreach($path in $script:SessionPolicyPaths) {
    $value=(Get-ItemProperty -Path $path -Name fSingleSessionPerUser -ErrorAction SilentlyContinue).fSingleSessionPerUser
    if($null -ne $value){return [int]$value -eq 0}
  }
  return $false
}

function Read-SharedConfig {
  $config=[pscustomobject]@{MultiDesktop=$null;Bindings=@()}
  try {
    $path=Join-Path $sharedFolder 'config.json'
    if(Test-Path -LiteralPath $path) {
      $saved=[IO.File]::ReadAllText($path)|ConvertFrom-Json
      if($null -ne $saved.MultiDesktop){$config.MultiDesktop=[bool]$saved.MultiDesktop}
      $config.Bindings=@($saved.Bindings|Where-Object {$_ -and $_.Client -and $_.User}|ForEach-Object {
        [pscustomobject]@{User=[string]$_.User;Domain=[string]$_.Domain;Client=[string]$_.Client;SessionId=[int]$_.SessionId}
      })
    }
  } catch {}
  if($null -eq $config.MultiDesktop){$config.MultiDesktop=Get-MultiDesktopRegistry}
  return $config
}

function Save-SharedConfig {
  param($Config)
  $path=Join-Path $sharedFolder 'config.json'
  $temp="$path.$PID.tmp"
  $data=[pscustomobject]@{MultiDesktop=[bool]$Config.MultiDesktop;Bindings=[object[]]@($Config.Bindings)}
  [IO.File]::WriteAllText($temp,($data|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
  Move-Item -LiteralPath $temp -Destination $path -Force
}

# Devices are identified by the RDP client name (the computer or phone name the client reports).
function Find-DeviceBinding {
  param($Config,[string]$User,[string]$Domain,[string]$Client)
  if(!$Client){return $null}
  return $Config.Bindings|Where-Object {$_.User -eq $User -and $_.Domain -eq $Domain -and $_.Client -eq $Client}|Select-Object -First 1
}

function Set-DeviceBindingEntry {
  param($Config,[string]$User,[string]$Domain,[string]$Client,$SessionId)
  $Config.Bindings=@($Config.Bindings|Where-Object {!($_.User -eq $User -and $_.Domain -eq $Domain -and $_.Client -eq $Client)})
  if($null -ne $SessionId) {
    $Config.Bindings+=[pscustomobject]@{User=$User;Domain=$Domain;Client=$Client;SessionId=[int]$SessionId}
  }
}

# The tray leaves a short-lived marker before a manual switch so the broker does not
# pull a bound device back while the user is deliberately moving it to another desktop.
function Set-SwitchMarker {
  param([int]$TargetId)
  try {[IO.File]::WriteAllText((Join-Path $sharedFolder "switch-$TargetId.txt"),[DateTime]::UtcNow.AddSeconds(30).ToString('o'))} catch {}
}

function Test-SwitchMarker {
  param([int]$TargetId)
  $path=Join-Path $sharedFolder "switch-$TargetId.txt"
  if(!(Test-Path -LiteralPath $path)){return $false}
  try {
    $valid=[DateTimeOffset]::Parse([IO.File]::ReadAllText($path)).UtcDateTime -gt [DateTime]::UtcNow
    Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
    return $valid
  } catch {return $false}
}
