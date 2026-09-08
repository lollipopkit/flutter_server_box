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
bun run pack      # dist/plugin.js and dist/<id>-<version>.sbp
```

`test/plugin_disk_usage_test.dart` in the app reads `dist/plugin.js`, so it
fails if the bundle is stale.
