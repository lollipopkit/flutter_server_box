part of 'page.dart';

extension _AskAi on SSHPageState {
  List<ContextMenuButtonItem> _buildTerminalToolbar(
    BuildContext context,
    CustomTextEditState state,
    List<ContextMenuButtonItem> defaultItems,
  ) {
    final rawSelection = _termKey.currentState?.renderTerminal.selectedText;
    final selection = rawSelection?.trim();
    if (selection == null || selection.isEmpty) {
      return defaultItems;
    }

    final items = List<ContextMenuButtonItem>.from(defaultItems);
    items.add(
      ContextMenuButtonItem(
        label: context.l10n.askAi,
        onPressed: () {
          state.hideToolbar();
          _showAskAiSheet(selection);
        },
      ),
    );
    return items;
  }

  Future<void> _showAskAiSheet(String selection) async {
    if (!mounted) return;

    final localeHint = Localizations.maybeLocaleOf(context)?.toLanguageTag();

    final scrollback = _buildTerminalScrollbackTail(maxLines: 200);

    final blocks = <String>[
      '[Terminal Selection]\n$selection',
      '[Terminal Scrollback Tail]\n$scrollback',
      '[Session]\nserver: ${widget.args.spi.user}@${widget.args.spi.ip}:${widget.args.spi.port}\nsessionId: $_sessionId',
    ];

    final redactedBlocks = AiSafety.redactBlocks(blocks, spi: widget.args.spi);

    await showAiAssistSheet(
      context,
      AiAssistArgs(
        title: context.l10n.askAi,
        contextBlocks: redactedBlocks,
        scenario: AskAiScenario.terminal,
        localeHint: localeHint,
        applyLabel: context.l10n.askAiInsertTerminal,
        applyBehavior: AiApplyBehavior.insert,
        redacted: false,
        onInsert: (command) {
          _terminal.textInput(command);
          (widget.args.focusNode?.requestFocus ?? _termKey.currentState?.requestKeyboard)?.call();
        },
      ),
    );
  }

  String _buildTerminalScrollbackTail({required int maxLines}) {
    final lines = _terminal.buffer.lines.toList();
    if (lines.isEmpty) return '';

    final start = (lines.length - maxLines).clamp(0, lines.length);
    final tail = lines.sublist(start);

    return tail.map((e) => e.toString()).join('\n');
  }
}
