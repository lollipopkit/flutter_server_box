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
        label: 'Ask AI',
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return _AskAiSheet(
          selection: selection,
          localeHint: localeHint,
          onCommandApply: _applyAiCommand,
        );
      },
    );
  }

  void _applyAiCommand(String command) {
    if (command.isEmpty) {
      return;
    }
    _terminal.textInput(command);
    widget.args.focusNode?.requestFocus() ?? _termKey.currentState?.requestKeyboard();
  }
}

class _AskAiSheet extends ConsumerStatefulWidget {
  const _AskAiSheet({
    required this.selection,
    required this.localeHint,
    required this.onCommandApply,
  });

  final String selection;
  final String? localeHint;
  final ValueChanged<String> onCommandApply;

  @override
  ConsumerState<_AskAiSheet> createState() => _AskAiSheetState();
}

class _AskAiSheetState extends ConsumerState<_AskAiSheet> {
  late final StreamSubscription<AskAiEvent> _subscription;
  final _commands = <AskAiCommand>[];
  String _contentText = '';
  bool _isLoading = true;
  bool _completed = false;
  String? _error;
  final _responseScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(selection: widget.selection, localeHint: widget.localeHint)
        .listen(
      _handleEvent,
      onError: (error, stack) {
        if (!mounted) return;
        setState(() {
          _error = _describeError(error);
          _isLoading = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    _responseScroll.dispose();
    super.dispose();
  }

  void _handleEvent(AskAiEvent event) {
    if (!mounted) return;
    var shouldScroll = false;
    setState(() {
      if (event is AskAiContentDelta) {
        _contentText += event.delta;
        _isLoading = false;
        shouldScroll = true;
      } else if (event is AskAiToolSuggestion) {
        _addCommand(event.command);
      } else if (event is AskAiCompleted) {
        if (event.fullText.isNotEmpty) {
          _contentText = event.fullText;
        }
        for (final command in event.commands) {
          _addCommand(command);
        }
        _isLoading = false;
        _completed = true;
        shouldScroll = true;
      } else if (event is AskAiStreamError) {
        _error = _describeError(event.error);
        _isLoading = false;
      }
    });

    if (shouldScroll) {
      _scheduleAutoScroll();
    }
  }

  void _addCommand(AskAiCommand command) {
    final exists = _commands.any((item) => item.command == command.command);
    if (!exists) {
      _commands.add(command);
    }
  }

  void _scheduleAutoScroll() {
    if (!_responseScroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_responseScroll.hasClients) return;
      _responseScroll.animateTo(
        _responseScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _describeError(Object error) {
    if (error is AskAiConfigException) {
      return '请前往设置配置 ${error.missingFields.join('、')}';
    }
    if (error is AskAiNetworkException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleApplyCommand(BuildContext context, AskAiCommand command) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: '执行前确认',
      child: SelectableText(
        command.command,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () => context.pop(true),
          child: Text(libL10n.ok),
        ),
      ],
    );
    if (confirmed == true) {
      widget.onCommandApply(command.command);
      if (!mounted) return;
      context.showSnackBar('命令已插入终端');
    }
  }

  Future<void> _copyCommand(BuildContext context, AskAiCommand command) async {
    await Clipboard.setData(ClipboardData(text: command.command));
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text('问 AI', style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  if (_isLoading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomPadding),
                children: [
                  Text('选中的内容', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  CardX(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        widget.selection,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('AI 回复', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  CardX(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 160),
                      child: Scrollbar(
                        controller: _responseScroll,
                        child: SingleChildScrollView(
                          controller: _responseScroll,
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _contentText.isEmpty
                                ? (_isLoading ? '等待 AI 响应…' : (_error ?? (_completed ? '无回复内容' : '')))
                                : _contentText,
                            style: const TextStyle(height: 1.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_commands.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('建议命令', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ..._commands.map((command) {
                      return CardX(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                command.command,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                              if (command.description.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  command.description,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _copyCommand(context, command),
                                    icon: const Icon(Icons.copy, size: 18),
                                    label: Text(libL10n.copy),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.icon(
                                    onPressed: () => _handleApplyCommand(context, command),
                                    icon: const Icon(Icons.terminal, size: 18),
                                    label: const Text('上屏'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    CardX(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  ],
                  if (_isLoading) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
