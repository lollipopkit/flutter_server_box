---
title: Desk App Reference
description: The contract between a desk app and the Monitor panel's desk — sandbox, manifest, lifecycle, bridge protocol, UI, permissions, packages and the wasm backend
---

This page is the contract a third-party desk app is built against. For a
walkthrough from the template to an installed package, see
[Developing Desk Apps](/docs/development/desk-apps/). The client library,
`serverbox-desk`, implements the protocol below; `protocol.ts` in it is the one
copy of the message shapes.

## App kinds and the sandbox

| Kind | Code | Runs in | Reaches |
|---|---|---|---|
| `web` | A static bundle (HTML, JavaScript, CSS) installed on the Monitor | A sandboxed iframe | The desk only, over a message bridge. No Monitor API, no network |
| `wasm` | A `web` bundle plus a WebAssembly component (API 2) | Frontend: a sandboxed iframe. Backend: the Monitor's wasmtime runtime | The desk, and its own backend's service through `call` and `job`. The backend reaches the machine only through the host functions its permissions allow |

A third-party app never runs in the panel's own page: code there could read the
session token and act as the signed-in account. The frame is
`sandbox="allow-scripts"` without `allow-same-origin`, so it runs in an opaque
origin. The Monitor serves an installed bundle with
`Content-Security-Policy: sandbox allow-scripts allow-forms; default-src 'self'; connect-src 'none'`,
so the bundle stays sandboxed even when it is opened directly.

The sandbox does not stop an app from sending out what it has read:
`connect-src 'none'` blocks its requests, but a frame can navigate itself to
any URL, and WebRTC is outside `connect-src` in Chromium. The bridge is
therefore reached only over a `MessagePort` the desk hands the frame's first
page; when the frame loads another page, the desk closes the bridge and removes
the frame, so a page the app navigates to never acts as the app. **An approved
app is trusted with whatever its permissions let it read**, and the approval
dialog says so.

## Manifest

`manifest.json` in the package.

| Field | Meaning |
|---|---|
| `publisher`, `name` | Each `[a-z][a-z0-9_]`, at most 24 characters (a publisher at least 2). The app's id is `<publisher>.<name>`, made from them and never written. It is stable: windows, the dock, icons and the app's storage are kept by it. The panel's own apps use `serverbox`, which no package can take without its signature |
| `api` | The desk API version the app was built for; the desk refuses a newer major |
| `kind` | `web` or `wasm` |
| `title`, `keywords` | Shown in the dock, Apps, Spotlight and the menubar. A string, or translations keyed by locale |
| `description` | What the app does, on its App Store page (at most 600 characters). A string, or translations keyed by locale |
| `glyph`, `tone` | The app icon: a Material Symbols Rounded name and a tone of the desk's design system |
| `instances` | How many windows may be open (default 1) |
| `size`, `min_size` | The first window's size and the smallest allowed |
| `permissions` | See [Permissions](#permissions) |
| `opens` | File types the app can open (`{ "ext": ["log", "txt"], "dirs": false }`, `"*"` for any); Files offers the app under **Open with** |
| `os` | Optional: `linux`, `macos`, `windows`, or a distribution's `/etc/os-release` `ID`. The catalog offers the package only on those systems |

## Windows and lifecycle

A window is one process of its app, with its own state and lifecycle. Closing
the window ends the process.

| State | When | What the app does | What the desk does |
|---|---|---|---|
| `active` | The front window | Everything | The menubar shows the app's menus; its shortcuts are live |
| `visible` | On screen, not in front | Everything | — |
| `background` | Minimised, the desk locked, or the browser tab hidden | Stops drawing (animation, charts, polling for display); keeps the sessions it needs | The window's content is not rendered; the frame stays |
| `suspended` | `background` while background running is off | — | Removes the content after 5 seconds: sockets and timers end. The window remains; when it comes back the app starts again and restores itself from `appState` |

Background running is on by default. The owner can turn it off for the desk, or
for one app, under **Settings → Apps**; a third-party app also needs the
`background` permission. `keepAlive(reason)` holds a `background` app off
suspension until released, at most 10 minutes (an upload in progress).
Control Centre lists the apps running in the background.

An app saves what it needs to come back with (`setAppState`, at most 16 KiB of
JSON, never secrets) whenever it changes, not on suspension: a frozen browser
tab may be suspended with no code running.

## The bridge

The desk posts `{ sbm: 1, event: 'connect' }` with a `MessagePort` to the
frame's first page. The frame posts calls `{ sbm: 1, id, call, args }` on that
port and gets `{ sbm: 1, re, ok, value | error, message? }` (`message`: a
backend's own words). The desk sends events `{ sbm: 1, event, data }`, held
until the frame's `hello`. Only the port is heard, and every shape and size is
checked: 1 MiB per message, 32 calls in flight, `appState` at most 16 KiB,
three `open` calls per 10 seconds.

| Call | Does |
|---|---|
| `hello` | Answers the app and window id, `appState`, the lifecycle state, theme, locale, the granted permissions and `ui.stylesheet` |
| `setTitle`, `setAppName`, `setIcon`, `setBadge`, `setAppState`, `close` | The window's title, the app's name, icon (`{ glyph, tone }`) and badge, its saved state, closing it |
| `toolbar` `{ title, subtitle, actions }`, `menus` `{ menus }` | Described by the app, drawn by the desk; using one sends `action { id }`. Menu entries may carry a `shortcut` (`⌘⇧N`), live while the window is in front; the desk's own shortcuts come first |
| `sidebar` `{ sections: [{ title?, items: [{ id, label, icon?, trailing? }] }], selected? }` | The window's inset sidebar (folded in a narrow window); choosing an item sends `navigate { id }`. No sections, no sidebar |
| `notify` `{ title, body, level }` | A banner (unless Do Not Disturb) and a row in the notification centre; clicking it brings the window forward. Needs `notifications` |
| `storage.get`, `storage.set`, `storage.remove`, `storage.keys` | The app's own storage: JSON by key, per app and server. 256 KiB per app and 4 MiB across apps; keys at most 128 bytes |
| `open` `{ appId, newWindow, intent }` | Opens another app. The only intent an app may hand on is `open` of a path |
| `handlers` `{ path, kind }` | The apps that can open a path |
| `keepAlive`, `release` `{ token, reason }` | See [Windows and lifecycle](#windows-and-lifecycle). Needs `background` |
| `backend.call`, `backend.job` `{ function, args, sudo? }` | Its backend's `api` function (`{ value }`) or one of its `jobs` (the job's view). With `sudo` (`{ title, body, confirmWord? }`, plain text, bounded) the desk first shows its own dialog naming the app; sudo's password goes from the desk to the Monitor with that request, never to the frame. Closing the dialog answers `declined` |
| `backend.jobView` `{ since }`, `backend.cancel` | The app's running or last job (lines from `since`, then `value` or `error`), and asking it to stop |
| `openUrl` `{ url }` | An http(s) page in a tab of its own (the frame has no popups); counted with `open` |
| `power` `{ action }` | The desk's own restart and shut-down dialog, which the user confirms there. Needs `root`; counted with `open` |
| `openStack` `{ id, model?, backend? }` | The desk's own page for a model server stack (`ollama.ollama`, `ggml.llama_cpp`, `vllm.vllm`, `sglang.sglang`) in a sheet over the window, set up with the model and backend when it is not deployed; the user confirms there with the password. Answers once the sheet is closed. Needs `process`; one at a time |

Events: `lifecycle`, `theme`, `locale`, `intent` (`{ action, data, from }`),
`action`, `navigate`. An intent carries `from`, set by the desk: act on one only
from the apps you expect.

## UI

An installed app is drawn with the desk's design system without carrying any of
it. What an app gets is an interface — classes and tokens — never the code; the
classes and tokens are kept stable for apps, and a rename keeps the old name
working for a release.

- **Delivery.** The Monitor serves the design system's stylesheet and fonts at
  `/desk-app/` (one URL for every app, open to any origin, the fonts immutable).
  `hello` passes the stylesheet's address on as `ui.stylesheet`.
- **`connect()`** in `serverbox-desk` puts the sheet first in `<head>` (the
  app's own styles win) and waits for it (at most 5 seconds), gives `<body>`
  the `lk` class the system is scoped to, sets the mode on `<html>`
  (`data-theme`), and sets the installed theme's tokens on `<body>`, again on
  every `theme` event. `connect({ style: false })` leaves the page alone.
- **Classes**: buttons (`lk-btn` with `--primary`, `--secondary`, `--tinted`,
  `--ghost`, `--destructive`, `--sm`, `--lg`, `--block`), icon buttons
  (`lk-iconbtn`), fields (`lk-input`, `lk-select`, `lk-field`), checkbox and
  radio (`lk-check`, `--radio`, `--on`), switches (`lk-switch`, `--on`),
  segmented controls (`lk-seg`), cards (`lk-card`, `--raised`, `--glass`,
  `--interactive`, `--selected`), badges (`lk-badge` with a tone), settings
  groups (`lk-setgroup`, `lk-setrow`), tables (`lk-table`, `lk-table__row`,
  `--sel`), tooltips (`lk-tip`), stat tiles (`lk-stat`), status bars
  (`lk-statusbar`), the text helpers `lk-caps`, `lk-mono`, `lk-num`, and icons:
  `<span class="lk-icon" data-icon="folder">` (Material Symbols Rounded names;
  `lk-icon--fill`).
- **Tokens**: `--color-*`, `--surface-*`, `--text-*`, `--border-*`, `--fill-*`,
  `--space-*`, `--radius-*`, `--shadow-*`, `--font-*`, `--dur-*` and `--ease-*`.
  A theme changes token values, never names.

## Permissions

A manifest lists what the app needs. The Monitor decides on every call: what an
app may do is bounded by its approved permissions and by the transport rule
(acting needs TLS or a loopback caller, see
[Monitor API and Access Model](/docs/development/monitor-agent/#transport)).
Within them it reaches what the Monitor's system account can, except the
Monitor's own state.

| Permission | Allows | Transport rule |
|---|---|---|
| `notifications` | `notify` | — |
| `background` | Background running and `keepAlive` | — |
| `status` | The backend's read of the status sample | — |
| `process` | The backend's `exec` and a job's `run`: a script as the Monitor's account | yes |
| `root` | The backend's `exec-root` and a job's `run-root`: a script as root, with the sudo password the desk asked for that call or job | yes |
| `providers` | The backend's `providers` and `endpoint`: Agent mode's providers with an address on this machine, each one's key included | yes |
| `network` | The backend's `http`: requests from the Monitor (loopback directly, the rest through its proxy settings; no redirect followed) and downloads checked by their SHA-256 into the app's folder | yes |

The owner installs an app and approves it under **Settings → Apps**. An
approval names the package (its SHA-256) and asks for the Monitor's password
again; an upload asks for none, so **any new package, whatever its version or
permissions, waits for approval again**. Removing an app removes what it kept
in its storage.

## Packages

A package is a `.fsba` file (a gzipped tar): `manifest.json`, `ui/` (the
bundle, with `ui/index.html` as the entry), `backend.wasm` (`wasm` only),
`LICENSE`. A `web` package takes API 1 or 2, a `wasm` package API 2. The
Monitor checks the manifest, the sizes (bundle 20 MiB, backend 20 MiB) and the
paths (no `..`, no links), and refuses a backend it cannot compile
(`invalidBackend`) or an API 1 core module (`unsupportedApi`).

- **Signatures.** `SIGNATURE` (`{ key, signature }`) is an ed25519 signature
  over the SHA-256 of the package's listing: `<sha256>  <path>` for every
  other file, sorted, as `sha256sum` writes it. A package signed with an
  unknown key, or not signed, installs as from an unknown publisher; a
  signature that does not verify refuses the package (`badSignature`). Once a
  signed app is installed, it is replaced only by a package signed with the
  same key (`publisherChanged`). Only ServerBox's own key may use the
  `serverbox` publisher.
- **Catalog.** The App Store lists packages from the store's repositories
  beside the web apps. Installing one from there installs and approves it in
  one step with the password; a package uploaded by hand waits for approval.

## The backend (`wasm`)

- `backend.wasm` is a WebAssembly **component** (WASI 0.2, `wasm32-wasip2`)
  of a world that includes `sbm:app/imports` (`monitor/wit/app.wit` in the
  repository) and exports the app's service: `api` (unary calls) and, when it
  has any, `jobs`. Every function returns `result<T, error>`, `error` being
  gRPC's canonical codes (`invalid-argument`, `not-found`, `already-exists`,
  `permission-denied`, `failed-precondition`, `unavailable`,
  `deadline-exceeded`, `cancelled`, `internal`).
- The app's own WIT is its typed contract. The frame names a function and
  passes its parameters as one JSON object: camelCase names, a `variant` as
  `{ tag, val }`, an `option` as `null`, a `result` as `{ ok }` or `{ err }`.
  Resources, streams and nested options are refused at install.
- The Monitor runs it with wasmtime: compiled once per package, a fresh
  instance per call or job (what lasts goes through `kv`), with no preopened
  directories, environment, arguments or network.
- **Host functions**: `log`; `kv-get`, `kv-set`, `kv-remove` (the app's
  storage, JSON texts); `home`; `data-dir` (the app's own folder, `0700`, never
  served by the file API, removed with the app); `status` (`status`); `exec`
  (`process`, within the Monitor's command limits); `exec-root` (`root`, with
  the request's sudo password, else `permission-denied("sudo")`);
  `holds-state`, `stack-leftovers`, `web-apps`, `shared-dir`, `stacks` and
  `models-changed` (what the Monitor knows of its own state and its web apps;
  for an app granted `process` or `root`, another is told nothing);
  `http.fetch`, `http.fetch-lines` (the body as it comes) and `http.download`
  (`network`); `providers` and `endpoint` (`providers`). In a job: `line` (its
  log), `run` (as the account, its output streamed to the log), `run-root` (as
  root) and `private-file` (a secret in a `0600` file removed when the job
  ends, so a script reads it by path and no log, argument or audit holds it).
  A permission is checked with the transport rule when the function runs.
- **Limits**: 64 MiB of memory; a trap after 10 seconds of the guest's own CPU
  time (time in host calls is not counted); a call ends after 60 seconds; at
  most 8 calls at once (`429`). A trap answers `422 { error: "trap" }`.
- **Calls and jobs**: `POST /apps/{id}/call` and `POST /apps/{id}/jobs` take
  `{ function, args, sudo? }` (`sudo`: `{ password, remember }`, tried first:
  `403 sudo_rejected`; `remember` keeps it in memory for 15 minutes). A job runs
  alone per app (`409`) until it returns or `POST /apps/{id}/jobs/cancel`;
  `GET /apps/{id}/jobs?since=` reads it. Root work and every job are audited
  with the app.

The examples in the repository are `monitor/examples/desk-app-hello` (`web`)
and `monitor/examples/desk-app-uptime` (`wasm`, a Rust component).
