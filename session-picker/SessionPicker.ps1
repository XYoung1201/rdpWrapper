param([switch]$ListOnly,[switch]$ShowOnce)
# Runs in each signed-in session as a tray icon. -ShowOnce is kept for old shortcuts and behaves like a normal start.
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs')
if ($ListOnly) { [SessionNative]::List() | ConvertTo-Json; exit }
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'Watcher.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
[void][SessionNative]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()
$sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
# A second start (for example from the Start menu) asks the running tray icon to open its menu.
$showSignal=New-Object Threading.EventWaitHandle($false,[Threading.EventResetMode]::AutoReset,"Local\RdpSessionPickerShowMenu")
$mutex=New-Object Threading.Mutex($false,"Local\RdpSessionPicker")
if (!$mutex.WaitOne(0)) { [void]$showSignal.Set(); exit }
$stateFolder=Join-Path $env:LOCALAPPDATA 'RdpSessionPicker'
New-Item -ItemType Directory -Force $stateFolder | Out-Null
. (Join-Path $PSScriptRoot 'PickerUI.ps1')
$script:Settings=Read-PickerSettings
$script:Tray=New-PickerTray
$watcher=New-Object SessionWatcher
$script:wasActive=$false
$script:lastConnection=$watcher.Connections
$timer=New-Object Windows.Forms.Timer
$timer.Interval=400
$timer.Add_Tick({
  try {
    $current=[SessionNative]::List()|Where-Object Id -eq $sessionId
    $isActive=$current.State -eq 0 -and $current.Protocol -in 0,2
    if($isActive -and (!$script:wasActive -or $script:lastConnection -ne $watcher.Connections)) {
      $skipPath=Join-Path $stateFolder "skip-$sessionId.txt"
      $skip=$false
      if(Test-Path -LiteralPath $skipPath) {
        $skip=[DateTimeOffset]::Parse([IO.File]::ReadAllText($skipPath)).UtcDateTime -gt [DateTime]::UtcNow
        Remove-Item -LiteralPath $skipPath
      }
      if(!$skip){Show-DesktopHint -Tray $script:Tray}
    }
    $script:wasActive=$isActive
    $script:lastConnection=$watcher.Connections
    if($showSignal.WaitOne(0)){Show-TrayMenu $script:Tray}
  } catch {Write-PickerLog "tick-error $_"}
})
$timer.Start()
Write-PickerLog "tray-started session=$sessionId"
try {[Windows.Forms.Application]::Run()}
finally {
  $timer.Dispose()
  $script:Tray.Visible=$false
  $script:Tray.Dispose()
  $watcher.Dispose()
  $mutex.ReleaseMutex();$mutex.Dispose()
}
