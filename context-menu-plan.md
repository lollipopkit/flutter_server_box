# Right-click, wherever there is a long press

A long press is how a touch screen asks for "the other thing". A pointer asks
by right-clicking, and this app never listened. On a desktop — or an iPad with
a trackpad, or an Android tablet with a mouse — every one of those actions is
currently unreachable without holding the button down.

## What exists today

`onLongPress` appears at 13 sites in `lib/` and 14 in `packages/fl_lib/`.
They are not one kind of thing:

| Shape | Where | What the long press does |
| ----- | ----- | ------------------------ |
| Opens a menu | `storage/file_browser.dart:789` | A centred `showRoundDialog` holding a column of `Btn.tile` |
| Runs an action | `server/tab/utils.dart:43` | Flips the card, or opens the edit page when not connected |
| Runs an action | `ssh/tab.dart:86`, `ssh/tab_add.dart` ×4 | Opens the edit page, or removes a rootfs |

So "support right-click" means two different things. For the second group it
means the same action on a different gesture. For the first it means a menu
**at the pointer**, because that is where a desktop user is looking.

Neither `ListTile` nor `InkWell` takes a secondary-tap callback, so every site
either wraps or is wrapped. The shared carriers in `fl_lib` are worth doing
first because they cover most of them at once:

- `view/widget/tile/card_tile.dart:63`
- `view/widget/side_bar.dart:173`
- `view/widget/btn/btn.dart` (`onLongTap`, six call sites within the file)
- `core/ext/widget.dart:52` — the `InkWell` behind `.cardx`-style wrapping

Nothing in the repo handles a secondary tap today. The vendored xterm fork
already exposes `onSecondaryTapDown`/`onSecondaryTapUp`
(`terminal_view.dart:41`) and the app passes neither, so the terminal is an
opportunity rather than a conflict.

## Two decisions

### Not gated on platform

`onSecondaryTap` only fires where there is a secondary button. A phone never
produces one; an iPad with a trackpad and an Android with a mouse do — and
those are exactly the users who want this. Gating on `Pfs.type` would withhold
it from the case that motivated the request. Wiring it unconditionally costs
nothing on a touch-only device.

### `onSecondaryTapUp`, not `...Down`

It carries the position *and* fires on release. Windows opens a context menu on
release, macOS on press; release is the one both audiences accept, and the one
that lets a user change their mind by dragging off the item.

## What the touch path keeps

The centred dialog. A menu that opens under the finger that summoned it is a
menu partly covered by that finger, and `showRoundDialog` is already what every
other confirmation in this app looks like.

The consequence is that one menu has two appearances depending on how it was
opened. That is deliberate: they are two different pointing devices with two
different occlusion problems, and matching them to each other would mean
choosing which one to serve badly.

## Stages

| Stage | Content | Verifiable on its own |
| ----- | ------- | --------------------- |
| 1 | Right-click does what long press does, everywhere | every existing action reachable with a mouse |
| 2 | `ContextMenuAction` + `showContextMenu`; the menus open at the pointer | the file browser's entry menu appears where the cursor is |
| 3 | The terminal's own right-click | copy a selection, else paste |

### Stage 1 — the gesture

One helper in `fl_lib`, because 27 sites should not each build a
`GestureDetector`:

```dart
extension WidgetSecondaryX on Widget {
  /// Right-click, for the same thing a long press does.
  Widget onSecondary(void Function(Offset at)? onTap);
}
```

The four shared carriers grow an `onSecondaryTap` that defaults to their
`onLongPress`, so a caller that already passes one gets right-click for free
and cannot forget. Sites using `ListTile` directly wrap with the extension.

Behaviour change: none. Right-click reaches what a long press reached.

### Stage 2 — the menu, where the pointer is

The menus are currently built as `List<Widget>` and rendered into a dialog.
That shape cannot be positioned, and it makes every action responsible for
closing the menu itself — which is the same `popDialog` trap `CLAUDE.md`
warns about, repeated once per entry.

```dart
class ContextMenuAction {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool destructive;
}

/// [at] null renders a centred dialog; a position renders a popup there.
Future<void> showContextMenu(
  BuildContext context,
  List<ContextMenuAction> actions, {
  Offset? at,
});
```

`FileBrowserArgs.entryActions` changes from `List<Widget>` to
`List<ContextMenuAction>`; `local.dart` and `sftp.dart` follow. Every one of
them loses its leading `context.popDialog()`, because closing the menu becomes
the menu's job rather than each action's.

### Stage 3 — the terminal

`TerminalView.onSecondaryTapUp` is already there. Bound to the convention every
terminal on every platform uses: copy when there is a selection, paste when
there is not. Nothing else — a terminal's right-click doing something clever is
a terminal people fight.

## Risks

- **The gesture arena.** An `InkWell` inside a wrapping `GestureDetector`, both
  inside a scrollable. A secondary button does not start a scroll drag, so
  they should not compete — but this is the kind of thing that is only really
  settled on a device, and Stage 1 has to be checked there before Stage 2
  builds on it.
- **A menu at the edge of the window.** `showMenu` reflows, but the entry menu
  is tall; a right-click near the bottom on a short window is worth looking at.
- **Two appearances of one menu.** Stated above as deliberate. If it reads as
  inconsistent in use rather than on paper, the fallback is to position the
  touch menu too and accept the occlusion.
- **`entryActions`' signature is public to three pages.** The change is
  mechanical, but a caller that keeps building widgets would still compile if
  the parameter were left as `List<Widget>` alongside — so it is replaced, not
  added beside.

## Verification

Most of this list turned out not to need hands. Every right-click in the app
goes through one extension, so its contract is checked once rather than per
page; what is left below is what a test cannot reach.

### 1. The gesture — covered by `fl_lib/test/secondary_tap_test.dart`

- [x] Right-click a server card: it flips, exactly as a long press does.
      Structural: `tab/tab.dart:272` passes `asSecondary(() =>
      _onLongPressCard(srv))`, the same callback `onLongPress` gets.
- [x] Long press still works on all of the above — `the primary button still
      taps and long-presses`. `HitTestBehavior.translucent` is what buys it.
- [x] Scrolling a list with the left button still scrolls, and a long press
      during a scroll does not fire — `a scroll drag still scrolls, and is not
      a long press`.
- [x] Also locked, and not on the original list: it fires on **release**, a
      drag off before release calls nothing, the position handed over is
      global, and a null callback leaves the widget unwrapped.
- [x] Right-click a server in the SSH tab's list: the edit page opens.
      Structural, and checked at both ends: `tab_add.dart:249` passes one
      callback to `onLongPress:` and to `.onSecondary(asSecondary(...))`, and
      `tab.dart:87` is that callback — `ServerEditPage.route.go`.
- [x] Right-click a server card that is not connected: the edit page opens —
      `test/server_card_gesture_test.dart`, on a real `ServerPage`. Both
      gestures are checked there, and they agree because `tab/tab.dart:272`
      hands `asSecondary` the same `_onLongPressCard(srv)` the long press
      gets.

The page pumps with the three stores registered and no seam, given two things
the app supplies at its root: `ResponsivePoints.builder`, and
`LibLocalizations.delegate` beside the app's own — `context.libL10n` is a
`!` on a lookup, so without it the top bar throws. The refresh interval is set
to 0, which `normalizeServerStatusRefreshSeconds` reads as off; otherwise its
periodic timer outlives the tree and fails the run.

### 2. The menu — covered by `test/file_browser_test.dart`

- [x] Right-click a file in the browser: the menu opens at the cursor —
      `a right-click opens it where the pointer is`.
- [x] Long press the same file: the centred dialog — `a long press opens it
      centred`.
- [x] An entry runs after the menu has closed — `an action runs after the menu
      has closed`. Not literally every entry.
- [x] Right-click in empty space offers what can be made here.
- [ ] ~~Right-click near the bottom edge: the menu stays on screen.~~ **Not
      ours.** Where Flutter puts a menu that would overflow is Flutter's
      layout; asserting it would test the framework. Left to the framework
      deliberately — the same reasoning the test file already records.

### 3. The terminal — the chords are covered, the pointer is not

- [x] Ctrl+C still interrupts — `test/terminal_clipboard_chord_test.dart`. The
      whole platform matrix: away from macOS copy is Ctrl+**Shift**+C and a
      plain Ctrl+C is not a chord at all, which is what leaves SIGINT alone;
      on macOS it is Cmd+C and Ctrl+C is likewise untouched. Paste takes Shift
      too rather than being the odd one out.
- [x] With nothing selected, right-click pastes —
      `test/terminal_clipboard_test.dart`, on a real `SSHPage` with a mocked
      clipboard channel. An empty clipboard types nothing, and the handler is
      the page's rather than the terminal's own.
- [ ] With text selected, right-click copies it and clears the selection.
- [ ] Neither interferes with the existing text-selection drag.

`TerminalSession.over` is the seam that made the page reachable: it takes a
`ShellBackend` outright, and because `adopt` returns early when one is already
set, the page never opens a connection. `test/helpers/fake_shell.dart` is the
backend. That harness is reusable for anything else on this page.

Two things it does not reach, both about a selection there is no way to make
from a test. The page owns its `TerminalController` privately, so a selection
cannot be arranged; and a synthetic secondary tap never arrives, because
xterm's gesture handler is `HitTestBehavior.deferToChild` over a render object
a widget test's mouse does not hit. The paste test therefore calls the callback
`TerminalView` was handed rather than synthesising a pointer — the branch is
the app's, the arena is xterm's.

Stale while checking this: the comment at `page.dart:430` says
`_onClipboardAction` "was already exactly that, for the toolbar button". There
is no such button any more; the right-click is its only caller.

`isClipboardChord` was lifted out of `_Keyboard` to make the matrix testable:
it read `HardwareKeyboard.instance` and `isMacOS` inline, so stating it needed
three operating systems and a keyboard. That is a change to source made for a
test, and it is the only one in this sweep.


## The rest of the desktop gaps

Surveyed after the three stages above, and done in the same sweep.

| # | Gap | Outcome |
| - | --- | ------- |
| 1 | ⌘1-9 and ⌘, existed only inside `PlatformMenuBar`, a macOS API | `desktopShortcuts` binds them on all three; the menu bar keeps its entries for discovery |
| 2 | No drag and drop at all | A dropped path is a `LocalFileRef`, so it is an ordinary `FileTransfer` |
| 3 | No multi-select | Modifier-click, shift-range, Cmd+A; a bar replaces the bottom row while something is picked |
| 4 | No keyboard navigation | Arrows, Enter, Backspace, F2, Delete, Cmd+A, Escape, on the list's own focus |
| 5 | 44 icon buttons said nothing on hover | 81 of 82 now do; the 82nd draws its own label |
| 6 | Terminal had no clipboard chords | Cmd+C/V on macOS, Ctrl+Shift+C/V elsewhere |
| 6b | Terminal had no line-editing chords, and no platform at all | Found by hand, after the rest of this was called done — see below |
| 7 | Nothing on a right-click in empty space | The same "what can be made here" list as the add button |
| 8 | No double-click | **Not done, deliberately** — see below |

### Why there is no double-click

Single click opens, on both kinds of pointer, and that did not change.
Reversing it — click selects, double-click opens, as a desktop file manager
does — would make entering a folder cost two taps on a touch screen, and this
is one browser on both.

That leaves double-click with nothing to do that the first click has not
already done. Adding it anyway is not free: declaring `onDoubleTap` puts a
double-tap recogniser in the arena, and every single click then waits out the
double-tap timeout before opening. A delay on every open, to gain a gesture
that is already handled.

### What selection does that a desktop user expects, and what it does not

- A plain click **opens**. A modifier click picks. Once anything is picked, a
  plain click picks too — otherwise the second file would need the modifier
  held again, which is not how any list behaves.
- Shift extends from the last pick, as everywhere else.
- A selection is names in one listing, so leaving the directory drops it.
- Finder *replaces* the selection on a plain click and this *adds* to it.
  Deliberate: with no double-click to open, replace-on-click would make it
  impossible to open anything while a selection is open.

#### What the keyboard walkthrough turned up

Two defects, one root and one gap, neither of which any test could have seen
because nothing set them up.

`TerminalSession` built its `Terminal()` without a `platform`, so it was
`TerminalTargetPlatform.unknown` — the default, and what this app passed for as
long as it had a terminal. Every keytab entry that distinguishes a Mac took the
other branch: Option+Left sent `\E[1;5D` where a Mac wants `\Eb`, which a shell
ignores, so word movement did nothing. The same setting decides whether
`AltInputHandler` stands aside, so Option+e was sending an escape sequence
rather than composing `é`. `lib/data/ssh/terminal_platform.dart` answers it now,
and iOS answers `macos` — the keytab's question is about the keyboard, and an
iPad's is an Apple one.

Command chords could not work at all. `keyInput` takes shift, alt and ctrl and
**no meta**, and the keytab has no Command entry, so ⌘⌫ and ⌘←/→ reached the
terminal as nothing. They are intercepted in `_handleKeyEvent` beside the
clipboard chords and sent as the control characters a shell's own line editor
binds — `^U`, `^A`, `^E`.

While there: `_isClipboardChord` asked `isMacOS`, so ⌘C on an iPad with a
keyboard was not a copy. It asks `_appleKeyboard` now, which is the same
question the keytab is asked.

### Verification for these

- [x] ⌘/Ctrl+1-9 switches tabs on Linux and Windows, not only macOS —
      `test/desktop_shortcuts_test.dart`, `meta on macOS, control everywhere
      else`. The binding, not a run on those two OSes.
- [x] ⌘/Ctrl+, opens settings — same file, `settings has its own chord`.
- [x] Ctrl-click picks; shift-click extends; ⌘A picks the listing; Escape
      clears; leaving the directory clears — five tests in `picking several
      out` and `the keyboard`.
- [x] Arrow keys move a cursor without picking; Enter opens it; Backspace goes
      up; F2 renames — `arrows move a cursor, enter opens it`, `backspace goes
      up`, `F2 renames where the cursor is`. F2 with two picked does nothing
      rather than guessing, which is also locked.
- [x] Delete with several picked asks once, listing them, not once per file —
      `asks once, and names what it is about to delete`, plus that confirming
      removes every one and that dismissing removes none. The way out is the
      barrier: `Btnx.okReds` is one button, so there is no Cancel.
- [x] Hovering any toolbar icon says what it does — `every icon button says
      what it does` walks the tree rather than listing buttons, so one added
      later is covered without anyone remembering.
- [ ] "Send to" with several picked asks where once and reuses it.
- [ ] Dragging a file from the system onto the listing queues a transfer; a
      folder queues the whole tree. A real OS drag; the platform channel could
      be faked, which tests the fake.
- [ ] Ctrl+Shift+C/V in the terminal on Linux, and Ctrl+C still interrupts.
      Needs Linux for the real thing, and a terminal harness for the binding.
