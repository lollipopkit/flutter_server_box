# The desk's app framework (`sys`)

The panel's desk (`monitor/frontend/src/desk`) is a small operating system: a shell (menubar, dock, launchpad, Spotlight, notification centre) that runs apps in windows. `sys` is the one interface between an app and the desk. Built-in apps and third-party apps use the same interface; they differ in where their code runs and what it may reach.

Status: phases 1–5 are implemented (the SDK is not published yet) (see [Phases](#phases)); the rest is the agreed design.

## App kinds

| Kind | Code | Runs in | Reaches |
|---|---|---|---|
| `system` | Svelte components in this repo (`desk/apps/<id>/`) | The panel's page | `sys`, `lk`, the agent's HTTP API within the account's grants |
| `web` | A static bundle (HTML/JS/CSS) installed on the agent | A sandboxed iframe | `sys` only, over a message bridge. No agent API, no network |
| `wasm` | A `web` bundle plus a WASI component installed on the agent | Frontend: a sandboxed iframe. Backend: the agent's WASM runtime | `sys`, and its own backend through `sys.backend`. The backend reaches the machine only through host functions its permissions allow |

A third-party app never runs in the panel's own page. Code in the page can read the session token and act as the signed-in account; an iframe with `sandbox="allow-scripts"` (no `allow-same-origin`) runs in an opaque origin, which is the only boundary the browser enforces. The agent serves an installed bundle with `Content-Security-Policy: sandbox allow-scripts allow-forms; default-src 'self'; connect-src 'none'`, so the bundle stays sandboxed even when it is opened directly.

What the sandbox does not do: stop an app from sending data out. `connect-src 'none'` blocks its requests, but a frame may navigate itself to any URL (with data in it), and WebRTC is outside `connect-src` in Chromium. So the bridge is reached only over a `MessagePort` the desk hands the frame's first page; when the frame loads a second page the desk closes the bridge and removes the frame, so a page the app navigates to never acts as the app. One navigation can still carry out what the app had read. **An approved app is trusted with whatever its permissions let it read**, and the approval dialog says so.

## Manifest

Every app is a manifest. A built-in app's is `apps/<id>/manifest.ts` (`defineApp({...})`) and is registered by being there; a third-party app's is `manifest.json` in its package.

| Field | Meaning |
|---|---|
| `id` | `[a-z][a-z0-9_]{0,31}` (the agent's bound); stable (windows, dock and icons are stored by it). Third-party ids carry a publisher prefix: `acme_notes` |
| `api` | The `sys` version the app was built for (third-party only; the desk refuses a newer major) |
| `kind` | `system` \| `web` \| `wasm` |
| `title`, `keywords` | Shown in the dock, launchpad, Spotlight, menubar. A string, or translations keyed by locale |
| `glyph`, `tone` | The app icon: a Material Symbols Rounded name and a tone of the lollipopkit Design System |
| `available` | System apps: a function of the agent's capabilities. Third-party: derived from `permissions` |
| `instances` | How many windows may be open (default 1) |
| `size`, `minSize` | The first window's size and the smallest allowed |
| `order`, `pinned` | Place in the launchpad; in a fresh desk's dock |
| `permissions` | Third-party only, see [Permissions](#permissions) |
| `opens` | File types and URL schemes the app can open (`{ "ext": ["log", "txt"], "mime": ["text/*"] }`), see [Intents](#intents) |
| `settings` | Its page in Settings → Apps (lazy), run as the app (its storage) inside the Settings window |

## Processes and lifecycle

A window is one process of its app: it has its own `sys` handle, state and lifecycle. Closing the window ends the process.

| State | When | What the app does | What the desk does |
|---|---|---|---|
| `active` | The front window | Everything | Menubar shows the app's menus; its shortcuts are live |
| `visible` | On screen, not in front | Everything | — |
| `background` | Minimised, or the desk is locked, or the browser tab is hidden | Stops drawing (animation frames, charts, polling for display). Keeps sessions it needs | The window's content is not rendered (`display: none`); the component stays mounted |
| `suspended` | `background` while background running is off | — | Unmounts the content after a grace period (5 s): sockets and timers end. The window remains. When the window comes back, the app is mounted again and restores itself from `appState` |

Background running is on by default: a hidden app keeps its sockets and timers. Settings → Apps → "Run apps in the background" turns it off for the desk (stored per account with the desk's preferences, `background`), and the same page has a switch per app (`background_denied`). A third-party app also needs the `background` permission.

`sys.lifecycle` gives the state (reactive) and `keepAlive(reason)`: a short assertion (an upload in progress) that holds a `background` app off suspension until released, at most 10 minutes. Control Centre lists apps running in the background and lets the user stop them.

An app saves what it needs to come back with `setAppState` (≤16 KiB JSON, never secrets) whenever it changes, not on suspension: suspension may follow a browser tab being frozen, when no code runs.

## The `sys` interface

One import for system apps: `import { … } from '../../sys'`. Third-party apps get the same interface from `@lollipopkit/desk-sys` (`monitor/sdk/desk-sys`), which carries it over `postMessage` (all calls are asynchronous there; reactive values arrive as events).

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
| Storage | `useWindow().storage.get/set/remove/keys` | JSON by key, per app, account and server: the agent's `/desk/apps/{app}/storage` (feature `desk_storage`, migration 021), else the browser. 256 KiB per app and 4 MiB per account across apps, keys ≤128 bytes. The agent cannot tell apps apart (the panel names the app), so it is not a boundary between apps of one account; for `web` apps the desk, not the iframe, names the app |
| Intents | `open(appId, { intent })`, `useIntents(handler)`, `handlers(path, kind)`, `opens` in the manifest | An intent is `{ action, data }`, delivered once to the window it opened (held until the app's handler is mounted, so none is lost to timing). `open` (`data: { path, kind }`) is the desk's; others are named by the receiving app (`terminal.type`, `lib/snippetIntent`). Files lists the apps whose `opens` match under "Open with" |
| Clipboard | `clipboard.writeText` | Read is not offered (browsers prompt; an app gets text by paste) |
| Theme and locale | `theme.dark`, `locale` | Tokens come from `lk.css` |
| Backend | `backend.call(method, params)`, `backend.events(handler)` | `wasm` apps only |

## Permissions

A third-party manifest lists what it needs. The agent decides on every call: what an app may do is the intersection of its approved permissions and the signed-in account's grants (`docs/dev/monitor-permissions.md`); an app never gets more than the account using it.

| Permission | Allows | Needs grant |
|---|---|---|
| `notifications` | `notify` | — |
| `background` | Background running and `keepAlive` | — |
| `files.read`, `files.write` | The backend's `fs` host functions, inside `fs.roots` | `files` (`read`/`write`) |
| `exec` | The backend's `exec` host function | `shell` |
| `net` | The backend's outbound TCP, to the addresses listed in the manifest | `connect` covering them |
| `status` | The backend's read of the status sample | — |

An admin installs an app and approves it in Settings → Apps. An approval names the package (its SHA-256) and asks the admin's password; an upload asks none, so **any new package, whatever its version or permissions, waits for approval again**. Ids of the panel's own apps are refused. Removing an app removes what its users kept in its storage.

## Packages and installation (`web`, `wasm`)

A package is a `.sbapp` (gzipped tar): `manifest.json`, `ui/` (the bundle, `ui/index.html` the entry), `backend.wasm` (`wasm` only), `LICENSE`. Admin endpoints: `GET /apps`, `POST /apps` (upload), `PUT /apps/{id}/approval`, `DELETE /apps/{id}`. The agent checks the manifest, the size limits (bundle 20 MiB, backend 20 MiB) and paths (no `..`, no links), stores the package under its data directory and serves `ui/` at `/apps/{id}/ui/*`.

## The bridge (phase 3)

The desk posts `{ sbm: 1, event: 'connect' }` with a `MessagePort` to the frame's first page; the frame posts calls `{ sbm: 1, id, call, args }` on that port and gets `{ sbm: 1, re, ok, value | error }`; the desk sends events `{ sbm: 1, event, data }` (held until the frame's `hello`). Only the port is heard, and every shape and size is checked (1 MiB, 32 calls in flight, `appState` ≤ 16 KiB, three `open`s per 10 s).

| Call | Does |
|---|---|
| `hello` | Answers app and window id, `appState`, lifecycle, theme, locale, granted permissions |
| `setTitle`, `setAppName`, `setIcon`, `setBadge`, `setAppState`, `close` | As the window handle |
| `toolbar` `{ title, subtitle, actions }`, `menus` `{ menus }` | Described, drawn by the desk with `lk`; a use sends `action { id }` |
| `notify` | Needs `notifications` |
| `storage.get/set/remove/keys` | The app's own storage |
| `open` `{ appId, newWindow, intent }` | The only intent it may hand on is `open` of a path (an app must not make Terminal type) |
| `handlers` `{ path, kind }`, `keepAlive`/`release` `{ token, reason }` (needs `background`) | |
| `backend.call` `{ method, params }` | Its backend (`wasm` apps), as the signed-in account |

Events: `lifecycle`, `theme`, `locale`, `intent` (`{ action, data, from }`), `action`.

Intents carry `from`, set by the desk: an app acts on one only from the apps it expects (Terminal takes `terminal.type` from Snippets alone).

## The WASM backend (phase 4)

- The agent runs `backend.wasm`, a core WebAssembly module, with wasmi (an interpreter: no JIT, no executable memory; `portable-dispatch`, so a long loop cannot overflow the stack in any build). One fresh instance per call on a thread of its own; what an app keeps between calls goes through `kv`.
- ABI: the module exports `memory`, `sbm_alloc(len) -> ptr` and `sbm_call(ptr, len) -> (ptr << 32) | len`; the request is `{ method, params, caller: { username, admin } }`, the reply `{ ok }` or `{ error }`. It imports `sbm.host(ptr, len)`, called with `{ fn, args }` and answered the same way. A Rust example: `monitor/examples/desk-app-uptime`.
- Host functions: `log`; `kv.get/set/remove/keys` (the calling account's app storage); `status` (`status`); `fs.list`, `fs.read` (`files.read` and the caller's `files` grant, inside `fs.roots`, 1 MiB per read); `exec` (`exec` and the caller's `shell` grant, `[remote_access.exec]`'s bounds, audited like `/exec`). Nothing else of the host is linked.
- Bounds per call: 2·10⁹ fuel or 10 s, whichever ends first (checked between fuel slices); 64 MiB of memory, one instance; 1000 host calls; 1 MiB request, 4 MiB reply. A bound reached answers `422 { error: "tooLong" | "trap" | … }`.
- `POST /apps/{id}/call` (`{ method, params }`, any account) runs it as the signed-in account; the frame reaches it with the bridge's `backend.call`. Calls are logged with the account and app.
- At most 8 calls at once per agent and 2 per account (`429 busy`). A host function is never re-entered (the guest's allocator calling `sbm.host` traps), and the clock is checked before each host call.
- Not yet: `fs.write`, `net`, events pushed from a backend.

## Phases

1. **sys core, system apps** (done, `656d5872`): manifests and registry, `sys` (window, identity, menus, shortcuts, lifecycle, background setting), the shell reading it; apps import only `sys`, `lk` and shared code (lint-enforced).
2. **Services** (done): per-app background choice (`background_denied`, migration 020), storage, notifications, dock menus, `keepAlive`, Control Centre's background list, intents and "Open with" (Snippets → Terminal moved onto them), app settings pages.
3. **`web` apps** (done): the agent's package store (`api::apps`, migration 022), the frame host and bridge (`desk/webapps/`: `protocol.ts`, `bridge.svelte.ts`, `WebAppFrame.svelte`), Settings → Apps (install, approve, remove), an example (`monitor/examples/desk-app-hello`). The SDK package moves to phase 5.
4. **`wasm` apps** (done): `api::app_runtime`, `/apps/{id}/call`, host functions, bounds; the bridge's `backend.call`. Events from a backend and `fs.write`/`net` are left.
5. **SDK** (done, unpublished): `monitor/sdk/desk-sys` (the client; `protocol.ts` is the one copy of the protocol, the panel's bridge imports it), `monitor/sdk/template` (vite, relative URLs, `npm run pack`), examples `monitor/examples/desk-app-hello` (`web`) and `desk-app-uptime` (`wasm`, Rust). Publishing waits for a license decision.
