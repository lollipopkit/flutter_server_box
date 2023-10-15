English | [简体中文](README_zh.md)

<!-- Title-->
<p align="center">
  <img src="https://socialify.git.ci/lollipopkit/flutter_server_box/image?description=1&font=Raleway&logo=https%3A%2F%2Fgithub.com%2Flollipopkit%2Fflutter_server_box%2Fblob%2Fmain%2Fassets%2Fapp_icon.png%3Fraw%3Dtrue&name=1&owner=1&pattern=Solid&theme=Auto" alt="flutter_server_box" width="640" height="320" />
</p>

<!-- Badges-->
<p align="center">
  <img alt="lang" src="https://img.shields.io/badge/lang-dart-pink">
  <img alt="countly" src="https://img.shields.io/badge/analysis-countly-pink">
  <img alt="license" src="https://img.shields.io/badge/license-GPLv3-pink">
</p>

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


## ⬇️ Download
Platform | Support | Sign
--- | --- | ---
[iOS](https://apps.apple.com/app/id1586449703) / [Android](https://res.lolli.tech/serverbox/latest.apk) / [macOS](https://apps.apple.com/app/id1586449703) | Full | My own certificate
[Linux](https://res.lolli.tech/serverbox/latest.AppImage) / [Windows](https://res.lolli.tech/serverbox/latest.7z) | Not tested | Flutter default certificate

- Due to Chinese government policy and the [BEIAN](https://github.com/lollipopkit/flutter_server_box/discussions/180) issue. iOS app is now free. Please download it from other regions of AppStore.
- Security:
  - To prevent injection attacks and etc., please don't download from untrusted sources.
  - Since `Linux / Windows` is signed with flutter default certificate, it is recommended to **build it yourself**.


## 🆘 Help
- In order to push  server status to your portable device without opening ServerBox app (Such as **message push** and **home widget**), you need to install [ServerBoxMonitor](https://github.com/lollipopkit/server_box_monitor) on your servers, and config it correctly. See [wiki](https://github.com/lollipopkit/server_box_monitor/wiki) for more details.
- **Common issues** can be found in [app wiki](https://github.com/lollipopkit/flutter_server_box/wiki).
- If you have **any question or feature request**, please open a [discussion](https://github.com/lollipopkit/flutter_server_box/discussions/new/choose).  
-  If ServerBox app has **any bug**, please open an [issue](https://github.com/lollipopkit/flutter_server_box/issues/new).


## 🏙️ ScreenShots
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
