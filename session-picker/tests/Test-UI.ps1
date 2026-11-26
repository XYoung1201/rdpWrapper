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
$sharedFolder=Join-Path $stateFolder 'shared'
New-Item -ItemType Directory -Force $sharedFolder|Out-Null
Remove-Item -LiteralPath (Join-Path $sharedFolder 'config.json') -ErrorAction SilentlyContinue
. (Join-Path $packageRoot 'SharedConfig.ps1')
. (Join-Path $packageRoot 'PickerUI.ps1')
$script:Settings=[pscustomobject]@{Notify=$true}
$fixtures=@(
 [pscustomobject]@{Id=$sessionId;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#1';State=0;Client='Phone';Address='192.0.2.10';Protocol=2},
 [pscustomobject]@{Id=100;User='Demo';Domain='EXAMPLE';Name='Console';State=0;Client='';Address='';Protocol=0},
 [pscustomobject]@{Id=101;User='Demo';Domain='EXAMPLE';Name='RDP-Tcp#2';State=0;Client='Office Laptop';Address='192.0.2.20';Protocol=2},
 [pscustomobject]@{Id=102;User='Demo';Domain='EXAMPLE';Name='';State=4;Client='';Address='';Protocol=2},
 [pscustomobject]@{Id=103;User='Other';Domain='EXAMPLE';Name='RDP-Tcp#3';State=0;Client='Somebody else';Address='192.0.2.30';Protocol=2}
)
$config=[pscustomobject]@{MultiDesktop=$true;Bindings=@()}

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
 [void](Update-TrayMenu -Menu $menu -Sessions $fixtures -Config $config)
 $desktops=@($menu.Items|Where-Object {$_ -is [Windows.Forms.ToolStripMenuItem] -and $_.Tag})
 if($desktops.Count -ne 3){throw "Expected 3 desktops in the menu, found $($desktops.Count)"}
 if($desktops.Tag.Id -contains 103){throw 'Another account appeared in the menu'}
 if($desktops[0].ShortcutKeyDisplayString -notlike '本机屏幕*'){throw 'Local desktop is not labelled'}
 $cleanup=$menu.Items|Where-Object Text -eq '注销已断开的桌面'
 if(!$cleanup -or $cleanup.DropDownItems.Count -ne 1 -or $cleanup.DropDownItems[0].Tag.Id -ne 102){throw 'Cleanup menu should list only the disconnected desktop'}
 # Multi-desktop switch and device bindings.
 $multi=$menu.Items|Where-Object Text -eq '启用多桌面'
 if(!$multi -or !$multi.Checked){throw 'Multi-desktop switch is missing or unchecked'}
 $bindings=$menu.Items|Where-Object Text -eq '设备绑定'
 if(!$bindings -or !$bindings.Enabled){throw 'Device binding menu is missing or disabled'}
 $devices=@($bindings.DropDownItems|Where-Object {$_ -is [Windows.Forms.ToolStripMenuItem] -and $_.DropDownItems.Count})
 if(($devices.Text -join ',') -ne 'Office Laptop,Phone（本设备）'){throw "Unexpected devices: $($devices.Text -join ',')"}
 if($devices.Text -match 'Somebody'){throw 'Another account device appeared'}
 $phone=$devices[1]
 if($phone.ShortcutKeyDisplayString -ne '未绑定'){throw 'Phone should start unbound'}
 if($phone.DropDownItems.Count -ne 4){throw "Phone should offer the 4 desktops of this account, found $($phone.DropDownItems.Count)"}
 ($phone.DropDownItems|Where-Object {$_.Tag.SessionId -eq 101}).PerformClick()
 $saved=Read-SharedConfig
 $bound=Find-DeviceBinding $saved 'Demo' 'EXAMPLE' 'Phone'
 if(!$bound -or $bound.SessionId -ne 101){throw 'Binding was not saved'}
 [void](Update-TrayMenu -Menu $menu -Sessions $fixtures -Config $saved)
 $phone=@(($menu.Items|Where-Object Text -eq '设备绑定').DropDownItems|Where-Object Text -like 'Phone*')[0]
 if($phone.ShortcutKeyDisplayString -ne '→ 会话 101'){throw 'Bound desktop is not shown'}
 if(!($phone.DropDownItems|Where-Object {$_.Tag.SessionId -eq 101}).Checked){throw 'Bound desktop is not checked'}
 $laptopDesktop=$menu.Items|Where-Object {$_.Tag -and $_.Tag.Id -eq 101}
 if($laptopDesktop.ShortcutKeyDisplayString -notlike '*绑定 Phone*'){throw 'Desktop entry does not show its bound device'}
 ($phone.DropDownItems|Where-Object Text -eq '解除绑定').PerformClick()
 if(Find-DeviceBinding (Read-SharedConfig) 'Demo' 'EXAMPLE' 'Phone'){throw 'Unbinding did not save'}
 [void](Update-TrayMenu -Menu $menu -Sessions $fixtures -Config ([pscustomobject]@{MultiDesktop=$false;Bindings=@()}))
 if(($menu.Items|Where-Object Text -eq '启用多桌面').Checked){throw 'Multi-desktop switch should be unchecked'}
 if(($menu.Items|Where-Object Text -eq '设备绑定').Enabled){throw 'Device bindings should be disabled without multi-desktop'}
 Set-SwitchMarker 101
 if(!(Test-SwitchMarker 101)){throw 'Switch marker was not found'}
 if(Test-SwitchMarker 101){throw 'Switch marker should be used only once'}
 [void](Update-TrayMenu -Menu $menu -Sessions $fixtures -Config $config)
 if($MenuPreviewPath) {
  $menu.Show(40,40)
  [Windows.Forms.Application]::DoEvents()
  Save-ControlImage $menu $MenuPreviewPath
  $menu.Close()
 }
 [void](Update-TrayMenu -Menu $menu -Sessions @($fixtures[0]) -Config $config)
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
'PASS: tray menu, multi-desktop switch, device bindings, switch dialog choices, and notices'
