English | [简体中文](README_zh.md)
<!-- Title-->
<p align="center">
  <img src="imgs/flutter_server_box.png">
</p>

<!-- Badges-->
<p align="center">
  <a href="https://apps.apple.com/app/id1586449703">
    <img style="height: 37px" src="imgs/appstore.svg">
  </a>
  <a href="https://count.ly/f/badge" rel="nofollow">
    <img style="height: 37px" src="https://count.ly/badges/dark.svg">
  </a>
  <a href="https://github.com/lollipopkit/flutter_server_box/releases/latest">
    <img style="height: 37px" src="imgs/dl-android.svg">
  </a>
</p>

<p align="center" style="font-weight: bold">Due to Chinese government policy and the <a href="https://github.com/lollipopkit/flutter_server_box/discussions/180">BEIAN</a> issue. ServerBox is now free. Please download it from other regions.</p>

<p align="center">
A Flutter project which provide charts to display <a href="../../issues/43">Linux</a> server status and tools to manage server.
<br>
Especially thanks to <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>.
</p>


## 🔖 Feature
- [x] Functions
  - [x] `SSH` Terminal, `SFTP`, `Docker & Pkg & Process`, Status chart, Code editor...
  - [x] Platform specific: `Bio auth`、`Msg push`、`Home widget`、`watchOS App`...
- [x] Localization ( English, 简体中文, Deutsch, 繁體中文, Indonesian. [l10n guide](#l10n-guide) )
- [x] Platform support: `iOS / Android / macOS / Windows / Linux`


## 📩 Push
In order to push  server status to your portable device without opening ServerBox app (Such as **message push** and **home widget**), you need to install [ServerBoxMonitor](https://github.com/lollipopkit/server_box_monitor) on your servers, and config it correctly. See [Wiki](https://github.com/lollipopkit/server_box_monitor/wiki) for more details.


## 🆘 Help
If you have any question or feature request, please open a [discussion](https://github.com/lollipopkit/flutter_server_box/discussions/new/choose).  
If ServerBox app has any bug, please open an [issue](https://github.com/lollipopkit/flutter_server_box/issues/new).


## 🏙️ ScreenShots
<table>
  <tr>
    <td>
	    <img width="200px" src="imgs/server.png">
    </td>
    <td>
	    <img width="200px" src="imgs/detail.png">
    </td>
    <td>
	    <img width="200px" src="imgs/sftp.png">
    </td>
  </tr>
</table>
<table>
  <tr>
    <td>
	    <img width="200px" src="imgs/editor.png">
    </td>
    <td>
	    <img width="200px" src="imgs/ssh.png">
    </td>
    <td>
	    <img width="200px" src="imgs/docker.png">
    </td>
  </tr>
</table>


## 🖥 Platform
Status|Platform          
--- | ---
Full Support| Android / iOS / macOS
Not tested| Windows / Linux


## 🧱 Contribution
**Any positive contribution is welcome**.

### l10n guide
1. Fork this repo and clone forked repo to your local machine.
2. Create `arb` file in `lib/l10n/` directory
   - File name should be `intl_XX.arb`, where `XX` is the language code. Such as `intl_en.arb` for English and `intl_zh.arb` for Chinese.
3. Add content to the file. You can refer to `intl_en.arb` and `intl_zh.arb` for the format.
4. Run `flutter gen-l10n` to generate files.
5. Pull commit to your forked repo.
6. Request a pull request on my repo.


## 📝 License
`GPL v3 lollipopkit 2023`
