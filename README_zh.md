简体中文 | [English](README.md)

<h2 align="center">Flutter Server Box</h2>

<p align="center">
  <img alt="lang" src="https://img.shields.io/badge/lang-dart-pink">
  <img alt="countly" src="https://img.shields.io/badge/analysis-countly-pink">
  <img alt="license" src="https://img.shields.io/badge/license-GPLv3-pink">
</p>

<p align="center">
使用 Flutter 开发的 <a href="../../issues/43">Linux</a> 服务器工具箱，提供服务器状态图表和管理工具。
<br>
特别感谢 <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>。
</p>


## 🔖 特点
- [x] 功能
  - [x] `SSH` 终端, `SFTP`, `Docker & 包 & 进程` 管理器, 状态图表, 代码编辑器...
  - [x] 特殊支持：`生物认证`、`推送`、`桌面小部件`、`watchOS App`、`跟随系统颜色`...
- [x] 本地化 ( English, 简体中文, Deutsch, 繁體中文, Indonesian, Français )
- [x] 全平台支持（除 `Web`）


## 🏙️ 截屏
<table>
  <tr>
    <td>
	    <img width="277px" src="imgs/server.png">
    </td>
    <td>
	    <img width="277px" src="imgs/detail.png">
    </td>
    <td>
	    <img width="277px" src="imgs/sftp.png">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="277px" src="imgs/editor.png">
    </td>
    <td>
	    <img width="277px" src="imgs/ssh.png">
    </td>
    <td>
	    <img width="277px" src="imgs/docker.png">
    </td>
  </tr>
</table>


## ⬇️ 下载
平台 | 支持 | 签名
:-: | :-: | :-:
[iOS](https://apps.apple.com/app/id1586449703) / [Android](https://res.lolli.tech/serverbox/latest.apk) / [macOS](https://apps.apple.com/app/id1586449703) | 完整 | 个人可信签名
[Linux](https://res.lolli.tech/serverbox/latest.AppImage) / [Windows](https://res.lolli.tech/serverbox/latest.win.zip) | 未测试 | Flutter 默认签名

- 由于中国政策原因，且**目前**无法完成[备案](https://github.com/lollipopkit/flutter_server_box/discussions/180)。iOS 端现已转为免费，请移步 AppStore 其他区下载。
- 关于安全：
  - 为了防止注入攻击等因素，请勿从不可信来源下载。
  - 由于 `Linux / Windows` 使用了默认签名，因此建议[自行构建](https://github.com/lollipopkit/flutter_server_box/wiki/%E4%B8%BB%E9%A1%B5#%E8%87%AA%E7%BC%96%E8%AF%91)。


## 🆘 帮助

- 吹水、参与开发、了解如何使用，QQ群 **762870488**
- 为了可以在不使用 ServerBox app 时获取服务器状态（例如：桌面小部件、推送服务），你需要在你的服务器上安装 [ServerBoxMonitor](https://github.com/lollipopkit/server_box_monitor)，并且正确配置，详情可见 [wiki](https://github.com/lollipopkit/server_box_monitor/wiki/%E4%B8%BB%E9%A1%B5)。
- **常见问题**可以在 [app wiki](https://github.com/lollipopkit/flutter_server_box/wiki/主页) 查看。

反馈前须知：
1. 反馈问题请附带 log（点击首页右上角），并以 bug 模版提交。
2. 反馈问题前请检查是否是 serverbox 的问题。
3. 欢迎所有有效、正面的反馈，主观（比如你觉得其他UI更好看）的反馈不一定会接受

确认了解上述内容后：
- 如果你有**任何问题或者功能请求**，请在 [讨论](https://github.com/lollipopkit/flutter_server_box/discussions/new/choose) 中交流。
- 如果 ServerBox app 有**任何 bug**，请在 [问题](https://github.com/lollipopkit/flutter_server_box/issues/new) 中反馈。


## 🧱 贡献
- 任何正面的贡献都欢迎。
- [本地化翻译指南](https://blog.lolli.tech/faq/) 可在我的博客中找到。


## 💡 我的其它 Apps
- [GPT Box](https://github.com/lollipopkit/flutter_gpt_box) - 支持 OpenAI API 的 第三方全平台客户端。
- [2FA Box](https://github.com/lollipopkit/flutter_2fa) - 开源的 2FA 应用。
- [更多](https://github.com/lollipopkit) - 工具 & etc.


## 📝 协议
`GPL v3 lollipopkit`
