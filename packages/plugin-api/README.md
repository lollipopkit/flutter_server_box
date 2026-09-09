# @serverbox/plugin-api

Write [ServerBox](https://github.com/lollipopkit/flutter_server_box) plugins in
TypeScript or JavaScript.

A plugin is **one ES module**. It holds its own state, asks the app for the
things it cannot do itself through the global `sb`, and answers with a tree of
widgets the app draws with its own controls. It never sees a credential, a
server's address, or anything outside what its manifest asked for and the user
agreed to.

```ts
import { card, kv, btn, onTap, type Plugin, type UiOutput } from "@serverbox/plugin-api";

let count = 0;

export function open(): UiOutput {
  return { ui: view() };
}

export function onEvent(): UiOutput {
  count++;
  return { ui: view() };
}

const view = () =>
  card([kv("Taps", String(count)), onTap(btn("Again"), { m: "again" })]);
```

That runs under `bun test` against `MockHost` from `@serverbox/plugin-api/test`
— no QuickJS, no app, no build step.

## The two files

**`plugin.js`** exports what it implements and omits the rest. `open` alone is a
card; `statusCmd` plus `parse` alone is a status plugin with no interface at all.
Every export may be `async`, and the host awaits it.

| Export | When |
|---|---|
| `init(ctx)` | Once, before any surface is shown. |
| `open(surface)` | A surface is being shown; the tree it answers with is the whole of it. |
| `onEvent(msg, value)` | The user did something. `msg` is whatever the plugin attached. |
| `tick()` | The app's shared refresh interval, and only while a surface is visible. |
| `listWindow(key, from, count)` | More rows for a `list` that declared more than it carried. |
| `onServerEvent(event)` | A server connected, disconnected, or was deleted. |
| `onHook(event)` | A surface was entered. Answers nothing — send with `sb.ui.patch`. |
| `validateConfig(cfg)` | Before the settings editor saves, with the form as typed. |
| `configOptions(key)` | The choices for a `select` field the manifest could not enumerate. |
| `tool(name, args)` | A tool the AI agent may call, by the name the manifest declared. |
| `dispose()` | The instance is going away. |
| `statusCmd(ctx)` / `parse(ctx)` | A status plugin: the command to run, and its output as readings. |

**`manifest.json`** says who the plugin is, what it needs, and where it appears:

```json
{
  "id": "com.example.thing",
  "version": "1.0.0",
  "abi": 2,
  "name": "Thing",
  "description": "One sentence, shown wherever the plugin is listed.",
  "license": "MIT",
  "l10n": ["en"],
  "permissions": { "server.exec": true },
  "contributes": {
    "page": { "id": "thing", "label": "Thing", "icon": "chart", "default_on": true, "needs": ["shell"] }
  }
}
```

`contributes` may name a `status` (readings on the server detail page), a `card`
(a widget card there), a `page` (a button in the server function bar), a `tab`
(a tab on the home page), and `settings` (a section of the app's settings). Each
one is a separate entry with its own id, because where it goes decides what it
is given.

## `abi` is the compatibility axis, not the app's version

`ABI_VERSION` from this package is the number to put in the manifest. The app
refuses a plugin declaring **higher** than its own, and a repository's index
keeps several versions of a plugin so an older app still finds one it can run.

The check is one-directional, so **understating it is the dangerous direction**:
a manifest that says 1 while using a v2 node installs on an app too old for it
and draws "unknown widget" in every row, reporting nothing.

- **v1** — the original set.
- **v2** — `tile`, `summary` and `toggle` nodes; `tap` honoured on any node
  rather than only on `btn`; `icon` on every contribution.

## Permissions

Everything on `sb` that reaches outside the plugin is behind one, named in the
manifest and agreed to by the user at install. An ungranted function is installed
as a stub that throws, so a plugin that asks for less than it uses fails on the
call rather than quietly doing less.

| Permission | What it opens |
|---|---|
| `server.exec` | Run a command on a server the *user* pointed at — the one this surface is bound to, or one picked through `sb.ui.pickServer`. |
| `server.stream` | Open a TCP connection through that server's SSH connection. |
| `server.list` | Enumerate the servers. **Strictly more than `server.exec`**: it hands over the whole list without anybody choosing, which a card for the machine in front of you must not have. Names and handles only — no address, user name or credential, and no permission grants those. |
| `net.http` | `sb.http.fetch`. `true` for anywhere, or a list of hosts (`["api.example.com", "$config.addr"]`) to be held to them. |
| `ui.dialog` | Raise a dialog and wait for an answer. |
| `clipboard` | Read and write the clipboard. |
| `storage.sync` | Grants no function: it lets this plugin's stored data take part in the user's backup sync, and it is here because that is something to be asked about. |

`sb.store`, `sb.ui.patch` and `sb.diag.crumb` need none: storage is per plugin
and per scope, patching is the surface it is already drawing, and a crumb is a
line in the app's own log.

A plugin declaring `runs_in: ["agent"]` runs on the monitor agent as well, where
there is no user: `sb.ui`, `sb.nav`, `sb.clipboard` and `sb.server.list` do not
exist there, and the same throwing stubs say so.

## Building, packing, publishing

```sh
bun build src/plugin.ts --outfile dist/plugin.js --format esm --minify-whitespace
bun run ../../plugin-tools/bin/pack.ts .      # writes dist/<id>-<version>.sbp
```

A `.sbp` is a zip holding `manifest.json`, `plugin.js`, `l10n/<locale>.json` and
`icon.png` — nothing else is read. The packer refuses to write one the app would
refuse to install: a locale the manifest declares with no file behind it,
translations with no `en` to fall back on, a manifest missing `id`, `version` or
`abi`.

To hand it to somebody, either send the `.sbp` (the app installs one from a
share sheet) or list it in a **repository** and let them add its address. A
repository is shaped like a Homebrew tap: a git repository with one TOML file per
plugin at `plugins/<a>/<b>/<rest>.toml` from its id, each naming the address its
package is served from and that package's SHA-256. Nothing binary is in it —
publish the `.sbp` wherever you like; the official repository uses its own
releases, one per plugin version, tagged `<id>-<version>`.
`packages/plugin-tools/bin/repo.ts` writes the files and computes the digests; a
client reads the repository with one request for a tarball of its latest tree.
The official one is
[`lollipopkit/serverbox-plugins`](https://github.com/lollipopkit/serverbox-plugins),
and it takes pull requests.

On a desktop there is a third way, and it is the one to develop with: **point the
app at the plugin's directory.** Settings → Plugins → add a development
directory. The files are read where they are on every launch, so editing
`plugin.js` and restarting is the whole cycle.

## Testing

`@serverbox/plugin-api/test` is a `MockHost`: it answers `sb` calls with what you
script, records what was asked, and lets a test assert on the widget tree the
plugin returned. The three plugins in
[`packages/plugins/`](https://github.com/lollipopkit/flutter_server_box/tree/main/packages/plugins)
are written this way and are the worked examples — a directory scanner, a port
lister, and a reader of cron and systemd timers.

What a mock cannot tell you is whether the app agrees with this SDK, since both
sides of the conversation would be yours. That is what the app's own
`test/plugin_*_test.dart` do: they load a real built `dist/plugin.js` into
QuickJS through the app's host and assert on what comes back.
