# Tray icon, desktop menu and switch dialogs for RDP Session Picker.
# Dot-sourced by SessionPicker.ps1 and the UI test. Expects $sessionId and $stateFolder.

$script:UiFontName='Microsoft YaHei UI'
$script:Accent=[Drawing.Color]::FromArgb(37,99,235)
$script:AccentDark=[Drawing.Color]::FromArgb(29,78,216)
$script:Danger=[Drawing.Color]::FromArgb(220,38,38)
$script:DangerDark=[Drawing.Color]::FromArgb(185,28,28)
$script:Warning=[Drawing.Color]::FromArgb(217,119,6)
$script:Ink=[Drawing.Color]::FromArgb(17,24,39)
$script:Muted=[Drawing.Color]::FromArgb(107,114,128)
$script:Line=[Drawing.Color]::FromArgb(226,232,240)
$script:Hover=[Drawing.Color]::FromArgb(241,245,255)
$script:Online=[Drawing.Color]::FromArgb(22,163,74)
$script:Offline=[Drawing.Color]::FromArgb(148,163,184)
$script:DialogOpen=$false
$probe=[Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
$script:DpiScale=$probe.DpiX/96.0
$probe.Dispose()

function New-UiFont {
  param([single]$Size,[switch]$Bold)
  $style=if($Bold){[Drawing.FontStyle]::Bold}else{[Drawing.FontStyle]::Regular}
  New-Object Drawing.Font($script:UiFontName,$Size,$style)
}
$script:Fonts=@{
  Title=New-UiFont 16 -Bold; Subtitle=New-UiFont 10.5; Body=New-UiFont 12
  CardTitle=New-UiFont 13 -Bold; CardDetail=New-UiFont 10.5; Button=New-UiFont 11.5 -Bold
  Pill=New-UiFont 9 -Bold; Menu=New-UiFont 10; MenuTitle=New-UiFont 10.5 -Bold; MenuNote=New-UiFont 9
}

function Write-PickerLog {
  param([string]$Text)
  try {Add-Content (Join-Path $stateFolder 'history.log') "$(Get-Date -Format o) $Text"} catch {}
}

function Read-PickerSettings {
  $settings=[pscustomobject]@{Notify=$true}
  try {
    $path=Join-Path $stateFolder 'settings.json'
    if(Test-Path -LiteralPath $path) {
      $saved=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
      if($null -ne $saved.Notify){$settings.Notify=[bool]$saved.Notify}
    }
  } catch {}
  return $settings
}

function Save-PickerSettings {
  param($Settings)
  try {$Settings|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $stateFolder 'settings.json') -Encoding UTF8} catch {}
}

# ---------- Session helpers ----------

function Get-SessionKind {param($Session) if($Session.Name -eq 'console'){'本机屏幕'}else{'远程 RDP'}}
function Get-SessionStatus {param($Session) if($Session.State -eq 0){'正在使用'}else{'已断开'}}
function Get-SessionDevice {
  param($Session)
  if($Session.Name -eq 'console'){'本机键盘、鼠标'}elseif($Session.Client){[string]$Session.Client}else{''}
}
function Get-SessionSummary {
  param($Session,[switch]$NoStatus)
  $parts=@(Get-SessionKind $Session)
  if(!$NoStatus){$parts+=Get-SessionStatus $Session}
  $device=Get-SessionDevice $Session
  if($device){$parts+=$device}
  return $parts -join ' · '
}

function Get-DesktopState {
  param([object[]]$Sessions=@([SessionNative]::List()))
  $current=$Sessions|Where-Object Id -eq $sessionId|Select-Object -First 1
  $others=@()
  if($current) {
    $others=@($Sessions|Where-Object {$_.Id -ne $sessionId -and $_.User -eq $current.User -and $_.Domain -eq $current.Domain -and $_.State -in 0,4}|Sort-Object Id)
  }
  return [pscustomobject]@{Current=$current;Others=$others}
}

function Test-DesktopStillAvailable {
  param($Target,[int[]]$States=@(0,4))
  $state=Get-DesktopState
  return [bool]($state.Others|Where-Object {$_.Id -eq $Target.Id -and $_.State -in $States})
}

# ---------- Drawing ----------

function New-RoundedPath {
  param([single]$X,[single]$Y,[single]$Width,[single]$Height,[single]$Radius)
  $path=New-Object Drawing.Drawing2D.GraphicsPath
  $d=$Radius*2
  $path.AddArc($X,$Y,$d,$d,180,90)
  $path.AddArc($X+$Width-$d,$Y,$d,$d,270,90)
  $path.AddArc($X+$Width-$d,$Y+$Height-$d,$d,$d,0,90)
  $path.AddArc($X,$Y+$Height-$d,$d,$d,90,90)
  $path.CloseFigure()
  return $path
}

# A rounded square badge with a monitor (or "!") drawn in white.
function Draw-Badge {
  param([Drawing.Graphics]$Graphics,[single]$X,[single]$Y,[single]$Size,[Drawing.Color]$Color,[string]$Glyph='monitor')
  $Graphics.SmoothingMode='AntiAlias'
  $path=New-RoundedPath $X $Y $Size $Size ($Size*0.24)
  $brush=New-Object Drawing.SolidBrush $Color
  $Graphics.FillPath($brush,$path)
  $brush.Dispose(); $path.Dispose()
  $pen=New-Object Drawing.Pen([Drawing.Color]::White,[Math]::Max(1.6,$Size*0.075))
  $pen.StartCap='Round'; $pen.EndCap='Round'; $pen.LineJoin='Round'
  if($Glyph -eq 'monitor') {
    $screen=New-RoundedPath ($X+$Size*0.2) ($Y+$Size*0.24) ($Size*0.6) ($Size*0.4) ($Size*0.06)
    $Graphics.DrawPath($pen,$screen)
    $screen.Dispose()
    $Graphics.DrawLine($pen,[single]($X+$Size*0.5),[single]($Y+$Size*0.64),[single]($X+$Size*0.5),[single]($Y+$Size*0.76))
    $Graphics.DrawLine($pen,[single]($X+$Size*0.34),[single]($Y+$Size*0.76),[single]($X+$Size*0.66),[single]($Y+$Size*0.76))
  } else {
    $Graphics.DrawLine($pen,[single]($X+$Size*0.5),[single]($Y+$Size*0.26),[single]($X+$Size*0.5),[single]($Y+$Size*0.58))
    $dot=New-Object Drawing.SolidBrush ([Drawing.Color]::White)
    $r=$Size*0.06
    $Graphics.FillEllipse($dot,[single]($X+$Size*0.5-$r),[single]($Y+$Size*0.72-$r),[single]($r*2),[single]($r*2))
    $dot.Dispose()
  }
  $pen.Dispose()
}

function New-TrayIconImage {
  $size=[int][Math]::Max(32,32*$script:DpiScale)
  $bitmap=New-Object Drawing.Bitmap($size,$size)
  $graphics=[Drawing.Graphics]::FromImage($bitmap)
  Draw-Badge $graphics 1 1 ($size-2) $script:Accent
  $graphics.Dispose()
  $icon=[Drawing.Icon]::FromHandle($bitmap.GetHicon())
  $bitmap.Dispose()
  return $icon
}

function New-DotImage {
  param([Drawing.Color]$Color,[switch]$Hollow)
  $size=[int](16*$script:DpiScale)
  $bitmap=New-Object Drawing.Bitmap($size,$size)
  $graphics=[Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode='AntiAlias'
  [single]$d=$size*0.5; [single]$o=($size-$d)/2
  if($Hollow) {
    $pen=New-Object Drawing.Pen($Color,[Math]::Max(1.5,$size*0.1))
    $graphics.DrawEllipse($pen,$o,$o,$d,$d); $pen.Dispose()
  } else {
    $brush=New-Object Drawing.SolidBrush $Color
    $graphics.FillEllipse($brush,$o,$o,$d,$d); $brush.Dispose()
  }
  $graphics.Dispose()
  return $bitmap
}
$script:Dots=@{Online=New-DotImage $script:Online; Offline=New-DotImage $script:Offline -Hollow}

# ---------- Tray menu ----------

function Update-TrayMenu {
  param([Windows.Forms.ContextMenuStrip]$Menu,[object[]]$Sessions=@([SessionNative]::List()))
  $state=Get-DesktopState -Sessions $Sessions
  # Items share images and fonts, so they are cleared rather than disposed.
  $Menu.Items.Clear()

  $title=New-Object Windows.Forms.ToolStripLabel('RDP 桌面切换')
  $title.Font=$script:Fonts.MenuTitle
  $title.ForeColor=$script:Ink
  $title.Margin=New-Object Windows.Forms.Padding(0,6,0,0)
  [void]$Menu.Items.Add($title)
  $hereText=if($state.Current){"当前：会话 $sessionId · $(Get-SessionSummary $state.Current -NoStatus)"}else{"当前：会话 $sessionId"}
  $here=New-Object Windows.Forms.ToolStripLabel($hereText)
  $here.Font=$script:Fonts.MenuNote
  $here.ForeColor=$script:Muted
  $here.Margin=New-Object Windows.Forms.Padding(0,0,0,6)
  [void]$Menu.Items.Add($here)
  [void]$Menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))

  $section=New-Object Windows.Forms.ToolStripLabel('进入其他桌面')
  $section.Font=$script:Fonts.MenuNote
  $section.ForeColor=$script:Muted
  [void]$Menu.Items.Add($section)
  if($state.Others.Count) {
    foreach($desktop in $state.Others) {
      $item=New-Object Windows.Forms.ToolStripMenuItem("会话 $($desktop.Id)")
      $item.ShortcutKeyDisplayString=Get-SessionSummary $desktop
      $item.Image=if($desktop.State -eq 0){$script:Dots.Online}else{$script:Dots.Offline}
      $item.ToolTipText=if($desktop.State -eq 0){'正在其他设备上使用，进入后那台设备会断开'}else{'已断开，程序仍在运行，可直接恢复'}
      $item.Tag=$desktop
      $item.Add_Click({
        $target=$this.Tag
        try {Start-DesktopSwitch -Target $target} catch {Write-PickerLog "switch-error $_"}
      })
      [void]$Menu.Items.Add($item)
    }
  } else {
    $none=New-Object Windows.Forms.ToolStripMenuItem('没有其他可进入的桌面')
    $none.Enabled=$false
    [void]$Menu.Items.Add($none)
  }

  $disconnected=@($state.Others|Where-Object State -eq 4)
  if($disconnected.Count) {
    [void]$Menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
    $cleanup=New-Object Windows.Forms.ToolStripMenuItem('注销已断开的桌面')
    foreach($desktop in $disconnected) {
      $entry=New-Object Windows.Forms.ToolStripMenuItem("会话 $($desktop.Id)")
      $entry.ShortcutKeyDisplayString=Get-SessionSummary $desktop -NoStatus
      $entry.Image=$script:Dots.Offline
      $entry.Tag=$desktop
      $entry.Add_Click({
        $target=$this.Tag
        try {Remove-DisconnectedDesktop -Target $target} catch {Write-PickerLog "logoff-error $_"}
      })
      [void]$cleanup.DropDownItems.Add($entry)
    }
    [void]$Menu.Items.Add($cleanup)
  }

  [void]$Menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
  $notify=New-Object Windows.Forms.ToolStripMenuItem('登录或解锁时提醒我')
  $notify.Checked=[bool]$script:Settings.Notify
  $notify.Add_Click({
    $script:Settings.Notify=!$script:Settings.Notify
    Save-PickerSettings $script:Settings
  })
  [void]$Menu.Items.Add($notify)
  return $state
}

function New-TrayMenu {
  $menu=New-Object Windows.Forms.ContextMenuStrip
  $menu.Font=$script:Fonts.Menu
  $menu.Renderer=New-Object Windows.Forms.ToolStripProfessionalRenderer((New-Object TrayMenuColors))
  $menu.Padding=New-Object Windows.Forms.Padding(4,6,4,6)
  $menu.ShowItemToolTips=$true
  $menu.Add_Opening({
    try {[void](Update-TrayMenu -Menu $this)} catch {Write-PickerLog "menu-error $_"}
  })
  return $menu
}

function New-PickerTray {
  $tray=New-Object Windows.Forms.NotifyIcon
  $tray.Icon=New-TrayIconImage
  $tray.Text="RDP 桌面切换 · 会话 $sessionId"
  $tray.ContextMenuStrip=New-TrayMenu
  [void](Update-TrayMenu -Menu $tray.ContextMenuStrip)
  $tray.Add_MouseUp({
    try {if($_.Button -eq [Windows.Forms.MouseButtons]::Left){Show-TrayMenu $this}} catch {Write-PickerLog "menu-error $_"}
  })
  $tray.Add_BalloonTipClicked({try {Show-TrayMenu $this} catch {Write-PickerLog "menu-error $_"}})
  $tray.Visible=$true
  return $tray
}

function Show-TrayMenu {
  param([Windows.Forms.NotifyIcon]$Tray)
  if($script:DialogOpen){return}
  # NotifyIcon only exposes right-click opening; this private method opens the same menu at the cursor.
  $method=[Windows.Forms.NotifyIcon].GetMethod('ShowContextMenu',[Reflection.BindingFlags]'Instance,NonPublic')
  [void]$method.Invoke($Tray,$null)
}

function Show-DesktopHint {
  param([Windows.Forms.NotifyIcon]$Tray)
  if(!$script:Settings.Notify){return}
  $state=Get-DesktopState
  if(!$state.Others.Count){return}
  $names=($state.Others|Select-Object -First 3|ForEach-Object {"会话 $($_.Id)（$(Get-SessionKind $_)，$(Get-SessionStatus $_)）"}) -join '、'
  if($state.Others.Count -gt 3){$names+=' 等'}
  $Tray.ShowBalloonTip(10000,"还有 $($state.Others.Count) 个桌面可以进入","$names`r`n点击这里或右下角图标选择。",[Windows.Forms.ToolTipIcon]::None)
  Write-PickerLog "hint-shown session=$sessionId choices=$($state.Others.Count)"
}

# ---------- Dialogs ----------

function New-DialogShell {
  param([string]$Title,[string]$Subtitle,[int]$Height,[Drawing.Color]$BadgeColor=$script:Accent,[string]$Glyph='monitor')
  $form=New-Object Windows.Forms.Form
  $form.SuspendLayout()
  $form.AutoScaleDimensions=New-Object Drawing.SizeF(96,96)
  $form.AutoScaleMode='Dpi'
  $form.Text=$Title
  $form.Font=$script:Fonts.Body
  $form.FormBorderStyle='None'
  $form.ShowInTaskbar=$true
  $form.StartPosition='CenterScreen'
  $form.TopMost=$true
  $form.KeyPreview=$true
  $form.BackColor=[Drawing.Color]::White
  $form.ClientSize=New-Object Drawing.Size(560,$Height)
  $form.Tag=[pscustomobject]@{Result=$null;BadgeColor=$BadgeColor;Glyph=$Glyph;Buttons=@{}}
  $form.Add_Paint({
    $g=$_.Graphics
    $k=$script:DpiScale
    Draw-Badge $g (28*$k) (28*$k) (44*$k) $this.Tag.BadgeColor $this.Tag.Glyph
    $pen=New-Object Drawing.Pen($script:Line)
    $g.DrawRectangle($pen,0,0,$this.ClientSize.Width-1,$this.ClientSize.Height-1)
    $pen.Dispose()
  })
  $form.Add_Shown({$this.Activate()})
  $heading=New-Object Windows.Forms.Label
  $heading.Text=$Title
  $heading.Font=$script:Fonts.Title
  $heading.ForeColor=$script:Ink
  $heading.AutoEllipsis=$true
  $heading.SetBounds(88,24,444,34)
  $sub=New-Object Windows.Forms.Label
  $sub.Text=$Subtitle
  $sub.Font=$script:Fonts.Subtitle
  $sub.ForeColor=$script:Muted
  $sub.AutoEllipsis=$true
  $sub.SetBounds(88,60,444,26)
  $form.Controls.AddRange(@($heading,$sub))
  return $form
}

function New-FlatButton {
  param([string]$Text,[Drawing.Color]$Color,[switch]$Secondary)
  $button=New-Object Windows.Forms.Button
  $button.Text=$Text
  $button.Font=$script:Fonts.Button
  $button.FlatStyle='Flat'
  $button.Cursor='Hand'
  if($Secondary) {
    $button.BackColor=[Drawing.Color]::White
    $button.ForeColor=$script:Ink
    $button.FlatAppearance.BorderColor=$script:Line
    $button.FlatAppearance.BorderSize=1
    $button.FlatAppearance.MouseOverBackColor=[Drawing.Color]::FromArgb(248,250,252)
  } else {
    $button.BackColor=$Color
    $button.ForeColor=[Drawing.Color]::White
    $button.FlatAppearance.BorderSize=0
    $button.FlatAppearance.MouseOverBackColor=if($Color -eq $script:Danger){$script:DangerDark}else{$script:AccentDark}
  }
  return $button
}

# A large two-line choice card: bold title, grey explanation, coloured edge.
function New-ChoiceCard {
  param([string]$Title,[string]$Detail,[Drawing.Color]$Color,[string]$Result,[string]$Pill)
  $card=New-Object Windows.Forms.Button
  $card.Text=''
  $card.FlatStyle='Flat'
  $card.Cursor='Hand'
  $card.BackColor=[Drawing.Color]::White
  $card.FlatAppearance.BorderColor=$script:Line
  $card.FlatAppearance.BorderSize=1
  $card.FlatAppearance.MouseOverBackColor=$script:Hover
  $card.FlatAppearance.MouseDownBackColor=[Drawing.Color]::FromArgb(224,233,255)
  $card.AccessibleName="$Title。$Detail"
  $card.Tag=[pscustomobject]@{Title=$Title;Detail=$Detail;Color=$Color;Result=$Result;Pill=$Pill}
  $card.Add_Enter({$this.FlatAppearance.BorderColor=$script:Accent})
  $card.Add_Leave({$this.FlatAppearance.BorderColor=$script:Line})
  $card.Add_Paint({
    $g=$_.Graphics
    $k=$script:DpiScale
    $info=$this.Tag
    $g.SmoothingMode='AntiAlias'
    $bar=New-Object Drawing.SolidBrush $info.Color
    $g.FillRectangle($bar,1,1,[int](5*$k),$this.Height-2)
    $bar.Dispose()
    $flags=[Windows.Forms.TextFormatFlags]'NoPadding,SingleLine,EndEllipsis'
    $titleSize=[Windows.Forms.TextRenderer]::MeasureText($g,$info.Title,$script:Fonts.CardTitle,(New-Object Drawing.Size(9999,9999)),$flags)
    [Windows.Forms.TextRenderer]::DrawText($g,$info.Title,$script:Fonts.CardTitle,(New-Object Drawing.Point([int](24*$k),[int](15*$k))),$script:Ink,$flags)
    if($info.Pill) {
      $pillSize=[Windows.Forms.TextRenderer]::MeasureText($g,$info.Pill,$script:Fonts.Pill,(New-Object Drawing.Size(9999,9999)),$flags)
      $px=24*$k+$titleSize.Width+10*$k; $py=15*$k+($titleSize.Height-$pillSize.Height-6*$k)/2
      $pill=New-RoundedPath $px $py ($pillSize.Width+14*$k) ($pillSize.Height+6*$k) (($pillSize.Height+6*$k)/2)
      $fill=New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(219,234,254))
      $g.FillPath($fill,$pill); $fill.Dispose(); $pill.Dispose()
      [Windows.Forms.TextRenderer]::DrawText($g,$info.Pill,$script:Fonts.Pill,(New-Object Drawing.Point([int]($px+7*$k),[int]($py+3*$k))),$script:AccentDark,$flags)
    }
    $detailBounds=New-Object Drawing.Rectangle([int](24*$k),[int](48*$k),[int]($this.Width-64*$k),[int](26*$k))
    [Windows.Forms.TextRenderer]::DrawText($g,$info.Detail,$script:Fonts.CardDetail,$detailBounds,$script:Muted,$flags)
    $pen=New-Object Drawing.Pen($script:Offline,[Math]::Max(1.6,2*$k))
    $pen.StartCap='Round'; $pen.EndCap='Round'
    $cx=$this.Width-26*$k; $cy=$this.Height/2
    $g.DrawLine($pen,[single]($cx-4*$k),[single]($cy-7*$k),[single]($cx+3*$k),[single]$cy)
    $g.DrawLine($pen,[single]($cx+3*$k),[single]$cy,[single]($cx-4*$k),[single]($cy+7*$k))
    $pen.Dispose()
  })
  $card.Add_Click({
    $window=$this.FindForm()
    $window.Tag.Result=$this.Tag.Result
    $window.DialogResult='OK'
  })
  return $card
}

function New-SwitchDialog {
  param($Target,$Current)
  $warning=$Target.State -eq 0
  $height=if($warning){460}else{408}
  $form=New-DialogShell -Title "进入会话 $($Target.Id)" -Subtitle (Get-SessionSummary $Target) -Height $height
  $y=104
  if($warning) {
    $note=New-Object Windows.Forms.Label
    $note.Text='这个桌面正在另一台设备上使用，进入后那台设备会断开连接。'
    $note.Font=$script:Fonts.Subtitle
    $note.ForeColor=[Drawing.Color]::FromArgb(154,52,18)
    $note.BackColor=[Drawing.Color]::FromArgb(255,247,237)
    $note.Padding=New-Object Windows.Forms.Padding(12,0,12,0)
    $note.TextAlign='MiddleLeft'
    $note.SetBounds(28,$y,504,40)
    $form.Controls.Add($note)
    $y+=52
  }
  $question=New-Object Windows.Forms.Label
  $question.Text="离开当前桌面（会话 $sessionId）后，要怎么处理它？"
  $question.ForeColor=$script:Ink
  $question.SetBounds(28,$y,504,30)
  $form.Controls.Add($question)
  $y+=40
  $keep=New-ChoiceCard -Title '保留当前桌面' -Detail '只断开连接，程序继续运行，之后可从托盘菜单回来' -Color $script:Accent -Result 'Keep' -Pill '推荐'
  $keep.SetBounds(28,$y,504,84)
  $y+=96
  $logoff=New-ChoiceCard -Title '注销并删除当前桌面' -Detail '关闭其中所有程序，未保存的工作会丢失' -Color $script:Danger -Result 'Logoff'
  $logoff.SetBounds(28,$y,504,84)
  $y+=100
  $cancel=New-FlatButton -Text '取消' -Secondary
  $cancel.DialogResult='Cancel'
  $cancel.SetBounds(424,$y,108,42)
  $form.Controls.AddRange(@($keep,$logoff,$cancel))
  $form.CancelButton=$cancel
  $form.ActiveControl=$keep
  $form.Tag.Buttons=@{Keep=$keep;Logoff=$logoff;Cancel=$cancel}
  $form.ResumeLayout($false)
  return $form
}

function Show-SwitchDialog {
  param($Target,$Current)
  $form=New-SwitchDialog -Target $Target -Current $Current
  try {
    if($form.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){return $form.Tag.Result}
    return $null
  } finally {$form.Dispose()}
}

function New-PickerNotice {
  param([string]$Title,[string]$Text,[string]$ConfirmText,[switch]$Danger)
  $color=if($Danger){$script:Danger}else{$script:Accent}
  $badge=if($Danger){$script:Danger}else{$script:Warning}
  $form=New-DialogShell -Title $Title -Subtitle 'RDP 桌面切换' -Height 292 -BadgeColor $badge -Glyph '!'
  $body=New-Object Windows.Forms.Label
  $body.Text=$Text
  $body.ForeColor=$script:Ink
  $body.SetBounds(28,104,504,100)
  $form.Controls.Add($body)
  if($ConfirmText) {
    $ok=New-FlatButton -Text $ConfirmText -Color $color
    $ok.DialogResult='Yes'
    $ok.SetBounds(372,226,160,44)
    $back=New-FlatButton -Text '取消' -Secondary
    $back.DialogResult='Cancel'
    $back.SetBounds(252,226,108,44)
    $form.Controls.AddRange(@($back,$ok))
    $form.CancelButton=$back
    $form.ActiveControl=$back
  } else {
    $ok=New-FlatButton -Text '知道了' -Color $script:Accent
    $ok.DialogResult='OK'
    $ok.SetBounds(392,226,140,44)
    $form.Controls.Add($ok)
    $form.CancelButton=$ok
    $form.ActiveControl=$ok
  }
  $form.Tag.Buttons=@{Ok=$ok}
  $form.ResumeLayout($false)
  return $form
}

function Show-PickerNotice {
  param([string]$Title,[string]$Text,[string]$ConfirmText,[switch]$Danger)
  $form=New-PickerNotice -Title $Title -Text $Text -ConfirmText $ConfirmText -Danger:$Danger
  try {return $form.ShowDialog() -eq [Windows.Forms.DialogResult]::Yes}
  finally {$form.Dispose()}
}

# ---------- Actions ----------

function Start-DesktopSwitch {
  param($Target)
  if($script:DialogOpen){return}
  $script:DialogOpen=$true
  try {
    $state=Get-DesktopState
    $latest=$state.Others|Where-Object Id -eq $Target.Id
    if(!$latest) {
      [void](Show-PickerNotice -Title '这个桌面已经不在了' -Text "会话 $($Target.Id) 已退出或状态发生变化。请重新打开托盘菜单查看最新列表。")
      return
    }
    $choice=Show-SwitchDialog -Target $latest -Current $state.Current
    if(!$choice){return}
    if(!(Test-DesktopStillAvailable $latest)) {
      [void](Show-PickerNotice -Title '这个桌面已经不在了' -Text "会话 $($Target.Id) 已退出或状态发生变化。当前桌面已保留。")
      return
    }
    $skipPath=Join-Path $stateFolder "skip-$($latest.Id).txt"
    [IO.File]::WriteAllText($skipPath,[DateTime]::UtcNow.AddSeconds(30).ToString('o'))
    if([SessionNative]::WTSConnectSessionW($latest.Id,$sessionId,'',$true)) {
      Write-PickerLog "switched $sessionId -> $($latest.Id) current=$choice"
      if($choice -eq 'Logoff') {
        if($script:Tray){$script:Tray.Visible=$false}
        [void][SessionNative]::WTSLogoffSession([IntPtr]::Zero,$sessionId,$false)
      }
    } else {
      $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
      Remove-Item -LiteralPath $skipPath -ErrorAction SilentlyContinue
      [void](Show-PickerNotice -Title '没能切换桌面' -Text "Windows 返回错误 $code。`r`n当前桌面已保留，没有任何改动。")
    }
  } finally {$script:DialogOpen=$false}
}

function Remove-DisconnectedDesktop {
  param($Target)
  if($script:DialogOpen){return}
  $script:DialogOpen=$true
  try {
    $text="会话 $($Target.Id)（$(Get-SessionSummary $Target -NoStatus)）里的所有程序都会关闭，未保存的工作会丢失。"
    if(!(Show-PickerNotice -Title "注销会话 $($Target.Id)？" -Text $text -ConfirmText '注销' -Danger)){return}
    if(!(Test-DesktopStillAvailable $Target -States 4)) {
      [void](Show-PickerNotice -Title '这个桌面状态已变化' -Text "会话 $($Target.Id) 已退出或重新连接，没有执行注销。")
      return
    }
    if([SessionNative]::WTSLogoffSession([IntPtr]::Zero,$Target.Id,$false)) {
      Write-PickerLog "logged-off $($Target.Id) from $sessionId"
    } else {
      $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
      [void](Show-PickerNotice -Title '没能注销桌面' -Text "Windows 返回错误 $code。")
    }
  } finally {$script:DialogOpen=$false}
}
