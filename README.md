<!-- Title-->
<p align="center">
  <h1 align="center">Server Box</h1>
</p>

<!-- Badges-->
<p align="center">
  <a href="https://apps.apple.com/app/id1586449703">
    <img style="height: 37px" src="screenshots/appstore.svg">
  </a>
  <a href="https://github.com/lollipopkit/flutter_server_box/releases/latest">
    <img style="height: 37px" src="screenshots/dl-android.svg">
  </a>
</p>

<p align="center">
  <a href="https://count.ly/f/badge" rel="nofollow">
    <img style="height: 37px" src="https://count.ly/badges/light.svg">
  </a>
</p>

<p align="center">
A Flutter project which provide charts to display server status and tools to manage server.
<br>
Especially thanks to <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>.
</p>


## 🔖 Feature
- [x] Functions
  - [x] `SSH` Terminal, `SFTP`
  - [x] `Docker & Pkg` Manager
  - [x] Status charts
  - [x] etc.
- [x] i18n (English, Chinese)
  - **Welcome contribution** :)
  - [How to contribute?](#i18n-guide)
- [x] Desktop support

## 📱 ScreenShots
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

## 🖥 Platform
Status|Platform          
--- | ---
Full Support|Android/iOS
Support, but not tested|macOS/Windows/Linux

## i18n guide
1. Fork this repo and clone it to your local machine.
2. Create `arb` file in `lib/l10n/` directory
   - File name should be `intl_XX.arb`, where `XX` is the language code. Such as `intl_en.arb` for English and `intl_zh.arb` for Chinese.
3. Add content to the file. You can refer to `intl_en.arb` and `intl_zh.arb` for the format.
4. Pull commit to your forked repo.
5. Request a pull request on my repo.

## 📝 License
`GPL v3. lollipopkit 2023`
