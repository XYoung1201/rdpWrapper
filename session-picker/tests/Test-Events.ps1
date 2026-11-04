$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path (Split-Path $PSScriptRoot -Parent) 'Watcher.cs') -ReferencedAssemblies System.Windows.Forms
$watcher=New-Object SessionWatcher
try {
 $method=[SessionWatcher].GetMethod('WndProc',[Reflection.BindingFlags]'Instance,NonPublic')
 foreach($code in 1,3,8) {
  $before=$watcher.Connections
  $message=[Windows.Forms.Message]::Create($watcher.Handle,0x2B1,[IntPtr]$code,[IntPtr]([Diagnostics.Process]::GetCurrentProcess().SessionId))
  $arguments=[object[]]@($message)
  [void]$method.Invoke($watcher,$arguments)
  if($watcher.Connections -ne $before+1){throw "Event $code was ignored"}
 }
 $before=$watcher.Connections
 $message=[Windows.Forms.Message]::Create($watcher.Handle,0x2B1,[IntPtr]7,[IntPtr]([Diagnostics.Process]::GetCurrentProcess().SessionId))
 [void]$method.Invoke($watcher,[object[]]@($message))
 if($watcher.Connections -ne $before){throw 'Lock unexpectedly opened a selector'}
 'PASS: console attach, RDP attach, unlock; lock does not open selector'
} finally {$watcher.Dispose()}
