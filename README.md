English | [简体中文](README_zh.md)

<h2 align="center">Flutter Server Box</h2>

<div align="center">
  <a href="https://cdn.lollipopkit.com/donate"><img alt="donate" src="https://img.shields.io/badge/donate-me-pink"></a>
  <img alt="lang" src="https://img.shields.io/badge/lang-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/license-AGPLv3-yellow">
  <a href="https://deepwiki.com/lollipopkit/flutter_server_box"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</div>

<p align="center">
A Flutter project which provides charts to display Linux, Unix and Windows server status and tools to manage servers.
<br>
Read the <a href="https://serverbox.lolli.tech/docs/">documentation site</a> for user guides, architecture notes, and development instructions.
</p>

## Acknowledgements

Special thanks to <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>.
Thanks to my partner for their emotional and financial support.
Thanks to <a href="https://openai.com">OpenAI</a> for providing six months of ChatGPT Pro 20x subscription! Not an advertisement, just appreciation for their contribution to FOSS.

## Screenshots

<!-- Folded by platform, and every image is `loading="lazy"`: this is 31 shots
     across three device classes, and unfolded it is several megabytes before a
     reader has decided they want to look. Add `open` to a `<details>` to have
     that group start expanded. -->

<details>
<summary><b>iPhone</b> — 11 screenshots</summary>
<br>
<table>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/home.jpg" alt="Server list"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/server-details.jpg" alt="Server details"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/terminal.jpg" alt="Terminal"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/files.jpg" alt="Files"></td>
  </tr>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/container.jpg" alt="Containers"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/process.jpg" alt="Processes"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/services.jpg" alt="Services"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/snippets.jpg" alt="Snippets"></td>
  </tr>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/agent.jpg" alt="Agent"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/bench.jpg" alt="Benchmark"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/settings.jpg" alt="Settings"></td>
    <td></td>
  </tr>
</table>
</details>

<details>
<summary><b>iPad</b> — 10 screenshots</summary>
<br>
<table>
  <tr>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/home.jpg" alt="Server list"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/server-details.jpg" alt="Server details"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/terminal.jpg" alt="Terminal"></td>
  </tr>
  <tr>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/files.jpg" alt="Files"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/container.jpg" alt="Containers"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/process.jpg" alt="Processes"></td>
  </tr>
  <tr>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/services.jpg" alt="Services"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/globe.jpg" alt="Globe"></td>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/agent.jpg" alt="Agent"></td>
  </tr>
  <tr>
    <td><img width="280px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/ipad/settings.jpg" alt="Settings"></td>
    <td></td>
    <td></td>
  </tr>
</table>
</details>

<details>
<summary><b>macOS</b> — 10 screenshots</summary>
<br>
<table>
  <tr>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/home.jpg" alt="Server list"></td>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/server-details.jpg" alt="Server details"></td>
  </tr>
  <tr>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/terminal.jpg" alt="Terminal"></td>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/files.jpg" alt="Files"></td>
  </tr>
  <tr>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/container.jpg" alt="Containers"></td>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/process.jpg" alt="Processes"></td>
  </tr>
  <tr>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/services.jpg" alt="Services"></td>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/globe.jpg" alt="Globe"></td>
  </tr>
  <tr>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/agent.jpg" alt="Agent"></td>
    <td><img width="380px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/mac/settings.jpg" alt="Settings"></td>
  </tr>
</table>
</details>

## Installation

| Platform | Download |
| --- | --- |
| iOS | [AppStore](https://apps.apple.com/app/id1586449703) / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) (`_NoSign.ipa`, unsigned, you need to sign it yourself) |
| macOS | [App Store](https://apps.apple.com/app/id1586449703) (Apple silicon only) / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) (architecture-specific `.dmg`) / `brew install --cask server-box` |
| Android | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) / [CDN](https://cdn.lollipopkit.com/serverbox/pkg/?sort=time&order=desc&layout=grid) / [F-Droid](https://f-droid.org/packages/tech.lolli.toolbox) / [OpenAPK](https://www.openapk.net/serverbox/tech.lolli.toolbox/) |
| Linux / Windows | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) / [CDN](https://cdn.lollipopkit.com/serverbox/pkg/?sort=time&order=desc&layout=grid) |

Download packages only from sources you trust.

## Features

- Status charts for CPU, sensors, GPU, and other metrics; an SSH terminal; SFTP; [RDP and VNC through SSH](https://serverbox.lolli.tech/docs/advanced/remote-desktop/); Docker, process, and service management; and S.M.A.R.T.
- Platform features include biometric authentication, push notifications, home-screen widgets, a watchOS app, and system color themes.
- 16 languages. The current list is in `lib/l10n/`; its git history records the translators.

## Help

<div align="center">
  <a href="https://qm.qq.com/q/daCGa7eShG"><img alt="qq" src="https://img.shields.io/badge/QQ-Group-pink"></a>
  <a href="https://t.me/lpktg"><img alt="donate" src="https://img.shields.io/badge/Telegram-lpktg-green"></a>
  <a href="https://discord.gg/SsVNbRhK7w"><img alt="discord" src="https://img.shields.io/badge/Discord-lpkt-purple"></a>
</div>

- [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) is an agent you install on your servers. It is required for features that need to work while the app is closed — **push notifications**, **home-screen widgets**, and the **watch app**. It also offers another way to add a server: the app can connect to it over HTTP instead of SSH, which suits hosts whose SSH port you prefer not to expose, and gives charts historical data from before the app's first connection. Monitor also serves its own web panel. See its [Chinese documentation](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/README_zh.md) for setup and details on what each remote-access switch allows.
- **Common issues** are listed in the [app wiki](https://github.com/lollipopkit/flutter_server_box/wiki/主页).
- **Agent onboarding:** This repository includes a skill for installing and using the app, deploying and configuring Monitor agent, setting up the Flutter + Rust + Node environment, and answering common server-management questions. Add it to your agent with

  ```sh
  npx skills add lollipopkit/flutter_server_box
  ```

  The source is [`.claude/skills/serverbox-onboarding`](.claude/skills/serverbox-onboarding), so you can read what it will tell your agent before installing it.

Before opening an issue, please:

1. Include the log (click the top-right corner of the home page) and use the bug report template.
2. Confirm that the issue is caused by ServerBox.
3. Concrete, constructive feedback is welcome. Subjective requests, such as preferring another UI, may not be accepted.

## Contributions

Any positive contribution is welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the development setup, the commit convention, the checks to run, and how translations work.

Contributors sign the [CLA](CLA.md) ([Chinese version](CLA_zh.md)) once by leaving a comment on their first pull request. It grants the right to ship your work in App Store builds alongside the AGPLv3 source. You retain the copyright to your work.

If I forgot to add your name to the contributors list, please add a comment in the issue or PR you opened to let me know, I will add it as soon as possible.

## License

`AGPL v3 lollipopkit & all contributors`
