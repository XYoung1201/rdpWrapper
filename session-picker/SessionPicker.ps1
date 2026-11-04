param([switch]$ListOnly,[switch]$ShowOnce)
$ErrorActionPreference='Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'Native.cs')
if ($ListOnly) { [SessionNative]::List() | ConvertTo-Json; exit }
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'Watcher.cs') -ReferencedAssemblies System.Windows.Forms
$sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
$mutex=New-Object Threading.Mutex($false,"Local\RdpSessionPicker")
if (!$ShowOnce -and !$mutex.WaitOne(0)) { exit }
$stateFolder=Join-Path $env:LOCALAPPDATA 'RdpSessionPicker'
New-Item -ItemType Directory -Force $stateFolder | Out-Null
. (Join-Path $PSScriptRoot 'PickerUI.ps1')
if($ShowOnce){Show-SessionPicker;exit}
$wasActive=$false
$watcher=New-Object SessionWatcher
$lastConnection=$watcher.Connections
try {
  while($true) {
    [Windows.Forms.Application]::DoEvents()
    $current=[SessionNative]::List()|Where-Object Id -eq $sessionId
    $isActive=$current.State -eq 0 -and $current.Protocol -in 0,2
    if($isActive -and (!$wasActive -or $lastConnection -ne $watcher.Connections)) {
      $skipPath=Join-Path $stateFolder "skip-$sessionId.txt"
      $skip=$false
      if(Test-Path -LiteralPath $skipPath) {
        $skip=[DateTimeOffset]::Parse([IO.File]::ReadAllText($skipPath)).UtcDateTime -gt [DateTime]::UtcNow
        Remove-Item -LiteralPath $skipPath
      }
      if(!$skip){Show-SessionPicker}
    }
    $wasActive=$isActive
    $lastConnection=$watcher.Connections
    Start-Sleep -Milliseconds 200
  }
} finally {$watcher.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
