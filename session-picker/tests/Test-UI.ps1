param([string]$PreviewPath,[string]$MenuPreviewPath)
$packageRoot=Split-Path $PSScriptRoot -Parent
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -Path (Join-Path $packageRoot 'Native.cs')
Add-Type -Path (Join-Path $packageRoot 'Watcher.cs') -ReferencedAssemblies System.Windows.Forms,System.Drawing
[void][SessionNative]::SetProcessDPIAware()
[Windows.Forms.Application]::EnableVisualStyles()
$sessionId=[Diagnostics.Process]::GetCurrentProcess().SessionId
$stateFolder=Join-Path $env:TEMP 'RdpSessionPickerTest'
New-Item -ItemType Directory -Force $stateFolder|Out-Null
. (Join-Path $packageRoot 'PickerUI.ps1')
$script:Settings=[pscustomobject]@{Notify=$true}
$fixtures=@(
 [pscustomobject]@{Id=$sessionId;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#1';State=0;Client='Phone'},
 [pscustomobject]@{Id=100;User='Demo';Domain='EXAMPLE';Name='Console';State=0;Client=''},
 [pscustomobject]@{Id=101;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#2';State=0;Client='Office Laptop'},
 [pscustomobject]@{Id=102;User='Demo';Domain='EXAMPLE';Name='';State=4;Client=''},
 [pscustomobject]@{Id=103;User='Other';Domain='EXAMPLE';Name='RDP-Tcp#3';State=0;Client='Somebody else'}
)

function Save-ControlImage {
  param([Windows.Forms.Control]$Control,[string]$Path)
  if(!$Path){return}
  $bitmap=New-Object Drawing.Bitmap($Control.Width,$Control.Height)
  try {
    $Control.DrawToBitmap($bitmap,(New-Object Drawing.Rectangle(0,0,$bitmap.Width,$bitmap.Height)))
    $bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
  } finally {$bitmap.Dispose()}
}

# Tray menu: same-account desktops only, with a cleanup entry for the disconnected one.
$menu=New-TrayMenu
try {
 [void](Update-TrayMenu -Menu $menu -Sessions $fixtures)
 $desktops=@($menu.Items|Where-Object {$_ -is [Windows.Forms.ToolStripMenuItem] -and $_.Tag})
 if($desktops.Count -ne 3){throw "Expected 3 desktops in the menu, found $($desktops.Count)"}
 if($desktops.Tag.Id -contains 103){throw 'Another account appeared in the menu'}
 if($desktops[0].ShortcutKeyDisplayString -notlike '本机屏幕*'){throw 'Local desktop is not labelled'}
 $cleanup=$menu.Items|Where-Object Text -eq '注销已断开的桌面'
 if(!$cleanup -or $cleanup.DropDownItems.Count -ne 1 -or $cleanup.DropDownItems[0].Tag.Id -ne 102){throw 'Cleanup menu should list only the disconnected desktop'}
 if($MenuPreviewPath) {
  $menu.Show(40,40)
  [Windows.Forms.Application]::DoEvents()
  Save-ControlImage $menu $MenuPreviewPath
  $menu.Close()
 }
 [void](Update-TrayMenu -Menu $menu -Sessions @($fixtures[0]))
 if(!($menu.Items|Where-Object Text -eq '没有其他可进入的桌面')){throw 'Empty state is missing'}
} finally {$menu.Dispose()}

# Switch dialog: keep / log off cards, warning for a desktop in use elsewhere.
$form=New-SwitchDialog -Target $fixtures[3] -Current $fixtures[0]
try {
 $form.Show()
 [Windows.Forms.Application]::DoEvents()
 $buttons=$form.Tag.Buttons
 if($buttons.Keep.Height -lt 70 -or $buttons.Logoff.Height -lt 70){throw 'Choice cards are too small'}
 if($form.ActiveControl -ne $buttons.Keep){throw 'Keeping the desktop should be the default choice'}
 Save-ControlImage $form $PreviewPath
 $buttons.Logoff.PerformClick()
 if($form.Tag.Result -ne 'Logoff'){throw 'Log off card did not report its choice'}
 $buttons.Keep.PerformClick()
 if($form.Tag.Result -ne 'Keep'){throw 'Keep card did not report its choice'}
} finally {$form.Dispose()}
$busy=New-SwitchDialog -Target $fixtures[2] -Current $fixtures[0]
try {
 if(!($busy.Controls|Where-Object {$_ -is [Windows.Forms.Label] -and $_.Text -like '*另一台设备*'})){throw 'Missing warning for a desktop in use'}
 if($busy.ClientSize.Height -le $form.ClientSize.Height){throw 'Warning did not make room'}
} finally {$busy.Dispose()}

# Notices: Esc / cancel returns false.
$state=[pscustomobject]@{Checked=$false}
$timer=New-Object Windows.Forms.Timer
$timer.Interval=100
$timer.Add_Tick({
 $popup=[Windows.Forms.Application]::OpenForms|Where-Object Text -eq 'Confirmation layout test'
 if(!$popup){return}
 $state.Checked=$popup.CancelButton -and $popup.Tag.Buttons.Ok.Height -ge 40
 $timer.Stop()
 $popup.DialogResult='Cancel'
})
try {
 $timer.Start()
 $result=Show-PickerNotice -Title 'Confirmation layout test' -Text 'Test confirmation text and buttons.' -ConfirmText 'Confirm' -Danger
 if($result -or !$state.Checked){throw 'Confirmation or cancel behavior failed'}
} finally {$timer.Dispose()}
'PASS: tray menu, switch dialog choices, and notices'
