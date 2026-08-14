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
└──────────────────────┘      tap ↓ opens a panel
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
the float is off by default: a toggle in the tab's header turns it on, and
`open_server` and `ssh_connect` turn it on themselves, because both are about
to put something on screen that the conversation has to be next to. It hides
itself while the Agent tab is the one being looked at.

The page splits in three rather than growing a flag. `view.dart` is the
conversation — timeline and composer — with `showHeader: false` where the
container draws its own bar. `history.dart` is the conversation list, which
watches the session and so no longer needs the sheet to be told to redraw.
`agent.dart` is what is left of the tab: the pane split and the toggle.

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
| `serverbox` / `add_server` | `session_id`, `name`, optional monitor address | `caution` |

`add_server` is `caution`, not `destructive` as first planned. The save
dialog is already the review step — it shows exactly what would be stored and
can be cancelled — so a confirmation in front of it would be a second question
about the same thing. `caution` still means it can never auto-run.

`ssh_connect` collects either a password typed for that connection or one of
the private keys already in the app, whichever the user picks. The key list is
only offered when there is one; a first-run app with no stored keys still gets
a single password field.

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

| Stage | Content | Verifiable on its own | |
| ----- | ------- | --------------------- | - |
| 1 | `AgentSessionNotifier`; timeline entries become data; `agent.dart` reduced to rendering | agent tab behaves exactly as before | shipped |
| 2 | `AgentShellMode` provider + floating container, both form factors | conversation continues while the tab is off screen | shipped |
| 3 | `serverbox` gains `open_server` | agent opens a server and stays visible | shipped |
| 4 | `AgentSshTarget` resolver; `ConfiguredTarget` only | no behaviour change, refactor only | shipped |
| 5 | `AdHocSshSession` registry, `ssh_connect` / `ssh_disconnect`, credential dialog | connect to an unsaved host, run a command | shipped |
| 6 | `serverbox` gains `add_server`; risk floor for ad-hoc commands | full scenario end to end | shipped |

Stages 1 and 4 change no behaviour. Each stage is a separate commit and can be
reverted alone.

Four defects found by running it, each fixed in its own commit afterwards:

| Found | Cause |
| ----- | ----- |
| The Agent refused to reach an unlisted host | The instructions opened with "configured servers" and "use only exact server IDs", written before ad-hoc existed; `ssh_connect` was eight lines further down and read as a footnote. |
| "No response" for a tool the model had called | `_parseCommand` took a proposal's one-line identity from a `command` argument and discarded a call that had none — which `ssh_connect` does not. |
| The float appeared beside the tab it duplicates | `currentHomeTabProvider` was published from `initState` and `afterFirstLayout`, neither of which a hot reload runs. |
| The float's last line sat below the visible area | Its position was clamped against `MediaQuery.sizeOf` — the window — rather than the box it is painted in. |

The first two are the same shape: a tool declared in one file and interpreted
in another, added to only one of them. Both now have a test that walks
`globalAgentToolDefinitions` rather than naming a tool.

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
- **Orphan host key entries.** Resolved: closing a session forgets the keys
  filed under its id, and `add_server` is the one caller that keeps them. The
  cost of the arrangement is that connecting twice to the same host without
  saving asks about its key twice — each unsaved attempt is its own trust
  decision, which is defensible but is a wart.
- **`add_server` and `shouldReconnect`.** Resolved by closing the ad-hoc
  connection before adding the server, rather than handing the client over.
  `addServer` refreshes, which connects; adopting the open client instead would
  mean coupling the ad-hoc registry to `ServerNotifier`'s connection lifecycle
  — its state, its `TryLimiter` key, its identity checks — to save one
  reconnect.
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

Boxes are ticked only where there is evidence, and the run so far went
straight for group 4 — the point of the work — so most of the rest is
untouched rather than passing.

Both rules of the security model that could only be checked at runtime have
been. A proxy in front of the AI endpoint recorded the *shape* of each request
— field names, never values, so nothing sensitive reached the log — and a full
conversation replayed on a later turn carried no key matching
`pass|pwd|secret|passphrase|credential|private_key|token|api_key` at any depth.

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

- [x] Desktop: the panel drags, and is where it was left after a window
      resize. Resizing by the corner handle is untried.
- [ ] Desktop: collapsing glides rather than jumping, and closing fades. Both
      animations were added after this run and have not been seen.
- [ ] Mobile: the pill snaps to an edge; tapping opens the sheet; the composer
      stays above the keyboard. **Nothing on a phone has been run at all.**
- [x] The float and the agent tab show the same conversation — seen while both
      were on screen at once, which was itself the bug above.
- [ ] Closing the float does not stop a running stream.

### 3. Navigation — needs a configured server

- [ ] Asking the agent to open a server switches tab, pushes the detail page,
      and leaves the conversation visible over it.
- [ ] Back from that page leaves the float where it was.
- [ ] `open_server` with an unknown id produces a usable error, not a crash.

`open_server` has not been called once. Nothing about it is known beyond its
unit tests.

### 4. Ad-hoc SSH — needs a throwaway host

- [x] `ssh_connect` prompts for the credential in a dialog.
- [x] The password appears nowhere in the conversation, including after
      reopening it from history. `ssh_connect` went over the wire as
      `args=[description, host, port, safe_to_run, user]` and came back as
      `data=[accepted_host_key, host, port, session_id, user]`. Nowhere to put
      one, and none anywhere else in the request.
- [x] The host key dialog appears. It had been reported as not appearing on a
      repeat connection, which the code says is impossible — each ad-hoc `Spi`
      gets a fresh id, so the fingerprint store cannot have an entry under it.
      The wire settles it: `accepted_host_key` is written only from the
      callback that fires when a *new* key is accepted, and omitted entirely
      otherwise, and it is present. The prompt fired; it was the observation
      that was wrong.
- [ ] Refusing the host key fails the tool cleanly. Untried — accepting it is
      what has been exercised.
- [x] A second command on the same `session_id` does not re-prompt for
      anything.
- [ ] A read-only command on an ad-hoc session is **not** auto-run even with
      auto-run enabled. Commands were approved by hand; whether auto-run was
      even on is unrecorded.
- [ ] `ssh_disconnect`, and the close button in the float, both end the
      session.

### 5. Full scenario

- [x] Give the agent an address and user; it connects and saves the server.
      Installing monitor was skipped: the throwaway host was a container, and
      the installer wants systemd. **The monitor half of the scenario — the
      one the whole plan was written for — is unproven.**
- [x] The saved server appears in the list and connects on its own.
- [ ] It does **not** ask for the host key again. Not separately confirmed, and
      tied to the open question in group 4.
- [x] The conversation, re-read from history, contains no password and no
      monitor credential. `add_server` carries `monitor_addr` — an address, not
      a secret — and reports back only `has_monitor`. The dialog's user and
      password have no field to travel in.

### 6. Restart

- [ ] Ad-hoc sessions are gone, and a restored conversation referring to one
      says so rather than throwing.
- [ ] The float's position and mode are restored.
- [ ] Servers saved through `add_server` survive.
