# Multi-pane layout plan

Desktop and iPad get a three-column shell: the existing tab rail, a compact
server list, and a detail/edit area. Phones and narrow windows keep exactly
what they have today. One codebase, one navigation model, two renderings.

```
┌──────┬─────────────┬──────────────────────────────┐
│ Rail │ server list │ Navigator(pane)              │
│ tabs │ (compact)   │  └ detail ──push──→ edit     │
└──────┴─────────────┴──────────────────────────────┘
   ↑ exists already    ↑ new, inside ServerPage
```

Panes 2 and 3 live **inside `ServerPage`**, not in `home.dart`. The rail is
already pane 1 (`lib/view/page/home.dart:153`), and keeping the split local
means the SSH, snippet and file tabs are untouched by this work.

## Decision: keep `AppRoute`, do not adopt go_router or auto_route

|                                   | `AppRoute` today   | go_router              | auto_route          |
| --------------------------------- | ------------------ | ---------------------- | ------------------- |
| Nested navigators (panes need it) | hand-rolled        | `ShellRoute`           | `AutoRouter`        |
| Persistent tabs                   | hand-rolled        | `StatefulShellRoute`   | `AutoTabsRouter`    |
| Typed arguments                   | `AppRoute<Ret,Arg>`| non-URL args via `extra`, untyped | codegen  |
| URL / deep links                  | none               | yes                    | yes                 |
| **Flutter state restoration**     | native             | long-standing gap      | limited             |

The last row decides it. This app leans on restoration hard: 52 references,
four `RestorationMixin` users — the home tab index (`home.dart:38`), the whole
set of open terminal sessions (`ssh/tab.dart:41`), each terminal's tmux
session and window (`ssh/page/page.dart:144`), and
`Navigator.restorablePush` in `server_func_btns.dart:221`. `MaterialApp` sets
`restorationScopeId: 'serverbox'`.

Switching routers trades working session restoration for URLs the app has no
use for: there is no web target, no deep links, and `app.dart:126` is a plain
`MaterialApp(home:)` without even `onGenerateRoute`. What a router would buy —
declarative nested shells — is one layer we can write once and own.

So the work is to **fix `AppRoute`**, not replace it. Its problem is not that
it isn't go_router.

## What fl_lib gets wrong today

| # | Where | Problem |
| - | ----- | ------- |
| 1 | `route.dart:26` | `AppRouteIface.toWidget()` throws `UnimplementedError` in the base class. A base class whose primary method is a runtime crash should be `abstract`. |
| 2 | `route.dart:31`, `:70` | `AppRoute` and `AppRouteArg` are near-identical, differing only in argument nullability. One sealed hierarchy with one `go`. |
| 3 | `route.dart:53` | `go()` hardcodes `MaterialPageRoute` and `Navigator.push(context)`. **There is no way to target a nested navigator** — the direct blocker for panes. |
| 4 | `appbar.dart:37` | `CustomAppBar` cannot tell whether it is inside a pane, so it always draws the implicit back button. |
| 5 | `ctx/dialog.dart:42` | `showDialog` without `useRootNavigator`, relying on a Flutter default that is being deprecated. Once nested navigators exist this becomes a real bug: dialogs clipped inside a pane. |
| 6 | `ctx/common.dart:9` | `context.pop()` is a bare `Navigator.pop`. Nothing expresses "pop to this pane's root" or "the pane is at its root, let the outer route handle it". |

`SplitView` / `SplitViewController` (`split.dart:18`) has the same class of
problem — a bespoke route stack in a `ValueNotifier<List<_RouteEntry>>`
instead of a `Navigator`, and two panes hardcoded — but it is **left alone by
this plan**. It has no users; new work goes to `AdaptivePanes` instead.

## Target architecture

### Pane 3 hosts a real `Navigator`

This is the decision everything else rests on. The detail page pushes edit,
SFTP, process and systemd pages; the edit page returns its result through
`context.pop(true)` after a delete. If a pane merely *rendered a widget*, every
one of those pages would need a callback instead, and would have to know it
might not be on a route stack — the abstraction would leak into every leaf.

With a nested `Navigator`, `context.pop()`, `canPop`, `PopScope`, return
values and transitions all keep working. **`ServerDetailPage` and
`ServerEditPage` need no changes at all.**

### `AppRoute` gains a target

```dart
enum NavTarget { nearest, root, pane }

Future<Ret?> go(
  BuildContext context, {
  Arg? args,
  NavTarget target = NavTarget.nearest,
});
```

`nearest` is today's behaviour. Inside a pane it resolves to that pane's
navigator, so **all 59 existing call sites keep working unchanged**. `root` is
for things that must own the screen; `pane` is for things that must not.

### Selection is state, not a route argument

Which server is open is currently the pushed route's argument. In a pane
layout it has to outlive pane 3's contents, so it becomes a provider —
consistent with `serverProvider(id)`, which is already a family keyed by id:

```dart
// lib/data/provider/server/selection.dart
@riverpod
class ServerSelection extends _$ServerSelection {
  @override String? build() => null;
}
```

Pane 2's highlight, pane 3's content and restoration all read one value.

### One branch point for mobile vs desktop

```dart
void openServer(BuildContext ctx, WidgetRef ref, Spi spi) {
  if (PaneScope.of(ctx) case final _?) {
    ref.read(serverSelectionProvider.notifier).select(spi.id);
  } else {
    ServerDetailPage.route.go(ctx, args: SpiRequiredArgs(spi));
  }
}
```

Two call sites today (`server/tab/utils.dart:13` and the long-press path).
Everything else stays unaware that panes exist.

## Terminal and SFTP become tab sessions

There are currently **two unconnected ways to get a terminal**:
`server_func_btns.dart:221` pushes a full-screen `SSHPage`, while
`SSHTabPage` keeps its own session table (`ssh/tab.dart:101`). Opening the
same server twice yields two sessions that do not know about each other.

After this work there is one way: `openTerminal(spi)` switches to the SSH tab
and adds a session there. SFTP gets the same treatment and lands in the
**existing file tab**, which becomes "local plus N remote sessions" — files
are one concept, and a fourth tab would not earn its place.

The machinery `SSHTabPage` hand-rolls — the session map, the `PageController`,
the per-session `GlobalKey`s, the encode/decode in `_restorableTabsState` —
becomes one reusable widget:

```dart
SessionTabs<T>(
  restorationId: 'ssh_tabs',
  encode: ..., decode: ...,   // restoration stays with the caller, which
  builder: (session) => ...,  // is the only thing that knows its own data
  emptyPage: ...,
)
```

SFTP instantiates it a second time rather than reimplementing it.

## Breakpoints and the escape hatch

Widths are for content panes; the rail is separate.

| Width | Layout | Devices |
| ----- | ------ | ------- |
| `< 800` | one pane, push navigation | phones, narrow windows |
| `>= 800` | list + detail | iPad 11" portrait (834), most desktop windows |
| `>= 1400` | as above, rail expands to show labels | iPad landscape (1194+), large windows |

800 is chosen for iPad 11" portrait at 834pt — the narrowest device that must
show two panes.

`Stores.setting.forceSinglePane` (default false) forces single-pane at any
width, under the interface section of settings.

## Motion

| Moment | Treatment |
| ------ | --------- |
| Crossing a breakpoint; pane appearing or leaving | list width animates, detail slides in, `Durations.medium3` |
| Selecting a different server | **fade-through**. A slide would imply hierarchy; switching servers is lateral. |
| detail to edit inside the pane | normal push slide, reduced travel — full-width travel inside a narrow column reads as frantic |

`split.dart:328` already has usable push/pop tweens to draw from.

## What moves into fl_lib, and what does not

**Moves in**

- `AppRoute`, reworked: sealed hierarchy, `NavTarget`, no `UnimplementedError`
- `PaneScope` — an `InheritedWidget` answering "am I in a pane" and "can this pane pop"
- `PaneNavigator` — one pane, one nested `Navigator`, no back button at its root
- `AdaptivePanes` — N panes with minimum widths and a collapse order
- `SessionTabs<T>`
- `CustomAppBar` reading `PaneScope`; `showDialog` pinned to the root navigator

**Stays in the app**

Pane 2's server list. It reads `serversProvider`, connection-state colours and
tag filters — entirely business. The only thing it shares with the existing
card grid is "name plus connection-state dot", which becomes one small
`ServerStatusDot` used by both.

## Delivery stages

| Stage | Content | Verifiable on its own |
| ----- | ------- | --------------------- |
| 1 | fl_lib: `AppRoute` rework, `PaneScope`, `CustomAppBar` awareness, dialog navigator, widget tests | app behaviour unchanged, 59 call sites untouched |
| 2 | fl_lib: `AdaptivePanes` + `PaneNavigator` | app not touched |
| 3 | fl_lib: `SessionTabs<T>`; `SSHTabPage` migrates onto it | terminal behaviour regression-tested |
| 4 | app: single entry point for terminal and SFTP; file tab gains remote sessions | two paths become one |
| 5 | app: `serverSelectionProvider`, `ServerPage` splits into two panes, compact list, motion | the visible result |
| 6 | app: `forceSinglePane`, restoration of the selection, Escape and back key | polish |

Stages 1–3 are entirely inside fl_lib with no app behaviour change. Each stage
is a separate commit and can be reverted alone.

## Open risks

- **Dialogs inside a pane.** Must be pinned to the root navigator explicitly
  (fl_lib #5 above), or every confirmation dialog gets clipped to a column.
- **Back and Escape.** A pane at its root route must let the key fall through
  to the outer navigator rather than swallow it. `PaneScope` owns this.
- **Restoration of the selection.** `home.dart` already restores its tab
  index; the selected server needs the same, or reopening a window lands on an
  empty pane 3.
- **Terminal sessions during migration.** Stage 3 moves live session state
  onto new machinery. The encode/decode format in `_restorableTabsState` must
  stay compatible, or users lose their open terminals on upgrade.

## Manual verification

Everything here needs a running app and, in places, a real server. Collected
as it came up rather than checked one item at a time.

### Panes

- [ ] Window at least 800pt wide: tapping a server shows a compact list on the
      left and its details on the right. Below 800pt, unchanged.
- [ ] Selecting another server cross-fades the detail; the list stays put.
- [ ] The divider drags, and the width it is left at survives a relaunch.
- [ ] Settings → single column forces one pane however wide the window is.
- [ ] A server that has never connected still selects, and the detail pane
      shows the error in full plus a working Retry.
- [ ] Deleting a server closes the dialog and collapses the pane back to a
      full-width list.

### Navigation

- [ ] The bar (or rail) stays visible on a server's details, its files, its
      processes.
- [ ] Leaving a tab and returning lands back where you were in it.
- [ ] Back steps through a tab's own stack, and only leaves the app once that
      stack is empty.
- [ ] Switching between Server / SSH / File tabs is smooth — the regression
      that rebuilt each tab once per animation frame is fixed, but only a real
      run says whether anything else is heavy.

### Terminal

- [ ] Opening the first terminal shows no red screen (was `View.of` during
      `initState` in xterm).
- [ ] The terminal button on a server opens a tab in the SSH tab rather than a
      full-screen page.
- [ ] The same server opened twice gives `name` and `name(1)`.
- [ ] Closing a middle tab keeps the tab you were looking at.
- [ ] Cancelling the close confirmation leaves the terminal focused.
- [ ] Switching tabs moves focus with them — typing goes to the visible one.
- [ ] Quit and reopen: terminals come back, with their tmux session and
      window, and it lands on the first.
- [ ] Sort menu: all four options apply, and the icon on the bar changes.
- [ ] Search and history both open a terminal; a server deleted since is a
      disabled row rather than an error toast.

### Files

- [ ] The SFTP button opens a tab in the File tab beside this device's files.
- [ ] Two servers' files stay open at once, and switching between them does
      not reconnect.

### Known gaps

- SFTP sessions are not restored across launches; terminals are.
- The File tab shows two bars: the tab strip, and SFTP's own bar carrying
  download/sort/search/sudo/refresh. Movable into the strip if it reads heavy.
