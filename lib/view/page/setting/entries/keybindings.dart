import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/inset.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/keybinding.dart';
import 'package:server_box/data/provider/app/keybindings.dart';

/// Every key the app takes, and the way to change them.
///
/// One list for every page's keys, because a chord is a resource they share:
/// the workspace and the server tab may both use one, a global chord no other
/// page can, and only a list of all of them can say which.
class KeybindingsPage extends ConsumerStatefulWidget {
  /// Shown inside the settings pane, which already names it.
  final bool embedded;

  const KeybindingsPage({super.key, this.embedded = false});

  static const route = AppRouteNoArg(
    page: KeybindingsPage.new,
    path: '/settings/keybindings',
  );

  @override
  ConsumerState<KeybindingsPage> createState() => _KeybindingsPageState();
}

class _KeybindingsPageState extends ConsumerState<KeybindingsPage> {
  final _search = TextEditingController();
  var _needle = '';
  var _onlyModified = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kb = ref.watch(keybindingsProvider);
    final rows = [
      for (final c in KbCommand.values)
        if ((!_onlyModified || kb.isModified(c)) && _matches(kb, c)) c,
    ];
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 7, 7, 9),
          child: Row(
            children: [
              Expanded(
                child: Input(
                  controller: _search,
                  icon: Icons.search,
                  hint: l10n.kbSearchHint,
                  suggestion: false,
                  noWrap: true,
                  onChanged: (v) =>
                      setState(() => _needle = v.trim().toLowerCase()),
                ),
              ),
              Btn.icon(
                text: l10n.kbOnlyModified,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: _onlyModified
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onTap: () => setState(() => _onlyModified = !_onlyModified),
              ),
              Btn.icon(
                text: l10n.kbResetAll,
                icon: const Icon(Icons.restart_alt, size: 18),
                onTap: _resetAll,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: context.padBottom(
              const EdgeInsets.symmetric(horizontal: 7),
            ),
            children: [
              if (rows.isEmpty)
                EmptyPane(icon: Icons.search_off, label: _search.text),
              for (final c in rows) _KbRow(command: c, kb: kb, onTap: _edit),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 17, 13, 20),
                child: Text(l10n.kbNote, style: UIs.text12Grey),
              ),
            ],
          ),
        ),
      ],
    );
    if (widget.embedded) return body;
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.keybindings)),
      body: body,
    );
  }

  bool _matches(KbState kb, KbCommand c) {
    if (_needle.isEmpty) return true;
    return c.title.toLowerCase().contains(_needle) ||
        kb.labelOf(c).toLowerCase().contains(_needle) ||
        c.scope.label.toLowerCase().contains(_needle);
  }

  Future<void> _resetAll() async {
    final kb = ref.read(keybindingsProvider);
    if (kb.overrides.isEmpty) return;
    final ok = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text(l10n.kbResetAllAsk),
      actions: Btnx.cancelRedOk,
    );
    if (ok != true) return;
    ref.read(keybindingsProvider.notifier).resetAll();
    Toast.show(l10n.kbResetDone);
  }

  Future<void> _edit(KbCommand c) async {
    if (c.fixed) {
      Toast.show(l10n.kbFixedHint);
      return;
    }
    await context.showRoundDialog<void>(
      title: c.title,
      child: _Recorder(command: c),
    );
  }
}

extension KbCommandL10n on KbCommand {
  String get title => switch (this) {
    KbCommand.wsSplitRight => l10n.kbWsSplitRight,
    KbCommand.wsSplitDown => l10n.kbWsSplitDown,
    KbCommand.wsFocusLeft => l10n.kbWsFocusLeft,
    KbCommand.wsFocusRight => l10n.kbWsFocusRight,
    KbCommand.wsFocusUp => l10n.kbWsFocusUp,
    KbCommand.wsFocusDown => l10n.kbWsFocusDown,
    KbCommand.wsNewTab => l10n.kbWsNewTab,
    KbCommand.wsCloseTab => l10n.kbWsCloseTab,
    KbCommand.wsNextTab => l10n.kbWsNextTab,
    KbCommand.wsPrevTab => l10n.kbWsPrevTab,
    KbCommand.wsTabs => l10n.kbWsTabs,
    KbCommand.wsReopenTab => l10n.kbWsReopenTab,
    KbCommand.wsMaximize => l10n.kbWsMaximize,
    KbCommand.wsSync => l10n.kbWsSync,
    KbCommand.wsQuickOpen => l10n.kbWsQuickOpen,
    KbCommand.wsSwitcher => l10n.kbWsSwitcher,
    KbCommand.homeTab => l10n.kbHomeTab,
    KbCommand.appSettings => l10n.kbAppSettings,
    KbCommand.settingsSearch => l10n.kbSettingsSearch,
    KbCommand.serverPrev => l10n.kbServerPrev,
    KbCommand.serverNext => l10n.kbServerNext,
    KbCommand.serverList => l10n.kbServerList,
    KbCommand.serverClose => l10n.kbServerClose,
  };
}

extension KbScopeL10n on KbScope {
  String get label => switch (this) {
    KbScope.global => l10n.kbScopeGlobal,
    KbScope.workspace => l10n.workspace,
    KbScope.settings => l10n.kbScopeSettings,
    KbScope.serverTab => l10n.kbScopeServerTab,
  };
}

/// Keycaps, the way a chord is drawn everywhere on this page.
class KbCaps extends StatelessWidget {
  const KbCaps({super.key, required this.chord, this.large = false});

  final String chord;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caps = KbChord.caps(chord, KbPlatform.current);
    if (caps.isEmpty) {
      return Text(l10n.kbUnassigned, style: UIs.text12Grey);
    }
    final size = large ? 30.0 : 22.0;
    return Wrap(
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final c in caps)
          Container(
            constraints: BoxConstraints(minWidth: size, minHeight: size),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(5),
            ),
            // Centred in the cap without making the cap fill the row.
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                c,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: large ? 15 : 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KbRow extends ConsumerWidget {
  const _KbRow({required this.command, required this.kb, required this.onTap});

  final KbCommand command;
  final KbState kb;
  final ValueChanged<KbCommand> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final modified = kb.isModified(command);
    final source = command.fixed
        ? l10n.kbFixed
        : modified
        ? l10n.kbModified
        : l10n.kbDefault;
    return ListTile(
      onTap: () => onTap(command),
      title: Text(command.title),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${command.scope.label} · '),
            TextSpan(
              text: source,
              style: modified
                  ? TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w500,
                    )
                  : null,
            ),
          ],
        ),
        style: UIs.text12Grey,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          KbCaps(chord: kb.chordOf(command)),
          if (modified)
            Btn.icon(
              text: l10n.kbResetOne,
              icon: const Icon(Icons.undo, size: 18),
              onTap: () =>
                  ref.read(keybindingsProvider.notifier).reset(command),
            ),
        ],
      ),
    );
  }
}

/// Waits for a chord, shows what it would take from other commands, and
/// binds it on Enter.
class _Recorder extends ConsumerStatefulWidget {
  const _Recorder({required this.command});

  final KbCommand command;

  @override
  ConsumerState<_Recorder> createState() => _RecorderState();
}

class _RecorderState extends ConsumerState<_Recorder> {
  final _focus = FocusNode();
  String? _chord;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.handled;
    final hw = HardwareKeyboard.instance;
    final plain =
        !hw.isControlPressed &&
        !hw.isMetaPressed &&
        !hw.isAltPressed &&
        !hw.isShiftPressed;
    // Bare Escape and Enter are this dialog's own: a chord of either alone
    // would be one nobody could set.
    if (plain && e.logicalKey == LogicalKeyboardKey.escape) {
      context.popDialog();
      return KeyEventResult.handled;
    }
    if (plain && e.logicalKey == LogicalKeyboardKey.enter) {
      _confirm();
      return KeyEventResult.handled;
    }
    final chord = KbChord.fromEvent(e, hw);
    if (chord != null) setState(() => _chord = chord);
    return KeyEventResult.handled;
  }

  void _confirm() {
    final chord = _chord;
    if (chord == null) return;
    ref.read(keybindingsProvider.notifier).bind(widget.command, chord);
    context.popDialog();
    Toast.show(
      l10n.kbChanged(
        widget.command.title,
        KbChord.label(chord, KbPlatform.current),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kb = ref.watch(keybindingsProvider);
    final scheme = Theme.of(context).colorScheme;
    final chord = _chord;
    final conflicts = chord == null
        ? const <KbCommand>[]
        : kb.conflictsOf(widget.command, chord);
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.kbCurrent(
              kb.labelOf(widget.command).isEmpty
                  ? l10n.kbUnassigned
                  : kb.labelOf(widget.command),
              widget.command.scope.label,
            ),
            style: UIs.text12Grey,
          ),
          UIs.height13,
          Focus(
            focusNode: _focus,
            autofocus: true,
            onKeyEvent: _onKey,
            child: GestureDetector(
              onTap: _focus.requestFocus,
              child: ListenableBuilder(
                listenable: _focus,
                builder: (context, _) => Container(
                  constraints: const BoxConstraints(minHeight: 64),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: _focus.hasFocus
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: 2,
                    ),
                  ),
                  child: chord == null
                      ? Text(l10n.kbPress, style: UIs.textGrey)
                      : KbCaps(chord: chord, large: true),
                ),
              ),
            ),
          ),
          UIs.height13,
          Text(l10n.kbRecordHint, style: UIs.text12Grey),
          if (conflicts.isNotEmpty) ...[
            UIs.height13,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: scheme.onErrorContainer),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final c in conflicts)
                          Text(
                            l10n.kbConflict(c.title, c.scope.label),
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        Text(
                          l10n.kbConflictNote,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          UIs.height13,
          Row(
            children: [
              TextButton(
                onPressed: () {
                  ref
                      .read(keybindingsProvider.notifier)
                      .unbind(widget.command);
                  context.popDialog();
                },
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                child: Text(l10n.kbRemove),
              ),
              const Spacer(),
              TextButton(
                onPressed: context.popDialog,
                child: Text(libL10n.cancel),
              ),
              TextButton(
                onPressed: chord == null ? null : _confirm,
                child: Text(libL10n.ok),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
