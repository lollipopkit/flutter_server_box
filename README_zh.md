简体中文 | [English](README.md)
<!-- Title-->
![flutter_server_box](https://socialify.git.ci/lollipopkit/flutter_server_box/image?description=1&descriptionEditable=%E6%9C%8D%E5%8A%A1%E5%99%A8%E7%8A%B6%E6%80%81%20%26%20%E5%B7%A5%E5%85%B7%E7%AE%B1%E5%BA%94%E7%94%A8%EF%BC%8C%E4%BD%BF%E7%94%A8%20Flutter&font=Jost&forks=1&issues=1&logo=https%3A%2F%2Fraw.githubusercontent.com%2Flollipopkit%2Fflutter_server_box%2Fmain%2Fassets%2Fapp_icon.png&name=1&owner=1&pattern=Plus&pulls=1&stargazers=1&theme=Auto)

<!-- Badges-->
<p align="center">
  <a href="https://apps.apple.com/app/id1586449703">
    <img style="height: 37px" src="screenshots/appstore.svg">
  </a>
  <a href="https://count.ly/f/badge" rel="nofollow">
    <img style="height: 37px" src="https://count.ly/badges/light.svg">
  </a>
  <a href="https://github.com/lollipopkit/flutter_server_box/releases/latest">
    <img style="height: 37px" src="screenshots/dl-android.svg">
  </a>
</p>

<p align="center">
使用Flutter开发的服务器工具箱，提供服务器状态图表和管理工具。
<br>
特别感谢 <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>.
</p>


## 🔖 特点
- [x] 功能
  - [x] `SSH` 终端, `SFTP`
  - [x] `Docker & 包` 管理器
  - [x] 状态图表
  - [x] `Ping` 和 更多
- [x] 本地化 ( 英语, 中文 )
  - 欢迎贡献 :)，[怎么贡献?](#l10n)
- [x] 桌面端支持


## 📩 推送
你需要在你的服务器上安装 [ServerBoxMonitor](https://github.com/lollipopkit/server_box_monitor)。    
并且配置 `iOS / Webhook / Server酱` 推送服务，这样，你可以在不使用 ServerBox app 时获取服务器状态。


## 🆘 帮助
如果你有任何问题或者功能请求，请在 [讨论](https://github.com/lollipopkit/flutter_server_box/discussions/new/choose) 中交流。  
如果 ServerBox app 有任何 bug，请在 [问题](https://github.com/lollipopkit/flutter_server_box/issues/new) 中反馈。


## 📱 截屏
<table>
  <tr>
    <td>
	    <img width="200px" src="screenshots/server.jpg">
    </td>
    <td>
	    <img width="200px" src="screenshots/detail.jpg">
    </td>
    <td>
	    <img width="200px" src="screenshots/ssh.jpg">
    </td>
    <td>
	    <img width="200px" src="screenshots/apt.png">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="200px" src="screenshots/ping.png">
    </td>
    <td>
	    <img width="200px" src="screenshots/sftp.jpg">
    </td>
    <td>
	    <img width="200px" src="screenshots/docker.jpg">
    </td>
    <td>
	    <img width="200px" src="screenshots/convert.png">
    </td>
  </tr>
</table>


## 🖥 平台
状态|平台         
--- | ---
完整支持 | Android / iOS / macOS
可能支持，未测试 | Windows / Linux


## l10n
1. Fork本项目，并Clone你Fork的项目至你的电脑
2. 在 `lib/l10n/` 文件夹内创建 `.arb` 本地化文件
   - 文件名应该类似 `intl_XX.arb`,  `XX` 是语言标识码。 例如 `intl_en.arb` 是给英语的， `intl_zh.arb` 是给中文的
3. 向 `.arb` 本地化文件添加内容。 你可以查看 `intl_en.arb` 和 `intl_zh.arb` 的内容，并理解其含义，来创建新的本地化文件
4. 运行 `flutter gen-l10n` 来生成所需文件
5. Commit 变更到你的 Fork 的 Repo
6. 在我的项目中发起 Pull Request.


## 📝 License
`GPL v3. lollipopkit 2023`
