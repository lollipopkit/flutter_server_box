# TODOs / future directions

Not scheduled work — ideas and known gaps captured here so they aren't lost.

## App: fetch server data over HTTP, not only SSH + shell

Today the Flutter app's only way to read a server's status is: SSH in, upload/run
the generated script, parse `SrvBoxSep`-delimited text output. That's the sole
data path even for servers that already run `monitor` (which exposes the same
data — and more, including history — over a real HTTP API with auth).

Idea: let the app optionally talk to a server's `monitor` instance directly via
its HTTP API (`/api/v1/status`, `/api/v1/metrics`, `/api/v1/metrics/history`)
instead of SSH+shell, when the user has `monitor` running there. Benefits:
- No SSH round-trip / shell parsing for status polling — lower latency, no
  script upload/versioning dance
- Access to `monitor`'s history endpoint (charts) and richer metrics
  (gpus/disk_details/ifaces) the current SSH+shell path doesn't parse at all
- One less code path to keep correct — SSH+shell parsing already has a long
  tail of platform quirks (see crates/sbm_parser's dart_compat fixtures)

Open questions (not decided, just flagged):
- Auth/pairing UX: the app would need each server's `monitor` URL + credentials
  (mirrors the panel's server registry in `monitor/frontend/src/lib/servers.svelte.ts`)
- SSH would likely remain required for actions monitor doesn't expose (process
  list/kill, shutdown/reboot/suspend, terminal, SFTP) — this is additive to SSH,
  not a replacement
- CORS: monitor's `cors_allowed_origins` is built for browser origins (Pages
  panel); the app isn't a browser, so this constraint may not even apply to it
  the way it does to the web panel — needs checking `ntex_cors`/`Cors`
  middleware behavior for non-browser HTTP clients (Origin header is
  browser-sent; a Dart `http`/`dio` client won't send one unless we set it,
  so it would likely just pass through unauthenticated-by-CORS, same as curl)
- Would need a `monitor` client module in the app (auth token storage, base
  URL config) and a decision on how it composes with the existing per-server
  provider model

## macOS per-core CPU: monitor done, App still can't

`monitor` now gets real per-core CPU on macOS via `sysinfo`/Mach
`host_processor_info` (see `monitor/src/monitoring/macos_cpu.rs`) when it runs
natively on the host. The **app** still cannot get this for a macOS server it
SSHes into — there is no shell command that exposes per-core data on macOS
(htop's own macOS backend calls the same Mach API in-process, not via shell).
This is the same architectural line as the item above: if the app could talk to
a `monitor` instance over HTTP, it would inherit the real per-core reading for
free, whereas the SSH+shell path is a structural dead end here.
