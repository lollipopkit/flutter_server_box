import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
import 'package:server_box/data/provider/virtual_keyboard.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/view/widget/float_shell.dart';
import 'package:xterm/core.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

/// A terminal, over whatever else is on screen.
///
/// The same shell the tab has, not a second one on the same server — see
/// [FloatingTerminal], which is also why the tab draws a placeholder while
/// this is up. The window itself is [FloatShell], shared with the Agent's.
class TerminalFloatingShell extends ConsumerWidget {
  const TerminalFloatingShell({super.key, required this.area});

  /// The box this is painted in, measured by the caller.
  final Size area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final floating = ref.watch(terminalShellProvider);
    final shell = ref.read(terminalShellProvider.notifier);

    return FloatShell(
      area: area,
      visible: floating != null,
      mode: floating.mode,
      geometry: terminalShellGeometry,
      title: floating?.title ?? libL10n.terminal,
      icon: Icons.terminal,
      onExpand: shell.expand,
      onCollapse: shell.collapse,
      // Taken back to where it came from, not merely closed: the shell is
      // still running and the tab is where the rest of what you can do with it
      // lives — snippets, sudo, tmux, the file browser.
      onHide: () {
        shell.hide();
        ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
      },
      hideTooltip: context.l10n.floatReturnToTab,
      // Empty the moment the terminal goes back, rather than kept for the two
      // hundred milliseconds the window takes to fade: the tab puts its own
      // view back on this session in the same frame, and two of them on one
      // terminal is exactly what the placeholder exists to prevent.
      builder: (_) => switch (floating) {
        null => const SizedBox.shrink(),
        final it => _FloatTerminal(key: ValueKey(it.session), session: it.session),
      },
    );
  }
}

/// What the window holds: the terminal, and on a phone the keys a terminal
/// needs that a software keyboard has not got.
class _FloatTerminal extends ConsumerStatefulWidget {
  const _FloatTerminal({super.key, required this.session});

  final TerminalSession session;

  @override
  ConsumerState<_FloatTerminal> createState() => _FloatTerminalState();
}

class _FloatTerminalState extends ConsumerState<_FloatTerminal> {
  final _controller = TerminalController();
  final _focusNode = FocusNode();
  final _termKey = GlobalKey<TerminalViewState>();

  Terminal get _terminal => widget.session.terminal;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = TerminalLook.isDark(context);
    final theme = TerminalLook.themeOf(context);

    return ColoredBox(
      color: theme.background,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              child: TerminalView(
                _terminal,
                key: _termKey,
                controller: _controller,
                focusNode: _focusNode,
                textStyle: TerminalLook.style,
                theme: theme,
                backgroundOpacity: 0,
                keyboardType: TextInputType.text,
                keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
                deleteDetection: isMobile,
                // The same convention the tab keeps: copy what is selected,
                // and paste when nothing is.
                onSecondaryTapUp: (_, _) => unawaited(_clipboardAction()),
                onCopied: _onCopied,
                onPaste: _paste,
                onSelectAll: () =>
                    _termKey.currentState?.renderTerminal.selectAll(),
                autofocus: false,
                hideScrollBar: false,
              ),
            ),
          ),
          if (isMobile) _buildKeys(),
        ],
      ),
    );
  }
}

extension _Utils on _FloatTerminalState {
  /// The keys this window can actually serve.
  ///
  /// The tab's strip carries four more — snippets, the file browser, the sudo
  /// password, the tmux switcher — and every one of them opens a page or a
  /// dialog belonging to the terminal *page*, which is not what is in this
  /// window. Left in, they would be buttons that take a tap and do nothing,
  /// which is the failure `VirtKeyX.worksOn` exists to avoid; so they are not
  /// drawn here, on the same terms.
  ///
  /// Read on every build rather than cached: this is a short list behind a
  /// widget that rebuilds only when a modifier is armed, and a strip that went
  /// stale the moment the keys were reordered in the settings would be the
  /// more surprising of the two.
  List<VirtKey> get _keys {
    final disabled = Stores.setting.sshVirtKeysDisabled.fetch().toSet();
    final spi = widget.session.spi;
    return VirtKeyX.loadFromStore(persistRepairs: false)
        .where((key) => !disabled.contains(key.name))
        .where((key) => key.worksOn(spi))
        .where(
          (key) => switch (key.func) {
            null ||
            VirtualKeyFunc.clipboard ||
            VirtualKeyFunc.toggleIME => true,
            _ => false,
          },
        )
        .toList();
  }

}

/// One row, as tall as the tab's rows are.
const _keyRowHeight = 37.0;

/// Wide enough for `PgDn` and for a 17pt icon to sit in the middle of.
const _keyWidth = 46.0;

extension _Widgets on _FloatTerminalState {
  /// One row that scrolls sideways, rather than the tab's grid of seven per
  /// row: this window is as wide as it was dragged to, and a row that reflowed
  /// as it was resized would move every key under the thumb reaching for one.
  Widget _buildKeys() {
    return Consumer(
      builder: (context, ref, _) {
        final state = ref.watch(virtKeyboardProvider);
        final notifier = ref.read(virtKeyboardProvider.notifier);
        // The modifiers are the terminal's, not the strip's, and while this
        // window is up the tab is drawing a placeholder — so nothing else is
        // setting this.
        _terminal.inputHandler = notifier;

        final keys = _keys;
        if (keys.isEmpty) return const SizedBox.shrink();

        final isDark = TerminalLook.isDark(context);
        return SizedBox(
          height: _keyRowHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: keys.length,
            itemBuilder: (_, at) =>
                _buildKey(keys[at], state, notifier, isDark),
          ),
        );
      },
    );
  }

  Widget _buildKey(
    VirtKey item,
    VirtKeyState state,
    VirtKeyboard notifier,
    bool isDark,
  ) {
    final armed = switch (item.key) {
      TerminalKey.control => state.ctrl,
      TerminalKey.alt => state.alt,
      TerminalKey.shift => state.shift,
      _ => false,
    };
    final color = isDark ? Colors.white : Colors.black;

    return InkWell(
      onTap: () => _press(item, notifier),
      child: SizedBox(
        width: _keyWidth,
        height: _keyRowHeight,
        child: Center(
          child: item.icon != null
              ? Icon(item.icon, size: 17, color: color)
              : Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: armed ? UIs.primaryColor : color,
                  ),
                ),
        ),
      ),
    );
  }

}

extension _Actions on _FloatTerminalState {
  void _press(VirtKey item, VirtKeyboard notifier) {
    switch (item.func) {
      case VirtualKeyFunc.toggleIME:
        HapticFeedback.mediumImpact();
        _termKey.currentState?.toggleFocus();
        return;
      case VirtualKeyFunc.clipboard:
        HapticFeedback.mediumImpact();
        unawaited(_clipboardAction());
        return;
      // Filtered out by [_keys], and stated rather than defaulted so a key
      // added to `VirtualKeyFunc` has to be thought about here too.
      case VirtualKeyFunc.backspace:
      case VirtualKeyFunc.snippet:
      case VirtualKeyFunc.file:
      case VirtualKeyFunc.sudoPassword:
      case VirtualKeyFunc.tmuxSwitch:
        return;
      case null:
        break;
    }

    if (item.key case final key?) {
      HapticFeedback.mediumImpact();
      switch (key) {
        case TerminalKey.control:
          notifier.setCtrl(!notifier.ctrl);
        case TerminalKey.alt:
          notifier.setAlt(!notifier.alt);
        case TerminalKey.shift:
          notifier.setShift(!notifier.shift);
        default:
          _terminal.keyInput(key);
      }
    }
    if (item.inputRaw case final raw?) {
      HapticFeedback.mediumImpact();
      _terminal.textInput(raw);
    }
  }

  void _onCopied() {
    if (mounted) Toast.success(libL10n.success);
    _controller.clearSelection();
  }

  Future<void> _paste() async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    final text = value?.text;
    if (text == null) return;
    // `paste`, not `textInput`: it brackets the text when the program asked
    // for that (DECSET 2004).
    _terminal.paste(text);
    _controller.clearSelection();
  }

  Future<void> _clipboardAction() async {
    if (_controller.selection != null) {
      final selected = _termKey.currentState?.renderTerminal.selectedText;
      if (selected != null && selected.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: selected));
        _onCopied();
      }
      return;
    }
    await _paste();
  }
}
