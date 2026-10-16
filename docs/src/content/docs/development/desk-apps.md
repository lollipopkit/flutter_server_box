---
title: Developing Desk Apps
description: Build third-party apps for the Monitor panel's desk with serverbox-desk
---

A desk app is a static web bundle that the Monitor panel runs in a window,
inside a sandboxed frame. It is packaged as a `.fsba` file, which the
agent's owner installs and approves (see [Desk Apps](/docs/advanced/monitor-desk-apps/)).
The full design, including the message protocol, is
[`docs/dev/desk-sys.md`](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md).

| Kind | What it contains | What it can reach |
|---|---|---|
| `web` | A static bundle (HTML, JavaScript, CSS) | The desk, through `serverbox-desk` |
| `wasm` | A `web` bundle and `backend.wasm`, a WebAssembly module the agent runs | The desk, and its backend through `desk.backend()` |

## Start from the template

The template in
[`monitor/sdk/template`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/sdk/template)
uses vite and the [`serverbox-desk`](https://www.npmjs.com/package/serverbox-desk)
package (Apache-2.0, so an app built on it keeps its own license, closed source
included). Copy the directory, then point the dependency at the published
package:

```sh
npm install serverbox-desk
npm run pack   # builds dist/ and writes <publisher>.<name>.fsba
```

Inside this repository the template depends on `file:../serverbox-desk`, which
needs `npm run build --prefix ../serverbox-desk` once.

The bundle runs with no network access: everything it needs must be inside the
package, and its URLs must be relative (`base: './'` in vite).

## Talk to the desk

```ts
import { connect } from 'serverbox-desk'

const desk = await connect()
await desk.toolbar({ actions: [{ id: 'refresh', label: 'Refresh', icon: 'refresh' }] })
desk.on('action', ({ id }) => {
  if (id === 'refresh') void load()
})
const count = (await desk.storage.get<number>('count')) ?? 0
await desk.storage.set('count', count + 1)
```

`connect()` resolves once the desk has handed the frame its channel. The
returned object offers:

| Area | Calls |
|---|---|
| Window | `setTitle`, `setAppName`, `setIcon`, `setBadge`, `setAppState` (JSON up to 16 KiB that the window comes back with; never secrets), `close` |
| Chrome | `toolbar({ title, subtitle, actions })`, `menus([...])`; the desk draws them and sends an `action` event when one is used |
| Notifications | `notify({ title, body, level })`, with the `notifications` permission |
| Storage | `storage.get/set/remove/keys`: JSON per app, kept on the agent (256 KiB per app) |
| Other apps | `open(appId, { path })` opens another app, optionally with a file or folder; `handlers(path, kind)` lists the apps that can open it |
| Background | `keepAlive(reason)`, with the `background` permission |
| Backend | `backend(method, params)`, `wasm` apps only |

Events (`desk.on`): `lifecycle` (`active`, `visible`, `background`,
`suspended`), `theme`, `locale`, `intent`, `action`. `desk.info` holds what the
desk answered when connecting: the app and window ids, the saved `appState`,
the locale and the granted permissions. A refused call throws `DeskError`.

## Look like the desk

`connect()` loads the desk's stylesheet into the page, keeps the page in the
desk's light or dark mode, and applies the tokens of the theme the desk
uses. Build the UI with its classes and tokens instead of your own colors:

```html
<div class="lk-card">
  <button class="lk-btn lk-btn--primary">
    <span class="lk-icon" data-icon="play_arrow"></span>Run
  </button>
</div>
```

Buttons (`lk-btn` with `--primary`, `--secondary`, `--tinted`, `--ghost`,
`--destructive`), icon buttons (`lk-iconbtn`), fields (`lk-input`,
`lk-select`), switches (`lk-switch`), cards (`lk-card`), badges, tables
(`lk-table`), settings groups (`lk-setgroup`, `lk-setrow`) and icons
(`lk-icon` with a Material Symbols Rounded name) are listed in the
[UI section of the design](https://github.com/lollipopkit/flutter_server_box/blob/main/docs/dev/desk-sys.md#ui-third-party-apps).
The stylesheet is served by the agent and is not in the package, so the app
looks right only inside the panel. `connect({ style: false })` leaves the page
alone.

## Manifest

`manifest.json` sits at the root of the package. The agent refuses unknown
fields.

```json
{
  "publisher": "acme",
  "name": "notes",
  "version": "1.0.0",
  "api": 1,
  "kind": "web",
  "title": { "en": "Notes", "zh-CN": "笔记" },
  "glyph": "sticky_note_2",
  "tone": "amber",
  "permissions": ["notifications"],
  "size": { "width": 640, "height": 440 }
}
```

| Field | Meaning |
|---|---|
| `publisher`, `name` | Each `[a-z][a-z0-9_]*`, at most 24 characters, a publisher at least 2. The app's id is `<publisher>.<name>`; the panel's own `serverbox` publisher is refused |
| `version` | Up to 32 characters |
| `api` | `1` |
| `kind` | `web` or `wasm` |
| `title` | A string, or translations by locale with `en` required; up to 64 characters |
| `glyph` | A Material Symbols Rounded name, such as `sticky_note_2` |
| `tone` | `berry`, `soft`, `ink`, `sky`, `teal`, `violet`, `amber`, `leaf`, `pale`, `bright` or `mist` |
| `permissions` | See [Permissions](/docs/advanced/monitor-desk-apps/#permissions). A `web` app may ask for `notifications` and `background`; a `wasm` app also for `status`, `files.read` and `exec` |
| `instances` | How many windows may be open, 1 to 8 (default 1) |
| `size`, `min_size` | `{ "width", "height" }`: the first window's size and the smallest allowed |
| `opens` | `{ "ext": ["md", "txt"], "dirs": false }`: the files (`"*"` for any) and whether folders the app offers to open in Files' "Open with" |
| `keywords` | Extra words Spotlight matches |

## Package

A `.fsba` is a gzipped tar of `manifest.json`, `ui/` (the bundle, with
`ui/index.html` as the entry), `backend.wasm` (present exactly when the kind is
`wasm`), and optionally `LICENSE`, `NOTICE` and `README.md`; nothing else is
accepted. The agent accepts regular files only, with plain relative paths,
at most 2000 files and 20 MiB compressed and unpacked. On macOS set
`COPYFILE_DISABLE=1` for `tar`, or it adds `._` files that the agent refuses;
the template's `npm run pack` does this.

## A backend (`wasm`)

The agent runs `backend.wasm` with an interpreter, in a fresh instance for each
call, as the system account the agent runs as. The module exports `memory`,
`sbm_alloc(len) -> ptr` and `sbm_call(ptr, len) -> (ptr << 32) | len`. A call
receives `{ method, params }` as JSON and answers
`{ "ok": … }` or `{ "error": … }`. The module imports `sbm.host(ptr, len)` for
host functions, called with `{ fn, args }`:

| Function | Needs |
|---|---|
| `log` | — |
| `kv.get`, `kv.set`, `kv.remove`, `kv.keys` | — (the app's own storage) |
| `status` | `status` |
| `fs.list`, `fs.read` | `files.read`; 1 MiB per read |
| `exec` | `exec` |

Each call is bounded: 10 seconds, 64 MiB of memory, 1000 host calls, a 1 MiB
request and a 4 MiB answer. At most 8 calls run at once; more are answered
`busy`. `fs.*` and `exec` also follow the agent's transport rule: HTTPS or a
caller on the same host, unless `[remote_access] allow_insecure`.

[`monitor/examples/desk-app-uptime`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-uptime)
is a complete example in Rust:

```sh
cargo build --release --target wasm32-unknown-unknown
cp target/wasm32-unknown-unknown/release/desk_app_uptime.wasm backend.wasm
COPYFILE_DISABLE=1 tar -czf example.uptime.fsba manifest.json backend.wasm ui
```

[`monitor/examples/desk-app-hello`](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor/examples/desk-app-hello)
is a `web` app without a build step.

## Test it

Install the package in **Settings → Apps → Installed** and approve it. Each new package needs approval again, so a test cycle is: pack,
install, approve, open. Remove the app to clear what it stored.
