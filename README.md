English | [简体中文](README_zh.md)

<h2 align="center">Flutter Server Box</h2>

<div align="center">
  <a href="https://lollipopkit.com/donate"><img alt="donate" src="https://img.shields.io/badge/donate-me-pink"></a>
  <img alt="lang" src="https://img.shields.io/badge/lang-dart-cyan">
  <img alt="license" src="https://img.shields.io/badge/license-AGPLv3-yellow">
  <a href="https://deepwiki.com/lollipopkit/flutter_server_box"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"></a>
</div>

<p align="center">
A Flutter+Rust project which provides charts to display Linux, Unix and Windows server status and tools to manage servers.
<br>
Read the <a href="https://serverbox.lolli.tech/docs/">documentation site</a> for user guides, architecture notes, and development instructions.
</p>

## Acknowledgements

Special thanks to <a href="https://github.com/TerminalStudio/dartssh2">dartssh2</a> & <a href="https://github.com/TerminalStudio/xterm.dart">xterm.dart</a>.
Thanks to my partner for their emotional and financial support.
Thanks to <a href="https://openai.com">OpenAI</a> for providing six months of ChatGPT Pro 20x subscription.

## Screenshots

<table>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/home.jpg" alt="Server list"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/server-details.jpg" alt="Server details"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/terminal.jpg" alt="Terminal"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/files.jpg" alt="Files"></td>
  </tr>
</table>

<details>
<summary>8 more screenshots</summary>
<br>
<table>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/container.jpg" alt="Containers"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/process.jpg" alt="Processes"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/services.jpg" alt="Services"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/users.jpg" alt="Users"></td>
  </tr>
  <tr>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/agent.jpg" alt="Agent"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/bench.jpg" alt="Benchmark"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/virt.jpg" alt="Virtualization"></td>
    <td><img width="180px" loading="lazy" src="https://cdn.lollipopkit.com/serverbox/screenshot/iphone/themes.jpg" alt="Theme store"></td>
  </tr>
</table>
</details>


## Installation

| Platform | Download |
| --- | --- |
| iOS | [AppStore](https://apps.apple.com/app/id1586449703) / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) (`_NoSign.ipa`, unsigned, you need to sign it yourself) |
| macOS | [App Store](https://apps.apple.com/app/id1586449703) (Apple silicon only) / [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) (architecture-specific `.dmg`) / `brew install --cask server-box` |
| Android | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) / [F-Droid](https://f-droid.org/packages/tech.lolli.toolbox) / [OpenAPK](https://www.openapk.net/serverbox/tech.lolli.toolbox/) |
| Linux / Windows | [GitHub](https://github.com/lollipopkit/flutter_server_box/releases) |

Download packages only from sources you trust.

## Features

**Connecting**

- Connect directly over SSH, through a jump host or with a `ProxyCommand`; You can also connect over HTTP through the [Monitor agent](https://serverbox.lollipopkit.com/docs/advanced/monitor-agent/) when you do not want to expose a host's SSH port. A server can use both methods, with automatic fallback if one is unavailable.
- Open a shell on this device or install a Linux userland ([local terminal](https://serverbox.lollipopkit.com/docs/advanced/local-terminal/)) on supported platforms.

**Watching**

- Live and historical charts for CPU, memory, swap, disks, disk I/O and network, plus sensors, GPUs (NVIDIA, AMD), batteries and disk S.M.A.R.T.
- See all servers at a glance, filter them by tag or view them on a [globe](https://serverbox.lollipopkit.com/docs/advanced/globe/).
- Push alerts, [home-screen widgets](https://serverbox.lollipopkit.com/docs/advanced/widgets/) and a watchOS app. The Monitor agent keeps these features working while the app is closed.

**Working on a server**

- A full terminal with virtual keys on phones, plus a [workspace](https://serverbox.lollipopkit.com/docs/advanced/workspace/) with split panes that can send input to several terminals at once.
- Browse, upload, download and edit files over SFTP or SCP. Markdown files open in a rendered preview.
- [RDP and VNC](https://serverbox.lollipopkit.com/docs/advanced/remote-desktop/), to the server itself or to a desktop it can reach.
- Docker and Podman, processes, systemd services, users and groups, firewall rules (ufw, firewalld), scheduled tasks, port forwards and snippets.
- Virtual machines and containers on libvirt and Proxmox VE, and a server's BMC over Redfish ([BMC](https://serverbox.lollipopkit.com/docs/advanced/bmc/)).
- Benchmarks (YABS) and iperf.
- An [AI Agent](https://serverbox.lollipopkit.com/docs/advanced/agent/) that works with your servers and the model providers, MCP servers and skills you choose.

**Making it yours**

- Install [themes and icon packs](https://serverbox.lollipopkit.com/docs/advanced/theme-packages/) from the built-in store, or make your own.
- Biometric app lock, and backups to iCloud, WebDAV, GitHub Gist or a Monitor agent, encrypted with a password you choose.
- iOS, Android, macOS, Linux and Windows, in 17 languages.

## Help

<div align="center">
  <a href="https://qm.qq.com/q/daCGa7eShG"><img alt="qq" src="https://img.shields.io/badge/QQ-Group-pink"></a>
  <a href="https://t.me/lpktg"><img alt="donate" src="https://img.shields.io/badge/Telegram-lpktg-green"></a>
  <a href="https://discord.gg/SsVNbRhK7w"><img alt="discord" src="https://img.shields.io/badge/Discord-lpkt-purple"></a>
</div>

- [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) is an agent you install on your servers. It is required for features that need to work while the app is closed — **push notifications**, **home-screen widgets**, and the **watch app**. It also offers another way to add a server: the app can connect to it over HTTP instead of SSH, which suits hosts whose SSH port you prefer not to expose, and gives charts historical data from before the app's first connection.  
- **Agent skills:** This repository includes three skills for AI agents. Add them with

  ```sh
  npx skills add lollipopkit/flutter_server_box
  ```

  which lists them and lets you pick, or add one with `--skill <name>`:

  - [`serverbox-help`](.claude/skills/serverbox-help): using the app and deploying and configuring Monitor agent — adding servers, why a feature is missing for a server, permissions, alerts, widgets, backups. The app's own Agent ships with it.
  - [`serverbox-onboarding`](.claude/skills/serverbox-onboarding): working on the code — setting up the Flutter + Rust + Node environment, building and testing, and how the project works.
  - [`serverbox-theme`](.claude/skills/serverbox-theme): making a theme package (`.fsbt`), validating it and publishing it to the theme store.

  Their source is in this repository, so you can read what they will tell your agent before installing them.

Before opening an issue, please:

1. Use the bug report template.
2. Confirm that the issue is caused by ServerBox.
3. Concrete, constructive feedback is welcome. Subjective requests, such as preferring another UI, may not be accepted.

## Contributions

[CONTRIBUTING.md](CONTRIBUTING.md) covers the development setup, the commit convention, the checks to run, and how translations work.

Contributors sign the [CLA](CLA.md) once by leaving a comment on their first pull request. It grants the right to ship your work in App Store builds alongside the AGPLv3 source. You retain the copyright to your work.

If I forgot to add your name to the contributors list, please add a comment in the issue or PR you opened to let me know, I will add it as soon as possible.

## License

`AGPL v3 lollipopkit & all contributors`
