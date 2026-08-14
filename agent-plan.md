# Agent plan: floating shell, navigation, ad-hoc SSH

Three pieces of work, in this order:

1. The agent's conversation state moves out of `_AgentPageState` into a
   provider, and gains a second container that floats above the whole app.
2. The agent gains the ability to open a page — which is only useful once it
   can stay visible after doing so.
3. Remote execution stops meaning "on a configured server". The agent can
   connect to a host that is not in the app yet, work on it, and then save it.

```
Phase 1                    Phase 2                 Phase 3
┌──────────────┐           ┌──────────────┐        ┌──────────────┐
│ agent tab    │           │ agent floats │        │ ssh_connect  │
│      ↓       │           │ over detail  │        │      ↓       │
│ provider     │  ──────→  │      ↑       │ ────→  │ ad-hoc sess. │
│      ↓       │           │ open_server  │        │      ↓       │
│ float shell  │           └──────────────┘        │ add_server   │
└──────────────┘                                   └──────────────┘
```

Phase 3's first step — the target resolver — is a pure refactor with no UI
dependency and can land at any point. Everything else is ordered.

## What exists today

| Capability | State | Where |
| ---------- | ----- | ----- |
| Run a command / read / write a file | configured servers only | `global_agent_tools.dart:145` |
| `serverbox` actions | `list_servers`, `get_status`, `connect`, `refresh`, `disconnect` | `global_agent_tools.dart:730` |
| Add a server | exists, not exposed to the agent | `provider/server/all.dart:244` |
| Open a page | none | — |
| Cross-tab navigation | exists, used by other pages | `session_requests.dart`, `home.dart:152` |
| Server detail route | exists, takes `SpiRequiredArgs` | `server/detail/view.dart:46` |
| Ad-hoc SSH | none | — |
| Install monitor | server-side script only | `monitor/install.sh` |

Every tool takes a `server_id` and resolves it through a membership check that
rejects anything unsaved:

```dart
// global_agent_tools.dart:531
if (!_ref.read(serversProvider).servers.containsKey(serverId)) {
  throw StateError('Configured server not found: $serverId');
}
```

`_connectedServer` (`:499`) then goes through `ServerNotifier.ensureShellClient()`,
which only exists on `serverProvider(id)` — i.e. on a saved `Spi`.

## Phase 1 — session state into a provider, and a floating container

### Why the state has to move first

`_AgentPageState` owns the entire conversation: `_timeline`, `_history`,
`_subscription`, `_pendingTool`, `_streamingContent`, `_isStreaming`,
`_isExecuting`, `_toolService` (`agent.dart:114-138`). A second container
showing the same conversation is impossible while that is true, and
`AutomaticKeepAliveClientMixin` (`:143`) is the workaround that keeps it alive
today — it survives tab switches but is still one widget.

### `AgentSessionNotifier`

New: `lib/data/provider/ai/agent_session.dart`. A `keepAlive` Notifier holding
everything above, plus the methods that currently live on the page and mutate
it: `submitPrompt`, `startStream`, `handleEvent`, `runPendingTool`,
`declinePendingTool`, `stopWork`, `restoreConversation`, `beginNewConversation`.

Two things must change in the move, not after it:

**The timeline holds data, not localized strings.** Notices are built today
with `context.l10n.askAiActionDeclined` (`agent.dart:236`, `:579`) and stored as
finished text. A provider has no `BuildContext`, so `_AgentTimelineEntry.notice`
becomes a variant carrying a reason enum, localized at render time:

```dart
enum AgentNoticeKind { declined, interrupted, raw }

class AgentTimelineNotice {
  final AgentNoticeKind kind;
  final String? raw;   // only for AgentNoticeKind.raw
}
```

This is the single largest piece of mechanical work in the phase.

**`dispose` stops cancelling work.** `agent.dart:173` kills the running tool
when the page goes away. That is exactly the behaviour being removed: the
session outlives its views. `cancelCurrent()` becomes something only the user
triggers, through the stop button or by closing the conversation.

The page keeps its own UI-only state — `_scrollController`, `_inputController`,
history-panel expansion — because those are per-view and two views should not
share a scroll offset. It therefore stays `AutomaticKeepAliveClientMixin`,
which this plan first had it dropping: keeping it alive is no longer what
keeps the conversation running, but it is still what stops a half-typed
prompt disappearing on a tab switch.

### The floating container

Mounted in `home.dart`, wrapping the `Scaffold` at `:161` in a `Stack`, so it
sits above the `PageView` (`:167`) rather than inside any one tab.

Split by form factor — the same `ResponsiveBreakpoints` judgement `home.dart:158`
already makes:

```
Desktop                     Mobile
┌──────────────────────┐    ┌──────────────┐
│ Server Detail        │    │ Server Detail│
│   ┌──────────────┐   │    │        ╭───╮ │
│   │ Agent    _ □ │   │    │        │ ✦ │ │ ← collapsed pill
│   │ > _          │   │    │        ╰───╯ │
│   └──────────────┘   │    └──────────────┘
└──────────────────────┘      tap ↓ DraggableScrollableSheet
```

| | Desktop / wide | Mobile / narrow |
| - | -------------- | --------------- |
| Collapsed | title bar only, docked to a corner | pill, edge-snapped |
| Expanded | draggable, resizable panel | panel over the bottom, with a grab bar |
| Position | persisted in `Stores.setting` | snap side persisted |

Both render the same widget tree inside, driven by one visibility provider:

```dart
// lib/data/provider/ai/agent_shell.dart
enum AgentShellMode { hidden, collapsed, expanded }
```

The agent tab stays. The tab and the float are two views of one session, and
the float is hidden by default — it appears when the agent is working while its
tab is not on screen, or when Phase 2 navigates away from it.

`agent.dart` becomes rendering plus input handling. `_buildMain` (`:1544`),
`_buildComposer` (`:1399`), `_buildProposalCard` (`:1210`) and the timeline
builders are reused verbatim by the float; only `build` (`:1628`) differs,
since `SbPaneList` and its history column do not belong in a floating panel.

## Phase 2 — the agent can open a page

A new `serverbox` action rather than a new tool: navigation is an operation on
ServerBox state, and the model already knows that tool's shape.

```
action: 'open_server'   server_id: <configured id>   → switches to the server
                                                        tab and pushes detail
```

Implementation is two existing calls — `homeTabRequestProvider.go(AppTab.server)`
and `ServerDetailPage.route.go(...)` with `SpiRequiredArgs` — plus setting
`AgentShellMode.expanded` so the conversation follows the user to the page it
just opened. `risk` is `caution`: it changes what is on screen but nothing on
any server.

Because Phase 1 detached the session from the tab, the stream and any running
tool continue across the navigation.

## Phase 3 — remote execution, decoupled from the server list

### The target resolver

`_connectedServer(String? serverId)` returns `(ServerState, SSHClient)`, but
`_runShell` (`:541`), `_readFile` (`:611`) and `_writeFile` (`:658`) only use
the client and a display name. So:

```dart
sealed class AgentSshTarget {
  Future<({SSHClient client, String label, String? serverId})> resolve(Ref ref);
}

class ConfiguredTarget extends AgentSshTarget { final String serverId; }
class AdHocTarget     extends AgentSshTarget { final String sessionId; }
```

`ConfiguredTarget` is today's path unchanged. This step alone touches no UI and
changes no behaviour.

### Ad-hoc sessions are a registry, not a function call

The scenario is multi-step: test the connection, install monitor (several
commands), then configure the server. A per-call connection would re-authenticate,
re-prompt for the host key and re-ask for the password every time. So ad-hoc
connections live in a provider, keyed by an opaque handle:

```dart
// lib/data/provider/ai/adhoc_ssh.dart
class AdHocSshSession {
  final String id;
  final Spi spi;          // never persisted; carries the password
  final SSHClient client;
  final DateTime openedAt;
}
```

In-memory only, cleared on app exit. The floating shell lists open sessions and
offers a close button, so a connection the model forgot about is still visible
and killable.

The `Spi` is built with a real `ShortId.generate()` id from the start. This is
load-bearing — see the host key note below.

### New tools

| Tool | Arguments | Risk |
| ---- | --------- | ---- |
| `ssh_connect` | `host`, `port`, `user`, `description` | `destructive` |
| `ssh_disconnect` | `session_id` | `caution` |
| `serverbox` / `add_server` | `session_id`, `name`, optional monitor address | `destructive` |

`ssh_connect` collects a **password** only. A host reachable solely by key
cannot be connected to this way yet; the app has a key store and the dialog
could offer to pick from it, but that is more UI than this stage needs to be
reviewable and nothing else depends on it.

`ssh_connect` returns a `session_id`, the resolved host, and the accepted host
key fingerprint. Nothing else.

`run_shell_command`, `read_file` and `write_file` gain an optional `session_id`
as an alternative to `server_id`; exactly one must be present.

### Installing monitor

No new tool. With an ad-hoc session open, the model runs the documented
installer through `run_shell_command`, and the user approves it like any other
state-changing command. `add_server` then saves the host with its
`MonitorHttpCredential`.

## Security model

The four rules that shape the above.

### 1. The model never accepts a host key

`genClient`'s `onHostKeyPrompt` already defaults to `showHostKeyPrompt`
(`core/utils/server.dart:106`), which puts a real dialog on the root navigator
via `AppNavigator.context` (`:400-445`). The ad-hoc path gets this by **not**
passing a handler. Agreement inside the conversation is not agreement by the
user, and the model has no way to express the latter.

The storage key is derived from `spi.id`, falling back to `user@ip:port` when
the id is empty (`server.dart:519-524`). Hence the generated id on the ad-hoc
`Spi`: `add_server` saves *that same* `Spi`, so the fingerprint carries over and
the user is not asked a second time for a host they already vetted.

If the session is discarded without saving, its fingerprint entry is removed
with it — otherwise every rejected trial connection leaves a stale entry.

### 2. Passwords do not enter the conversation

`AskAiCommand.rawArguments` is written into the conversation verbatim
(`ask_ai_models.dart:367-380`) and persisted (`agent.dart:314`). So the password
is not a tool argument: `ssh_connect` takes host, port and user, and the app
prompts for the secret with `Input` inside `context.showRoundDialog`. The
password reaches `AdHocSshSession.spi` and nowhere else.

Two related holes, both closed here:

- The user pasting a password into the chat box puts it in context before any
  tool is involved. `buildGlobalAgentInstructions` (`global_agent_tools.dart:295`)
  gains a line forbidding the model from asking for credentials in conversation,
  and directing it to `ssh_connect`.
- `run_shell_command` stdout is fed back to the model. Installing monitor
  produces credentials; if the model reads them off disk they are in context.
  `add_server` therefore collects monitor `user`/`pwd` through the same dialog,
  not from command output.

### 3. Nothing on an unvetted host runs unattended

`canAutoRun` requires `readOnly` (`ask_ai_models.dart:356`), so `destructive`
can never auto-run — `ssh_connect` is gated by the confirmation at
`agent.dart:500` and by `shouldAutoRunAgentCommand` at once.

But `run_shell_command` classifies by command text (`classifyRisk`,
`ask_ai_models.dart:400`), so `ls` on a machine met thirty seconds ago would be
`readOnly` and eligible for auto-run. **Commands on an `AdHocTarget` are floored
at `caution`**: no confirmation dialog, but never automatic. Auto-run is a
convenience for hosts the user has already accepted into the app.

### 4. Ad-hoc credentials are never persisted

`AdHocSshSession` is in-memory. Only `add_server` writes anything to Hive, and
only for the host the user chose to keep.

## Delivery stages

| Stage | Content | Verifiable on its own |
| ----- | ------- | --------------------- |
| 1 | `AgentSessionNotifier`; timeline entries become data; `agent.dart` reduced to rendering | agent tab behaves exactly as before |
| 2 | `AgentShellMode` provider + floating container, both form factors | conversation continues while the tab is off screen |
| 3 | `serverbox` gains `open_server` | agent opens a server and stays visible |
| 4 | `AgentSshTarget` resolver; `ConfiguredTarget` only | no behaviour change, refactor only |
| 5 | `AdHocSshSession` registry, `ssh_connect` / `ssh_disconnect`, credential dialog | connect to an unsaved host, run a command |
| 6 | `serverbox` gains `add_server`; risk floor for ad-hoc commands | full scenario end to end |

Stages 1 and 4 change no behaviour. Each stage is a separate commit and can be
reverted alone.

## Open risks

- **Timeline localization.** Notices stored as finished strings today. Anything
  missed keeps a `BuildContext` alive in provider state, or renders in the
  language the app was in when the notice was created. Stage 1 must convert all
  of them, not most.
- **Dialogs raised from a background session.** Once the session is detached
  from its page, a host key prompt or credential dialog can appear while the
  agent is not visible anywhere. `ssh_connect` raises the shell before it asks,
  which covers the prompts this work introduces. It does **not** cover the host
  key prompt a configured server can still raise from
  `ensureShellClient` — that path predates all of this and is unchanged, but it
  has the same problem and deserves the same treatment.
- **Conversation persistence and handles.** `session_id` values are meaningless
  after a restart, but a restored conversation still refers to them. Restored
  tool calls pointing at dead sessions must fail with a message the model can
  act on, not a bare `StateError`.
- **Orphan host key entries.** Trial connections that are never saved leave
  fingerprints keyed by an id nothing references.
- **`add_server` and `shouldReconnect`.** Saving an ad-hoc `Spi` and immediately
  navigating to it means the provider connects while the ad-hoc client is still
  open — two SSH connections to one host. `add_server` should hand the existing
  client over or close it explicitly.
- **Mobile keyboard vs. sheet.** The composer has to stay above the keyboard
  without fighting the panel's own drag. `DraggableScrollableSheet` was the
  obvious fit and turned out to be the wrong one: it drives its drag from a
  `ScrollController` it hands to its child, and the conversation's list
  already owns one — which is also what the auto-scroll uses. The panel is a
  height fraction with its own grab bar instead, and the fraction is measured
  against what is left once the keyboard has taken its share.

## Manual verification

Ordered so a failure stops wasted effort. Restarts come last, because they
clear the state everything earlier sets up.

### 1. Session state — no server needed

- [ ] Send a prompt, switch to another tab mid-stream, come back: the answer
      continued and is complete.
- [ ] Same, but with a tool proposal pending: it is still pending on return,
      not re-proposed.
- [ ] Stop button interrupts. Leaving the tab does not.
- [ ] History panel: rename, delete, switch conversation — unchanged.
- [ ] Declined-tool and interrupted notices read correctly after changing the
      app language.

### 2. Floating shell

- [ ] Desktop: the panel drags, resizes, collapses to its title bar, and is
      where it was left after a window resize.
- [ ] Mobile: the pill snaps to an edge; tapping opens the sheet; the composer
      stays above the keyboard.
- [ ] The float and the agent tab show the same conversation, and typing in one
      is reflected in the other.
- [ ] Closing the float does not stop a running stream.

### 3. Navigation — needs a configured server

- [ ] Asking the agent to open a server switches tab, pushes the detail page,
      and leaves the conversation visible over it.
- [ ] Back from that page leaves the float where it was.
- [ ] `open_server` with an unknown id produces a usable error, not a crash.

### 4. Ad-hoc SSH — needs a throwaway host

- [ ] `ssh_connect` prompts for the password in a dialog. The password appears
      nowhere in the conversation, including after reopening it from history.
- [ ] The host key dialog appears and is refusable; refusing fails the tool
      cleanly.
- [ ] A second command on the same `session_id` does not re-prompt for anything.
- [ ] A read-only command on an ad-hoc session is **not** auto-run even with
      auto-run enabled.
- [ ] `ssh_disconnect`, and the close button in the float, both end the session.

### 5. Full scenario

- [ ] Give the agent an address and user; it connects, installs monitor, and
      saves the server with its monitor credentials.
- [ ] The saved server appears in the list and connects on its own.
- [ ] It does **not** ask for the host key again.
- [ ] The conversation, re-read from history, contains no password and no
      monitor credential.

### 6. Restart

- [ ] Ad-hoc sessions are gone, and a restored conversation referring to one
      says so rather than throwing.
- [ ] The float's position and mode are restored.
- [ ] Servers saved through `add_server` survive.
