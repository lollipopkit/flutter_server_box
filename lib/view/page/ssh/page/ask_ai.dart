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
        return _AskAiSheet(selection: selection, localeHint: localeHint, onCommandApply: _applyAiCommand);
      },
    );
  }

  void _applyAiCommand(String command) {
    if (command.isEmpty) {
      return;
    }
    _terminal.textInput(command);
    (widget.args.focusNode?.requestFocus ?? _termKey.currentState?.requestKeyboard)?.call();
  }
}

class _AskAiSheet extends ConsumerStatefulWidget {
  const _AskAiSheet({required this.selection, required this.localeHint, required this.onCommandApply});

  final String selection;
  final String? localeHint;
  final ValueChanged<String> onCommandApply;

  @override
  ConsumerState<_AskAiSheet> createState() => _AskAiSheetState();
}

class _AskAiSheetState extends ConsumerState<_AskAiSheet> {
  StreamSubscription<AskAiEvent>? _subscription;
  final _commands = <AskAiCommand>[];
  final _conversation = <AskAiMessage>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  String? _streamingContent;
  String? _error;
  bool _isStreaming = false;
  bool _didApplyRecommendShell = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
    _startStream();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _startStream() {
    _subscription?.cancel();
    setState(() {
      _isStreaming = true;
      _error = null;
      _streamingContent = '';
      _didApplyRecommendShell = false;
    });

    final messages = List<AskAiMessage>.from(_conversation);

    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          selection: widget.selection,
          localeHint: widget.localeHint,
          conversation: messages,
        )
        .listen(
          _handleEvent,
          onError: (error, stack) {
            if (!mounted) return;
            setState(() {
              _error = _describeError(error);
              _isStreaming = false;
              _streamingContent = null;
            });
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
              _isStreaming = false;
            });
          },
        );
  }

  void _handleEvent(AskAiEvent event) {
    if (!mounted) return;
    if (event is AskAiToolSuggestion && event.command.toolName == 'recommend_shell') {
      _handleRecommendShell(event.command);
      return;
    }

    var shouldScroll = false;
    setState(() {
      if (event is AskAiContentDelta) {
        _streamingContent = (_streamingContent ?? '') + event.delta;
        shouldScroll = true;
      } else if (event is AskAiToolSuggestion) {
        _addCommand(event.command);
      } else if (event is AskAiCompleted) {
        final fullText = event.fullText.isNotEmpty ? event.fullText : (_streamingContent ?? '');
        if (fullText.trim().isNotEmpty) {
          _conversation.add(AskAiMessage(role: AskAiMessageRole.assistant, content: fullText));
        }
        for (final command in event.commands) {
          if (command.toolName == 'recommend_shell') {
            WidgetsBinding.instance.addPostFrameCallback((_) => _handleRecommendShell(command));
          } else {
            _addCommand(command);
          }
        }
        _streamingContent = null;
        _isStreaming = false;
        shouldScroll = true;
      } else if (event is AskAiStreamError) {
        _error = _describeError(event.error);
        _streamingContent = null;
        _isStreaming = false;
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
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
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

  void _handleRecommendShell(AskAiCommand command) {
    if (_didApplyRecommendShell) {
      return;
    }
    _didApplyRecommendShell = true;
    widget.onCommandApply(command.command);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    context.showSnackBar('命令已插入终端');
  }

  Future<void> _handleApplyCommand(BuildContext context, AskAiCommand command) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: '执行前确认',
      child: SelectableText(command.command, style: const TextStyle(fontFamily: 'monospace')),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        TextButton(onPressed: () => context.pop(true), child: Text(libL10n.ok)),
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

  void _sendMessage() {
    if (_isStreaming) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _conversation.add(AskAiMessage(role: AskAiMessageRole.user, content: text));
      _inputController.clear();
    });
    _startStream();
    _scheduleAutoScroll();
  }

  List<Widget> _buildConversationWidgets(ThemeData theme) {
    final widgets = <Widget>[];
    for (final message in _conversation) {
      widgets.add(_buildMessageBubble(theme, message));
      widgets.add(const SizedBox(height: 12));
    }

    if (_streamingContent != null) {
      widgets.add(_buildAssistantBubble(
        theme,
        content: _streamingContent!,
        streaming: true,
      ));
      widgets.add(const SizedBox(height: 12));
    } else if (_conversation.isEmpty && _error == null) {
      widgets.add(_buildAssistantBubble(
        theme,
        content: '',
        streaming: true,
      ));
      widgets.add(const SizedBox(height: 12));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildMessageBubble(ThemeData theme, AskAiMessage message) {
    if (message.role == AskAiMessageRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: CardX(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(message.content),
          ),
        ),
      );
    }
    return _buildAssistantBubble(theme, content: message.content);
  }

  Widget _buildAssistantBubble(
    ThemeData theme, {
    required String content,
    bool streaming = false,
  }) {
    final trimmed = content.trim();
    final child = trimmed.isEmpty
        ? Text(streaming ? '等待 AI 响应…' : '无回复内容', style: theme.textTheme.bodySmall)
        : SimpleMarkdown(data: content);
    return Align(
      alignment: Alignment.centerLeft,
      child: CardX(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    );
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
                  if (_isStreaming)
                    const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                    Text('AI 对话', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    ..._buildConversationWidgets(theme),
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
                                  Text(command.description, style: theme.textTheme.bodySmall),
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
                          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ),
                    ],
                    if (_isStreaming) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Input(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      action: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Btn.icon(
                    onTap: _isStreaming || _inputController.text.trim().isEmpty ? null : _sendMessage,
                    icon: const Icon(Icons.send, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
