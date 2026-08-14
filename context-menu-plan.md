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

## Manual verification

### 1. The gesture

- [ ] Right-click a server card: it flips, exactly as a long press does.
- [ ] Right-click a server card that is not connected: the edit page opens.
- [ ] Right-click a server in the SSH tab's list: the edit page opens.
- [ ] Long press still works on all of the above, on a touch screen.
- [ ] Scrolling a list with the left button still scrolls, and a long press
      during a scroll does not fire.

### 2. The menu

- [ ] Right-click a file in the browser: the menu opens at the cursor.
- [ ] Long press the same file on a touch screen: the centred dialog.
- [ ] Every entry in both does what it did before, and closes the menu.
- [ ] Right-click near the bottom edge: the menu stays on screen.

### 3. The terminal

- [ ] With text selected, right-click copies it and clears the selection.
- [ ] With nothing selected, right-click pastes.
- [ ] Neither interferes with the existing text-selection drag.
