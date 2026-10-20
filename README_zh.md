简体中文 | [English](README.md)

<h2 align="center">Flutter Server Box</h2>

<div align="center">
  <a href="https://lollipopkit.com/donate"><img alt="donate" src="https://img.shields.io/badge/捐赠-我-pink"></a>
  <img alt="语言" src="https://img.shields.io/badge/语言-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/证书-AGPLv3-yellow">
  <a href="https://deepwiki.com/lollipopkit/flutter_server_box"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</div>

<p align="center">
使用 Flutter+Rust 开发的 Linux, Unix, Windows 服务器工具箱，提供服务器状态图表和管理工具。
<br>
用户指南、架构说明和开发文档请参阅<a href="https://serverbox.lollipopkit.com/docs/">文档站</a>。
</p>


## 致谢

特别感谢 <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>。
感谢我的对象提供的 精神+经济 支持。
感谢 <a href="https://openai.com">OpenAI</a> 赠送的六个月 ChatGPT Pro 20x 订阅。


## 截屏

<details>
<summary><b>iPhone</b> — 12 张</summary>
<br>
<table>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/home.jpg" alt="服务器列表"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/server-details.jpg" alt="服务器详情"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/terminal.jpg" alt="终端"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/files.jpg" alt="文件"></td>
  </tr>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/container.jpg" alt="容器"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/process.jpg" alt="进程"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/services.jpg" alt="服务"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/users.jpg" alt="用户"></td>
  </tr>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/agent.jpg" alt="Agent"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/bench.jpg" alt="基准测试"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/virt.jpg" alt="虚拟化"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/themes.jpg" alt="主题商店"></td>
  </tr>
</table>
</details>


## 安装

| 平台 | 下载 |
| --- | --- |
| iOS | [AppStore](https://apps.apple.com/app/id1586449703) / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases)（`_NoSign.ipa`，未签名，需自行签名后安装） |
| macOS | [App Store](https://apps.apple.com/app/id1586449703)（仅支持 Apple silicon） / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases)（按架构分别提供 `.dmg`） / `brew install --cask server-box` |
| Android | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) / [F-Droid](https://f-droid.org/packages/tech.lolli.toolbox) / [OpenAPK](https://www.openapk.net/serverbox/tech.lolli.toolbox/) |
| Linux / Windows | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) |

请只从可信来源下载。

## 特点

**连接**

- 支持 SSH 直连、经跳板机连接或使用 `ProxyCommand`；也可通过 [Monitor agent](https://serverbox.lollipopkit.com/docs/zh/advanced/monitor-agent/) 使用 HTTP 连接，适用于不希望暴露 SSH 端口的主机。
- 在支持的平台上，可打开本机 shell，或安装 Linux 用户空间（[本机终端](https://serverbox.lollipopkit.com/docs/zh/advanced/local-terminal/)）。

**查看状态**

- CPU、内存、交换分区、磁盘、磁盘 I/O 和网络的实时与历史图表，以及传感器、GPU（NVIDIA、AMD）、电池和磁盘 S.M.A.R.T.。
- 一览所有服务器，可按标签筛选，也可在[地球视图](https://serverbox.lollipopkit.com/docs/zh/advanced/globe/)中查看。
- 推送提醒、[桌面小组件](https://serverbox.lollipopkit.com/docs/zh/advanced/widgets/)和 watchOS App；App 关闭后，Monitor agent 仍会为这些功能提供支持。

**管理服务器**

- 完整的终端；[工作区](https://serverbox.lollipopkit.com/docs/zh/advanced/workspace/)支持分屏。
- 通过 SFTP 或 SCP 浏览、上传、下载并直接编辑文件。
- [RDP 和 VNC](https://serverbox.lollipopkit.com/docs/zh/advanced/remote-desktop/)，可以连服务器本身，也可以连它能访问到的其他桌面。
- Docker 与 Podman、进程、systemd 服务、用户与用户组、防火墙规则（ufw、firewalld）、定时任务、端口转发和代码片段。
- 管理 libvirt 和 Proxmox VE 上的虚拟机与容器，通过 Redfish 管理服务器的 [BMC](https://serverbox.lollipopkit.com/docs/zh/advanced/bmc/)。
- 基准测试（YABS）和 iperf。
- [AI Agent](https://serverbox.lollipopkit.com/docs/zh/advanced/agent/) 可协助管理服务器，并使用你选择的模型提供商、MCP server 和 skill。

**个性化**

- 内置商店里的[主题和图标包](https://serverbox.lollipopkit.com/docs/zh/advanced/theme-packages/)，也可以自己制作。
- 生物识别应用锁；可将备份保存到 iCloud、WebDAV、GitHub Gist 或 Monitor agent，并使用你设置的密码加密。
- 支持 iOS、Android、macOS、Linux 和 Windows，16 种语言。

## 帮助

<div align="center">
  <a href="https://qm.qq.com/q/daCGa7eShG"><img alt="qq" src="https://img.shields.io/badge/QQ-群-pink"></a>
  <a href="https://t.me/lpktg"><img alt="donate" src="https://img.shields.io/badge/Telegram-lpktg-green"></a>
  <a href="https://discord.gg/SsVNbRhK7w"><img alt="discord" src="https://img.shields.io/badge/Discord-lpkt-purple"></a>
</div>

- [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) 是安装在你服务器上的 agent。不打开 ServerBox app 时仍需工作的功能都依赖它 —— **推送通知**、**桌面小部件** 和 **手表 app**；它同时也是添加服务器的第二种方式：app 可以经 HTTP 而不是 SSH 访问它，适用于不便暴露 SSH 端口的主机，并且图表在 app 首次连接前就已有历史数据。  
- **Agent skills：** 本仓库包含三份供 AI agent 使用的 skill。使用下面的命令添加：

  ```sh
  npx skills add lollipopkit/flutter_server_box
  ```

  - [`serverbox-help`](.claude/skills/serverbox-help)：使用 App，以及部署和配置 Monitor agent，例如添加服务器、某台服务器缺少某个功能的原因、权限、告警、小部件和备份。App 内置的 Agent 自带这份 skill。
  - [`serverbox-onboarding`](.claude/skills/serverbox-onboarding)：参与开发，包括搭建 Flutter + Rust + Node 开发环境、构建与测试，以及项目的工作原理。
  - [`serverbox-theme`](.claude/skills/serverbox-theme)：制作主题包（`.fsbt`），校验后发布到主题商店。

  它们的源文件都在本仓库中，安装前可以先读一读它们会告诉你的 agent 什么。

提交 issue 前请确认：

1. 使用 bug 报告模板提交。
2. 确认问题确实由 ServerBox 引起。
3. 欢迎具体、建设性的反馈。主观偏好，例如更喜欢其他 UI，可能不会被采纳。

## 贡献

[CONTRIBUTING.md](CONTRIBUTING.md) 说明了开发环境、commit 规范、提交前要跑的检查，以及翻译流程。

贡献者需要签署一次 [CLA](CLA_zh.md)（[英文原文](CLA.md)，以英文为准）：在你的第一个 PR 下留一条评论即可。它授予的权利使你的工作可以随 App Store 版本一起发布，同时源码保持 AGPLv3——你自己的版权仍然属于你。

如果我忘记在贡献者列表中添加你的名字，请在你打开的 issue 或 PR 中添加评论让我知道，我会尽快添加。

## 证书

`AGPL v3 lollipopkit & 所有贡献者`
