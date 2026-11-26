<h1 align="center">RDP Wrapper + Session Picker</h1>

<p align="center"><b>本地与远程桌面会话选择工具</b></p>
<p align="center">右下角托盘图标常驻，右键即可进入同账户的其他桌面，离开时选择保留或注销当前桌面。</p>

<p align="center">
  <b>简体中文</b> · <a href="README_EN.md">English</a>
</p>

<p align="center">
  <a href="https://github.com/XYoung1201/rdpWrapper/releases/latest"><b>下载安装包</b></a> ·
  <a href="#快速上手"><b>快速上手</b></a> ·
  <a href="#功能与操作"><b>功能与操作</b></a> ·
  <a href="#常见问题"><b>常见问题</b></a> ·
  <a href="#反馈与贡献"><b>反馈与贡献</b></a>
</p>

<p align="center">
  <a href="https://github.com/XYoung1201/rdpWrapper/releases/latest"><img src="https://img.shields.io/github/v/release/XYoung1201/rdpWrapper?color=2563eb" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/tested-Windows%2011%20x64-0078D4" alt="Tested on Windows 11 x64">
  <img src="https://img.shields.io/badge/PowerShell-5.1-5391FE" alt="Windows PowerShell 5.1">
  <img src="https://img.shields.io/badge/runtime-.NET%20Framework-512BD4" alt=".NET Framework">
</p>

<p align="center">
  <a href="session-picker/preview.png"><img src="session-picker/preview.png" alt="托盘菜单列出其他桌面，进入时询问保留还是注销当前桌面" width="960"></a>
</p>
<p align="center"><sub>设计示意图，使用演示数据：右侧为托盘右键菜单，左侧为进入桌面时的提示窗口。</sub></p>

本仓库基于 sergiye/rdpWrapper，增加了用于 Windows 本地与远程桌面的 Session Picker 配套扩展。上游工具负责配置 RDP Wrapper / TermWrap，选择器以托盘图标常驻在每个桌面的右下角，右键菜单列出当前账户已有的其他桌面，点击即可进入。

它适合在本机 HDMI 屏幕、另一台电脑和移动端 RDP 客户端之间切换工作位置。进入其他桌面时会询问如何处理当前桌面：保留（只断开，程序继续运行）或注销删除。

已在 Windows 11 x64、TermWrap 环境验证本地与 RDP 桌面的双向接管，以及同账户 RDP 会话之间的接管。其他系统与客户端组合需要在目标设备上验证。

## 目录

- [产品特性](#产品特性)
- [适用场景](#适用场景)
- [快速上手](#快速上手)
- [界面导览](#界面导览)
- [功能与操作](#功能与操作)
- [安装与卸载](#安装与卸载)
- [配置说明](#配置说明)
- [常见问题](#常见问题)
- [开发与扩展](#开发与扩展)
- [反馈与贡献](#反馈与贡献)
- [资料与资源](#资料与资源)

## 产品特性

| 特性 | 可以做什么 | 使用效果 |
|---|---|---|
| 托盘常驻 | 右下角图标常驻，右键或左键打开桌面菜单 | 不再占用屏幕，需要时再打开 |
| 本地与 RDP 桌面选择 | 菜单列出同账户的本地屏幕桌面、活动 RDP 桌面与断开的桌面 | 按工作位置和已有内容选择桌面 |
| 登录与解锁提醒 | 本地登录、解锁及 RDP 连接、重连后，若有其他桌面则弹出一条通知 | 不打扰，又不会忘记还有旧桌面 |
| 保留或注销 | 进入其他桌面时选择保留当前桌面或注销删除它 | 想留就留，用完即删 |
| 分列状态信息 | 展示会话编号、桌面类型、使用状态和连接设备 | 清楚辨认将要接管的桌面 |
| 清理旧桌面 | 托盘菜单可直接注销已断开的桌面 | 保留的桌面用完后随时清理 |
| 多桌面开关 | 托盘菜单“启用多桌面”一键开启或关闭同账户多会话 | 不想新建桌面时关掉，新的连接直接进入已有桌面 |
| 设备绑定 | 多桌面开启时，把某台设备（按 RDP 客户端名称识别）固定到某个桌面 | 手机、笔记本每次连上都回到各自的桌面 |
| 后台启动补齐 | 为已存在的会话启动选择器，并检查选择器进程 | 安装前已登录的桌面也能获得选择入口 |

## 适用场景

| 使用需求 | 操作方式 |
|---|---|
| 从手机或另一台电脑继续操作本机桌面 | RDP 登录后右键托盘图标，选择“本机屏幕”那一项 |
| 回到本机继续使用远程桌面的工作内容 | 解锁本机后右键托盘图标，选择正在使用的 RDP 桌面 |
| 恢复之前断开的桌面 | 在菜单中选择标为“已断开”（空心圆点）的会话 |
| 临时离开，之后还要回来 | 进入其他桌面时选择“保留当前桌面” |
| 用完就删 | 进入其他桌面时选择“注销并删除当前桌面”，或在菜单“注销已断开的桌面”中清理 |

## 快速上手

### 下载安装

1. 先通过上游 RDP Wrapper / TermWrap 配置好本机远程桌面支持。
2. 下载本仓库发行页中的 `RDP-Session-Picker-v1.0.0.zip`，解压完整文件夹。
3. 在正在使用的桌面中双击 `session-picker/Install.cmd`，确认 UAC 提示。
4. 右下角出现蓝色显示器图标。登录、解锁或 RDP 重连时，如果还有其他桌面，会弹出一条提醒。
5. 右键（或左键）托盘图标，点击要进入的桌面，然后选择“保留当前桌面”或“注销并删除当前桌面”。

进入后，目标桌面原来的连接会断开。选择注销时，当前桌面中未保存的工作会丢失。

安装包与上游工具分别提供下载入口。[选择器发行版](https://github.com/XYoung1201/rdpWrapper/releases/latest) · [上游 RDP Wrapper 发行版](https://github.com/sergiye/rdpWrapper/releases)

### 环境要求

| 项目 | 要求与用途 |
|---|---|
| 已验证系统 | Windows 11 x64 |
| 远程桌面服务 | 已配置并能正常连接的 RDP Wrapper / TermWrap 环境 |
| 脚本与界面运行时 | Windows PowerShell 5.1、.NET Framework、Windows Forms |
| 安装与卸载 | 管理员确认，用于部署系统任务和设置 |
| 日常使用 | 选择器以会话用户的普通权限运行，列出同一账户的桌面 |

### 从源码安装

```powershell
git clone https://github.com/XYoung1201/rdpWrapper.git
cd rdpWrapper
.\session-picker\Install.cmd
```

UAC 提示会出现在启动安装程序的会话中。通过 RDP 使用时，请在对应的远程桌面中启动安装程序。

## 界面导览

| 位置 | 主要内容 |
|---|---|
| 托盘图标 | 常驻右下角，悬停显示当前会话编号 |
| 菜单顶部 | 当前会话编号、桌面类型和设备 |
| 进入其他桌面 | 每个同账户会话一行：实心绿点为正在使用，空心圆点为已断开，右侧显示类型、状态与设备 |
| 注销已断开的桌面 | 子菜单列出已断开的会话，确认后注销 |
| 启用多桌面 | 勾选时每个新的远程连接打开独立桌面；取消勾选后新连接进入已有桌面 |
| 设备绑定 | 子菜单列出连接过本账户的远程设备，可把每台设备绑定到一个桌面或解除绑定 |
| 登录或解锁时提醒我 | 勾选后在回到桌面时弹出通知，可随时关闭 |
| 进入提示窗口 | 两张大卡片：“保留当前桌面”（默认）与“注销并删除当前桌面”，另有取消按钮 |

## 功能与操作

### 选择与接管桌面

在托盘菜单中点击一个桌面，再在提示窗口中选择如何处理当前桌面。目标会话会在执行前重新核验，确认属于当前账户且仍可使用后才尝试连接。

- **保留当前桌面**：当前桌面只是断开连接，程序继续运行，之后可以从托盘菜单回来。
- **注销并删除当前桌面**：当前桌面中的程序全部关闭，会话被注销。

本地屏幕与 RDP 桌面都以 Windows 会话呈现。Windows 的任务视图虚拟桌面属于各自会话内部，多个虚拟桌面会显示为同一个会话条目。

### 多桌面开关与设备绑定

托盘菜单中的 **启用多桌面** 控制 Windows 是否允许同一账户同时打开多个桌面（`fSingleSessionPerUser`）。

- 勾选（默认）：每个新的远程连接打开一个独立桌面。
- 取消勾选：新的远程连接直接进入这个账户已有的桌面，Windows 不再新建桌面。已经打开的桌面会保留，仍可从菜单进入或注销。

设置由后台任务以 SYSTEM 身份写入注册表，通常一两秒内生效，只影响之后的新连接。

多桌面开启时，**设备绑定** 子菜单列出连接过本账户的远程设备，按 RDP 客户端上报的设备名识别，悬停可看到当时的 IP。为某台设备选择“绑定到 会话 N”后：

- 这台设备每次新连接时，后台任务会把它直接移入会话 N。为这次连接临时打开的新桌面会随即注销；如果 Windows 恢复的是另一个已有桌面，那个桌面只会断开并保留。
- 如果会话 N 正在另一台设备上使用，那台设备会断开，与手动进入时一样。
- 如果会话 N 已被注销，这台设备下次连接时打开的新桌面会自动成为它的绑定桌面。
- 在托盘菜单中手动进入其他桌面不受绑定影响，绑定只作用于新的连接。
- 选择“解除绑定”可恢复默认行为。关闭多桌面时，绑定会暂停，重新开启后继续生效。

设备名可以在 RDP 客户端中修改，两台同名设备会被视为同一台设备。

### 常用操作与快捷键

| 操作 | 方式 |
|---|---|
| 打开桌面菜单 | 右键或左键点击托盘图标，点击登录提醒通知，或从开始菜单打开 `RDP Session Picker` |
| 选择菜单项 | 鼠标、触摸，或方向键加 Enter |
| 在提示窗口中切换选项 | Tab 或方向键，Enter 确认 |
| 取消进入 | 点击“取消”或按 Esc，当前桌面不变 |

### 当前功能边界

托盘图标在 Windows 完成登录后出现。连接过程中，Windows 可能已经恢复旧会话。登录前强制创建全新独立会话的功能尚未实现。

菜单每次打开时重新读取会话列表，目标状态在进入前再次核验。托盘程序由后台任务守护，退出后几秒内会自动重新启动，因此菜单中没有“退出”项。

## 安装与卸载

| 入口 | 作用 |
|---|---|
| `session-picker/Install.cmd` | 安装或更新选择器，并启动后台任务 |
| `session-picker/Uninstall.cmd` | 移除选择器任务、进程、开始菜单入口和运行文件，恢复保存的单会话设置 |
| 开始菜单中的 `RDP Session Picker` | 打开托盘图标的桌面菜单 |

卸载后保留本地运行历史，可按需删除。完整脚本说明见[选择器文档](session-picker/README.md)。

## 配置说明

| 位置 / 配置 | 作用 |
|---|---|
| `%ProgramFiles%\RdpSessionPicker` | 已安装的运行文件 |
| 系统任务 `RdpSessionPickerBroker` | 开机运行，以 SYSTEM 身份为各会话启动普通权限的选择器 |
| `fSingleSessionPerUser` | 安装时将系统与策略中的值设为 `0`，允许同账户多会话 |
| `settings-before-install.json` | 保存首次安装时的单会话设置，用于卸载恢复 |
| `%LocalAppData%\RdpSessionPicker\history.log` | 提醒显示与会话切换记录 |
| `%LocalAppData%\RdpSessionPicker\settings.json` | 是否在登录或解锁时提醒 |
| `%ProgramData%\RdpSessionPicker\broker.log` | 后台任务启动、多桌面设置与设备绑定执行记录 |
| `%ProgramData%\RdpSessionPicker\shared\config.json` | 多桌面开关与设备绑定，由托盘程序写入、后台任务执行；已登录用户可修改此目录 |

后台任务每秒应用一次多桌面设置并检查设备绑定，每五秒检查一次选择器进程；连接和解锁由 Windows WTS 事件触发。

## 常见问题

| 现象 | 检查与处理 |
|---|---|
| 右下角没有图标 | 展开托盘的隐藏图标区；确认已安装新版，检查后台任务和 `broker.log` |
| 重连或解锁后没有提醒 | 只有存在其他桌面时才提醒；确认菜单中“登录或解锁时提醒我”已勾选，并检查 Windows 通知设置 |
| 看不到其他桌面 | 当前列表只提供同一账户的其他 Windows 会话；核对账户、会话状态与实际安装版本 |
| 看不到任务视图中的多个虚拟桌面 | 虚拟桌面归属同一 Windows 会话，列表按会话显示 |
| 同账户连接后直接恢复了旧桌面 | Windows 已完成恢复；可从托盘菜单进入其他已有桌面 |
| 没看到 UAC 提示 | 查看启动安装程序的桌面；RDP 安装应从远程桌面内启动 |
| 进入时目标状态发生变化 | 重新打开托盘菜单，选择仍然存在的会话 |
| 绑定的设备没有进入绑定桌面 | 确认“启用多桌面”已勾选，设备名与“设备绑定”中的一致，并查看 `broker.log` 中的记录 |
| 关闭多桌面后仍新建了桌面 | 设置只影响之后的新连接；如仍不生效，检查组策略是否覆盖了单会话设置 |
| 切换失败并显示错误码 | 保留错误码、系统版本、会话状态与相关日志，用于复现和排查 |

## 开发与扩展

### 工程结构

| 路径 | 职责 |
|---|---|
| `rdpWrapper/`、`rdpWrapper.sln` | 上游 RDP Wrapper 的 C# 工程 |
| `session-picker/SessionPicker.ps1` | 托盘程序入口与事件循环 |
| `session-picker/PickerUI.ps1` | 托盘图标、右键菜单、进入提示窗口与切换操作 |
| `session-picker/Native.cs` | WTS 会话查询、连接与注销接口 |
| `session-picker/Watcher.cs` | 本地连接、RDP 连接与解锁通知；托盘菜单配色 |
| `session-picker/Broker.ps1`、`BrokerNative.cs` | 后台进程补齐、用户会话内启动、多桌面设置与设备绑定执行 |
| `session-picker/SharedConfig.ps1` | 托盘程序与后台任务共用的多桌面与设备绑定配置 |
| `session-picker/Install.ps1`、`Uninstall.ps1` | 安装、设置保存与卸载恢复 |
| `session-picker/tests/` | 事件与界面检查 |

### 验证命令

在仓库根目录运行。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File session-picker\tests\Test-Events.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File session-picker\tests\Test-UI.ps1
```

事件检查覆盖本地连接、远程连接、解锁和锁屏的处理。界面检查使用演示数据验证托盘菜单条目、空列表提示、进入提示窗口的两个选项与取消行为。实际网络连接与接管需要在目标设备上验证。

上游 C# 工程通过 `make.bat` 调用 Visual Studio MSBuild 进行还原与构建，相关工具功能与使用说明见上游项目。

## 反馈与贡献

欢迎通过本仓库的 Pull Request 改进代码或文档。复现说明应包含系统与客户端版本、选择器版本、最短操作步骤、预期结果和实际结果。提供日志或截图前，请移除账户、设备和网络信息。[提交 Pull Request](https://github.com/XYoung1201/rdpWrapper/pulls)

RDP Wrapper 核心与 TermWrap 相关问题可结合上游说明排查。[上游问题列表](https://github.com/sergiye/rdpWrapper/issues)

## 资料与资源

- [选择器详细文档](session-picker/README.md)
- [选择器发行版与安装包](https://github.com/XYoung1201/rdpWrapper/releases)
- [上游 sergiye/rdpWrapper](https://github.com/sergiye/rdpWrapper)
- [TermWrap](https://github.com/llccd/TermWrap)
- [RDPWrapOffsetFinder](https://github.com/llccd/RDPWrapOffsetFinder)
- [Windows WTS 会话事件](https://learn.microsoft.com/en-us/windows/win32/termserv/wm-wtssession-change)
