# Installing and using the app

For someone who wants to run ServerBox, not build it. Deploying the agent is
`monitor-deploy.md`; building from source is `dev-setup.md`.

The user documentation is `docs/src/content/docs/` (`installation.mdx`,
`quick-start.mdx`, `advanced/*`), published as the project's docs site, with a
`zh/` mirror of everything.

## Where to download

| Platform | Sources |
|---|---|
| iOS | App Store; or the unsigned `_NoSign.ipa` from GitHub Releases, which you sign yourself |
| macOS | App Store, `brew install --cask server-box`, or the `.dmg` from GitHub Releases |
| Android | GitHub Releases, the CDN mirror, F-Droid (`tech.lolli.toolbox`), OpenAPK |
| Linux | AppImage from GitHub Releases or the CDN |
| Windows | zip from GitHub Releases or the CDN |
| watchOS | Part of the iOS app |

App Store link: <https://apps.apple.com/app/id1586449703>. Releases:
<https://github.com/lollipopkit/flutter_server_box/releases>.

## Adding a server

The selector at the top of the add-server form chooses the connection method,
and a server is one or the other, never both.

**SSH** — name, host, port (22), user, and a password or a private key. This is
the default and the one to use unless something makes it impossible.

**Monitor HTTP** — the agent's URL (`https://1.2.3.4:3770`), its panel user and
password, and **Monitor Ignore certificate** for a self-signed certificate. The
server then carries no SSH credentials at all. Status and charts work
immediately, with history from before the app ever connected; everything else
depends on what the agent's operator enabled.

## What each feature needs

| Feature | Over SSH | Through an agent |
|---|---|---|
| Status, charts | yes | yes, plus stored history |
| Terminal | yes | `full_access` **and** `[remote_access.terminal] enabled` **and** secure transport |
| Commands, processes, systemd, containers, snippets, power | yes | the same three |
| File browsing | SFTP | `[remote_access.fs]` with `roots` set |
| SFTP transfers, port forwarding | yes | never — add the same machine over SSH as a second server |
| Push alerts, home widgets, watch app | not available | yes |

A button that is not on screen usually means the agent said it would refuse —
the app does not show controls that would answer 403. `monitor-deploy.md`
covers which switch turns which one on.

## The guides worth knowing about

Each is a file under `docs/src/content/docs/advanced/` (and `zh/advanced/`):

| Topic | File | What it is for |
|---|---|---|
| Monitor agent | `monitor-agent.md` | The agent, end to end, from a user's side |
| Home screen widgets | `widgets.md` | iOS, Android and watchOS widgets; needs an agent |
| Agent (the assistant) | `agent.md` | Diagnosing or operating a server through an LLM, with the approval model |
| Terminal on this device | `local-terminal.md` | A local shell, and the bundled Alpine userland |
| Bulk import | `bulk-import.md` | The JSON format for adding many servers at once |
| Custom commands | `custom-commands.md` | Extra status commands, stored in `~/.config/server_box/custom_cmds` on the server |
| Custom server logo | `custom-logo.md` | URL placeholders, distribution matching |
| Hidden settings | `json-settings.md` | The raw settings editor, and how to recover from a bad edit |
| Common issues | `troubleshooting.md` | Connection, input, widget and performance problems |

## Reporting a problem

The wiki collects the recurring ones:
<https://github.com/lollipopkit/flutter_server_box/wiki>. An issue should carry
the **entire log** — the button is at the top right of the home page — and
should establish that the app is what is failing. Subjective requests may be
declined; anything with a concrete argument is open to discussion.
