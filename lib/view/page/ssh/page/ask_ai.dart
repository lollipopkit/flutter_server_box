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

enum _ChatEntryType { user, assistant, command }

class _ChatEntry {
  const _ChatEntry._({required this.type, this.content, this.command});

  const _ChatEntry.user(String content) : this._(type: _ChatEntryType.user, content: content);

  const _ChatEntry.assistant(String content) : this._(type: _ChatEntryType.assistant, content: content);

  const _ChatEntry.command(AskAiCommand command) : this._(type: _ChatEntryType.command, command: command);

  final _ChatEntryType type;
  final String? content;
  final AskAiCommand? command;
}

class _AskAiSheetState extends ConsumerState<_AskAiSheet> {
  StreamSubscription<AskAiEvent>? _subscription;
  final _chatEntries = <_ChatEntry>[];
  final _history = <AskAiMessage>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final _seenCommands = <String>{};
  String? _streamingContent;
  String? _error;
  bool _isStreaming = false;

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
    });

    final messages = List<AskAiMessage>.from(_history);

    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(selection: widget.selection, localeHint: widget.localeHint, conversation: messages)
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
    var shouldScroll = false;
    setState(() {
      if (event is AskAiContentDelta) {
        _streamingContent = (_streamingContent ?? '') + event.delta;
        shouldScroll = true;
      } else if (event is AskAiToolSuggestion) {
        final inserted = _seenCommands.add(event.command.command);
        if (inserted) {
          _chatEntries.add(_ChatEntry.command(event.command));
          shouldScroll = true;
        }
      } else if (event is AskAiCompleted) {
        final fullText = event.fullText.isNotEmpty ? event.fullText : (_streamingContent ?? '');
        if (fullText.trim().isNotEmpty) {
          final message = AskAiMessage(role: AskAiMessageRole.assistant, content: fullText);
          _history.add(message);
          _chatEntries.add(_ChatEntry.assistant(fullText));
        }
        for (final command in event.commands) {
          final inserted = _seenCommands.add(command.command);
          if (inserted) {
            _chatEntries.add(_ChatEntry.command(command));
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
    final l10n = context.l10n;
    if (error is AskAiConfigException) {
      if (error.missingFields.isEmpty) {
        if (error.hasInvalidBaseUrl) {
          return 'Invalid Ask AI base URL: ${error.invalidBaseUrl}';
        }
        return error.toString();
      }
      final locale = Localizations.maybeLocaleOf(context);
      final separator = switch (locale?.languageCode) {
        'zh' => '、',
        'ja' => '、',
        _ => ', ',
      };
      final formattedFields = error.missingFields
          .map(
            (field) => switch (field) {
              AskAiConfigField.baseUrl => l10n.askAiBaseUrl,
              AskAiConfigField.apiKey => l10n.askAiApiKey,
              AskAiConfigField.model => l10n.askAiModel,
            },
          )
          .join(separator);
      final message = l10n.askAiConfigMissing(formattedFields);
      if (error.hasInvalidBaseUrl) {
        return '$message (invalid URL: ${error.invalidBaseUrl})';
      }
      return message;
    }
    if (error is AskAiNetworkException) {
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleApplyCommand(BuildContext context, AskAiCommand command) async {
    final confirmed = await context.showRoundDialog<bool>(
      title: context.l10n.askAiConfirmExecute,
      child: SelectableText(command.command, style: const TextStyle(fontFamily: 'monospace')),
      actions: [
        TextButton(onPressed: context.pop, child: Text(libL10n.cancel)),
        TextButton(onPressed: () => context.pop(true), child: Text(libL10n.ok)),
      ],
    );
    if (confirmed == true) {
      widget.onCommandApply(command.command);
      if (!mounted) return;
      context.showSnackBar(context.l10n.askAiCommandInserted);
    }
  }

  Future<void> _copyCommand(BuildContext context, AskAiCommand command) async {
    await Clipboard.setData(ClipboardData(text: command.command));
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  Future<void> _copyText(BuildContext context, String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    context.showSnackBar(libL10n.success);
  }

  void _sendMessage() {
    if (_isStreaming) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      final message = AskAiMessage(role: AskAiMessageRole.user, content: text);
      _history.add(message);
      _chatEntries.add(_ChatEntry.user(text));
      _inputController.clear();
    });
    _startStream();
    _scheduleAutoScroll();
  }

  List<Widget> _buildConversationWidgets(BuildContext context, ThemeData theme) {
    final widgets = <Widget>[];
    for (final entry in _chatEntries) {
      widgets.add(_buildChatItem(context, theme, entry));
      widgets.add(const SizedBox(height: 12));
    }

    if (_streamingContent != null) {
      widgets.add(_buildAssistantBubble(theme, content: _streamingContent!, streaming: true));
      widgets.add(const SizedBox(height: 12));
    } else if (_chatEntries.isEmpty && _error == null) {
      widgets.add(_buildAssistantBubble(theme, content: '', streaming: true));
      widgets.add(const SizedBox(height: 12));
    }

    if (widgets.isNotEmpty) {
      widgets.removeLast();
    }
    return widgets;
  }

  Widget _buildChatItem(BuildContext context, ThemeData theme, _ChatEntry entry) {
    switch (entry.type) {
      case _ChatEntryType.user:
        return Align(
          alignment: Alignment.centerRight,
          child: CardX(
            child: Padding(padding: const EdgeInsets.all(12), child: SelectableText(entry.content ?? '')),
          ),
        );
      case _ChatEntryType.assistant:
        return _buildAssistantBubble(theme, content: entry.content ?? '');
      case _ChatEntryType.command:
        final command = entry.command!;
        return _buildCommandBubble(context, theme, command);
    }
  }

  Widget _buildAssistantBubble(ThemeData theme, {required String content, bool streaming = false}) {
    final trimmed = content.trim();
    final l10n = context.l10n;
    final child = trimmed.isEmpty
        ? Text(
            streaming ? l10n.askAiAwaitingResponse : l10n.askAiNoResponse,
            style: theme.textTheme.bodySmall,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleMarkdown(data: content),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _copyText(context, content),
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(libL10n.copy),
                  ),
                ],
              ),
            ],
          );
    return Align(
      alignment: Alignment.centerLeft,
      child: CardX(
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    );
  }

  Widget _buildCommandBubble(BuildContext context, ThemeData theme, AskAiCommand command) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: CardX(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.askAiRecommendedCommand, style: theme.textTheme.labelMedium),
              const SizedBox(height: 8),
              SelectableText(command.command, style: const TextStyle(fontFamily: 'monospace')),
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
                    label: Text(l10n.askAiInsertTerminal),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  Text(context.l10n.askAi, style: theme.textTheme.titleLarge),
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
                    Text(context.l10n.askAiSelectedContent, style: theme.textTheme.titleMedium),
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
                    Text(context.l10n.askAiConversation, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    ..._buildConversationWidgets(context, theme),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      CardX(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      ),
                    ],
                    if (_isStreaming) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              context.l10n.askAiDisclaimer,
              style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomPadding),
            child: Row(
              children: [
                Expanded(
                  child: Input(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    hint: context.l10n.askAiFollowUpHint,
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
            ).cardx,
          ),
          ],
        ),
      ),
    );
  }
}
