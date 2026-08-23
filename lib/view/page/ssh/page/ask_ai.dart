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
          _showAskAiPanel(autoStart: true);
        },
      ),
    ];
  }

  String get _selectedTerminalText =>
      _termKey.currentState?.renderTerminal.selectedText?.trim() ?? '';

  String get _recentTerminalContext {
    final selection = _selectedTerminalText;
    if (selection.isNotEmpty) return selection;
    return _sess.outputTail.trim();
  }

  /// Makes this terminal reachable by the Agent session scoped to its server.
  ///
  /// Done by the page rather than by the panel, because the two have different
  /// lifetimes on purpose: closing the panel does not end a turn, so a command
  /// approved before it closed still has a terminal to run in. What ends the
  /// reach is the tab going away.
  ///
  /// The closures are what is handed over, never the terminal — a session that
  /// held the controller could reach one this page has already disposed.
  void _attachAgentHost() {
    final spi = widget.args.spi;
    // A terminal on this device has no server to scope a conversation to. The
    // app-wide Agent is what reaches it, through `LocalTarget`.
    if (spi == null) return;
    final host = TerminalAgentHost(
      serverName: spi.name,
      // Read per turn, not captured: this session outlives any one panel, and
      // by the next turn the screen has moved on.
      readContext: () => _recentTerminalContext,
      run: _runAiCommand,
      insert: _insertAiCommand,
      cancel: _cancelAiCommand,
    );
    final hosts = ref.read(agentScopeHostsProvider)..register(spi.id, host);
    _releaseAgentHost = () => hosts.unregister(spi.id, host);
  }

  /// Opens the Agent for this terminal's server.
  ///
  /// Takes no terminal context: what gets sent is read from the terminal when
  /// a turn starts, through the host this page registered, so a session that
  /// outlives this panel is never sending a screen from an earlier one.
  Future<void> _showAskAiPanel({required bool autoStart}) async {
    if (!mounted) return;
    final localeHint = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    // The width this page has, not the window's. On anything but a phone the
    // navigation rail takes its share out of the window before a tab sees any
    // of it, and every other split in the app — `AdaptiveSideList`,
    // `AdaptivePanes` — decides from what it was handed. Asking `MediaQuery`
    // instead measured the window, so the same 800 landed about a rail's width
    // earlier here than everywhere else: on an iPad in portrait this opened
    // beside the terminal while the server list still had one column.
    final width =
        context.size?.width ?? MediaQuery.sizeOf(context).width;
    final placement = askAiPanelPlacementForWidth(width);

    // The panel's tools act on a server, so there has to be one. A terminal on
    // this device has none: the global Agent is what reaches it, through
    // `LocalTarget`, and this per-server panel is not that.
    final spi = widget.args.spi;
    if (spi == null) return;

    Widget panel(BuildContext panelContext) => _AskAiPanel(
      serverId: spi.id,
      serverName: spi.name,
      localeHint: localeHint,
      autoStart: autoStart,
      // The decision already made, not a second one. Recomputed inside the
      // route it could disagree with the route it is in — a sheet telling
      // itself it is a side panel — since a sheet's context measures the
      // sheet.
      placement: placement,
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
/// The Agent for one server, shown beside its terminal.
///
/// A view onto [agentSessionProvider] and nothing more: the conversation, the
/// turn it is in the middle of and the proposal awaiting review all live in
/// that session, scoped to [serverId] — the same scope the conversations are
/// stored under. This panel had its own copy of that state machine until the
/// two drifted apart in three places; what is left here is what a panel is
/// for, which is layout, scrolling and what is being typed.
class _AskAiPanel extends ConsumerStatefulWidget {
  const _AskAiPanel({
    required this.serverId,
    required this.serverName,
    required this.localeHint,
    required this.autoStart,
    required this.placement,
  });

  final String serverId;
  final String serverName;
  final String? localeHint;
  final bool autoStart;
  final AskAiPanelPlacement placement;

  @override
  ConsumerState<_AskAiPanel> createState() => _AskAiPanelState();
}

class _AskAiPanelState extends ConsumerState<_AskAiPanel> {
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  bool _autoStarted = false;

  AgentSession get _notifier =>
      ref.read(agentSessionProvider(widget.serverId).notifier);

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_handleInputChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoStarted || !widget.autoStart) return;
    _autoStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _submitPrompt(context.l10n.askAiAnalyzeSelectionPrompt);
    });
  }

  @override
  void dispose() {
    // Nothing about the conversation is torn down here. A turn belongs to the
    // session, which outlives this panel on purpose: closing it used to cancel
    // whatever was streaming, which is not what closing a window means.
    _scrollController.dispose();
    _inputController
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  void _handleInputChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submitPrompt(String prompt) async {
    final taken = await _notifier.submitPrompt(
      prompt,
      localeHint: widget.localeHint,
    );
    // Only once it was taken: a prompt refused because a turn is already
    // running is still in the box, and emptying it would lose what was typed.
    if (taken && mounted) _inputController.clear();
  }

  /// Runs the pending command, asking first when it is the kind that cannot be
  /// undone.
  ///
  /// The asking is here rather than in the session because it is a dialog, and
  /// the session has no `BuildContext` to put one on.
  Future<void> _runPendingCommand(AskAiCommand command) async {
    if (command.risk == AskAiCommandRisk.destructive) {
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
            onPressed: () => context.popDialog(true),
            child: Text(libL10n.run),
          ),
        ],
      );
      if (confirmed != true || !mounted) return;
    }
    await _notifier.runPendingTool();
  }

  Future<void> _insertPendingCommand() async {
    if (await _notifier.insertPendingTool()) {
      Toast.show(context.l10n.askAiCommandInserted);
    }
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    final compact = MediaQuery.sizeOf(context).width < 480;
    final status = switch ((
      session.isExecuting,
      session.isStreaming,
      session.pendingTool != null,
    )) {
      (true, _, _) => libL10n.running,
      (_, true, _) => libL10n.thinking,
      (_, _, true) => context.l10n.askAiReviewNeeded,
      _ => libL10n.ready,
    };
    final statusColor = session.pendingTool != null
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final title = session.conversation?.title.trim() ?? '';
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
                  'SSH Agent',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  title.isNotEmpty
                      ? '${widget.serverName} · $title'
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
            onPressed: session.isWorking ? null : _showConversationHistory,
            icon: const Icon(Icons.history),
          ),
          if (session.isWorking)
            IconButton(
              tooltip: libL10n.stop,
              onPressed: _notifier.stopWork,
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
    // What the next turn would send, read now — the same getter the session
    // reads through its host. Showing the screen as it was when this panel
    // opened would be a disclosure of something else.
    final content = ref
        .read(agentScopeHostsProvider)[widget.serverId]
        .terminalContext
        .trim();
    if (content.isEmpty) return const SizedBox.shrink();
    final preview = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Hairline.color(context)),
      ),
      child: ExpansionTile(
        initiallyExpanded: widget.autoStart,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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
            context.l10n.agentWelcomeTip,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineEntry(
    BuildContext context,
    ThemeData theme,
    AgentTimelineEntry entry,
  ) {
    Widget notice(String text) => Row(
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
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );

    return switch (entry) {
      AgentUserEntry(:final content) => Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(content),
        ),
      ),
      AgentAssistantEntry(:final content) => Align(
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
              SimpleMarkdown(data: content),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: libL10n.copy,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => copyAgentText(content),
                  icon: const Icon(Icons.copy, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
      AgentShellResultEntry() => _buildCommandResult(context, theme, entry),
      // Written only by the app-wide Agent, whose tools are not all shells.
      // Reachable here through a restored backup, and shown as its own summary
      // rather than forced into a shell result's shape.
      AgentToolResultEntry(:final result) => notice(result.summary),
      AgentNoticeEntry(:final kind) => notice(agentNoticeText(context, kind)),
      AgentRawNoticeEntry(:final text) => notice(text),
    };
  }

  Widget _buildCommandResult(
    BuildContext context,
    ThemeData theme,
    AgentShellResultEntry entry,
  ) {
    final command = entry.command;
    final result = entry.result;
    final output = result.displayOutput;
    final color = result.succeeded
        ? theme.colorScheme.primary
        : theme.colorScheme.error;
    final status = result.cancelled
        ? libL10n.cancelled
        : result.timedOut
        ? libL10n.timedOut
        : result.succeeded
        ? libL10n.success
        : '${libL10n.fail} (${result.exitCode ?? '?'})';
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Hairline.color(context)),
      ),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(),
        collapsedShape: const RoundedRectangleBorder(),
        initiallyExpanded: !result.succeeded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
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

  Widget _buildStreamingBubble(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    final content = session.streamingContent?.trim() ?? '';
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
            : SimpleMarkdown(data: content),
      ),
    );
  }

  Widget _buildProposalCard(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    final command = session.pendingTool!;
    final working = session.isWorking;
    final (label, color, icon) = switch (command.risk) {
      AskAiCommandRisk.readOnly => (
        context.l10n.askAiRiskReadOnly,
        theme.colorScheme.primary,
        Icons.visibility_outlined,
      ),
      AskAiCommandRisk.unknown => (
        context.l10n.askAiRiskUnknown,
        theme.colorScheme.tertiary,
        Icons.help_outline,
      ),
      AskAiCommandRisk.unvettedHost => (
        context.l10n.askAiRiskUnvetted,
        theme.colorScheme.tertiary,
        Icons.shield_outlined,
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
          if (session.pendingToolRestored) ...[
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
                onPressed: working ? null : _notifier.declinePendingTool,
                child: Text(context.l10n.askAiDecline),
              ),
              TextButton.icon(
                onPressed: working
                    ? null
                    : () => copyAgentText(command.command),
                icon: const Icon(Icons.copy, size: 17),
                label: Text(libL10n.copy),
              ),
              OutlinedButton.icon(
                onPressed: working ? null : _insertPendingCommand,
                icon: const Icon(Icons.keyboard_return, size: 17),
                label: Text(context.l10n.askAiInsertTerminal),
              ),
              FilledButton.icon(
                onPressed: working ? null : () => _runPendingCommand(command),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: Text(context.l10n.askAiApproveRun),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Enter, under the same setting the Agent page reads.
  ///
  /// A bare Enter mid-composition belongs to the IME, which uses it to accept
  /// a candidate; a modified one never does, so only the bare form gives way.
  KeyEventResult _handleComposerKey(KeyEvent event, bool canSend) {
    if (!composerKeySends(
      event,
      composing: !_inputController.value.composing.isCollapsed,
      sendOnEnter: Stores.setting.askAiSendOnEnter.fetch(),
    )) {
      return KeyEventResult.ignored;
    }
    if (canSend) _submitPrompt(_inputController.text);
    // Handled either way: the key meant "send", and letting it through would
    // leave a line break behind whenever there was nothing to send.
    return KeyEventResult.handled;
  }

  Widget _buildComposer(
    BuildContext context,
    ThemeData theme,
    AgentSessionState session,
  ) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canSend =
        !session.isWorking &&
        session.pendingTool == null &&
        _inputController.text.trim().isNotEmpty;
    final sendOnEnter = Stores.setting.askAiSendOnEnter.fetch();
    final error = session.error;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.fromLTRB(12, 8, 12, 12 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.pendingTool != null) ...[
            _buildProposalCard(context, theme, session),
            const SizedBox(height: 8),
          ],
          if (error != null) ...[
            AgentErrorBanner(
              message: describeAgentError(context, error),
              onRetry: session.isWorking
                  ? null
                  : () => _notifier.startStream(localeHint: widget.localeHint),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                // Same key handling as the Agent page's composer: this is the
                // app's other chat box, and a setting that governs one of two
                // identical fields is a setting nobody can rely on.
                child: Focus(
                  onKeyEvent: (_, event) => _handleComposerKey(event, canSend),
                  child: Input(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 5,
                    hint: session.pendingTool == null
                        ? context.l10n.askAiAgentPromptHint
                        : context.l10n.askAiReviewBeforeContinuing,
                    // On every keyboard, soft ones included — same reasoning as
                    // the Agent tab's composer.
                    action: sendOnEnter
                        ? TextInputAction.send
                        : TextInputAction.newline,
                    onSubmitted: sendOnEnter
                        ? (_) {
                            if (canSend) _submitPrompt(_inputController.text);
                          }
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.send,
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
    final provider = agentSessionProvider(widget.serverId);
    final session = ref.watch(provider);

    // Following the state rather than scrolling wherever this panel last
    // appended something: the session moves on its own, so a turn started here
    // keeps going while the panel is closed and comes back further along than
    // it was left.
    ref.listen(provider, (previous, next) {
      final settled =
          previous?.timeline.length != next.timeline.length ||
          previous?.pendingTool != next.pendingTool;
      if (settled || previous?.streamingContent != next.streamingContent) {
        scheduleAgentAutoScroll(_scrollController, force: settled);
      }
    });

    final content = Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(context, theme, session),
          // The app's one line — see [Hairline]. This panel sits beside the
          // terminal, so its rules meet that column's edge.
          Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  _buildTerminalContext(context, theme),
                  if (session.isEmpty) _buildEmptyState(context, theme),
                  for (final entry in session.timeline) ...[
                    _buildTimelineEntry(context, theme, entry),
                    const SizedBox(height: 10),
                  ],
                  if (session.isStreaming)
                    _buildStreamingBubble(context, theme, session),
                ],
              ),
            ),
          ),
          Divider(
            height: Hairline.thickness,
            thickness: Hairline.thickness,
            color: Hairline.color(context),
          ),
          _buildComposer(context, theme, session),
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
