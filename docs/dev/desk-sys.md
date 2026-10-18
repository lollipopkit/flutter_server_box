# The desk's app framework (`sys`)

The panel's desk (`monitor/frontend/src/desk`) is a small operating system: a shell (menubar, dock, Apps, Spotlight, notification centre) that runs apps in windows. `sys` is the one interface between an app and the desk. Built-in apps and third-party apps use the same interface; they differ in where their code runs and what it may reach.

Status: phases 1–5 are implemented (see [Phases](#phases)); the rest is the agreed design.

## App kinds

| Kind | Code | Runs in | Reaches |
|---|---|---|---|
| `system` | Svelte components in this repo (`desk/apps/<name>/`) | The panel's page | `sys`, `lk`, the agent's HTTP API |
| `web` | A static bundle (HTML/JS/CSS) installed on the agent | A sandboxed iframe | `sys` only, over a message bridge. No agent API, no network |
| `wasm` | A `web` bundle plus a WebAssembly component installed on the agent (API 2) | Frontend: a sandboxed iframe. Backend: the agent's wasmtime runtime | `sys`, and its own backend's service through `call`/`job`. The backend reaches the machine only through host functions its permissions allow |

A third-party app never runs in the panel's own page. Code in the page can read the session token and act as the signed-in account; an iframe with `sandbox="allow-scripts"` (no `allow-same-origin`) runs in an opaque origin, which is the only boundary the browser enforces. The agent serves an installed bundle with `Content-Security-Policy: sandbox allow-scripts allow-forms; default-src 'self'; connect-src 'none'`, so the bundle stays sandboxed even when it is opened directly.

What the sandbox does not do: stop an app from sending data out. `connect-src 'none'` blocks its requests, but a frame may navigate itself to any URL (with data in it), and WebRTC is outside `connect-src` in Chromium. So the bridge is reached only over a `MessagePort` the desk hands the frame's first page; when the frame loads a second page the desk closes the bridge and removes the frame, so a page the app navigates to never acts as the app. One navigation can still carry out what the app had read. **An approved app is trusted with whatever its permissions let it read**, and the approval dialog says so.

## Manifest

Every app is a manifest. A built-in app's is `apps/<name>/manifest.ts` (`defineApp({...})`) and is registered by being there; a third-party app's is `manifest.json` in its package.

| Field | Meaning |
|---|---|
| `publisher`, `name` | Each `[a-z][a-z0-9_]`, at most 24 (a publisher at least 2). The app's id is `<publisher>.<name>`, made from them, never written: stable (windows, dock, icons and app storage are stored by it). The panel's own apps are `serverbox.*`, a publisher no package takes: `serverbox.files`, `acme.notes` |
| `api` | The `sys` version the app was built for (third-party only; the desk refuses a newer major) |
| `kind` | `system` \| `web` \| `wasm` |
| `title`, `keywords` | Shown in the dock, Apps, Spotlight, menubar. A string, or translations keyed by locale |
| `glyph`, `tone` | The app icon: a Material Symbols Rounded name and a tone of the lollipopkit Design System |
| `available` | System apps: a function of the agent's capabilities. Third-party: derived from `permissions` |
| `instances` | How many windows may be open (default 1) |
| `size`, `min_size` (`minSize` in a built-in app) | The first window's size and the smallest allowed |
| `order`, `pinned` | Place in Apps; in a fresh desk's dock |
| `permissions` | Third-party only, see [Permissions](#permissions) |
| `opens` | File types the app can open (`{ "ext": ["log", "txt"], "dirs": false }`, `"*"` for any), see [Intents](#intents) |
| `settings` | Built-in apps: its page in Settings → Apps (lazy), run as the app (its storage) inside the Settings window |

## Processes and lifecycle

A window is one process of its app: it has its own `sys` handle, state and lifecycle. Closing the window ends the process.

| State | When | What the app does | What the desk does |
|---|---|---|---|
| `active` | The front window | Everything | Menubar shows the app's menus; its shortcuts are live |
| `visible` | On screen, not in front | Everything | — |
| `background` | Minimised, or the desk is locked, or the browser tab is hidden | Stops drawing (animation frames, charts, polling for display). Keeps sessions it needs | The window's content is not rendered (`display: none`); the component stays mounted |
| `suspended` | `background` while background running is off | — | Unmounts the content after a grace period (5 s): sockets and timers end. The window remains. When the window comes back, the app is mounted again and restores itself from `appState` |

Background running is on by default: a hidden app keeps its sockets and timers. Settings → Apps → "Run apps in the background" turns it off for the desk (stored with the desk's preferences, `background`), and the same page has a switch per app (`background_denied`). A third-party app also needs the `background` permission.

`sys.lifecycle` gives the state (reactive) and `keepAlive(reason)`: a short assertion (an upload in progress) that holds a `background` app off suspension until released, at most 10 minutes. Control Centre lists apps running in the background and lets the user stop them.

An app saves what it needs to come back with `setAppState` (≤16 KiB JSON, never secrets) whenever it changes, not on suspension: suspension may follow a browser tab being frozen, when no code runs.

## The `sys` interface

One import for system apps: `import { … } from '../../sys'`. Third-party apps get the same interface from `serverbox-desk` (`monitor/sdk/serverbox-desk`), which carries it over `postMessage` (all calls are asynchronous there; reactive values arrive as events).

| Area | Interface | Notes |
|---|---|---|
| Manifest | `defineApp(manifest)`, `registerApp(manifest)` | `registerApp` returns an unregister function |
| Window | `useWindow()`: `id`, `appState`, `setAppState`, `setTitle`, `close`, `open(appId, {appState, newWindow})`, `openWindow(appState)` + `canOpenWindow` (another window of its own app), `closed`, `panes` (`newTab`, `split`, `close`, `count`; a pane of an app whose manifest sets `panes`) | `open` goes through the target's `available` |
| Identity | `setAppName`, `setIcon({glyph, tone})`, `setBadge(text)` | Per window; the menubar shows the front window's, the dock the newest window's badge |
| Chrome | `AppToolbar` (title bar title or `heading` snippet, back, tools, tabs, `flush` over a table), `SplitView` (inset sidebar), `WindowFooter` (status bar and what sits over it), `PageStack` (pages inside the app: slide in and back, swipe back/forward) | Third-party: declarative descriptions, drawn by the desk |
| Menus | `useMenus(() => AppMenu[])` | Menubar menus between the app menu and the Window menu. Entries carry `shortcut` (`⌘⇧N`); the desk runs it while the window is active. The desk's own shortcuts (⌘K, ⌘,) come first |
| Dock | `useDockMenu(() => MenuEntry[])` | Rows above the desk's own in the app's dock menu (the newest window's) |
| Lifecycle | `useLifecycle()`: `state`, `keepAlive(reason)` | See above |
| Notifications | `useWindow().notify({ title, body, level })` | A banner (unless Do Not Disturb) and a row in the notification centre; clicking it brings the window forward (or opens the app). Kept for the page's life; the agent's own (monitoring rules) are stored |
| Storage | `useWindow().storage.get/set/remove/keys` | JSON by key, per app and server: the agent's `/desk/apps/{app}/storage` (feature `desk`, migration 018), else the browser. 256 KiB per app and 4 MiB across apps, keys ≤128 bytes. The agent cannot tell apps apart (the panel names the app), so it is not a boundary between apps; for `web` apps the desk, not the iframe, names the app |
| Intents | `open(appId, { intent })`, `useIntents(handler)`, `handlers(path, kind)`, `opens` in the manifest | An intent is `{ action, data }`, delivered once to the window it opened (held until the app's handler is mounted, so none is lost to timing). `open` (`data: { path, kind }`) is the desk's; others are named by the receiving app (`terminal.type`, `lib/snippetIntent`). Files lists the apps whose `opens` match under "Open with" |
| Clipboard | `clipboard.writeText` | Read is not offered (browsers prompt; an app gets text by paste) |
| Theme and locale | `theme` (`{ dark, tokens }`), `locale` | Third-party: the desk's design system is put on the page by `connect()` (see UI) |
| Backend | `call(fn, args, { sudo })`, `job(fn, args, { sudo, onLine })`, `jobView`, `follow`, `cancelJob` | `wasm` apps only |

## UI (third-party apps)

An installed app is drawn with the desk's own design system without carrying any of it: the implementation stays in ServerBox (`monitor/frontend/src/desk/lk`), and what an app gets is an interface, classes and tokens. Outside ServerBox web there is nothing behind them.

- **Delivery.** The panel build writes `dist/desk-app/` (`vite.desk-app.config.ts`: `desk.css`, the text fonts, the icon font), which the agent serves at `/desk-app/{name}` (`api/assets.rs`): one URL for every app and launch, so the browser keeps one copy; open to any origin (the frame's is opaque and fonts load with CORS), precompressed, the fonts immutable, `desk.css` revalidated. `POST /apps/{id}/launch` answers `stylesheet`; the bridge's `hello` passes it on as `ui.stylesheet` (null from an older agent).
- **`connect()`** (`serverbox-desk`, `src/ui.ts`) puts the sheet first in `<head>` (the app's own styles win) and waits for it (5 s at most), gives `<body>` the `lk` class the system is scoped to, sets the mode on `<html>` (`data-theme`), and sets the installed theme's tokens on `<body>`, again on every `theme` event. `connect({ style: false })` leaves the page alone.
- **The interface** is what `desk.css` holds, by class (`monitor/frontend/src/desk/lk/components.css`): buttons (`lk-btn` + `--primary`, `--secondary`, `--tinted`, `--ghost`, `--destructive`, `--sm`, `--lg`, `--block`), icon buttons (`lk-iconbtn`), fields (`lk-input`, `lk-select`, `lk-field`), checkbox and radio (`lk-check`, `--radio`, `--on`), switches (`lk-switch`, `--on`), segmented controls (`lk-seg`), cards (`lk-card`, `--raised`, `--glass`, `--interactive`, `--selected`), badges (`lk-badge` + tone), settings groups (`lk-setgroup`, `lk-setrow`), tables (`lk-table`, `lk-table__row`, `--sel`), tooltips (`lk-tip`), stat tiles (`lk-stat`), status bars (`lk-statusbar`), the text helpers `lk-caps`, `lk-mono`, `lk-num`, and icons: `<span class="lk-icon" data-icon="folder">` (Material Symbols Rounded names; `lk-icon--fill`). Tokens: `--color-*`, `--surface-*`, `--text-*`, `--border-*`, `--fill-*`, `--space-*`, `--radius-*`, `--shadow-*`, `--font-*`, `--dur-*`/`--ease-*` (`tokens.css`). A theme changes token values, never names.
- Classes and tokens are kept stable for apps: a rename keeps the old name working for a release (TODO when it happens). The Svelte components are the desk's and are not offered.

## Permissions

A third-party manifest lists what it needs. The agent decides on every call: what an app may do is bounded by its approved permissions and the transport rule (`docs/dev/monitor-permissions.md`). Within them it reaches what the agent's system account can, except the agent's own state.

| Permission | Allows | Transport rule |
|---|---|---|
| `notifications` | `notify` | — |
| `background` | Background running and `keepAlive` | — |
| `status` | The backend's read of the status sample | — |
| `process` | The backend's `exec` and a job's `run`: a script as the agent's account | yes |
| `root` | The backend's `exec-root` and a job's `run-root`: a script as root, with the sudo password the desk asked for that call or job | yes |
| `providers` | The backend's `providers` and `endpoint`: Agent mode's providers with an address here, each one's key included | yes |
| `network` | The backend's `http`: requests from the agent (loopback directly, the rest through its proxy settings; no redirect followed) and downloads checked by their SHA-256 into the app's folder | yes |

The owner installs an app and approves it in Settings → Apps. An approval names the package (its SHA-256) and asks the agent's password again; an upload asks none, so **any new package, whatever its version or permissions, waits for approval again**. Ids of the panel's own apps are refused. Removing an app removes what it kept in its storage.

## Packages and installation (`web`, `wasm`)

A package is a `.fsba` (gzipped tar): `manifest.json`, `ui/` (the bundle, `ui/index.html` the entry), `backend.wasm` (`wasm` only, a component; checked and compiled at install, `invalidBackend` otherwise), `LICENSE`. `web` takes API 1 or 2, `wasm` API 2 (API 1's core module is refused, `unsupportedApi`). `os` (optional, `/etc/os-release` `ID`s) says which systems a package is for; the catalog offers it only there (`notForThisSystem`).

- **Signatures** (`apps::sign`): `SIGNATURE` (`{ key, signature }`) is an ed25519 signature over the SHA-256 of the package's listing (`<sha256>  <path>` per other file, sorted, as `sha256sum` writes it). A first-party key (`FIRST_PARTY_KEYS`, the private key in the maintainer's keychain item `sbm-app-signing`, `scripts/build-desk-app.sh`) is the only way to use the panel's own publisher (`serverbox.*`); an unknown key or none installs as from an unknown publisher; a signature that does not verify refuses the package (`badSignature`). `signed_by` (migration 037) is kept, and a signed app is replaced only by a package with the same key (`publisherChanged`).
- **The catalog** (`apps::catalog`, `GET /apps/catalog`, `POST /apps/catalog/{id}/install`): `store/desk/<id>.fsba` (Git LFS), shipped inside the agent and read from the store's repositories with the web apps' catalog (`<stacks>/.desk-catalog/`); installing one is uploading it, so it waits for approval. The App Store lists them (`apps/store/DeskPackages.svelte`: install and approve with the password in one dialog). A signed `serverbox.*` package takes the place of the built-in app of that id in the desk (`AppRegistry.override`; TODO: remove once the built-in apps have left). Endpoints: `GET /apps`, `POST /apps` (upload), `PUT /apps/{id}/approval`, `DELETE /apps/{id}`. The agent checks the manifest, the size limits (bundle 20 MiB, backend 20 MiB) and paths (no `..`, no links), stores the package under its data directory and serves `ui/` at `/apps/{id}/ui/*`.

## The bridge (phase 3)

The desk posts `{ sbm: 1, event: 'connect' }` with a `MessagePort` to the frame's first page; the frame posts calls `{ sbm: 1, id, call, args }` on that port and gets `{ sbm: 1, re, ok, value | error, message? }` (`message`: a backend's words); the desk sends events `{ sbm: 1, event, data }` (held until the frame's `hello`). Only the port is heard, and every shape and size is checked (1 MiB, 32 calls in flight, `appState` ≤ 16 KiB, three `open`s per 10 s).

| Call | Does |
|---|---|
| `hello` | Answers app and window id, `appState`, lifecycle, theme, locale, granted permissions |
| `setTitle`, `setAppName`, `setIcon`, `setBadge`, `setAppState`, `close` | As the window handle |
| `toolbar` `{ title, subtitle, actions }`, `menus` `{ menus }` | Described, drawn by the desk with `lk`; a use sends `action { id }` |
| `sidebar` `{ sections: [{ title?, items: [{ id, label, icon?, trailing? }] }], selected? }` | The app's places, drawn as the window's own inset sidebar (folded in a narrow window); choosing one shows it chosen and sends `navigate { id }`; no sections, no sidebar |
| `notify` | Needs `notifications` |
| `storage.get/set/remove/keys` | The app's own storage |
| `open` `{ appId, newWindow, intent }` | The only intent it may hand on is `open` of a path (an app must not make Terminal type) |
| `handlers` `{ path, kind }`, `keepAlive`/`release` `{ token, reason }` (needs `background`) | |
| `backend.call`, `backend.job` `{ function, args, sudo? }` | Its backend's `api` function (`{ value }`) or one of its `jobs` (the job's view). With `sudo` (`{ title, body, confirmWord? }`, plain text, bounded) the desk first shows its own dialog naming the app (`AppSudoDialog`): sudo's password (or the one remembered) goes from the desk to the agent with that request, never to the frame; closing it answers `declined` |
| `backend.jobView` `{ since }`, `backend.cancel` | The app's job running or last (lines from `since`, then `value` or `error`), and asking it to stop |
| `openUrl` `{ url }` | An http(s) page in a tab of its own (the frame has no popups); counted with `open` |
| `power` `{ action }` | The desk's own restart / shut-down dialog (`PowerModal`), which the user confirms there; needs `root`; counted with `open` |
| `openStack` `{ id, model?, backend? }` | The desk's own page for a model server stack (`ollama.ollama`, `ggml.llama_cpp`, `vllm.vllm`, `sglang.sglang`) in a sheet over the window, set up with the model and backend when not deployed; the account confirms there with its password; answers once it is closed; needs `process`, one at a time |

Events: `lifecycle`, `theme`, `locale`, `intent` (`{ action, data, from }`), `action`.

Intents carry `from`, set by the desk: an app acts on one only from the apps it expects (Terminal takes `terminal.type` from Snippets alone).

## The backend (API 2)

- `backend.wasm` is a WebAssembly **component** (WASI 0.2, `wasm32-wasip2`) of a world that includes `sbm:app/imports` (`monitor/wit/app.wit`) and exports the app's service: `api` (unary calls) and, when it has any, `jobs`. Every function returns `result<T, error>`, `error` being gRPC's canonical codes (`invalid-argument`, `not-found`, `already-exists`, `permission-denied`, `failed-precondition`, `unavailable`, `deadline-exceeded`, `cancelled`, `internal`). The app's own WIT is its typed contract: wit-bindgen for the Rust guest; the frame names a function and passes its parameters as one JSON object (`apps::value`: camelCase names, `variant` as `{ tag, val }`, `option` as `null`, `result` as `{ ok }`/`{ err }`; resources, streams and nested options are refused at install). Examples: `monitor/apps/cleanup`, `monitor/examples/desk-app-uptime`, the test guest `monitor/tests/apps/probe`.
- The agent runs it with wasmtime (`apps::runtime`): compiled once per package into `<database dir>/apps/cache/<sha256>.cwasm` (a protected tree, only the agent writes it), a fresh instance per call or job (what lasts goes through `kv`), no preopens, environment, arguments or network.
- Host functions (`host`, `agent`, `job`): `log`; `kv-get/set/remove` (the calling account's app storage, JSON texts); `home`; `data-dir` (the app's own folder, `<database dir>/apps/data/<id>`, 0700, never served by `/fs`, removed with the app); `status` (`status`); `exec` (`process`, `[remote_access.exec]`'s bounds); `exec-root` (`root`, with the request's sudo password, else `permission-denied("sudo")`); `holds-state`, `stack-leftovers` and `web-apps` (what the agent knows of its own state, its web apps' folders and the deployed web apps with a web UI: title by locale and loopback port); `shared-dir`, `stacks` (every deployed stack, model servers included: state, health, its `[llm]` port) and `models-changed` (Agent mode works out the model servers it offers again); `http.fetch`, `http.fetch-lines` (a `lines` resource: the body as it comes) and `http.download` (`network`); `providers` and `endpoint` (`providers`: Agent mode's providers with an address here, their models, and one's address and key); in a job, `line` (its log), `run` (as the account, its output streamed to the log), `run-root` (as root, its output streamed to the log) and `private-file` (a secret, a token or a key, in a 0600 file removed when the job ends, so a script reads it by path and no log, argument or audit has it). A permission is checked with the transport rule when the function runs.
- Bounds: 64 MiB of memory; CPU by epoch interruption every 10 ms, yielding at each tick, a trap after 10 s of the guest's own work (time in host calls is not counted); a call ends after 60 s; at most 8 calls at once (`429`). A trap is `422 { error: "trap" }`.
- `POST /apps/{id}/call` and `POST /apps/{id}/jobs` take `{ function, args, sudo? }` (`sudo`: `{ password, remember }`, tried first: `403 sudo_rejected`; `remember` keeps it in memory with Agent mode's for 15 minutes, `GET /apps/sudo` says whether one is kept). A job runs alone per app (`409`), until it returns or `POST /apps/{id}/jobs/cancel`; `GET /apps/{id}/jobs?since=` reads it. Root work and every job are audited with the app.

## Phases

1. **sys core, system apps** (done, `656d5872`): manifests and registry, `sys` (window, identity, menus, shortcuts, lifecycle, background setting), the shell reading it; apps import only `sys`, `lk` and shared code (lint-enforced).
2. **Services** (done): per-app background choice (`background_denied`, migration 018), storage, notifications, dock menus, `keepAlive`, Control Centre's background list, intents and "Open with" (Snippets → Terminal moved onto them), app settings pages.
3. **`web` apps** (done): the agent's package store (`api::apps`, migration 018), the frame host and bridge (`desk/webapps/`: `protocol.ts`, `bridge.svelte.ts`, `WebAppFrame.svelte`), Settings → Apps (install, approve, remove), an example (`monitor/examples/desk-app-hello`). The SDK package moves to phase 5.
4. **`wasm` apps** (done; API 2 since 2026-10, `docs/dev/app-platform.md` §B): wasmtime components with a typed service (`apps::runtime`, `api::app_backend`), jobs, root through the desk's own sudo dialog. First-party apps leave the panel this way (`monitor/apps/<name>`, `scripts/build-desk-app.sh`).
5. **SDK** (done): `monitor/sdk/serverbox-desk` (the client, on npm as `serverbox-desk`, Apache-2.0; `protocol.ts` is the one copy of the protocol, the panel's bridge imports it), `monitor/sdk/template` (vite, relative URLs, `npm run pack`), examples `monitor/examples/desk-app-hello` (`web`) and `desk-app-uptime` (`wasm`, a Rust component).
