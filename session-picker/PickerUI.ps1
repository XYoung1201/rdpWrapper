function New-PickerButton {
  param([string]$Text,[bool]$Primary=$false)
  $button=New-Object Windows.Forms.Button
  $button.Text=$Text
  $button.Dock='Fill'
  $button.Margin=New-Object Windows.Forms.Padding(8)
  $button.Font=New-Object Drawing.Font('Microsoft YaHei UI',17,[Drawing.FontStyle]::Bold)
  $button.FlatStyle='Flat'
  $button.BackColor=if($Primary){[Drawing.Color]::FromArgb(24,87,181)}else{[Drawing.Color]::White}
  $button.ForeColor=if($Primary){[Drawing.Color]::White}else{[Drawing.Color]::FromArgb(25,40,60)}
  return $button
}

function Show-PickerNotice {
  param([string]$Title,[string]$Text,[switch]$Confirm,[Windows.Forms.Form]$Owner)
  $dialog=New-Object Windows.Forms.Form
  $dialog.Text=$Title
  $dialog.Font=New-Object Drawing.Font('Microsoft YaHei UI',16)
  $dialog.AutoScaleMode='Dpi'
  $dialog.ClientSize=New-Object Drawing.Size(800,380)
  $dialog.StartPosition='CenterParent'
  $dialog.FormBorderStyle='FixedDialog'
  $dialog.MaximizeBox=$false
  $dialog.MinimizeBox=$false
  $layout=New-Object Windows.Forms.TableLayoutPanel
  $layout.Dock='Fill'
  $layout.Padding=New-Object Windows.Forms.Padding(24)
  $layout.RowCount=2
  [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
  [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',88)))
  $message=New-Object Windows.Forms.Label
  $message.Text=$Text
  $message.Dock='Fill'
  $message.TextAlign='MiddleLeft'
  $actions=New-Object Windows.Forms.TableLayoutPanel
  $actions.Dock='Fill'
  $actions.ColumnCount=2
  [void]$actions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50)))
  [void]$actions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50)))
  $back=New-PickerButton -Text '返回选择'
  $back.DialogResult='Cancel'
  $okText=if($Confirm){'确认接管'}else{'知道了'}
  $ok=New-PickerButton -Text $okText -Primary $true
  $ok.DialogResult=if($Confirm){'Yes'}else{'OK'}
  $actions.Controls.Add($back,0,0)
  $actions.Controls.Add($ok,1,0)
  $back.Visible=[bool]$Confirm
  $dialog.CancelButton=$back
  $dialog.AcceptButton=if($Confirm){$back}else{$ok}
  $layout.Controls.Add($message,0,0)
  $layout.Controls.Add($actions,0,1)
  $dialog.Controls.Add($layout)
  try {return $dialog.ShowDialog($Owner) -eq [Windows.Forms.DialogResult]::Yes}
  finally {$dialog.Dispose()}
}

function New-SessionPickerWindow {
  param([object[]]$Sessions=@([SessionNative]::List()))
  $current=$sessions|Where-Object Id -eq $sessionId
  $others=@($sessions|Where-Object { $_.Id -ne $sessionId -and $_.User -eq $current.User -and $_.Domain -eq $current.Domain -and $_.State -in 0,4 })
  $form=New-Object Windows.Forms.Form
  $form.Text='选择要使用的桌面'
  $form.Font=New-Object Drawing.Font('Microsoft YaHei UI',15)
  $form.AutoScaleMode='Dpi'
  $form.ClientSize=New-Object Drawing.Size(1024,660)
  $form.MinimumSize=New-Object Drawing.Size(860,600)
  $form.StartPosition='CenterScreen'
  $form.TopMost=$true
  $form.BackColor=[Drawing.Color]::FromArgb(245,248,252)
  $form.Tag=[pscustomobject]@{Current=$current;Targets=$others;List=$null;Connect=$null;Logged=$false}
  $layout=New-Object Windows.Forms.TableLayoutPanel
  $layout.Dock='Fill'
  $layout.Padding=New-Object Windows.Forms.Padding(24)
  $layout.RowCount=5
  foreach($height in 96,48){[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',$height)))}
  [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Percent',100)))
  foreach($height in 86,104){[void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle('Absolute',$height)))}
  $heading=New-Object Windows.Forms.Label
  $heading.Text="当前桌面：会话 $sessionId`r`n账户：$($current.Domain)\$($current.User)"
  $heading.Font=New-Object Drawing.Font('Microsoft YaHei UI',19,[Drawing.FontStyle]::Bold)
  $heading.Dock='Fill'
  $instruction=New-Object Windows.Forms.Label
  $instruction.Text='点击或用方向键选择桌面，按 Enter 或点击“接管选中的桌面”。'
  $instruction.Dock='Fill'
  $list=New-Object Windows.Forms.ListView
  $list.Dock='Fill'
  $list.View='Details'
  $list.FullRowSelect=$true
  $list.MultiSelect=$false
  $list.HideSelection=$false
  $list.GridLines=$true
  $list.HeaderStyle='Nonclickable'
  foreach($column in @(@('会话',90),@('桌面类型',230),@('状态',200),@('连接设备',400))) {
    [void]$list.Columns.Add($column[0],$column[1])
  }
  $rowImages=New-Object Windows.Forms.ImageList
  $rowImages.ImageSize=New-Object Drawing.Size(1,54)
  $list.SmallImageList=$rowImages
  foreach($item in $others) {
    $kind=if($item.Name -eq 'console'){'本机 HDMI / 屏幕'}else{'远程 RDP 桌面'}
    $status=if($item.State -eq 0){'正在使用'}else{'已断开，可恢复'}
    $client=if($item.Name -eq 'console'){'本机键盘、鼠标'}elseif($item.Client){$item.Client}else{'设备名称未报告'}
    $row=New-Object Windows.Forms.ListViewItem([string]$item.Id)
    [void]$row.SubItems.Add($kind)
    [void]$row.SubItems.Add($status)
    [void]$row.SubItems.Add($client)
    $row.Tag=$item
    [void]$list.Items.Add($row)
  }
  $note=New-Object Windows.Forms.Label
  $note.Text="接管后，原设备会断开连接，当前桌面会注销。`r`n请先保存当前桌面中的工作。"
  $note.Dock='Fill'
  $note.Padding=New-Object Windows.Forms.Padding(0,12,0,0)
  $note.ForeColor=[Drawing.Color]::FromArgb(130,60,10)
  if(!$others.Count){$note.Text='当前没有其他同账户桌面。点击下方按钮继续使用当前桌面。'}
  $buttons=New-Object Windows.Forms.TableLayoutPanel
  $buttons.Dock='Fill'
  $buttons.ColumnCount=2
  [void]$buttons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50)))
  [void]$buttons.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle('Percent',50)))
  $keep=New-PickerButton -Text '继续使用当前桌面'
  $keep.Add_Click({$this.FindForm().Close()})
  $connect=New-PickerButton -Text '接管选中的桌面' -Primary $true
  $connect.Enabled=$false
  $connect.BackColor=[Drawing.Color]::FromArgb(220,226,234)
  $form.Tag.List=$list
  $form.Tag.Connect=$connect
  $list.Add_SelectedIndexChanged({
    $state=$this.FindForm().Tag
    $state.Connect.Enabled=$this.SelectedItems.Count -eq 1
    $state.Connect.BackColor=if($state.Connect.Enabled){[Drawing.Color]::FromArgb(24,87,181)}else{[Drawing.Color]::FromArgb(220,226,234)}
  })
  $list.Add_KeyDown({
    if($_.KeyCode -eq [Windows.Forms.Keys]::Enter -and $this.SelectedItems.Count -eq 1) {
      $this.FindForm().Tag.Connect.PerformClick()
      $_.SuppressKeyPress=$true
    }
  })
  $connect.Add_Click({
    $window=$this.FindForm()
    $state=$window.Tag
    if($state.List.SelectedItems.Count -ne 1){return}
    $target=$state.List.SelectedItems[0].Tag
    $latest=[SessionNative]::List()|Where-Object Id -eq $target.Id
    if(!$latest -or $latest.User -ne $state.Current.User -or $latest.Domain -ne $state.Current.Domain -or $latest.State -notin 0,4) {
      [void](Show-PickerNotice -Title '桌面状态已变化' -Text '该桌面已退出或状态发生变化。请关闭选择器，重新打开后再选择。' -Owner $window)
      return
    }
    $text="即将接管会话 $($target.Id)。`r`n`r`n原设备会断开连接，当前会话 $sessionId 会注销。`r`n当前桌面中未保存的工作将丢失。"
    if(!(Show-PickerNotice -Title '确认接管桌面' -Text $text -Confirm -Owner $window)){return}
    $skipPath=Join-Path $stateFolder "skip-$($target.Id).txt"
    [IO.File]::WriteAllText($skipPath,[DateTime]::UtcNow.AddSeconds(30).ToString('o'))
    if([SessionNative]::WTSConnectSessionW($target.Id,$sessionId,'',$true)) {
      Add-Content (Join-Path $stateFolder 'history.log') "$(Get-Date -Format o) switched $sessionId -> $($target.Id)"
      $window.Close()
      [void][SessionNative]::WTSLogoffSession([IntPtr]::Zero,$sessionId,$false)
    } else {
      $code=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
      Remove-Item -LiteralPath $skipPath -ErrorAction SilentlyContinue
      [void](Show-PickerNotice -Title '未能切换桌面' -Text "Windows 返回错误 $code。当前桌面已保留。" -Owner $window)
    }
  })
  $buttons.Controls.Add($keep,0,0)
  $buttons.Controls.Add($connect,1,0)
  $layout.Controls.Add($heading,0,0)
  $layout.Controls.Add($instruction,0,1)
  $layout.Controls.Add($list,0,2)
  $layout.Controls.Add($note,0,3)
  $layout.Controls.Add($buttons,0,4)
  $form.Controls.Add($layout)
  $form.AcceptButton=$keep
  $form.CancelButton=$keep
  $form.Add_FormClosed({$this.Tag.List.SmallImageList.Dispose()})
  return $form
}

function Show-SessionPicker {
  $form=New-SessionPickerWindow
  try {
    $form.Add_Shown({
      if(!$this.Tag.Logged) {
        $this.Tag.Logged=$true
        Add-Content (Join-Path $stateFolder 'history.log') "$(Get-Date -Format o) picker-visible session=$sessionId visible=$($this.Visible) choices=$($this.Tag.Targets.Count)"
      }
    })
    $form.Show()
    $form.Hide()
    [void]$form.ShowDialog()
  } finally {$form.Dispose()}
}
