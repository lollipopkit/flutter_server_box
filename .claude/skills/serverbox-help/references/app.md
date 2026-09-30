# Using the app

When a setting's place is not below, the settings page has a search field at
the top: tell the user what to search for rather than guessing a path.

## Getting it

| Platform | Where |
|---|---|
| iOS | App Store, or the unsigned `.ipa` from GitHub Releases to sign yourself |
| macOS | App Store, `brew install --cask server-box`, or the `.dmg` from GitHub Releases |
| Android | GitHub Releases, F-Droid (`tech.lolli.toolbox`) |
| Linux | AppImage from GitHub Releases |
| Windows | zip from GitHub Releases |
| watchOS | Comes with the iOS app |

Releases: <https://github.com/lollipopkit/flutter_server_box/releases>.
<https://serverbox.lollipopkit.com/docs/installation/> has the rest.

## Adding a server

**+** on the server list. **SSH**: name, host, port (22), user, and a password
or a private key (private keys are managed under **Settings → Private keys**).
**Monitor HTTP**: see `monitor.md`. Both can be on for one server. A jump
server or a `ProxyCommand` is set in the same form; test that route on its own
when the connection fails. Many servers at once: bulk import,
<https://serverbox.lollipopkit.com/docs/advanced/bulk-import/>.

## The Agent (you)

Under **Settings → App → AI**:

- **Providers** — the model services and their API keys (kept in the system
  keychain), custom OpenAI-compatible, Anthropic or Google endpoints, and the
  default model. A custom provider at plain `http://` on another machine is
  refused unless **Allow plain HTTP** is on for it.
- **Tools** — which tool groups you may use, the tools allowed without asking,
  and **MCP servers**. An MCP server is edited on its own page: headers (for a
  key or token) and, for one using OAuth, **Log in**.
- **Skills** — instructions for particular tasks, installed from `owner/repo`,
  a GitHub or GitLab link, a site, a folder or a `.zip`, or a pasted
  `npx skills add …` command; **Check for updates** fetches them again.
- **Auto-run read-only commands** — off by default; when on, a server command
  that both you and the app judge read-only runs without asking, at most three
  times per message. Never for commands on this device.
- **Run commands on this device** — off by default; every such command is
  asked about.

A terminal's own chat (the AI button in a terminal) sees only that terminal:
it can read the screen and run commands in that session. The Agent tab
reaches every server. More: <https://serverbox.lollipopkit.com/docs/advanced/agent/>.

## Other things people ask about

- **Unlocking with Face ID, Touch ID or a fingerprint**, and on Android
  **Run in background** (keeps connections alive; also allow notifications and
  exempt the app from battery optimisation): **Settings → App → General**.
- **Backups**: the Backup page — a file, WebDAV, iCloud or a GitHub Gist. A
  backup has the servers, snippets, keys and settings; the Agent's providers,
  chats, skills and MCP secrets are not in it.
- **Terminal keys** (Esc, Tab, Ctrl, arrows): the bar above the keyboard in a
  terminal; **IME** shows or hides the system keyboard. A third-party keyboard
  that sends odd input: try the system one.
- **A shell on this phone or computer** without a server:
  <https://serverbox.lollipopkit.com/docs/advanced/local-terminal/>.
- **Extra status commands** shown on a server's page:
  <https://serverbox.lollipopkit.com/docs/advanced/custom-commands/>.

## Common problems

| Symptom | Try |
|---|---|
| SSH will not connect | Is sshd running? Does `ssh user@host -p port` work from elsewhere? Firewall, then the user and key or password. With a jump server, test that hop alone |
| Disconnects when idle or in the background | `ClientAliveInterval 60` and `ClientAliveCountMax 3` in the server's `sshd_config`; on Android, **Run in background**, notifications allowed, no battery optimisation (MIUI/HyperOS: **No restrictions**); iOS suspends background connections, and the app reconnects on return |
| A server page is missing a feature | See "The button is missing" in the skill, and `monitor.md` |
| Widgets or the watch do not update | They need the Monitor agent, reachable from the phone's network; <https://serverbox.lollipopkit.com/docs/advanced/widgets/> |
| The app will not start after editing hidden settings | Restore a backup; clearing the app's data or reinstalling loses what was not backed up. <https://serverbox.lollipopkit.com/docs/advanced/json-settings/> |
| Slow, or heavy on the battery | A longer status refresh interval; servers or status cards not needed turned off; fewer terminals and transfers at once; background running off when not needed. <https://serverbox.lollipopkit.com/docs/advanced/troubleshooting/> |
