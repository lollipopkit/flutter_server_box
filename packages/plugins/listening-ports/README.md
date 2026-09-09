# Listening ports

What a server is listening on, and which of it is reachable from outside.

The first plugin written against the host interface rather than alongside it,
and the reason it exists twice over: it is useful, and it is what proves the
interface is usable by somebody who did not write the interface.

## What it demonstrates

- `contributes.page` — a button in the server's function bar, with
  `needs: ["shell"]` so it does not appear on a server that cannot run a
  command.
- `onHook` — the reading is collected when the page is entered, not in `open`
  and not on a tick. `open` draws immediately and the rows are patched in when
  the command comes back, so a slow machine costs a spinner rather than a blank
  window held open. See PLUGINS.md 4.4.
- `sb.server.exec` — the one permission it asks for, and the only thing it does
  with it is a read-only probe.

## Building

```sh
bun install
bun test          # the parser, and the plugin against MockHost
bun run build     # dist/plugin.js, plus a copy of manifest.json beside it
bun run pack      # the above, and dist/<id>-<version>.sbp
```

## Finding one

A search box appears once there is enough to search — a list of two does not
need one, and a server with ninety open ports is exactly where the page stops
being readable without it. It matches the port as a **prefix** (`800` finds
8000 and 8080, which is what somebody typing three digits means), and the
process name and bound address anywhere.

The order is by port by default, because that is the one field every row has.
**By process** groups a server's services together, which is the other way
anybody looks at this, and the choice is remembered.

## Settings

The plugin contributes a page under **Settings → Plugins**, which is where its
own preferences live — not per server, so `sb.store`'s `global` scope. The page
is a surface like any other: `open` is called with `kind: "settings"`, and what
it draws comes from the store rather than from a machine.

## Translations

`l10n/en.json` and `l10n/zh-CN.json`; the manifest declares both and
`bun run pack` puts them in the `.sbp`. Every user-visible string goes
through `l10n("key")` — the app substitutes when it draws, so a count is
`l10n("ports", "2")` rather than a sentence assembled here. What is *not*
translated is the user's own text: a path, a cron line, a process name.

`test/plugin_l10n_test.dart` in the app holds all of it together: every key
the source asks for exists in every locale, the locales carry the same keys,
no key is left behind unused, and the built `.sbp` actually contains the
files.

## Trying it in the app

Two ways in, both under **Settings → Plugins → Installed → add**:

- **`.sbp`** — pick `dist/<id>-<version>.sbp` after `bun run pack`. What a
  user would install.
- **Dev directory** (desktop only) — pick **`dist/`**, not the plugin's root.
  The installer wants `manifest.json` and `plugin.js` side by side, which is
  why `bun run build` copies the manifest there. Re-running the build and
  reloading the plugin picks up an edit without repacking.

The consent dialog lists the permissions the manifest asks for; the page
contribution has `default_on`, so after installing it is a function button on
a server's detail page.

`test/plugin_listening_ports_test.dart` in the app reads `dist/plugin.js`, so
it fails if the bundle is stale.

## What it cannot do yet

Tapping a row to forward that port. The app has port forwarding and the plugin
has no way to reach it: there is no `sb.nav.openPortForward`, and inventing one
to satisfy a single plugin is how a host interface grows a method per feature.
Left undone deliberately, and recorded here because finding this is what
writing a real plugin was for.
