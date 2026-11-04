# RDP Session Picker · 桌面会话选择器

Large-text desktop selector for local console and RDP sessions belonging to the signed-in account. A companion for RDP Wrapper / TermWrap, with automatic launch after local sign-in, unlock, and RDP reconnection.

登录、解锁或重连后，选择继续使用当前桌面，或接管同一账户已有的本地 / RDP 桌面。

![大字界面预览，使用演示数据](preview.png)

## 功能

- 15–19 磅字体、54 像素列表行、大尺寸按钮和大字确认窗口。
- 按会话编号、桌面类型、使用状态和客户端设备分列显示。
- 本地 HDMI 屏幕登录 / 解锁、RDP 连接 / 重连后自动打开。
- 支持触摸、鼠标、方向键、Tab、Enter 和 Esc。
- 列出同账户正在使用和已经断开的本地 / RDP 桌面。
- 接管前再次确认。成功后注销当前过渡会话。
- 后台任务为安装前已经存在的会话启动选择器，并补齐退出的选择器进程。

## 安装

1. 先使用 RDP Wrapper / TermWrap 配置好远程桌面服务。
2. 下载本目录或发行包，并解压完整文件夹。
3. 在正在使用的本地或 RDP 桌面中双击 `Install.cmd`，确认 UAC 提示。
4. 登录、解锁或重连后会自动显示选择器。也可以从开始菜单打开 `RDP Session Picker`。

本扩展使用 Windows PowerShell 5.1、.NET Framework 和 Windows 自带的 WTS 接口。已在 Windows 11 x64、TermWrap 环境验证同账户并发、本地与 RDP 之间双向接管，以及 RDP 会话接管。其他系统版本的兼容性需要单独验证。

安装位置为 `%ProgramFiles%\RdpSessionPicker`。安装器将系统和策略中的 `fSingleSessionPerUser` 设为 `0`，并保存首次安装时的值。

系统任务 `RdpSessionPickerBroker` 在开机时启动，以 SYSTEM 身份为各用户自己的会话启动普通权限的选择器。选择器只提供当前账户的桌面。任务每五秒检查一次选择器进程，解锁与连接由 WTS 事件触发。

## 使用

选择一行，再点击“接管选中的桌面”，或按 Enter。确认窗口会再次说明目标会话与注销行为。

接管后，目标桌面的原连接会断开，当前桌面会注销。请先保存当前桌面中的工作。关闭窗口、按 Esc 或点击“继续使用当前桌面”会保留当前桌面。

界面显示的是 Windows 用户会话。同一会话中的多个虚拟桌面属于同一个条目。列表在窗口打开时读取，目标状态会在接管前再次核验。

选择器在 Windows 完成登录或解锁后显示。Windows 可能已经恢复旧会话。登录前强制创建全新独立会话的功能尚未实现。

## 卸载

双击 `Uninstall.cmd` 并确认 UAC。卸载器移除选择器的系统任务、进程、开始菜单入口和运行文件，并恢复保存的单会话设置。

选择器运行日志位于 `%LocalAppData%\RdpSessionPicker\history.log`，后台任务日志位于 `%ProgramData%\RdpSessionPicker\broker.log`。这些历史记录在卸载后保留，可按需删除。

## 验证

在本目录运行下面的命令。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File tests\Test-Events.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File tests\Test-UI.ps1
```

事件检查覆盖本地连接、远程连接、解锁和锁屏事件的处理。界面检查使用演示会话，核对本地 / 远程条目、字体、按钮尺寸和行选择。实际网络连接与登录仍需要在目标设备上验证。

## 与上游项目的关系

这是基于 sergiye/rdpWrapper 的 fork 中新增的配套扩展。上游工具负责配置远程桌面支持，本目录负责登录后的桌面选择。上游项目介绍见仓库根目录的 README。
