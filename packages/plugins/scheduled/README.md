# Scheduled

What runs on a timer: the user's crontab and systemd's timers, and the one
change worth making from a phone.

## What it demonstrates

The first plugin here with a **write path**, which is most of what it is for.

- **Compare-and-swap.** A crontab is the only copy and anything on the machine
  may edit it — another client, a person over ssh, a config-management run. The
  read takes a `cksum` and the write refuses unless it still matches, in one
  command so nothing can land between the check and the write. A refusal is a
  word on stdout rather than an exit code: the caller needs "somebody else got
  there first", which is answered by reloading rather than by retrying. Same
  reasoning as the app's own custom-command directory.
- **The whole file, every time.** There is no way to edit one line of a
  crontab, and pretending otherwise is how a read-modify-write loses the lines
  it did not understand. So every line is kept verbatim and written back.
- **`ui.dialog`**, and a question that names the command rather than the line
  number: a person confirming this needs to see what stops running.
- Turning a job off is small and reversible. Editing the whole file is not, and
  is left to the app's own editor over SFTP.

Timers are read-only. Enabling one is `systemctl`, which needs root on most
machines — a plugin asking for that would be asking for far more than toggling
a line of the user's own crontab.

## What writing it found

**A comment is the commonest thing in a crontab**, and "five whitespace-
separated fields then a command" is also the shape of most English. The first
version allowed letters in a schedule field so `MON` and `JAN` would parse, and
`# run this every day at three` became a job. The names cron accepts are now
enumerated.

## Building

```sh
bun install
bun test          # the two commands, the parser, and the plugin against MockHost
bun run build     # dist/plugin.js, plus a copy of manifest.json beside it
bun run pack      # the above, and dist/<id>-<version>.sbp
```

## Editing

Tap a row to edit it, **Add** for a new job, and **Select** turns the tap into
picking so several can be removed at once. The `on`/`off` tag is its own
control, because the row's tap is the editor.

Every one of those is the same act: **there is no way to edit one line of a
crontab**, so all four replace the whole file, and all four go through one
compare-and-swap — `crontab -l | cksum` is read with the file and handed back
as `expect`. A machine whose crontab moved in between answers `conflict`, and
the reply to that is to reload rather than to write again. Writing anyway is
what loses somebody else's change.

Removing several is **one** write for the same reason: a second
compare-and-swap would meet the fingerprint the first had just changed.

The schedule is checked before anything is written, with the same rule the
reader uses. `crontab` accepts a line it cannot parse and simply never runs
it — this dialog is the only moment anybody finds out.

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

`test/plugin_scheduled_test.dart` in the app reads `dist/plugin.js`, so it
fails if the bundle is stale.
