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

## State that tracks itself

A plugin holds its state in values that know who read them, and builds from
them. `surface()` writes the exports the host calls:

```ts
import { card, resource, skeleton, state, surface, tile } from "@serverbox/plugin-api";

const filter = state("");
const jobs = resource(async () => read(filter.value));

export const { open, onEvent, tick, dispose } = surface(
  () =>
    jobs.when({
      loading: () => skeleton(),
      error: (e) => notice({ title: "Could not read", detail: `${e}` }),
      data: (list) => card(list.map((j) => tile({ title: j.when }))),
    }),
  { onTick: () => jobs.reload() },
);
```

Four things follow, and each is something every plugin used to write by hand:

- **No `return { ui: view() }`.** Changing a value redraws what read it.
  Forgetting that return is precisely what a dead control is: the plugin handled
  the tap, moved its state, and answered with nothing.
- **Nothing to declare.** Reading `filter.value` while building *is* the
  subscription, and a branch that stops being drawn stops causing redraws. There
  is no `ref` to thread through the functions that draw your rows.
- **A handler is a closure**: `onTap(btn("Run"), () => jobs.reload())`. The SDK
  keeps the function and sends the app a token in its place, so nothing writes a
  `switch` over message shapes. Messages still work and are still what crosses.
- **Loading and failure are states of the value**, not flags beside it. A page
  cannot forget to clear a spinner it does not own.

`state`, `computed`, `resource`, `effect` and `family` are the five.
`.value` reads *and* subscribes; `.peek()` reads without subscribing, which is
what a handler wants; `.update(fn)` is `x.value = fn(x.value)`.

**Tracking is synchronous**: what a body reads before its first `await` is what
it depends on. A `resource` that needs a value should read it at the top —
which is also where it reads best.

**What a call starts, the call finishes.** The app drives a plugin only while it
is inside a call, so a fetch left running when one returns does not progress —
`surface()` therefore waits for what your handler set in motion before it
answers, sending each state on the way out as a patch. That is why the loading
line appears on a machine that takes a minute, and why `onHook` must `await
app.settle()`: it is the call the first reading gets to run in.

A change that lands while nothing is on screen is dropped rather than queued:
`sb.ui.patch` answers `no_surface`, and the next `open` sends a whole tree.

## Work somebody may want to stop

The app serves **one call per instance at a time**. A call that waits for a
four-minute `du` is four minutes in which no tap is delivered, so the Stop
button you drew cannot be pressed and nothing else on the page moves either.

Two things go together:

```ts
// The call does not wait for this one. Export `tick`, which is what the
// reading arrives on — the app calls it as soon as the answer is there.
const level = resource(async () => {
  return await sb.server.exec({
    server: server.value,
    script: `du -x -d 1 ${shellQuote(path.value)}`,
    timeoutMs: 120_000,
    cancelKey: "scan",       // the label a Stop names
  });
}, { background: true });

export const { open, onEvent, tick, dispose } = app;

// From a button, in a call of its own — which only exists because the one
// above did not hold the instance.
onTap(tag("Stop"), () => sb.server.cancel({ key: "scan" }));
```

A stopped or timed-out run **rejects**; it does not resolve with what it had.
A `du` that was stopped holds a prefix of its output, and resolving with that
would let a plugin draw a partial reading as a complete one.

`classify(e)` then gives two things, and the second is the one to say out loud:

```ts
const { kind, remote } = classify(e);   // "cancelled" | "timeout"
if (remote === "running") {
  // Only the waiting stopped. The command is still running on the server.
}
```

The app cannot decide `remote` for you and neither can this SDK: an SSH channel
carries a signal, so cancelling really ends the command; one HTTP request to a
monitor agent has nothing to signal down, so the agent runs it to its own
timeout. Reporting "stopped" over the second case tells somebody their server
is idle while it walks a filesystem.

Leave `background` off for the short reads waiting was invented for — a store
lookup, one `systemctl status`. Those belong inside the call.

## The two files

**`plugin.js`** exports what it implements and omits the rest. `open` alone is a
card; `statusCmd` plus `parse` alone is a status plugin with no interface at all.
Every export may be `async`, and the host awaits it.

| Export | When |
|---|---|
| `init(ctx)` | Once, before any surface is shown. |
| `open(surface)` | A surface is being shown; the tree it answers with is the whole of it. |
| `onEvent({msg, value})` | The user did something. `msg` is whatever the plugin attached; `value` is the control's current value. **One object**, like every export — a two-parameter version is a plugin whose controls do nothing in the app. |
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
  "abi": 3,
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

**`name`, `description` and every `label` may be an `l10n.` key**, resolved
against `l10n/<locale>.json` exactly like a string in a node. A manifest is one
document for every language, so writing them out means a plugin whose own rows
are translated and whose tab, button and install dialog are not.

```json
"name": "l10n.pluginName",
"contributes": { "page": { "id": "thing", "label": "l10n.pageLabel" } }
```

`en` is what a repository index carries — an index is one text file with no
locale — so `bun run pack` refuses a key `l10n/en.json` has no string for.

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
- **v3** — the set a page needs to look like the app around it.
  *Layout*: `flexible`, `align`, `center`, `wrap`, `stack`, `positioned`,
  `grid`; `main`/`cross` alignment on a row and a column; per-side `padding`.
  *Type*: named size, weight, `mono`, `max` and `select` on `text`.
  *Controls*: `checkbox`, `segmented`, `dropdown`, `slider`, `chip`, `menu`,
  `tabs`; `variant`/`icon`/`busy` on `btn`; `icon`/`lines`/`keyboard` and
  `onSubmit` on `input`; `selected` on `tile`; `onLongPress` on any node.
  *Display*: `banner`, `badge`, `tooltip`, `skeleton`, `pieChart`, and real line
  and bar charts.
  *Host*: `refresh` and `dismiss`, and a `sb.ui.prompt` whose body is a node
  tree — as a dialog or as a sheet.

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

### The loop

```sh
bun run dev        # rebuilds dist/ on every save
```

Point the app at the plugin's directory once (Settings → Plugins → add a
development directory) and **it reloads when the files change** — no restart, no
repack, no navigating back. It is Flutter's hot *restart* rather than hot
reload: the plugin's state lives in its JavaScript instance and there is nothing
to carry across a new script.

`console.log` works and goes to the app's log, with `warn` and `error` at their
own levels — as does `sb.log.*`, which is the same thing with a name. An
uncaught throw draws the message and the plugin's stack in place of the surface,
whole and selectable.

A development directory is desktop-only, for the reason it exists: a phone has
no directory anybody edits files in.

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
