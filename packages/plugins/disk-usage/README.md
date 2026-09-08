# Disk usage

Where the space went, one directory at a time — the question asked right after
`df` says 95%.

Answered by descending rather than by scanning: `du -x -d 1` on the directory
you are looking at, and again on whichever child turns out to be the large one.
A whole-tree scan answers the same question and takes minutes.

## What it demonstrates

- `contributes.page` with `onHook` collection, like the ports plugin.
- `sb.store` at `server` scope — the level you reached is remembered per
  machine, because "the big directory" is a property of the machine.
- `shellQuote`, which this plugin is the reason the SDK has. The path comes
  back out of a listing the *server* produced and goes straight into a shell
  command; a directory called `; rm -rf ~` is a legal directory name.

## Two things writing it found

**No cancellation.** `du` walks everything under what it reports on, so a big
directory is slow by construction. `sb.server.exec` takes a `timeoutMs` and
nothing else, so a level that is going to take four minutes cannot be
abandoned at one — it can only be given a shorter limit up front. A
`sb.server.cancel(handle)`, or an exec that answers something abortable, is
what this wants.

**A patch that lands nowhere must not stop the work.** `sb.ui.patch` rejects
when the surface is not on screen, which is right — a plugin streaming a log
should be able to tell. But awaiting it unguarded turns "nobody is watching"
into "the work stops": the first version of this drew `Measuring…`, threw, and
never ran the command. `draw()` swallows it. Worth knowing before writing the
next plugin.

## Building

```sh
bun install
bun test          # the command and the parser, and the plugin against MockHost
bun run build     # dist/plugin.js, plus a copy of manifest.json beside it
bun run pack      # the above, and dist/<id>-<version>.sbp
```

## Reading it honestly

`du` prints one line per directory it could not read, and this used to send
them to `/dev/null`. That made a `/` measured as an ordinary user report a
total quietly smaller than the `df` figure printed beside it — which reads as a
bug in the parser rather than as a fact about the account. They are counted
now, told apart from results by shape (a result is `<number>\t<path>`), and the
count is said next to the total: **the number is short by whatever is in
them.**

Rows are largest first, which is the question the page answers. **By name** is
for finding one you already know of, and the choice is remembered — an order
somebody chose is a preference, not a property of the directory they were in.

## Picking and deleting

Tap a directory to measure it; **Select** turns the same tap into picking, and
**Delete _n_** removes what is picked. Three things about that:

- The user is asked first, with the paths and the total listed. `sb.ui.prompt`
  with no fields is a confirmation, and the manifest asks for `ui.dialog`
  because of this and nothing else.
- Every path is quoted and `--` ends the options: a directory called `-rf` is a
  legal directory name, and it arrives here out of a listing this plugin asked
  the server for.
- The level is measured again afterwards rather than adjusted. What `rm`
  actually removed is a question for the machine, and every other row's share
  of the total moved with it.

Descending clears the selection. It describes what is in front of you, and
carrying it down would mean a delete that removes something off screen.

## Settings

The plugin contributes a page under **Settings → Plugins**, which is where its
own preferences live — not per server, so `sb.store`'s `global` scope. The page
is a surface like any other: `open` is called with `kind: "settings"`, and what
it draws comes from the store rather than from a machine.

## Translations

`l10n/en.json` and `l10n/zh-CN.json`; the manifest declares both and
`scripts/pack.ts` puts them in the `.sbp`. Every user-visible string goes
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

`test/plugin_disk_usage_test.dart` in the app reads `dist/plugin.js`, so it
fails if the bundle is stale.
