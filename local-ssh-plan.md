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

Step 1 is a week. Step 3 on Android is blocked by a documented OS restriction
and step 3 on iOS is a GPLv3 emulator plus an App Store review argument. This
document is what is known, what is guessed, and what has to be measured before
any of it is committed to.

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

## The seam already exists

`ShellBackend` (`lib/data/model/server/shell_backend.dart`) is the interface a
terminal is written against: open a shell, resize it, read bytes, ping it. Two
implementations today — `SshShellBackend` and `MonitorShellBackend`. A local
shell is a third, and nothing above `TerminalSession` has to learn about it.

What does need work is that `TerminalSession` is constructed from a `Spi`:

| Uses `spi` for | Where |
| --- | --- |
| `envs` → terminal environment, tmux `LANG` | `terminal_session.dart` |
| `ssh != null`, `monitorHttp` → which backend | `terminal_session.dart` |
| `id` → restoration bucket, `serverProvider`, `TermSessionManager` | `ssh/page/page.dart` |
| `name` → page title, tab name | `ssh/page/page.dart`, `ssh/tab.dart` |
| `isRoot` → whether to offer the sudo-password button | `ssh/page/page.dart` |

A local session has no server. The shape to copy is the file tab's
`_FileSession`: one sealed class, a local and a remote case, two ways to reach
something and no other difference the page cares about
(`lib/view/page/storage/tab.dart`). `TerminalSession` should take a backend
factory rather than a `Spi`, and the page should read its title and identity
from the session rather than from a server.

The rename itself is two string literals — `home_tab.dart:32` and `:62` both
say `'SSH'` where every other tab uses `libL10n`. `libL10n.terminal` exists.

## Agent mode

The agent has to run commands and touch files here too. It cannot today, and
the reason is not the missing local backend — it is that the agent never
adopted the abstraction the rest of the app runs on.

`ServerExec` (`lib/data/model/server/server_exec.dart`) is what the process,
systemd, container and power features use to run one command and get its output
back, with `SshExec` and `MonitorExec` behind it. The agent uses none of it:

```dart
// global_agent_tools.dart:584
typedef AgentShellHandle = ({SSHClient client, String? serverId});
// :814
final session = await client.execute(command);
```

`ServerExec` appears zero times across all nine agent files — `adhoc_ssh.dart`,
`agent_session.dart`, `agent_shell.dart`, `ask_ai.dart`,
`global_agent_tools.dart`, and the four under `view/page/agent/`. The
in-terminal agent does the same thing with its own `SSHSession`
(`ssh/page/page.dart:171`, `_aiCommandSession`).

Two consequences. One is the local shell: there is nowhere to put it. The other
is already a live bug — `_connectedServer` throws

> Server X has no SSH credential, so it cannot run commands. It reports status
> over its monitor agent only.

for a monitor-only server, which `MonitorExec` has been able to run commands on
since the agent-exec work landed. Fixing the coupling fixes both.

### What the tools need

This is the part that got easier while the document sat. The agent no longer
resolves a tool call straight to a server: there is a sealed target type, and a
second kind of target already exists beside the configured one.

```dart
// global_agent_tools.dart:619, :626
final class ConfiguredServerTarget extends AgentSshTarget { ... }
final class AdHocSessionTarget extends AgentSshTarget { ... }
```

So "this device" is a **third case of that sealed type**, not the reserved
`server_id` string this document originally proposed. Better in every way: the
compiler lists the places that have to answer for it, and a device is not a
server with a magic name.

What has *not* moved is what the target resolves **to** —
`AgentShellHandle = ({SSHClient client, String? serverId})`. The type abstracts
which machine; it does not abstract how a command runs there, which is why a
local case has nowhere to go and a monitor-only server is still refused. Change
the payload to `ServerExec` and both follow.

| Tool | On a server | On this device |
| --- | --- | --- |
| `run_shell_command` | `ServerExec` | `LocalExec` — the same interface over `Process`/`flutter_pty` |
| `read_file` / `write_file` | SFTP | `dart:io` `File`, inside whatever the platform lets the app reach |
| `serverbox` | connection state | not applicable; the device is always "connected" |

### Safety is a different question here

Running model-authored commands on a server the user deliberately configured is
one risk. Running them on the device the app itself lives on is another: the
Hive stores, the private keys and the keychain are all on that filesystem.

What exists today is `AskAiCommandRisk {readOnly, caution, destructive}` with
`canAutoRun => modelSafeToRun && risk == readOnly`, where the local half is a
regex allowlist of read-only command prefixes (`ask_ai_models.dart:472`). That
is a reasonable gate on *auto-running*. It is not a sandbox, and it should not
be asked to be one.

Positions to take before writing any of it:

- local execution **off by default**, opt-in per install;
- **never auto-run locally**, whatever `askAiAutoRunSafeCommands` says — the
  setting is about servers;
- once stage 4 exists, prefer running the agent's local commands **inside the
  bundled rootfs** rather than on the host. The rootfs is the sandbox, and this
  is the argument for building it that has nothing to do with iOS.

On iOS there is no host shell at all, so for that platform "the agent can run
code locally" *means* the rootfs. The capability lands per-platform, the same
way the terminal's does, and `ServerCapabilities` is the existing place to ask.

## What each platform can actually do

| | shell on the host | rootfs + package manager |
| --- | --- | --- |
| Linux | `flutter_pty` | unnecessary — it is Linux |
| Windows | `flutter_pty` (ConPTY) | unnecessary — WSL exists |
| macOS | `flutter_pty`, **DMG build only** | unnecessary |
| Android | `/system/bin/sh`, toybox only | blocked, see below |
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

Integration is not small: `deps/build_ish.sh` produces `libish`, `libish_emu`,
`libfakefs`, headers and a guest VDSO (which needs llvm to build), consumed by
an Xcode project; the Alpine tarball ships as an asset. That is a vendored
GPLv3 C codebase inside a Flutter app, with its own build step in CI for a
platform that currently has none.

## Android: the wall

Android 10 removed execute permission on the app's own data directory. From
[the behaviour-changes doc](https://developer.android.com/about/versions/10/behavior-changes-10):

> Untrusted apps that target Android 10 cannot invoke `execve()` directly on
> files within the app's home directory.

Binaries shipped in the APK are fine — `nativeLibraryDir` is read-only and
executable, which is why proot is packaged as `jniLibs/arm64-v8a/` and not only
as an asset. But a package manager exists to write **new** binaries into the
rootfs, and the rootfs is in the data directory. `apk add` succeeds and the
thing it installed will not run.

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
| a shell reading the rootfs's own files | `3.21.3`, `aarch64` |

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

So the Android half of stage 4 is **not blocked**. What it costs is a proot
build in CI for one ABI, an Alpine tarball as an asset, `useLegacyPackaging`
(a larger install), and the guest's environment — `PATH` has to be the
rootfs's, or a shell finds none of its own tools.

Not reproduced on physical hardware, and not with an app the Play Store has
seen. The binaries were built by hand into a scratch directory; this repository
has no recipe for them yet, so the test skips unless they are staged.

Three ways out, all with a cost:

| Route | Cost |
| --- | --- |
| `targetSdk` 28 | What Termux does on F-Droid. Google Play requires a recent target, so this ends Play distribution |
| An in-process ELF loader — map segments into anonymous `PROT_EXEC` memory, never call `execve` | Same architecture, so no emulation needed, only loading. But `fork`/`exec` inside the guest then has to be implemented by hand. Large |
| Android Virtualization Framework | Real Debian VM, `pKVM`, GPU access. Behind a developer option, `MANAGE_VIRTUAL_MACHINE` is privileged, Samsung does not support AVF. Not reachable from a third-party app today |

There is a widely repeated fourth — invoking `/system/bin/linker64` on a file in
app data — and it is the one measured above. It works, and it does not reach a
musl rootfs, so it settles the question without opening the door.

OpenMinis is the confusing data point. It targets **SDK 35**, ships an Alpine
minirootfs plus proot, and its proot fork is described only as "patches applied
to work better under Termux" — nothing about W^X. Either it hits this wall, or
there is a mechanism not visible from the build scripts. Worth reading the
Kotlin/JNI side before designing anything.

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
pass. **Not exercised end to end** — `LocalExec` has unit tests, but no agent
tool call has been made against this device.

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

iOS via ish-arm64 is the unmeasured half: vendor the fork, build the static
libs, wire the Xcode target, add an iOS build step to CI. That half carries the
review risk; treat it as a separate decision, not a continuation.
It is also what turns the agent's local execution from "on the user's
filesystem" into "in a sandbox", which may be the strongest reason to build it.

Stages 1, 2 and 2b are worth doing whatever happens to 3 and 4.

## Verification log

Update this as answers arrive; several decisions above move with them.

| # | Question | How to settle it | Status |
| --- | --- | --- | --- |
| 1 | Can a `targetSdk` 36 app exec a file in `filesDir` via `linker64`? | **Yes for a bionic binary, no for a musl one** — measured on an API 36 emulator, `integration_test/android_exec_test.dart`. Direct `execve` is denied; the linker maps it and runs it. A musl binary segfaults once its libc is found, because it wants musl's own loader. Unverified on physical hardware | **done** |
| 2 | How does OpenMinis run rootfs binaries at `targetSdk` 36? | **Answered**: proot's own loader, extracted via `/proc/self/fd` and mapping the guest ELF itself, so the host linker is never asked to understand musl. `RootfsManager.kt:42`, `PRootKernel.kt:83`. Not reproduced here | **done** |
| 3 | Are ish-arm64's 7–12x figures representative? | Build it, run a shell and a `python -c` loop | **open** |
| 4 | Does the macOS DMG build ship unsandboxed, or does local shell hide there? | **Answered, and the first answer was wrong.** A sandboxed process cannot host a pty at all, so the entitlement that was meant to fix it bought nothing and was reverted (`ccd2e77b`). iCloud turned out not to need the sandbox either. macOS ships two products from one binary (`52a0ec1b`), and the App Store one hides the feature | **done** |
| 5 | Is proot GPLv2-only or v2-or-later? | **v2 or later** — the source headers say "either version 2 of the License, or (at your option) any later version" (`src/tracee/tracee.h:9`, `src/cli/cli.c:9`). So it can be taken as GPLv3 and combined with this AGPL-3.0 app even if it were linked rather than invoked | **done** |
| 6 | Does `flutter_pty` still build against current Flutter on all four desktop/Android targets? | **macOS builds and runs** — `integration_test/local_shell_test.dart`, five tests, inside a real app. Linux, Windows and Android untried. One warning: `flutter_pty` does not support Swift Package Manager, which Flutter says "will become an error in a future version" — `sbm_ffi` is in the same list, so it is not a new exposure | **partly** |
| 7 | Would 2.5.2 be survivable for this app? | Cannot be settled in advance. Decide whether stage 4's iOS half is worth the update risk | **open** |
| 8 | Is local agent execution opt-in, and is auto-run barred locally? | **Answered** (`95aa2c30`, `c6c728f1`): both. `Stores.setting.agentLocalExec`, off by default, with a switch that is absent where the platform could not honour it. `AskAiCommand.onThisDevice` bars auto-run whatever the model or `askAiAutoRunSafeCommands` says | **done** |
| 9 | What can the agent's `read_file`/`write_file` reach locally per platform? | macOS: the DMG build reaches the whole home — measured; the App Store build offers no local target at all. iOS the same, for the same reason. Android scoped storage untested | **partly** |
| 10 | Does moving the agent to `ServerExec` change any recorded conversation's replay? | **No** — `agent_conversation_replay`'s tests pass unchanged across `328f92d9` and the local-target work. The recorded shape is the tool result, which did not move | **done** |
