param([string]$PreviewPath)
$packageRoot=Split-Path $PSScriptRoot -Parent
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $packageRoot 'Native.cs')
$sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
$stateFolder=Join-Path $env:LOCALAPPDATA 'RdpSessionPicker'
. (Join-Path $packageRoot 'PickerUI.ps1')
$fixtures=@(
 [pscustomobject]@{Id=$sessionId;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#1';State=0;Client='Phone'},
 [pscustomobject]@{Id=100;User='Demo';Domain='EXAMPLE';Name='Console';State=0;Client=''},
 [pscustomobject]@{Id=101;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#2';State=0;Client='Office Laptop'},
 [pscustomobject]@{Id=102;User='Demo';Domain='EXAMPLE';Name='';State=4;Client=''}
)
$form=New-SessionPickerWindow -Sessions $fixtures
try {
 $form.Show()
 [Windows.Forms.Application]::DoEvents()
 $form.PerformLayout()
 if($form.Tag.List.Items.Count -ne 3){throw 'Expected local, active remote, and disconnected remote rows'}
 $form.Tag.List.Items[0].Selected=$true
 [Windows.Forms.Application]::DoEvents()
 $bitmap=New-Object Drawing.Bitmap($form.ClientSize.Width,$form.ClientSize.Height)
 try {
  $form.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$bitmap.Width,$bitmap.Height)))
  if($PreviewPath){$bitmap.Save($PreviewPath,[Drawing.Imaging.ImageFormat]::Png)}
 } finally {$bitmap.Dispose()}
 if($form.Font.Size -lt 15){throw 'Font is too small'}
 if($form.Tag.Connect.Height -lt 70){throw 'Primary action is too small'}
 if($form.Tag.List.Items.Count){
  $form.Tag.List.Items[0].Selected=$true
  [Windows.Forms.Application]::DoEvents()
  if(!$form.Tag.Connect.Enabled){throw 'Selecting a row did not enable takeover'}
 }
 $form.Tag|Add-Member -NotePropertyName NoticeCheck -NotePropertyValue $false
 $timer=New-Object Windows.Forms.Timer
 $timer.Interval=100
 $timer.Add_Tick({
  $popup=[Windows.Forms.Application]::OpenForms|Where-Object Text -eq 'Confirmation layout test'
  if(!$popup){return}
  $form.Tag.NoticeCheck=$popup.Font.Size -ge 16 -and $popup.CancelButton.Font.Size -ge 17 -and $popup.CancelButton.Height -ge 60
  $timer.Stop()
  $popup.DialogResult='Cancel'
  $popup.Close()
 })
 try {
  $timer.Start()
  $result=Show-PickerNotice -Title 'Confirmation layout test' -Text 'Test large confirmation text and buttons.' -Confirm -Owner $form
  if($result -or !$form.Tag.NoticeCheck){throw 'Large confirmation or cancel behavior failed'}
 } finally {$timer.Dispose()}
 'PASS: large layout, buttons, and row selection'
} finally {$form.Dispose()}
