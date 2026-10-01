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
          _showAskAiPanel(selection: selection);
        },
      ),
    ];
  }

  String get _selectedTerminalText =>
      _termKey.currentState?.renderTerminal.selectedText?.trim() ?? '';

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
    // A terminal on this device has no server to scope a chat to. The
    // app-wide Agent is what reaches it, through `LocalTarget`.
    if (spi == null) return;
    _releaseAgentHost = TerminalHosts.register(
      spi.id,
      TerminalHost(
        serverName: spi.name,
        run: _runAiCommand,
        insert: _insertAiCommand,
        // Read per call, not captured: by the next turn the screen has moved
        // on.
        screen: () => _sess.screenText,
        cancel: _cancelAiCommand,
      ),
    );
  }

  /// Opens the Agent for this terminal's server.
  ///
  /// With [selection], on a new chat whose message starts as that text, for
  /// the user to say what they want to know about it: the screen itself is a
  /// tool away, and reads as the model needs it rather than once up front.
  Future<void> _showAskAiPanel({String? selection}) async {
    if (!mounted) return;
    // The width this page has, not the window's. On anything but a phone the
    // navigation rail takes its share out of the window before a tab sees any
    // of it, and every other split in the app — both `AdaptivePanes`
    // constructors — decides from what it was handed. Asking `MediaQuery`
    // instead measured the window, so the same 800 landed about a rail's width
    // earlier here than everywhere else: on an iPad in portrait this opened
    // beside the terminal while the server list still had one column.
    final width = context.size?.width ?? MediaQuery.sizeOf(context).width;
    final placement = askAiPanelPlacementForWidth(width);

    // The panel's tools act on a server, so there has to be one. A terminal on
    // this device has none: the global Agent is what reaches it, through
    // `LocalTarget`, and this per-server panel is not that.
    final spi = widget.args.spi;
    if (spi == null) return;

    final scope = AgentScope.terminal(spi.id);
    if (selection != null && selection.isNotEmpty) {
      AgentChats.startNew(scope);
      Composer.draftScope = scope;
      Composer.draft.value = '```\n$selection\n```\n\n';
    }

    Widget panel(BuildContext panelContext) =>
        _AskAiPanel(scope: scope, serverName: spi.name);

    if (placement == AskAiPanelPlacement.bottomSheet) {
      await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) =>
            FractionallySizedBox(heightFactor: 0.86, child: panel(sheetContext)),
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
      transitionBuilder: (transitionContext, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        // In from the edge it sits against, or only faded in where the device
        // has asked for less movement.
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(transitionContext.reduceMotion ? 0 : 1, 0),
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
    _focusTerminal();
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

/// The Agent for one server, beside its terminal: that server's terminal
/// chats — see [AgentScope.terminal] — in a sheet or a side panel.
class _AskAiPanel extends StatelessWidget {
  const _AskAiPanel({required this.scope, required this.serverName});

  final String scope;
  final String serverName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
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
                          serverName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AgentHeaderActions(showConversations: true, scope: scope),
                  IconButton(
                    tooltip: libL10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          Expanded(
            child: AgentConversationView(
              scope: scope,
              compact: true,
              showHeader: false,
            ),
          ),
        ],
      ),
    );
  }
}
