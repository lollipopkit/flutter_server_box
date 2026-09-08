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
bun run pack      # dist/plugin.js and dist/<id>-<version>.sbp
```

`test/plugin_listening_ports_test.dart` in the app reads `dist/plugin.js`, so
it fails if the bundle is stale.

## What it cannot do yet

Tapping a row to forward that port. The app has port forwarding and the plugin
has no way to reach it: there is no `sb.nav.openPortForward`, and inventing one
to satisfy a single plugin is how a host interface grows a method per feature.
Left undone deliberately, and recorded here because finding this is what
writing a real plugin was for.
