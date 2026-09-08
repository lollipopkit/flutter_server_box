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
bun run pack      # dist/plugin.js and dist/<id>-<version>.sbp
```

`test/plugin_scheduled_test.dart` in the app reads `dist/plugin.js`, so it
fails if the bundle is stale.
