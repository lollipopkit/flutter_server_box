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

**Status: research only. Nothing in stages 1–4 is implemented.** Last checked
against the tree at `f8f371b3`. Update the verification log at the bottom as
answers land — several decisions below are downstream of questions still marked
open.

What that check found, since sixteen commits of agent work landed between this
document being written and being read again:

| Anchor | State |
| --- | --- |
| `ShellBackend` implementations | still two, `Ssh` and `Monitor` |
| `ServerExec` implementations | still two, `SshExec` and `MonitorExec` |
| `ServerExec` in any agent file | still **zero** — nine files, 5,495 lines |
| `TerminalSession` | still `TerminalSession({required this.spi})` |
| `'SSH'` in `home_tab.dart` | still literal, `:32` and `:62` |
| `flutter_pty` | still not a dependency |
| monitor-only refusal | still thrown, now `global_agent_tools.dart:761` |

One thing did move, and it moved in this plan's favour — see
[what the tools need](#what-the-tools-need).

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
| macOS | `flutter_pty`, **inside the app sandbox** | unnecessary |
| Android | `/system/bin/sh`, toybox only | blocked, see below |
| iOS | impossible — no `fork`/`exec` for App Store apps | only via an interpreter |

`flutter_pty` is MIT, covers all five platforms, and is the obvious choice for
step 1. It is also marked *experimental* by its publisher and was last released
about 19 months ago (0.4.2). Its claimed iOS support is not useful here: iOS
has `forkpty` in the SDK, but there is no `/bin/sh` in the sandbox and no way to
exec an unsigned binary.

### macOS is sandboxed

`macos/Runner/*.entitlements` sets `com.apple.security.app-sandbox` to true in
both configurations. A child process inherits the sandbox, so a shell spawned
from the app cannot read the user's home directory — only the app container and
whatever the user picked through a file dialog. A terminal that cannot `ls ~`
is not the feature.

Two options, and they are not exclusive:

- ship the DMG/Homebrew build unsandboxed (separate entitlements per
  configuration; the release path is already separate — see `make release-macos-dmg`);
- keep the sandbox for any Mac App Store build and let the local-shell entry
  be absent there, the way `ServerFuncBtn` already hides what a connection
  cannot serve.

Decide before writing the backend: it changes whether "local shell" is a
capability the UI asks about or a constant.

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

Three ways out, all with a cost:

| Route | Cost |
| --- | --- |
| `targetSdk` 28 | What Termux does on F-Droid. Google Play requires a recent target, so this ends Play distribution |
| An in-process ELF loader — map segments into anonymous `PROT_EXEC` memory, never call `execve` | Same architecture, so no emulation needed, only loading. But `fork`/`exec` inside the guest then has to be implemented by hand. Large |
| Android Virtualization Framework | Real Debian VM, `pKVM`, GPU access. Behind a developer option, `MANAGE_VIRTUAL_MACHINE` is privileged, Samsung does not support AVF. Not reachable from a third-party app today |

There is a widely repeated fourth: invoking `/system/bin/linker64` explicitly on
a file in app data, on the grounds that the linker maps rather than execs.
**This is unverified** — the Termux wiki page that documents it is behind a
bot-check and could not be read. It decides whether route 2 collapses into a
one-line workaround or stays a large piece of work, so it is the first thing to
measure.

OpenMinis is the confusing data point. It targets **SDK 35**, ships an Alpine
minirootfs plus proot, and its proot fork is described only as "patches applied
to work better under Termux" — nothing about W^X. Either it hits this wall, or
there is a mechanism not visible from the build scripts. Worth reading the
Kotlin/JNI side before designing anything.

## Licensing and review

This project is **AGPL-3.0** (`LICENSE`), which settles most of it:

- **ish-arm64 is GPLv3** and would be statically linked. Compatible, and the
  obligation it brings — publish the whole app's source — is already met.
- **proot is GPLv2**, invoked as a separate process rather than linked, so it
  is aggregation, not a derived work. Shipping the binary means offering its
  source. Whether its headers say "v2 only" or "v2 or later" was not checked.
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
target.** Worth doing on its own merits — it is what makes the agent work on
monitor-only servers, which it silently refuses today. Local execution then
follows: a third `AgentSshTarget` case, `LocalExec`, `dart:io` for the file
tools, and the safety positions above. Can run in parallel with stage 1; it
needs `ServerExec`, not the terminal work.

Smaller than it was when this was written: the target abstraction now exists,
so this is one type's payload and the call sites that read it, rather than
inventing the seam as well.

**3. Measure the Android execution question.** A throwaway APK at the current
`targetSdk`: write a static binary into `filesDir`, try `execve`, try it through
`linker64`, record both. Twenty lines. Everything about Android rootfs support
depends on the answer, and nothing should be designed before it.

**4. Rootfs.** iOS via ish-arm64 — vendor the fork, build the static libs, wire
the Xcode target, ship an Alpine aarch64 tarball, add an iOS build step to CI.
Android per stage 3. This stage is larger than the first three together and
carries the review risk; treat it as a separate decision, not a continuation.
It is also what turns the agent's local execution from "on the user's
filesystem" into "in a sandbox", which may be the strongest reason to build it.

Stages 1, 2 and 2b are worth doing whatever happens to 3 and 4.

## Verification log

Update this as answers arrive; several decisions above move with them.

| # | Question | How to settle it | Status |
| --- | --- | --- | --- |
| 1 | Can a `targetSdk` 35 app exec a file in `filesDir` via `linker64`? | Throwaway APK on a real device (no Android hardware here) | **open** |
| 2 | How does OpenMinis run rootfs binaries at `targetSdk` 35? | Read its Kotlin/JNI sandbox code, not the shell scripts | **open** |
| 3 | Are ish-arm64's 7–12x figures representative? | Build it, run a shell and a `python -c` loop | **open** |
| 4 | Does the macOS DMG build ship unsandboxed, or does local shell hide there? | Product decision. Half answered: `macos/Runner/Release.entitlements:17` sets `app-sandbox` true, so **every** build is sandboxed today, DMG included. Un-sandboxing it is a change to make, not a state to use | **open** |
| 5 | Is proot GPLv2-only or v2-or-later? | Read source headers, not `COPYING` | **open** |
| 6 | Does `flutter_pty` still build against current Flutter on all four desktop/Android targets? | Add it, build each | **open** |
| 7 | Would 2.5.2 be survivable for this app? | Cannot be settled in advance. Decide whether stage 4's iOS half is worth the update risk | **open** |
| 8 | Is local agent execution opt-in, and is auto-run barred locally? | Product decision. Affects the settings surface and the tool instructions | **open** |
| 9 | What can the agent's `read_file`/`write_file` reach locally per platform? | macOS sandbox container vs. home; Android scoped storage; iOS app container only | **open** |
| 10 | Does moving the agent to `ServerExec` change any recorded conversation's replay? | `agent_conversation_replay` and its tests are the contract | **open** |
