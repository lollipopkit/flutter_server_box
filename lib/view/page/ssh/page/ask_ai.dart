part of 'page.dart';

extension _AskAi on SSHPageState {
  List<ContextMenuButtonItem> _buildTerminalToolbar(
    BuildContext context,
    CustomTextEditState state,
    List<ContextMenuButtonItem> defaultItems,
  ) {
    final selection = _selectedTerminalText;
    if (selection.isEmpty) return defaultItems;

    return [
      ...defaultItems,
      ContextMenuButtonItem(
        label: context.l10n.askAi,
        onPressed: () {
          state.hideToolbar();
          _showAskAiPanel(selection, autoStart: true);
        },
      ),
    ];
  }

  String get _selectedTerminalText =>
      _termKey.currentState?.renderTerminal.selectedText?.trim() ?? '';

  String get _recentTerminalContext {
    final selection = _selectedTerminalText;
    if (selection.isNotEmpty) return selection;
    return _sshOutputTail.trim();
  }

  Future<void> _showAskAiPanel(
    String terminalContext, {
    required bool autoStart,
  }) async {
    if (!mounted) return;
    final localeHint = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final width = MediaQuery.sizeOf(context).width;
    final placement = askAiPanelPlacementForWidth(width);

    Widget panel(BuildContext panelContext) => _AskAiPanel(
      terminalContext: terminalContext,
      serverId: widget.args.spi.id,
      serverName: widget.args.spi.name,
      localeHint: localeHint,
      autoStart: autoStart,
      placement: askAiPanelPlacementForWidth(
        MediaQuery.sizeOf(panelContext).width,
      ),
      onCommandInsert: _insertAiCommand,
      onCommandRun: _runAiCommand,
      onCommandCancel: _cancelAiCommand,
    );

    if (placement == AskAiPanelPlacement.bottomSheet) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: panel,
      );
      return;
    }

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) {
        final availableWidth = MediaQuery.sizeOf(dialogContext).width;
        final dialogWidth = (availableWidth * 0.55)
            .clamp(480.0, 620.0)
            .clamp(0.0, availableWidth)
            .toDouble();
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: dialogWidth, child: panel(dialogContext)),
          ),
        );
      },
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  void _insertAiCommand(String command) {
    if (command.isEmpty) return;
    _terminal.textInput(command);
    (widget.args.focusNode?.requestFocus ??
            _termKey.currentState?.requestKeyboard)
        ?.call();
  }

  Future<AskAiCommandResult> _runAiCommand(AskAiCommand proposal) async {
    final client = _client;
    if (client == null || client.isClosed) {
      throw StateError('SSH client is not connected.');
    }

    final startedAt = DateTime.now();
    _aiCommandCancelled = false;
    final session = await client.execute(proposal.command);
    _aiCommandSession = session;
    final stdoutFuture = const Utf8Decoder(
      allowMalformed: true,
    ).bind(session.stdout).join();
    final stderrFuture = const Utf8Decoder(
      allowMalformed: true,
    ).bind(session.stderr).join();
    var timedOut = false;

    try {
      try {
        await session.done.timeout(const Duration(minutes: 5));
      } on TimeoutException {
        timedOut = true;
        await _terminateAiCommandSession(session);
      }
      final stdout = await stdoutFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => '',
      );
      final stderr = await stderrFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () => '',
      );
      final limited = _limitAiCommandOutput(stdout, stderr);
      return AskAiCommandResult(
        command: proposal.command,
        exitCode: session.exitCode,
        stdout: limited.stdout,
        stderr: limited.stderr,
        duration: DateTime.now().difference(startedAt),
        cancelled: _aiCommandCancelled,
        timedOut: timedOut,
        truncated: limited.truncated,
      );
    } finally {
      if (identical(_aiCommandSession, session)) {
        _aiCommandSession = null;
        _aiCommandCancelled = false;
      }
    }
  }

  ({String stdout, String stderr, bool truncated}) _limitAiCommandOutput(
    String stdout,
    String stderr,
  ) {
    const maxOutput = 32000;
    final combinedLength = stdout.length + stderr.length;
    if (combinedLength <= maxOutput) {
      return (stdout: stdout, stderr: stderr, truncated: false);
    }

    const marker = '\n\n[... output truncated ...]\n\n';
    final stdoutBudget = stderr.isEmpty ? maxOutput : 22000;
    final stderrBudget = stderr.isEmpty ? 0 : maxOutput - stdoutBudget;

    String limit(String value, int budget) {
      if (value.length <= budget) return value;
      if (budget <= marker.length) {
        return value.substring(value.length - budget);
      }
      final side = (budget - marker.length) ~/ 2;
      return '${value.substring(0, side)}$marker${value.substring(value.length - side)}';
    }

    return (
      stdout: limit(stdout, stdoutBudget),
      stderr: limit(stderr, stderrBudget),
      truncated: true,
    );
  }

  Future<void> _terminateAiCommandSession(SSHSession session) async {
    try {
      session.kill(SSHSignal.KILL);
    } catch (_) {
      // The session may already have ended between the state check and kill.
    } finally {
      session.close();
    }
    try {
      await session.done;
    } catch (_) {
      // Termination is best-effort; the command result reports cancellation.
    }
  }

  Future<void> _cancelAiCommand() async {
    _aiCommandCancelled = true;
    final session = _aiCommandSession;
    if (session != null) await _terminateAiCommandSession(session);
  }
}

class _AskAiPanel extends ConsumerStatefulWidget {
  const _AskAiPanel({
    required this.terminalContext,
    required this.serverId,
    required this.serverName,
    required this.localeHint,
    required this.autoStart,
    required this.placement,
    required this.onCommandInsert,
    required this.onCommandRun,
    required this.onCommandCancel,
  });

  final String terminalContext;
  final String serverId;
  final String serverName;
  final String? localeHint;
  final bool autoStart;
  final AskAiPanelPlacement placement;
  final ValueChanged<String> onCommandInsert;
  final Future<AskAiCommandResult> Function(AskAiCommand command) onCommandRun;
  final Future<void> Function() onCommandCancel;

  @override
  ConsumerState<_AskAiPanel> createState() => _AskAiPanelState();
}

enum _ChatEntryType { user, assistant, result, notice }

class _ChatEntry {
  const _ChatEntry._({
    required this.type,
    this.content,
    this.command,
    this.result,
    this.autoApproved = false,
  });

  const _ChatEntry.user(String content)
    : this._(type: _ChatEntryType.user, content: content);

  const _ChatEntry.assistant(String content)
    : this._(type: _ChatEntryType.assistant, content: content);

  const _ChatEntry.result(
    AskAiCommand command,
    AskAiCommandResult result, {
    bool autoApproved = false,
  }) : this._(
         type: _ChatEntryType.result,
         command: command,
         result: result,
         autoApproved: autoApproved,
       );

  const _ChatEntry.notice(String content)
    : this._(type: _ChatEntryType.notice, content: content);

  final _ChatEntryType type;
  final String? content;
  final AskAiCommand? command;
  final AskAiCommandResult? result;
  final bool autoApproved;
}

class _AskAiPanelState extends ConsumerState<_AskAiPanel> {
  StreamSubscription<AskAiEvent>? _subscription;
  final _chatEntries = <_ChatEntry>[];
  final _history = <AskAiConversationItem>[];
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  late AskAiProtocol _protocol;
  AgentConversation? _conversation;
  AskAiCommand? _pendingCommand;
  String? _streamingContent;
  String? _error;
  bool _isStreaming = false;
  bool _isExecuting = false;
  bool _turnCompleted = false;
  bool _historyInitialized = false;
  bool _pendingCommandRestored = false;
  int _autoRunCount = 0;

  bool get _isWorking => _isStreaming || _isExecuting;

  @override
  void initState() {
    super.initState();
    _protocol = _resolvedConfiguredProtocol();
    _inputController.addListener(_handleInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_historyInitialized) return;
    _historyInitialized = true;
    _restoreConversation(
      Stores.agentConversation.fetchActive(widget.serverId),
      notify: false,
    );
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _submitPrompt(context.l10n.askAiAnalyzeSelectionPrompt);
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_isExecuting) widget.onCommandCancel();
    _scrollController.dispose();
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  AskAiProtocol _resolvedConfiguredProtocol() {
    return AskAiRepository.resolveProtocol(
      configured: parseAskAiProtocol(Stores.setting.askAiProtocol.fetch()),
      endpoint: Stores.setting.askAiBaseUrl.fetch(),
    );
  }

  void _restoreConversation(
    AgentConversation? conversation, {
    bool notify = true,
  }) {
    final replay = AgentConversationReplay.fromItems(
      conversation?.items ?? const [],
    );

    void apply() {
      final restoredProtocol = conversation?.protocol;
      _subscription?.cancel();
      _conversation = conversation;
      _protocol =
          restoredProtocol == null || restoredProtocol == AskAiProtocol.auto
          ? _resolvedConfiguredProtocol()
          : restoredProtocol;
      _history
        ..clear()
        ..addAll(conversation?.items ?? const []);
      _chatEntries
        ..clear()
        ..addAll(replay.entries.map(_chatEntryFromReplay));
      _pendingCommand = replay.pendingCommand;
      _pendingCommandRestored = replay.pendingCommand != null;
      _streamingContent = null;
      _error = null;
      _isStreaming = false;
      _isExecuting = false;
      _turnCompleted = false;
      _autoRunCount = 0;
      _inputController.clear();
    }

    if (notify) {
      setState(apply);
      _scheduleAutoScroll(force: true);
    } else {
      apply();
    }
  }

  _ChatEntry _chatEntryFromReplay(AgentConversationReplayEntry entry) {
    return switch (entry.type) {
      AgentConversationReplayEntryType.user => _ChatEntry.user(
        entry.content ?? '',
      ),
      AgentConversationReplayEntryType.assistant => _ChatEntry.assistant(
        entry.content ?? '',
      ),
      AgentConversationReplayEntryType.commandResult => _ChatEntry.result(
        entry.command!,
        entry.result!,
      ),
      AgentConversationReplayEntryType.declined => _ChatEntry.notice(
        context.l10n.askAiActionDeclined,
      ),
      AgentConversationReplayEntryType.inserted => _ChatEntry.notice(
        context.l10n.askAiCommandInserted,
      ),
      AgentConversationReplayEntryType.notice => _ChatEntry.notice(
        entry.content ?? '',
      ),
    };
  }

  AgentConversation _ensureConversation() {
    final existing = _conversation;
    if (existing != null) return existing;
    final created = Stores.agentConversation.create(
      serverId: widget.serverId,
      protocol: _protocol,
      providerBaseUrl: Stores.setting.askAiBaseUrl.fetch(),
      model: Stores.setting.askAiModel.fetch(),
    );
    _conversation = created;
    return created;
  }

  void _persistConversation() {
    final conversation = _ensureConversation();
    final trimmed = AgentConversationStore.trimItemsForStorage(_history);
    final updated = conversation.copyWith(
      updatedAt: DateTime.now(),
      protocol: _protocol,
      items: trimmed,
    );
    if (!Stores.agentConversation.save(updated)) return;
    _conversation = Stores.agentConversation.fetch(updated.id) ?? updated;
    if (trimmed.length != _history.length) {
      _history
        ..clear()
        ..addAll(trimmed);
    }
  }

  void _refreshConversationMetadata(String conversationId) {
    if (_conversation?.id != conversationId || !mounted) return;
    setState(() {
      _conversation = Stores.agentConversation.fetch(conversationId);
    });
  }

  void _submitPrompt(String prompt) {
    final text = prompt.trim();
    if (text.isEmpty || _isWorking || _pendingCommand != null) return;
    _ensureConversation();
    final message = AskAiMessageItem.user(text);
    setState(() {
      _history.add(message);
      _chatEntries.add(_ChatEntry.user(text));
      _inputController.clear();
      _autoRunCount = 0;
    });
    _persistConversation();
    _startStream();
    _scheduleAutoScroll(force: true);
  }

  void _startStream() {
    _subscription?.cancel();
    setState(() {
      _isStreaming = true;
      _turnCompleted = false;
      _error = null;
      _streamingContent = '';
    });

    _subscription = ref
        .read(askAiRepositoryProvider)
        .ask(
          terminalContext: widget.terminalContext,
          serverName: widget.serverName,
          localeHint: widget.localeHint,
          conversation: List.unmodifiable(_history),
          protocol: _protocol,
        )
        .listen(
          _handleEvent,
          onError: (Object error, StackTrace stackTrace) {
            if (!mounted) return;
            setState(() {
              _error = _describeError(error);
              _isStreaming = false;
              _streamingContent = null;
              _pendingCommand = null;
            });
          },
          onDone: () {
            if (!mounted || _turnCompleted) return;
            setState(() {
              _isStreaming = false;
              _streamingContent = null;
            });
          },
        );
  }

  void _handleEvent(AskAiEvent event) {
    if (!mounted) return;
    if (event is AskAiContentDelta) {
      setState(() {
        _streamingContent = (_streamingContent ?? '') + event.delta;
      });
      _scheduleAutoScroll();
      return;
    }
    if (event is AskAiToolSuggestion) {
      setState(() {
        _pendingCommand ??= event.command;
        _pendingCommandRestored = false;
      });
      return;
    }
    if (event is AskAiStreamError) {
      _subscription?.cancel();
      setState(() {
        _error = _describeError(event.error);
        _isStreaming = false;
        _streamingContent = null;
        _pendingCommand = null;
      });
      return;
    }
    if (event is! AskAiCompleted || _turnCompleted) return;

    final text = event.fullText.trim().isNotEmpty
        ? event.fullText
        : (_streamingContent ?? '');
    final command = event.commands.isEmpty
        ? _pendingCommand
        : event.commands.first;
    setState(() {
      _turnCompleted = true;
      _isStreaming = false;
      _streamingContent = null;
      _pendingCommand = command;
      _pendingCommandRestored = false;
      _protocol = event.protocol;
      _history.addAll(event.outputItems);
      if (text.trim().isNotEmpty) {
        _chatEntries.add(_ChatEntry.assistant(text));
      }
      if (text.trim().isEmpty && command == null) {
        _error = context.l10n.askAiNoResponse;
      }
    });
    _persistConversation();
    _scheduleAutoScroll(force: true);

    if (command != null &&
        shouldAutoRunAgentCommand(
          command: command,
          enabled: Stores.setting.askAiAutoRunSafeCommands.fetch(),
          restored: _pendingCommandRestored,
          runCount: _autoRunCount,
        )) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_pendingCommand, command)) {
          _runPendingCommand(autoApproved: true);
        }
      });
    }
  }

  void _scheduleAutoScroll({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!force && position.pixels < position.maxScrollExtent - 96) return;
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _describeError(Object error) {
    final l10n = context.l10n;
    if (error is AskAiConfigException) {
      if (error.missingFields.isEmpty) {
        return error.hasInvalidBaseUrl
            ? '${l10n.invalidUrl}: ${error.invalidBaseUrl}'
            : error.toString();
      }
      final locale = Localizations.maybeLocaleOf(context);
      final separator = switch (locale?.languageCode) {
        'zh' || 'ja' => '、',
        _ => ', ',
      };
      final fields = error.missingFields
          .map(
            (field) => switch (field) {
              AskAiConfigField.baseUrl => l10n.askAiBaseUrl,
              AskAiConfigField.apiKey => l10n.askAiApiKey,
              AskAiConfigField.model => libL10n.askAiModel,
            },
          )
          .join(separator);
      return l10n.askAiConfigMissing(fields);
    }
    if (error is AskAiNetworkException) return error.message;
    return error.toString();
  }

  Future<void> _runPendingCommand({bool autoApproved = false}) async {
    final command = _pendingCommand;
    if (command == null || _isWorking) return;

    if (!autoApproved && command.risk == AskAiCommandRisk.destructive) {
      final confirmed = await context.showRoundDialog<bool>(
        title: context.l10n.askAiHighRiskConfirmTitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.askAiHighRiskConfirmBody),
            const SizedBox(height: 12),
            SelectableText(
              command.command,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: context.popDialog, child: Text(libL10n.cancel)),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(libL10n.run),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _isExecuting = true;
      _error = null;
      if (autoApproved) _autoRunCount++;
    });
    try {
      final result = await widget.onCommandRun(command);
      if (!mounted) return;
      setState(() {
        _history.add(
          AskAiFunctionOutputItem(
            callId: command.id,
            output: result.toToolMessage(),
          ),
        );
        _chatEntries.add(
          _ChatEntry.result(command, result, autoApproved: autoApproved),
        );
        _pendingCommand = null;
        _pendingCommandRestored = false;
        _isExecuting = false;
      });
      _persistConversation();
      _scheduleAutoScroll(force: true);
      if (!result.cancelled) _startStream();
    } catch (error) {
      if (!mounted) return;
      final message = _describeError(error);
      setState(() {
        _history.add(
          AskAiFunctionOutputItem(
            callId: command.id,
            output: AskAiCommandResult(
              command: command.command,
              stdout: '',
              stderr: message,
              duration: Duration.zero,
            ).toToolMessage(),
          ),
        );
        _pendingCommand = null;
        _pendingCommandRestored = false;
        _error = message;
        _isExecuting = false;
      });
      _persistConversation();
    }
  }

  void _declinePendingCommand() {
    final command = _pendingCommand;
    if (command == null || _isWorking) return;
    final message = context.l10n.askAiActionDeclined;
    setState(() {
      _history.add(
        AskAiFunctionOutputItem(
          callId: command.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.declined,
          ),
        ),
      );
      _chatEntries.add(_ChatEntry.notice(message));
      _pendingCommand = null;
      _pendingCommandRestored = false;
    });
    _persistConversation();
  }

  void _insertPendingCommand() {
    final command = _pendingCommand;
    if (command == null || _isWorking) return;
    widget.onCommandInsert(command.command);
    final message = context.l10n.askAiCommandInserted;
    setState(() {
      _history.add(
        AskAiFunctionOutputItem(
          callId: command.id,
          output: encodeAgentConversationToolAction(
            AgentConversationToolAction.inserted,
          ),
        ),
      );
      _chatEntries.add(_ChatEntry.notice(message));
      _pendingCommand = null;
      _pendingCommandRestored = false;
    });
    _persistConversation();
    context.showSnackBar(message);
  }

  Future<void> _stopWork() async {
    if (_isExecuting) {
      await widget.onCommandCancel();
      return;
    }
    if (!_isStreaming) return;
    _subscription?.cancel();
    setState(() {
      _isStreaming = false;
      _streamingContent = null;
      _pendingCommand = null;
      _pendingCommandRestored = false;
      _chatEntries.add(_ChatEntry.notice(context.l10n.askAiInterrupted));
    });
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) context.showSnackBar(libL10n.success);
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    final compact = MediaQuery.sizeOf(context).width < 480;
    final status = switch ((
      _isExecuting,
      _isStreaming,
      _pendingCommand != null,
    )) {
      (true, _, _) => context.l10n.askAiRunningCommand,
      (_, true, _) => context.l10n.askAiThinking,
      (_, _, true) => context.l10n.askAiReviewNeeded,
      _ => context.l10n.askAiReady,
    };
    final statusColor = _pendingCommand != null
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.auto_awesome,
              size: 19,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.askAiAgentTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _conversation?.title.trim().isNotEmpty == true
                      ? '${widget.serverName} · ${_conversation!.title}'
                      : widget.serverName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (compact)
            Tooltip(
              message: status,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: Icon(Icons.circle, size: 10, color: statusColor),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            tooltip: context.l10n.askAiHistory,
            onPressed: _isWorking ? null : _showConversationHistory,
            icon: const Icon(Icons.history),
          ),
          if (_isWorking)
            IconButton(
              tooltip: libL10n.stop,
              onPressed: _stopWork,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
          IconButton(
            tooltip: libL10n.close,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildTerminalContext(BuildContext context, ThemeData theme) {
    final content = widget.terminalContext.trim();
    if (content.isEmpty) return const SizedBox.shrink();
    final preview = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        initiallyExpanded: widget.autoStart,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: const Icon(Icons.terminal, size: 19),
        title: Text(context.l10n.askAiTerminalContext),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.askAiAgentWelcome,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.askAiAgentWelcomeTip,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatEntry(
    BuildContext context,
    ThemeData theme,
    _ChatEntry entry,
  ) {
    return switch (entry.type) {
      _ChatEntryType.user => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(entry.content ?? ''),
        ),
      ),
      _ChatEntryType.assistant => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleMarkdown(data: entry.content ?? ''),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: libL10n.copy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _copyText(entry.content ?? ''),
                  icon: const Icon(Icons.copy, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
      _ChatEntryType.result => _buildCommandResult(context, theme, entry),
      _ChatEntryType.notice => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              entry.content ?? '',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    };
  }

  Widget _buildCommandResult(
    BuildContext context,
    ThemeData theme,
    _ChatEntry entry,
  ) {
    final command = entry.command!;
    final result = entry.result!;
    final output = result.displayOutput;
    final color = result.succeeded
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final status = result.cancelled
        ? context.l10n.askAiCommandCancelled
        : result.timedOut
        ? context.l10n.askAiCommandTimedOut
        : result.succeeded
        ? libL10n.success
        : '${libL10n.fail} (${result.exitCode ?? '?'})';
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        initiallyExpanded: !result.succeeded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Icon(Icons.terminal, size: 19, color: color),
        title: Text(
          command.command,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        subtitle: Text(
          [
            status,
            if (entry.autoApproved) context.l10n.askAiAutoApproved,
            '${result.duration.inMilliseconds} ms',
          ].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              output.isEmpty ? context.l10n.askAiNoCommandOutput : output,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          if (result.truncated) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.askAiOutputTruncated,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStreamingBubble(BuildContext context, ThemeData theme) {
    final content = _streamingContent?.trim() ?? '';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: content.isEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 9),
                  Text(context.l10n.askAiAwaitingResponse),
                ],
              )
            : SimpleMarkdown(data: _streamingContent!),
      ),
    );
  }

  Widget _buildProposalCard(BuildContext context, ThemeData theme) {
    final command = _pendingCommand!;
    final risk = command.risk;
    final (label, color, icon) = switch (risk) {
      AskAiCommandRisk.readOnly => (
        context.l10n.askAiRiskReadOnly,
        theme.colorScheme.primary,
        Icons.visibility_outlined,
      ),
      AskAiCommandRisk.caution => (
        context.l10n.askAiRiskCaution,
        theme.colorScheme.tertiary,
        Icons.warning_amber_rounded,
      ),
      AskAiCommandRisk.destructive => (
        context.l10n.askAiRiskDestructive,
        theme.colorScheme.error,
        Icons.dangerous_outlined,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.l10n.askAiReviewAction,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: SelectableText(
              command.command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
            ),
          ),
          if (command.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(command.description, style: theme.textTheme.bodySmall),
          ],
          if (_pendingCommandRestored) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.l10n.askAiRestoredReview,
                    style: theme.textTheme.bodySmall?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: _isWorking ? null : _declinePendingCommand,
                child: Text(context.l10n.askAiDecline),
              ),
              TextButton.icon(
                onPressed: _isWorking ? null : () => _copyText(command.command),
                icon: const Icon(Icons.copy, size: 17),
                label: Text(libL10n.copy),
              ),
              OutlinedButton.icon(
                onPressed: _isWorking ? null : _insertPendingCommand,
                icon: const Icon(Icons.keyboard_return, size: 17),
                label: Text(context.l10n.askAiInsertTerminal),
              ),
              FilledButton.icon(
                onPressed: _isWorking ? null : _runPendingCommand,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(context.l10n.askAiApproveRun),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context, ThemeData theme) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSend =
        !_isWorking &&
        _pendingCommand == null &&
        _inputController.text.trim().isNotEmpty;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingCommand != null) ...[
            _buildProposalCard(context, theme),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isWorking ? null : _startStream,
                    child: Text(libL10n.retry),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Input(
                  controller: _inputController,
                  minLines: 1,
                  maxLines: 5,
                  hint: _pendingCommand == null
                      ? context.l10n.askAiAgentPromptHint
                      : context.l10n.askAiReviewBeforeContinuing,
                  action: TextInputAction.send,
                  onSubmitted: (_) {
                    if (canSend) _submitPrompt(_inputController.text);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.askAiAgentSend,
                onPressed: canSend
                    ? () => _submitPrompt(_inputController.text)
                    : null,
                icon: const Icon(Icons.arrow_upward),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.askAiDisclaimer,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context, theme),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  _buildTerminalContext(context, theme),
                  if (_chatEntries.isEmpty && !_isStreaming)
                    _buildEmptyState(context, theme),
                  for (final entry in _chatEntries) ...[
                    _buildChatEntry(context, theme, entry),
                    const SizedBox(height: 10),
                  ],
                  if (_isStreaming) _buildStreamingBubble(context, theme),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          _buildComposer(context, theme),
        ],
      ),
    );

    if (widget.placement == AskAiPanelPlacement.sidePanel) {
      return ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        child: content,
      );
    }
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: content,
      ),
    );
  }
}
