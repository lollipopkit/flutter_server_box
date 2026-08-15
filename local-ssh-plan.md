# Local shell plan

The SSH tab becomes the Terminal tab, and a terminal stops meaning "a shell on
another machine". Three things, in increasing order of cost:

1. a shell on **this** machine, where the OS has one to give;
2. a Linux **rootfs** the app carries, on the two platforms that have no shell
   worth reaching (iOS, and Android's toybox);
3. a **package manager** in it, which is where the platforms stop cooperating.

Two consumers, not one: the terminal the user types into, and the **agent**,
which has to be able to run commands and read and write files here as well as
on a server. The agent turns out to be the reason to do this properly rather
than bolting a second path on — see [Agent mode](#agent-mode).

Step 1 was a week. Step 3 on Android read as blocked by a documented OS
restriction until it was measured — it is not, and it is done. Step 3 on iOS is
still a GPLv3 emulator plus an App Store review argument. This document is what
is known, what is guessed, and what has to be measured before any of it is
committed to; the measurements are kept where they were made rather than
summarised away.

**Status: stages 1, 2, 2b and 3 are done. Stage 4 is done on Android; its iOS
half is not started.**

| Stage | State |
| --- | --- |
| 1 — rename, local backend | done and **exercised**: `dd9b6e84`, `3d1acd6a`, `5fc31b8e`, `6e9d3d1b`, `df5fb7e7`, `79782d73` |
| 2 — Android host shell | done and **exercised** on an API 36 emulator: the Device entry opens `/system/bin/sh` |
| 2b — the Agent off SSH, and onto this device | done: `328f92d9`, `f1b869c1`, `95aa2c30`, `c6c728f1` |
| 3 — measure Android's `execve` | done: `integration_test/android_exec_test.dart`, and the answer is below |
| 4 — rootfs | **Android done**: `lib/core/utils/android_rootfs.dart`, an entry in the terminal tab, and `integration_test/rootfs_shell_test.dart`. iOS not started |

Stage 1 is no longer only analysed. `integration_test/local_shell_test.dart`
runs inside a real app, which is the only place an FFI plugin loads, and covers
a shell answering, starting in the home directory, reading the user's files,
a command run beside it, and closing ending it. It **skips itself** where the
build claims no local shell, so it means "wherever this is offered, it works".

What a local terminal deliberately does **not** offer, each decided rather than
left to fail:

| | Why |
| --- | --- |
| tmux | The control channel writes a command and reads to a marker, so it needs a channel that does not echo. `LocalShellBackend.execute` is a pseudo-terminal, which echoes |
| snippets that name a server | `${host}`, `${user}` have no answer here. The ones that name none *are* offered — `Snippet.needsServer` |
| SFTP | A file browser on this device already exists, in the file tab |
| the agent panel in the terminal | Its tools name a server. The Agent tab reaches this device instead |
| the sudo button | The shell is already whoever is running the app |

## The seam already existed — done

`ShellBackend` (`lib/data/model/server/shell_backend.dart`) is the interface a
terminal is written against: open a shell, resize it, read bytes, ping it.
`SshShellBackend` and `MonitorShellBackend` were the two implementations; a
local shell became the third, and nothing above `TerminalSession` had to learn
about it.

What needed work was that `TerminalSession` was constructed from a `Spi` — for
the terminal environment and tmux `LANG`, for which backend to build, for the
page title and tab name, and for whether to offer the sudo-password button.

A local session has no server, so it took the shape the file tab uses: one
sealed class, a local case and a remote one, two ways to reach something and no
other difference the page cares about. That is `TerminalSource`
(`lib/data/ssh/terminal_source.dart`) — `ServerSource` and `LocalSource`, the
second with a `rootfs` flag, since the Linux userland is still this device.
`TerminalSession` takes one of those rather than a `Spi`, and the page reads
its title and identity from the session.

One line of that table did not survive contact: the server id was also the
restoration bucket's name, and Flutter's restoration turned out never to have
worked in this app at all — measured, `bucket == null`, because
`MaterialApp.home` builds its route without a restoration id. The tab set lives
in `Stores.history.sshTabs` now. See TODOS.md for the three places still using
the dead mechanism.

The rename itself was two string literals in `home_tab.dart`.

## Agent mode

The agent has to run commands and touch files here too. It could not, and the
reason was not the missing local backend — it was that the agent had never
adopted the abstraction the rest of the app runs on. `AgentShellHandle` carried
an `SSHClient`, so a local case had nowhere to go, and a monitor-only server was
refused with

> Server X has no SSH credential, so it cannot run commands. It reports status
> over its monitor agent only.

for a machine `MonitorExec` could already run commands on. One coupling, two
symptoms. Done in 2b: the handle carries a `ServerExec`, and "this device" is a
third case of the sealed `AgentSshTarget` rather than a reserved `server_id`
string — the compiler lists what has to answer for it, and a device is not a
server with a magic name.

| Tool | On a server | On this device |
| --- | --- | --- |
| `run_shell_command` | `ServerExec` | `LocalExec` — pipes, not a pty, so the two streams stay apart |
| `read_file` / `write_file` | SFTP | `dart:io` `File`. On Android, inside the rootfs and nowhere else (`AndroidRootfs.hostPathOf`); elsewhere, whatever the platform lets the app reach |
| `serverbox` | connection state | not applicable; the device is always "connected" |

### Safety is a different question here

Running model-authored commands on a server the user deliberately configured is
one risk. Running them on the device the app itself lives on is another: the
Hive stores, the private keys and the keychain are all on that filesystem.

`AskAiCommandRisk` is a regex allowlist with
`canAutoRun => modelSafeToRun && risk == readOnly`. That is a reasonable gate on
*auto-running*. It is not a sandbox, and it should not be asked to be one. It
has since grown two values that withhold auto-run without claiming anything
about the command — `unknown` for what the allowlist did not recognise, and
`unvettedHost` for a recognised read-only command on a host met this
conversation. One verdict per cause, because a badge reading "changes system"
over a `sleep` is the app contradicting the model.

Positions to take before writing any of it:

- local execution **off by default**, opt-in per install;
- **never auto-run locally**, whatever `askAiAutoRunSafeCommands` says — the
  setting is about servers;
- once stage 4 exists, prefer running the agent's local commands **inside the
  bundled rootfs** rather than on the host. The rootfs is the sandbox, and this
  is the argument for building it that has nothing to do with iOS.
  **Done on Android**, and not as a preference: there the local target *is* the
  container or there is none. `LocalExec(inRootfs:)` runs commands through
  proot, and `AndroidRootfs.hostPathOf` maps the file tools' paths into the
  rootfs and refuses anything outside it — including a symlink out, which one
  reviewed `ln -s` would otherwise have made readable by the one pair of tools
  that is deliberately not reviewed.

On iOS there is no host shell at all, so for that platform "the agent can run
code locally" *means* the rootfs. The capability lands per-platform, the same
way the terminal's does, and `ServerCapabilities` is the existing place to ask.

## What each platform can actually do

| | shell on the host | rootfs + package manager |
| --- | --- | --- |
| Linux | `flutter_pty` | unnecessary — it is Linux |
| Windows | `flutter_pty` (ConPTY) | unnecessary — WSL exists |
| macOS | `flutter_pty`, **DMG build only** | unnecessary |
| Android | `/system/bin/sh`, toybox only | **done** — Alpine under proot, see below |
| iOS | impossible — no `fork`/`exec` for App Store apps | only via an interpreter |

`flutter_pty` is MIT, covers all five platforms, and is the obvious choice for
step 1. It is also marked *experimental* by its publisher and was last released
about 19 months ago (0.4.2). Its claimed iOS support is not useful here: iOS
has `forkpty` in the SDK, but there is no `/bin/sh` in the sandbox and no way to
exec an unsigned binary.

### macOS: two products, because the sandbox cannot host a terminal

Measured, and not what this document first assumed. A sandboxed process cannot
open a pseudo-terminal's slave device at all: `Process.run` succeeds, the
`forkpty` child exits 255 before it can exec, and neither a
`home-relative-path` nor a `/dev/` absolute-path exception changes it. Home
access was never the obstacle, so the entitlement added for it bought nothing
and was reverted (`ccd2e77b`).

iCloud was the other assumption, and also wrong: unsandboxed, the ubiquity
container resolves and an upload/list/delete round trip works. Dropping the
sandbox costs nothing there.

The App Store requires the sandbox, so macOS ships **two products** from one
binary (`52a0ec1b`):

| | App Store | DMG |
| --- | --- | --- |
| entitlements | `Release.entitlements`, sandboxed | `ReleaseDmg.entitlements`, not |
| applied by | the Xcode project | `CODE_SIGN_ENTITLEMENTS` in the release script |
| local terminal | absent | present |
| data | `~/Library/Containers/<id>/Data/Documents` | `~/Library/Application Support/ServerBox` |

No flavour, no second scheme, no second bundle id: the two differ in one
entitlement, and `LocalShellBackend.isSandboxed` asks the running process which
it is. Debug and Profile match the DMG (`ad6aa5b8`), so the feature is
reachable from `flutter run`; `test/macos_entitlements_test.dart` holds all of
that in place.

The data directories differ, which is its own problem — see `SandboxImport`,
and the migration TODO in `TODOS.md`.

## iOS: ish-arm64, not iSH

Upstream [iSH](https://github.com/ish-app/ish) emulates **32-bit x86** with a
threaded-code interpreter. As a Linux environment on an ARM phone it is a
curiosity — every guest instruction is a cross-architecture translation.

OpenMinis does not use it. Its `.gitmodules` points at
[OpenMinis/ish-arm64](https://github.com/OpenMinis/ish-arm64), which the README
describes as adding *"a native ARM64 guest backend to upstream iSH's
threaded-code interpreter"*.

| | upstream iSH | ish-arm64 |
| --- | --- | --- |
| guest architecture | x86 (32-bit) | aarch64 |
| rootfs | Alpine x86 | Alpine 3.21 aarch64 |
| dispatch | cross-architecture | same-architecture |
| claimed speedup | — | C arithmetic 12x, Python recursion 9.2x, Python sum 10.2x, shell 7.2x |

Same-architecture dispatch is the whole point: each guest instruction maps to a
small hand-written native gadget, so per-instruction overhead is dispatch and
little else. It is still **not a JIT** — the README is explicit that it "doesn't
emit machine code at runtime" — because App Store apps do not get the JIT
entitlement on iOS. Expect an interpreter's floor, not native speed.

The speedup figures are the fork's own benchmarks. Unverified.

Integration is not small: meson produces `libish.a`, `libish_emu.a`,
`libfakefs.a` and a guest VDSO (which needs llvm to build), consumed by an
Xcode project; a filesystem has to reach the device. That is a vendored GPLv3 C
codebase inside a Flutter app, with its own build step in CI for a platform
that currently has none.

### Measured: the engine builds for iOS and runs Alpine in the simulator

`scripts/build-ish-ios.sh`, which pins the fork to a commit and Alpine to the
same 3.22.5 aarch64 release the Android rootfs uses.

| | Result |
| --- | --- |
| the three libraries, `-isysroot iPhoneSimulator` | build clean; `LC_BUILD_VERSION platform 7` |
| a CLI hand-linked against them, run under `simctl spawn` | `3.22.5`, `aarch64`, `root` |
| the same engine built for macOS, for comparison | the same, and it is what builds the filesystem |

So the interpreter works when built for the iOS platform triple, which was the
first thing that could have stopped this. What it does **not** show: the
simulator is not a sandboxed device, and nothing here has been near App Store
review. The device build (`scripts/build-ish-ios.sh device`) compiles but has
not been run.

### The shim, and the switch that removes it

`ios/Runner/ish/sbm_ish.{h,c}` is the whole app-facing surface: `available`,
`boot`, `read`, `write`, `resize`, `exit_code`. Measured in the simulator —
`available=1`, `boot=0`, and `3.22.5 / aarch64 / root` back through it.

Three things it had to get right, each found by getting it wrong:

- **The boot runs on the guest's own thread.** `current` is thread-local and
  `xX_main_Xx` sets `current->thread = pthread_self()`, so booting on one
  thread and running `task_run_current()` on another is two tasks, one of them
  missing. `sbm_ish_boot` starts the thread and waits for it to report.
- **The console is a tty driver of ours**, installed *after* `xX_main_Xx` —
  which sets the host's own driver and builds stdio from it — and then
  `create_stdio` again. Otherwise the guest writes to the app's stdout, which
  belongs to the app's logs and is invisible to a terminal.
- **Output goes to a ring buffer, not a pipe.** A guest write must never block
  on nobody reading: a terminal on a page that is off screen is exactly that,
  and a blocked write inside the interpreter stops the whole guest.

The switch is `SBM_ISH` in `ios/Flutter/Ish.xcconfig`, and it is the reason the
shim is a C file with a preprocessor guard rather than a plugin. At `0` the
file compiles to stubs, no library is linked, no header path is added, and
`sbm_ish_available()` answers false — which is the same question the Dart side
already asks on Android before offering anything. Setting it and rebuilding is
the whole procedure, because what 2.5.2 blocks is not the feature but the next
update, and that is not the moment to be refactoring. It defaults to `0`: the
engine is not in this repository, so a checkout that has not run the build
script cannot link it, and a build that silently omitted it would be worse than
one that never tried.

### In the app: the engine is there, the guest does not start yet

`sbm_ish.c` is in the Runner target and `IosRootfs` (`dart:ffi`) reaches it.
Measured in the simulator, inside the app: `IosRootfs.isAvailable` is **true**,
so the symbols resolve in the running process and the switch is doing what it
says. Two things the wiring needed, both found by measurement:

- **The exported functions must be kept.** Nothing in the app calls them —
  Dart looks them up by name — so the linker dead-strips all six and the engine
  with them. The first build with the switch on produced a 58 KB binary with no
  `sbm_ish` symbol in it. `__attribute__((used, visibility("default")))` fixes
  it; in a Debug build the result lands in `Runner.debug.dylib`, not `Runner`.
- **The engine's headers need C11.** They use file-scope `static_assert`, which
  under Xcode's default standard parses as a declaration with no type. Meson
  builds with `-std=gnu11`; the xcconfig now sets the same, and only when the
  switch is on.

**The guest now boots inside the app**: `sbm_ish_boot` returns 0, measured in
the simulator. Getting there meant dropping `xX_main_Xx` and doing what
OpenMinis does — it ships this engine in an app, and `src/ios/iSH/ISHKernel.m`
is the reference:

- `mount_root(&fakefs, <root>/data)`, `become_first_process()`,
  `current->thread = pthread_self()`, the device nodes, `/proc` and `/dev/pts`,
  the exit hook, our tty driver, `set_console_device`, `create_stdio`,
  `do_execve` — the same sequence, without the command-line parsing and
  without the host tty driver `xX_main_Xx` installs.
- **`task_start(current)`, not `task_run_current()`.** The second turns the
  calling thread into the guest and never returns, which is right for a CLI and
  a hang for anything with a caller. The first gives the guest its own thread,
  so `sbm_ish_boot` can be an ordinary function call.
- **The crash handler is not optional**, and an embedded one differs from the
  CLI's twice over: it must not intercept signals on threads that are not the
  guest's (`ish_thread_marker`), and it must not `_exit`, because that is the
  app. `die_handler` needs replacing for the same reason — the default calls
  `abort()`.

**It answers.** Inside the app on the simulator, the guest prints its own
prompt, takes a typed command and sends back `3.22.5`, `aarch64`, `root` and
the marker — `integration_test/ios_rootfs_test.dart`, and the whole chain is
Dart → FFI → the engine's tty → Dart.

The thing that stood between was not a deadlock and not the interpreter.
`kernel/exit.c` ends the **host process** with `_exit(0)` when init dies, and
the first design made the caller's command init: the guest booted, the command
ran, and the app was gone before a byte of output could be read. It looked
exactly like a hang — the test "did not complete" instantly, no crash report,
nothing in the log, because a clean `_exit` leaves none of those.

So **init is a shell that stays**, and a command is typed at it. Two
consequences worth stating rather than discovering later:

- a guest that exits ends the app. Answered: init is `while :; do /bin/sh; done`,
  so nothing a user types can end the process, and `exit` gives them a new
  shell — which is what closing a terminal does on any other machine.
  Verified: typing `exit` leaves the app alive and prints another prompt;
- Enter is a **carriage return**. Writing a newline leaves the shell holding
  the line, because the line discipline is what turns CR into NL.

Reading must not block the isolate either — `sbm_ish_read` waits for its
timeout, and doing that on the Dart thread starves the framework. The test
polls; a terminal needs the reader off that thread entirely.

A useful thing fell out of the attempt: `Process.run` is refused on iOS *even
in the simulator* — "Starting new processes is not supported on iOS". The
staging step had to be rewritten in `dart:io`. That is the platform restating
why it gets an interpreter.

### What is left, and what only a device can answer

Done since: `IshShellBackend` is a `ShellBackend` over the six functions,
reading on a 16 ms timer because a blocking read on the Dart isolate starves
the framework; `Rootfs` is the facade the terminal tab asks, so the entry, the
rail and the restore path are one code path across both platforms; and
`Rootfs.prepare()` runs at launch on either.

Two things are deliberately not hidden behind that facade. `supportsExec` is
**false** here — there is one console, and a second command would interleave
its output with the terminal's — and closing a terminal does not stop the
guest, because the guest is the machine and cannot be started twice in one
process.

### Two design changes, researched

Both proposals hold up, and the engine already has the mechanism for each.

**A real directory tree instead of the sqlite one.** iSH ships two filesystems:
`fakefs` (opaque host files plus a `meta.db` holding every mode, owner and
symlink) and **`realfs`** (`fs/real.c`) — which is exactly "hijack the IO and
move the root": every guest path is `openat`'d relative to a root fd, and
nothing is stored beside it. The CLI picks between them with `-r` and `-f`.

Choosing `realfs` deletes the shipping blocker outright: installing becomes
"unpack a tarball into a directory", which Dart can do, with no `fakefsify`, no
libarchive and no metadata db to build on a phone. It also makes the guest's
files ordinary files — inspectable, backup-able, and something the Files app
could be pointed at later.

What it costs, read out of the source rather than assumed:

| | Under `realfs` |
| --- | --- |
| device nodes | `realfs_mknod` returns `_EPERM` for anything but a FIFO or a regular file — so `/dev/null`, `/dev/urandom`, `/dev/ptmx` cannot live in the tree. **The open question**: `/dev` needs its own mount, and the CLI only creates those nodes when the root is *not* realfs |
| ownership | `chown` is silently ignored when it fails with `EPERM`, which it will — the app is one uid. Harmless while everything in the guest is fake-root, and a lie `apk` does not check |
| modes | real `chmod` on the host, so the execute bit and the rest survive |
| symlinks, hard links | real ones; APFS has both |
| case | iOS's data volume is case-sensitive, so a Linux tree is fine **on a device**. The *simulator* borrows the Mac's volume, which is case-insensitive by default — `xX_main_Xx` tries `setiopolicy_np(...CASE_SENSITIVITY...)` for exactly this and says it needs root or a private entitlement, neither of which an App Store app has. So this is a simulator problem, not a shipping one |

**A shell each, not one shared console.** Also right, and not a limitation of
the engine — the limit was my console, not the guest. One guest holds many
tasks, and OpenMinis gives each command its own pty:

```
become_new_init_child();                                   // a task under init
struct tty *tty = pty_open_fake(&ish_pty_driver);          // its own pty
tty_set_winsize(tty, winsize);
create_stdio("/dev/pts/N", TTY_PSEUDO_SLAVE_MAJOR, tty->num);
do_execve(...); task_start(current);
```

That makes `supportsExec` true, gives the terminal and the Agent separate
channels, and removes the marker protocol the Agent would otherwise need. It
also makes closing a terminal ordinary: each is a child of init, and init stays
the loop that nothing can end.

**The first is done.** The guest boots on `realfs` with a tmpfs at `/dev`,
verified in the simulator against a plain unpacked tree — no `fakefsify`, no
metadata db, nothing but `tar`. `scripts/build-ish-ios.sh` unpacks one;
`IosRootfs.isInstalled` asks for a shell and a release file rather than a
manifest, because there is no manifest to ask.

One thing it cost, worth knowing before writing the installer: **symlinks must
be preserved, not followed**. Under `realfs` a guest link is resolved inside
the guest, so `/bin/sh -> /bin/busybox` means the guest's busybox; followed on
the host it points at the host's `/bin`, which is the wrong file or none. The
first attempt booted to `ENOENT` with no `/bin/sh` to run. `tar` gets this
right; a naive recursive copy does not.

**The second is done too.** A session is now a process in the machine with a
pty of its own — `become_new_init_child`, `pty_open_fake`, `create_stdio` on
`/dev/pts/N` — so `IshShellBackend.supportsExec` is true and two sessions
cannot land on each other's output. Verified: one session reports Alpine's
version, a second one running at the same time sees only its own marker.

**`/dev` is the piece that did not fall out.** The nodes are still missing, and
the reason is worth keeping because it is not obvious:

| Filesystem | Can it hold a device node |
| --- | --- |
| `realfs` | No — `realfs_mknod` refuses anything but a FIFO or a regular file, since creating one needs root on the host |
| `tmpfs` | **No** — it has no `mknod` operation at all |
| `fakefs` | Yes, and only it: `rdev` lives in its database, which is what this design set out to remove |

So `/dev` exists and is empty, `/dev/pts` works (devptsfs is its own
filesystem), and `/dev/null` and friends do not. Three ways out:

1. **Add `mknod` to `tmpfs`** in the vendored engine. It is in-memory and
   already stores a mode per node; `rdev` is one more field. The smallest
   change, and the one that keeps `/dev` where it belongs — but it is a patch
   to carry against upstream.
2. **Mount a small `fakefs` at `/dev`.** Only a dozen nodes, so the database is
   tiny — but the app would have to create one, and the schema lives in the
   host tool rather than in `libfakefs`.
3. **Ship a prebuilt `/dev`** in the bundle and mount it. No new code, and a
   read-only `/dev` that cannot grow a node the guest asks for later.

Nothing works around it in the meantime: a shell without `/dev/null` fails at
the first `2>/dev/null`. `integration_test/ios_rootfs_test.dart` carries the
test for it, skipped, ready to be turned on.

What is left:

1. **A filesystem on the device.** `fakefsify` is a host tool: it needs
   libarchive and writes a sqlite metadata db, so nothing today puts one on a
   phone, and the terminal entry says so rather than opening a shell with
   nothing to run. Two ways, neither free: ship a built filesystem in the
   bundle (tens of megabytes in the IPA, and it must be copied out of the
   read-only bundle before the guest can write), or compile the extraction into
   the app and do it at first launch, as Android downloads and unpacks. The
   piece that makes the second possible is already in the library —
   `fakefs_rebuild(struct fakefs_db *, int root_fd)` derives the metadata db
   from a tree, so the app only has to unpack a tarball, which Dart can do.
   **Until this exists the feature cannot ship**, whatever else works.
2. **The Agent's local target on iOS.** The same shape as Android's — the
   container is the only local machine and the file tools resolve inside it —
   but it needs a second channel, which one console does not have. Either the
   engine spawns a task per command (what OpenMinis' `ISHShellExecutor` does)
   or the Agent types into the same shell behind a marker protocol. Neither is
   written.

### Manual verification — nobody has done these

Everything measured so far is on the **simulator**, which is not a sandboxed
device and has no App Store in front of it. These need hands:

| # | What | How | Why it cannot be automated here |
| --- | --- | --- | --- |
| M1 | The engine runs on real hardware | `scripts/build-ish-ios.sh device`, `SBM_ISH = 1`, run `integration_test/ios_rootfs_test.dart` on an iPhone | No device build has ever been run. The simulator shares the Mac's kernel and page protections; a phone does not |
| M2 | Memory and thermals under load | A real workload — `apk add`, a build, a long-running process — watched in Instruments | An interpreter with a 256 KB output ring and a guest heap on a phone is a different proposition from one on a Mac |
| M3 | The performance figures (Q3) | `benchmark/run.sh` inside the guest, on a device | The fork's 7–12x claims are its own benchmarks, and the numbers that matter are the ones on the hardware users have |
| M4 | The strip switch produces a clean build | Build an IPA with `SBM_ISH = 0`, then search the binary for `sbm_ish_boot` and any engine symbol | This is the emergency path. It has been checked at the object level, never on a shipped artifact |
| M5 | App Store review | Submit, with the feature on, and see | Guideline 2.5.2. Not a technical question, and the downside is the app's next update rather than the feature |

M5 is the one that decides whether any of the rest is worth finishing, and it
is the reason the switch exists.

### What is left
- a filesystem on the device. `fakefsify` is a host tool that needs libarchive
  and writes a sqlite metadata db, so either the built filesystem ships in the
  bundle or that tool's job is done on the phone at first launch;
- the terminal and the Agent wired to it, which is where the Android work
  already ends up: a `ShellBackend` and a `ServerExec`.

One design consequence to settle before that last point: the kernel keeps its
state in globals, so there is **one guest per app process**. A second
`sbm_ish_boot` is refused rather than allowed to corrupt the first. A terminal
and the Agent therefore share one machine, and running two things at once means
two processes *inside* the guest, not two guests.

## Android: the wall, and the way through it

Android 10 removed execute permission on the app's own data directory. From
[the behaviour-changes doc](https://developer.android.com/about/versions/10/behavior-changes-10):

> Untrusted apps that target Android 10 cannot invoke `execve()` directly on
> files within the app's home directory.

Binaries shipped in the APK are fine — `nativeLibraryDir` is read-only and
executable, which is why proot is packaged into `jniLibs/arm64-v8a/`. The worry
was the package manager: it exists to write **new** binaries into the rootfs,
the rootfs is in the data directory, and so `apk add` would succeed and the
thing it installed would not run.

It does run. Nothing the guest installs is ever `execve`d by the kernel — proot
maps it — so the rule never applies to it. Measured: `apk add curl` inside the
container, then `curl --version`, on an API 36 emulator
(`integration_test/rootfs_shell_test.dart`).

### Measured, on an API 36 emulator with the app targeting 36

`integration_test/android_exec_test.dart`. One binary in two places, so the
location is the only variable, and then the same question for a rootfs's libc.

| | direct exec | via `/system/bin/linker64` |
| --- | --- | --- |
| bionic `sh`, copied into `/data/user/0/<pkg>/files` | **denied**, errno 13 | **works**, exit 0 |
| the same, on external storage | denied | fails at mmap — that volume is `noexec` whatever the target SDK |
| aarch64 **musl** busybox, internal | denied | `library "libc.musl-aarch64.so.1" not found` |
| the same, with `LD_LIBRARY_PATH` at its own libc | — | **SIGSEGV** |
| the same, chaining musl's own loader through `linker64` | — | `Could not find a PHDR: broken executable?` |

So the widely repeated workaround is **real**: W^X refuses `execve` on the app's
own directory, and Android's dynamic linker maps the file instead. Q1 is
answered, and route 2 below is not needed for bionic binaries.

It does **not** reach an Alpine rootfs. `linker64` is bionic's loader; with a
search path it finds musl's libc and then crashes, because a musl binary
expects musl's own loader to have set up its runtime. Chaining musl's loader
through `linker64` fails earlier still. Mixing the two libcs does not work, and
nothing here suggests it can be made to.

### Settled: an Alpine rootfs runs, on targetSdk 36, today

`integration_test/android_rootfs_test.dart`, same emulator. A real Alpine
aarch64 minirootfs unpacked into `/data/user/0/<pkg>/files`:

| | Result |
| --- | --- |
| `busybox` directly | denied, errno 13 |
| via `/system/bin/linker64` | `library "libc.musl-aarch64.so.1" not found` |
| **under proot** | **exit 0** |
| a shell reading the rootfs's own files | the release it was unpacked from, `aarch64` |

PRoot never asks the kernel to `execve` a guest binary. It carries a loader
whose job is to map the guest ELF and hand control to the guest's own
interpreter, so nothing on the host has to understand musl — which is exactly
what failed above.

Two requirements, both found by getting them wrong first:

- **`useLegacyPackaging = true`.** Native libraries are mapped straight out of
  the APK when `minSdk >= 23`, so nothing is extracted and there is no
  executable file for a helper binary to be. Without this, `nativeLibraryDir`
  does not exist and there is nowhere to put proot.
- **Ship proot's loader too, and name it in `PROOT_LOADER`.** Left alone, proot
  extracts the copy bundled in its own binary to a temp file — which lands in
  the app's directory, cannot be executed, and proot falls back to a plain
  `execve` and is refused. This is what the first attempt did, and it failed
  with `proot error: execve("/bin/busybox"): Permission denied`, which reads
  like the wall and is not.

So the Android half of stage 4 was **not blocked**, and it is now built. What it
cost: a proot build in CI for one ABI (`scripts/build-proot-android.sh`, run
from `.github/workflows/build.yml`, which then checks both binaries actually
reached the APK), an Alpine tarball fetched and digest-checked on first use
rather than shipped as an asset, `useLegacyPackaging` — and the guest's
environment, because `PATH` has to be the rootfs's or a shell finds none of its
own tools.

Still not reproduced on physical hardware, and not with an app the Play Store
has seen.

The three routes this document weighed before the measurement are recorded
because the reasoning still applies if proot ever stops working:

| Route | Cost |
| --- | --- |
| `targetSdk` 28 | What Termux does on F-Droid. Google Play requires a recent target, so this ends Play distribution |
| An in-process ELF loader — map segments into anonymous `PROT_EXEC` memory, never call `execve` | Same architecture, so no emulation needed, only loading. But `fork`/`exec` inside the guest then has to be implemented by hand. Large |
| Android Virtualization Framework | Real Debian VM, `pKVM`, GPU access. Behind a developer option, `MANAGE_VIRTUAL_MACHINE` is privileged, Samsung does not support AVF. Not reachable from a third-party app today |

There is a widely repeated fourth — invoking `/system/bin/linker64` on a file in
app data — and it is the one measured above. It works, and it does not reach a
musl rootfs, so it settles the question without opening the door.

OpenMinis was the confusing data point: SDK 35, an Alpine minirootfs plus proot,
and a fork described only as "patches applied to work better under Termux".
Answered — it is proot's own loader, and it is what this app does now.

## Licensing and review

This project is **AGPL-3.0** (`LICENSE`), which settles most of it:

- **ish-arm64 is GPLv3** and would be statically linked. Compatible, and the
  obligation it brings — publish the whole app's source — is already met.
- **proot is GPLv2 *or later*** — checked in the source headers, not in
  `COPYING`, which only carries the v2 text either way. It is invoked as a
  separate process rather than linked, so it is aggregation; and even if that
  changed, "or later" lets it be taken as GPLv3, which this AGPL-3.0 app can
  combine with. Shipping the binary means offering its source.
- **Apple's terms conflict with the GPL** — this is what removed VLC from the
  App Store. iSH ships a `LICENSE.IOS` waiver in which the copyright holders
  undertake not to enforce over that conflict alone
  ([copy in ish-AOK](https://github.com/emkey1/ish-AOK/blob/working/LICENSE.IOS)).
  It waives Apple's obstacle, not the GPL's own requirements.

The live risk is **App Store guideline 2.5.2**. iSH was told four days after
launch that it would be pulled for downloading and running executable code;
Apple reversed after an appeal, and only after arguing a shell is educational
([ish.app](https://ish.app/blog/app-store-removal),
[Michael Tsai's summary](https://mjtsai.com/blog/2020/11/09/ish-and-a-shell-vs-the-app-store/)).
The rule is being enforced hard again in 2026. A server-management app that
ships a package manager is a harder case to argue than a shell app was, and the
downside is not the feature being rejected — it is the whole app's update being
blocked.

## Stages

**1. Rename, and the local backend on desktop.** `libL10n.terminal` in
`home_tab.dart`; `LocalShellBackend` on `flutter_pty`; `TerminalSession` takes a
backend rather than a `Spi`; the tab's session model grows a local case. Gate
macOS on the sandbox decision. Independent of everything below.

**2. Android host shell.** `/system/bin/sh` through the same backend. No rootfs,
no package manager, toybox only — but it is a real shell and it costs almost
nothing once stage 1 lands.

**2b. Change `AgentShellHandle`'s payload to `ServerExec`, then add a local
target.** Done.

*First half (`328f92d9`).* The handle carries a `ServerExec` beside an optional
`SSHClient`, `_connectedServer` asks `ServerNotifier.ensureExec()` instead of
demanding a client, and the monitor-only refusal is gone. Cancellation moved
into `ServerExec.run(cancel:)`, because killing an `SSHSession` from outside
was the one thing tying the agent to SSH. **Verified** against the monitor-only
debian VM: a command runs, a file read is refused with a way forward, and stop
reports cancelled.

*Second half (`f1b869c1`, `95aa2c30`, `c6c728f1`).* `LocalExec` — pipes, not a
pty, so the two streams stay apart and nothing has to be stripped before it can
be parsed. A third `AgentSshTarget` case behind two gates: the platform, and a
setting that is off until asked for. Auto-run is barred here whatever
`askAiAutoRunSafeCommands` says. The file tools use `dart:io` rather than `cat`
and `tee`, because reading a file is not a command and should not go through
command review. The model is not told this machine exists unless both gates
pass. The seam is now exercised on a device — `rootfs_shell_test.dart` runs
commands through `LocalExec` on Android and checks both streams and the
filesystem it sees. What is still unexercised is a *model* driving it: that
needs an API key, so it is the user's to run.

**3. Measure the Android execution question.** Done — see
[the measurement](#measured-on-an-api-36-emulator-with-the-app-targeting-36).
`execve` from the app's own directory is refused, Android's linker runs a
bionic binary from there and segfaults on a musl one, and proot sidesteps the
whole question with a loader of its own. Stage 4's Android half is vendoring
proot and measuring it, not writing a loader.

**4. Rootfs.** Android is done. Alpine 3.22.5 aarch64, downloaded and digest-checked
on first use into `getApplicationSupportDirectory()`, entered through proot from
`nativeLibraryDir`; `apk add` installs over the network. Two things had to be
found by failing first: `useLegacyPackaging = true`, or nothing is extracted
from the APK and there is no `nativeLibraryDir` at all; and shipping
`libproot-loader.so` and naming it in `PROOT_LOADER`, or proot falls back to
`execve` and is refused. One thing is pinned rather than solved: Alpine 3.23 and
later ship apk-tools 3, whose network fetches fail under proot with `Permission
denied` on every repository while busybox `wget` fetches the same URLs — cause
not established, so the branch is 3.22, the last with apk-tools 2.14.

iOS via ish-arm64 is the half still open. The engine part of it is no longer
unmeasured — it builds for the iOS triple and runs Alpine in the simulator, see
above — but wiring the Xcode target, bridging it to Dart, getting a filesystem
onto the device and adding an iOS build step to CI are all still to do. That
half carries the review risk; treat it as a separate decision, not a
continuation.
It is also what turns the agent's local execution from "on the user's
filesystem" into "in a sandbox", which may be the strongest reason to build it.

Stages 1, 2 and 2b are worth doing whatever happens to 3 and 4.

## Verification log

Update this as answers arrive; several decisions above move with them.

| # | Question | How to settle it | Status |
| --- | --- | --- | --- |
| 1 | Can a `targetSdk` 36 app exec a file in `filesDir` via `linker64`? | **Yes for a bionic binary, no for a musl one** — measured on an API 36 emulator, `integration_test/android_exec_test.dart`. Direct `execve` is denied; the linker maps it and runs it. A musl binary segfaults once its libc is found, because it wants musl's own loader. Unverified on physical hardware | **done** |
| 2 | How does OpenMinis run rootfs binaries at `targetSdk` 36? | **Answered**: proot's own loader, extracted via `/proc/self/fd` and mapping the guest ELF itself, so the host linker is never asked to understand musl. `RootfsManager.kt:42`, `PRootKernel.kt:83`. Not reproduced here | **done** |
| 3 | Are ish-arm64's 7–12x figures representative? | Not yet measured. The engine now builds and runs (`scripts/build-ish-ios.sh`), so this is a matter of running `benchmark/run.sh` rather than of finding out whether it works at all | **open** |
| 4 | Does the macOS DMG build ship unsandboxed, or does local shell hide there? | **Answered, and the first answer was wrong.** A sandboxed process cannot host a pty at all, so the entitlement that was meant to fix it bought nothing and was reverted (`ccd2e77b`). iCloud turned out not to need the sandbox either. macOS ships two products from one binary (`52a0ec1b`), and the App Store one hides the feature | **done** |
| 5 | Is proot GPLv2-only or v2-or-later? | **v2 or later** — the source headers say "either version 2 of the License, or (at your option) any later version" (`src/tracee/tracee.h:9`, `src/cli/cli.c:9`). So it can be taken as GPLv3 and combined with this AGPL-3.0 app even if it were linked rather than invoked | **done** |
| 6 | Does `flutter_pty` still build against current Flutter on all four desktop/Android targets? | **macOS and Android build and run** — `local_shell_test.dart` on macOS, and on an API 36 emulator both the Device entry and the Alpine one open a shell through it (`rootfs_shell_test.dart`). Linux and Windows untried, and no physical Android device. One warning: `flutter_pty` does not support Swift Package Manager, which Flutter says "will become an error in a future version" — `sbm_ffi` is in the same list, so it is not a new exposure | **partly** |
| 7 | Would 2.5.2 be survivable for this app? | Cannot be settled in advance. Decide whether stage 4's iOS half is worth the update risk | **open** |
| 8 | Is local agent execution opt-in, and is auto-run barred locally? | **Answered** (`95aa2c30`, `c6c728f1`): both. `Stores.setting.agentLocalExec`, off by default, with a switch that is absent where the platform could not honour it. `AskAiCommand.onThisDevice` bars auto-run whatever the model or `askAiAutoRunSafeCommands` says | **done** |
| 9 | What can the agent's `read_file`/`write_file` reach locally per platform? | **Answered.** macOS: the DMG build reaches the whole home — measured; the App Store build offers no local target at all, and iOS the same. Android: nothing outside the rootfs, because the local target there *is* the container — `AndroidRootfs.hostPathOf` maps every path into it and refuses what leaves, symlinks included (`android_rootfs_path_test.dart`, and on a device in `rootfs_shell_test.dart`) | **done** |
| 10 | Does moving the agent to `ServerExec` change any recorded conversation's replay? | **No** — `agent_conversation_replay`'s tests pass unchanged across `328f92d9` and the local-target work. The recorded shape is the tool result, which did not move | **done** |
