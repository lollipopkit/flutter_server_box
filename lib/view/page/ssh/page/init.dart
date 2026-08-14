part of 'page.dart';

extension _Init on SSHPageState {
  void _logTmuxInfo(String message) {
    Loggers.app.info('[TMUX] $message');
  }

  /// Whether a second command can run beside the interactive shell. tmux,
  /// which drives a control channel of its own, is the main thing that cares.
  bool get _canExec => _sess.canExec;

  /// Connects a new source of shells, asking the provider what the agent
  /// allows at the moment of use rather than trusting a stored answer.
  Future<ShellBackend> _connectBackend() => _sess.connect(
    granted: ref.read(serverProvider(widget.args.spi.id)).remoteAccess,
    context: mounted ? context : null,
  );

  Map<String, String>? get _sshEnvironment => _sess.environment;

  String? get _tmuxLang => _sess.tmuxLang;

  void _bindForegroundSession(ShellSession session) {
    _sess.bindForeground(session);
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
  }

  void _onForegroundSessionDone(ShellSession session) {
    // When the SSH transport closed unexpectedly (e.g. toggling WiFi) while a
    // tmux session was attached, the server-side tmux session survives. Route
    // this to the existing reconnect logic instead of tearing the tab down, so
    // the tab isn't removed when WiFi comes back. Normal session end (shell
    // exit) and user-initiated disconnect keep the transport open, so they
    // still remove the tab via the path below.
    final transportClosed = _backend != null && _backend!.isClosed;
    if (mounted &&
        transportClosed &&
        _tmuxCurrentSession != null &&
        _tmuxCurrentSession!.isNotEmpty) {
      unawaited(_onConnectionLossSuspected());
      return;
    }

    if (mounted && widget.args.notFromTab) {
      context.pop();
    }
    widget.args.onSessionEnd?.call();
    TermSessionManager.remove(_sessionId);
  }

  Future<bool> _replaceForegroundWithLaunchPlan(TmuxLaunchPlan plan) async {
    if (!_canExec || !plan.shouldLaunchTmux) return false;

    final oldSession = _session;
    ShellSession? session;
    try {
      session = await _sess.execute(plan.command!);
    } catch (e, st) {
      Loggers.app.warning('Failed to replace foreground session with tmux', e, st);
      return false;
    }

    if (session == null) {
      Loggers.app.warning('Failed to replace foreground session with tmux');
      return false;
    }

    _sess.unbindForeground();
    try {
      oldSession?.close();
    } catch (e, st) {
      Loggers.app.warning('Failed to close old foreground session', e, st);
    }

    _saveTmuxState(
      sessionName: plan.sessionName!,
      windowIndex: plan.windowIndex,
    );
    _bindForegroundSession(session);
    widget.args.focusNode?.requestFocus();
    return true;
  }

  Future<ShellSession?> _openForegroundSession() async {
    final plan = await _resolveForegroundLaunchPlan();

    if (plan.shouldLaunchTmux) {
      ShellSession? session;
      try {
        session = await _sess.execute(plan.command!);
      } catch (e, st) {
        Loggers.app.warning('Failed to open foreground tmux session', e, st);
        _clearTmuxState();
        return null;
      }
      if (session != null) {
        _saveTmuxState(
          sessionName: plan.sessionName!,
          windowIndex: plan.windowIndex,
        );
      } else {
        _clearTmuxState();
      }
      return session;
    }

    _clearTmuxState();
    return _sess.openShell();
  }

  void _initStoredCfg() {
    final fontFamilly = Stores.setting.fontPath.fetch().getFileName();
    final textSize = Stores.setting.termFontSize.fetch();
    final textStyle = TextStyle(fontFamily: fontFamilly, fontSize: textSize);

    _terminalStyle = TerminalStyle.fromTextStyle(textStyle);
  }

  Future<void> _showHelp() async {
    if (Stores.setting.sshTermHelpShown.fetch()) return;

    return await context.showRoundDialog(
      title: libL10n.doc,
      child: Text(l10n.sshTermHelp),
      actions: [
        TextButton(
          onPressed: () {
            Stores.setting.sshTermHelpShown.put(true);
            context.popDialog();
          },
          child: Text(l10n.noPromptAgain),
        ),
      ],
    );
  }

  Future<void> _initTerminal() async {
    // A session handed to this page is already connected and already running
    // something — the dialog that started it did all of this. Opening a second
    // shell here would replace what the user asked to carry on watching.
    if (_adopted) {
      TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
      widget.args.focusNode?.requestFocus();
      return;
    }

    _writeLn(l10n.waitConnection);
    if (_backend == null) await _connectBackend();

    _writeLn('${libL10n.execute}: Shell');
    final session = await _openForegroundSession();

    if (session == null) {
      _writeLn(libL10n.fail);
      return;
    }

    _bindForegroundSession(session);

    final snippets = ref.read(snippetProvider.select((p) => p.snippets));
    if (_tmuxCurrentSession == null) {
      for (final snippet in snippets) {
        if (snippet.autoRunOn?.contains(widget.args.spi.id) == true) {
          snippet.runInTerm(_terminal, widget.args.spi);
        }
      }
    }

    final initCmd = widget.args.initCmd;
    if (initCmd != null && _tmuxCurrentSession == null) {
      _terminal.textInput(initCmd);
      _terminal.keyInput(TerminalKey.enter);
    }

    final initSnippet = widget.args.initSnippet;
    if (initSnippet != null && _tmuxCurrentSession == null) {
      initSnippet.runInTerm(_terminal, widget.args.spi);
    }

    widget.args.focusNode?.requestFocus();
  }

  void _setupDiscontinuityTimer() {
    _discontinuityTimer?.cancel();
    if (!mounted) return;

    _missedKeepAliveCount = 0;
    _discontinuityTimer = Timer.periodic(
      SSHPageState._connectionCheckInterval,
      (_) => _checkConnectionHealth(),
    );
  }

  Future<void> _checkConnectionHealth({bool immediate = false}) async {
    if (!mounted || _backend == null) return;
    if (_isCheckingConnection) {
      if (immediate) _hasPendingImmediateCheck = true;
      return;
    }
    _isCheckingConnection = true;

    try {
      await _backend!.ping().timeout(SSHPageState._connectionCheckTimeout);
      _missedKeepAliveCount = 0;
      if (_reportedDisconnected) {
        _reportedDisconnected = false;
        TermSessionManager.updateStatus(
          _sessionId,
          TermSessionStatus.connected,
        );
      }
    } on TimeoutException catch (error) {
      _handleConnectionCheckFailure(error, immediate: immediate);
    } on Object catch (error, stackTrace) {
      _handleConnectionCheckFailure(
        error,
        stackTrace: stackTrace,
        immediate: immediate,
      );
    } finally {
      _isCheckingConnection = false;
      if (_hasPendingImmediateCheck) {
        _hasPendingImmediateCheck = false;
        unawaited(_checkConnectionHealth(immediate: true));
      }
    }
  }

  void _handleConnectionCheckFailure(
    Object error, {
    StackTrace? stackTrace,
    bool immediate = false,
  }) {
    Loggers.root.warning('SSH keep-alive failed', error, stackTrace);
    _missedKeepAliveCount += 1;

    if (!immediate &&
        _missedKeepAliveCount < SSHPageState._maxKeepAliveFailures) {
      return;
    }

    _missedKeepAliveCount = 0;
    unawaited(_onConnectionLossSuspected());
  }

  Future<void> _onConnectionLossSuspected() async {
    if (!mounted || _disconnectDialogOpen) return;

    _disconnectDialogOpen = true;
    _reportedDisconnected = true;
    _discontinuityTimer?.cancel();
    _writeLn('\n\n${libL10n.disconnected}\r\n');
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.disconnected);

    final sessionName = _tmuxCurrentSession;
    // Check if we have any tmux session to recover
    if (sessionName != null && sessionName.isNotEmpty) {
      final restored = await _tryReconnectTmux(sessionName);
      if (!mounted) return;
      if (restored) {
        _disconnectDialogOpen = false;
        _reportedDisconnected = false;
        return;
      }
    }

    // Reconnect failed/cancelled, or no tmux to restore -> ask whether to leave.
    unawaited(_showDisconnectDialog());
  }

  /// Re-establish SSH and re-attach the previous tmux [sessionName]
  /// (+ window), showing a cancellable progress dialog while reconnecting.
  /// Returns `true` when the terminal was restored.
  Future<bool> _tryReconnectTmux(String sessionName) async {
    _reconnectCancelled = false;
    if (mounted) {
      _showReconnectingDialog(onCancel: () => _reconnectCancelled = true);
    }
    try {
      return await _reconnectAndAttachTmux(sessionName);
    } catch (e, st) {
      Loggers.app.warning('SSH reconnect threw', e, st);
      _closeFailedReconnectClient();
      return false;
    } finally {
      if (mounted) contextSafe?.pop();
    }
  }

  /// Cancellable progress dialog shown while reconnecting.
  void _showReconnectingDialog({required VoidCallback onCancel}) {
    unawaited(
      context.showRoundDialog(
        child: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(l10n.reconnecting)),
            Btn.cancel(onTap: onCancel),
          ],
        ),
        barrierDismiss: false,
      ),
    );
  }

  Future<void> _showDisconnectDialog() async {
    final shouldLeave = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('${libL10n.disconnected}\n${l10n.goBackQ}'),
      barrierDismiss: false,
      actions: [
        TextButton(
          onPressed: () => context.popDialog(false),
          child: Text(libL10n.cancel),
        ),
        TextButton(onPressed: () => context.popDialog(true), child: Text(libL10n.ok)),
      ],
    );

    if (!mounted) return;

    _disconnectDialogOpen = false;

    if (shouldLeave == true) {
      contextSafe?.pop(); // Pop the SSHPage
      return;
    }

    // If the client is gone or its transport already closed, "stay" means
    // "try again" rather than resuming monitoring of a dead connection.
    if (_backend == null || _backend!.isClosed) {
      unawaited(_onConnectionLossSuspected());
      return;
    }

    _reportedDisconnected = false;
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
    _setupDiscontinuityTimer();
  }

  /// Reconnect SSH after a connection loss and re-attach the previous tmux
  /// session+window.
  ///
  /// Returns `true` when a usable terminal was restored (either the tmux
  /// session was re-attached or, as a fallback, a raw shell was opened). Returns
  /// `false` only when the SSH transport itself could not be re-established, in
  /// which case the caller falls back to the disconnect prompt.
  Future<bool> _reconnectAndAttachTmux(String sessionName) async {
    // Tear down the stale SSH session/client first.
    _sess.closeBackend();

    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connecting);

    const maxAttempts = 10;
    const baseInterval = Duration(milliseconds: 200);
    const maxInterval = Duration(seconds: 3);
    var connected = false;
    for (
      var attempt = 0;
      attempt < maxAttempts && mounted && !_reconnectCancelled;
      attempt++
    ) {
      if (attempt > 0) {
        final backoffMs = (baseInterval.inMilliseconds << (attempt - 1))
            .clamp(0, maxInterval.inMilliseconds)
            .toInt();
        await Future.delayed(Duration(milliseconds: backoffMs));
        if (!mounted || _reconnectCancelled) {
          _closeFailedReconnectClient();
          return false;
        }
      }
      try {
        await _connectBackend();
        connected = true;
        break;
      } catch (_) {
        Loggers.app.info(
          'SSH reconnect attempt ${attempt + 1}/$maxAttempts failed',
        );
      }
    }
    if (!mounted || _reconnectCancelled) {
      _closeFailedReconnectClient();
      return false;
    }
    if (!connected) {
      Loggers.app.info('SSH reconnect failed after $maxAttempts attempts');
      _closeFailedReconnectClient();
      return false;
    }

    if (await _reattachTmux(sessionName: sessionName)) {
      if (!mounted || _reconnectCancelled) {
        _closeFailedReconnectClient();
        return false;
      }
      _setupDiscontinuityTimer();
      widget.args.focusNode?.requestFocus();
      return true;
    }
    if (!mounted || _reconnectCancelled) {
      _closeFailedReconnectClient();
      return false;
    }

    // tmux wasn't restorable (unavailable or session gone) — fall back to a
    // raw shell so the terminal remains usable instead of being left blank.
    _logTmuxInfo(
      'Previous tmux session "$sessionName" no longer available, '
      'falling back to a raw shell',
    );
    _clearTmuxState();

    final shell = await _sess.openShell();
    if (shell == null || !mounted || _reconnectCancelled) {
      if (mounted) _writeLn(libL10n.fail);
      _closeFailedReconnectClient();
      return false;
    }
    _bindForegroundSession(shell);
    _setupDiscontinuityTimer();
    widget.args.focusNode?.requestFocus();
    return true;
  }

  /// Re-attach the previous tmux [sessionName] (+ window) after reconnecting.
  ///
  /// Verifies via a control channel that tmux is available and that the session
  /// still exists, then launches the attach command as the foreground session.
  Future<bool> _reattachTmux({required String sessionName}) async {
    final control = await _createTmuxControlSession();
    try {
      bool available;
      try {
        available = await control.isAvailable;
      } catch (e, st) {
        Loggers.app.warning(
          'tmux availability check on reconnect failed',
          e,
          st,
        );
        return false;
      }
      if (!available) return false;

      final tmuxBin = control.scanner.tmuxBin ?? 'tmux';
      final List<TmuxSessionInfo> sessions;
      try {
        sessions = await control.sessions;
      } catch (e, st) {
        Loggers.app.warning('tmux list sessions on reconnect failed', e, st);
        return false;
      }
      if (!sessions.any((session) => session.name == sessionName)) {
        return false;
      }

      final restoredWindowIndex = _tmuxCurrentWindow;
      final windows = restoredWindowIndex == null
          ? const <TmuxWindowInfo>[]
          : await control.tryListWindows(sessionName) ??
                const <TmuxWindowInfo>[];
      final windowIndex = validateRestoredWindowIndex(
        restoredWindowIndex,
        windows,
      );
      final command = windowIndex != null
          ? TmuxCommandBuilder.attachSessionWindow(
              sessionName,
              windowIndex,
              tmuxBin: tmuxBin,
              lang: _tmuxLang,
            )
          : TmuxCommandBuilder.attachSession(
              sessionName,
              tmuxBin: tmuxBin,
              lang: _tmuxLang,
            );

      final session = await _sess.execute(command);
      if (session == null) return false;

      _saveTmuxState(sessionName: sessionName, windowIndex: windowIndex);
      _bindForegroundSession(session);
      _logTmuxInfo(
        'Reconnected and re-attached tmux session "$sessionName"'
        '${windowIndex != null ? ' window $windowIndex' : ''}',
      );
      return true;
    } finally {
      await control.dispose();
    }
  }

  /// Clear the in-memory + restorable tmux state (used when a session can no
  /// longer be restored, e.g. after it was killed server-side).
  void _clearTmuxState() {
    _tmuxCurrentSession = null;
    _tmuxCurrentWindow = null;
    _restorableTmuxSession.value = null;
    _restorableTmuxWindow.value = null;
    widget.args.onTmuxStateChanged?.call();
  }

  void _closeFailedReconnectClient() => _sess.closeBackend();

  void _writeLn(String p0) => _sess.writeLn(p0);

  TmuxRestoreState get _restoreTmuxState {
    return resolveTmuxRestoreState(
      argsSession: widget.args.tmuxSession,
      argsWindow: widget.args.tmuxWindow,
      restorableSession: _restorableTmuxSession.value,
      restorableWindow: _restorableTmuxWindow.value,
    );
  }

  void _saveTmuxState({required String sessionName, int? windowIndex}) {
    _tmuxCurrentSession = sessionName;
    _tmuxCurrentWindow = windowIndex;
    _restorableServerId.value = widget.args.spi.id;
    _restorableTmuxSession.value = sessionName;
    _restorableTmuxWindow.value = windowIndex;
    widget.args.onTmuxStateChanged?.call();
  }

  Future<TmuxSession> _createTmuxControlSession() async {
    return TmuxSession(
      PersistentShell(
        _client,
        sessionFactory: () async {
          final sh = await _client!.execute('sh', environment: _sshEnvironment);
          return SshPersistentShellSession(sh);
        },
      ),
      lang: _tmuxLang,
    );
  }

  Future<TmuxLaunchPlan> _resolveForegroundLaunchPlan() async {
    if (!Stores.setting.tmuxAuto.fetch() || !_canExec) {
      return const TmuxLaunchPlan.none();
    }

    final TmuxSession tmuxSession;
    try {
      tmuxSession = await _createTmuxControlSession().timeout(
        const Duration(seconds: 5),
      );
    } on TimeoutException catch (e, st) {
      Loggers.app.warning('tmux control session creation timed out', e, st);
      return const TmuxLaunchPlan.none();
    } catch (e, st) {
      Loggers.app.warning('tmux control session creation failed', e, st);
      return const TmuxLaunchPlan.none();
    }

    try {
      bool available;
      try {
        available = await tmuxSession.isAvailable;
      } catch (e, st) {
        Loggers.app.warning('tmux availability check failed', e, st);
        return const TmuxLaunchPlan.none();
      }

      if (!available) {
        return const TmuxLaunchPlan.none();
      }
      final tmuxBin = tmuxSession.scanner.tmuxBin ?? 'tmux';

      final showSelector = Stores.setting.tmuxShowSelector.fetch();
      final restoredState = _restoreTmuxState;
      final shouldPreloadSessions = restoredState.hasSession || showSelector;
      final sessions = shouldPreloadSessions
          ? await _loadTmuxSessions(tmuxSession)
          : const <TmuxSessionInfo>[];

      final restoredPlan = await _buildRestoredForegroundLaunchPlan(
        tmuxSession,
        sessions,
        tmuxBin: tmuxBin,
        lang: _tmuxLang,
      );
      if (restoredPlan.shouldLaunchTmux) return restoredPlan;

      final plan = await _buildInitialForegroundLaunchPlan(
        tmuxSession,
        preloadedSessions: sessions,
        tmuxBin: tmuxBin,
        lang: _tmuxLang,
      );
      return plan;
    } finally {
      await tmuxSession.dispose();
    }
  }

  Future<List<TmuxSessionInfo>> _loadTmuxSessions(
    TmuxSession tmuxSession,
  ) async {
    try {
      return await tmuxSession.sessions;
    } catch (e, st) {
      Loggers.app.warning('tmux list sessions failed', e, st);
      return const [];
    }
  }

  Future<TmuxLaunchPlan> _buildRestoredForegroundLaunchPlan(
    TmuxSession tmuxSession,
    List<TmuxSessionInfo> sessions, {
    required String tmuxBin,
    required String? lang,
  }) async {
    final restoredState = _restoreTmuxState;
    if (!restoredState.hasSession) return const TmuxLaunchPlan.none();

    final sessionExists = sessions.any(
      (session) => session.name == restoredState.sessionName,
    );
    if (!sessionExists) return const TmuxLaunchPlan.none();

    final windows = restoredState.windowIndex == null
        ? const <TmuxWindowInfo>[]
        : await tmuxSession.tryListWindows(restoredState.sessionName!) ??
              const <TmuxWindowInfo>[];

    final restoredPlan = buildRestoredTmuxLaunchPlan(
      restoredState,
      sessions,
      windows: windows,
      tmuxBin: tmuxBin,
      lang: lang,
    );
    if (restoredPlan.shouldLaunchTmux) {
      _logTmuxInfo(
        'Restoring tmux session "${restoredState.sessionName}"'
        '${restoredPlan.windowIndex != null ? ' window ${restoredPlan.windowIndex}' : ''}',
      );
      return restoredPlan;
    }

    Loggers.app.info(
      'Restored tmux session "${restoredState.sessionName}" not found, falling back to picker',
    );
    return const TmuxLaunchPlan.none();
  }

  Future<TmuxLaunchPlan> _buildInitialForegroundLaunchPlan(
    TmuxSession tmuxSession, {
    List<TmuxSessionInfo>? preloadedSessions,
    required String tmuxBin,
    required String? lang,
  }) async {
    final showSelector = Stores.setting.tmuxShowSelector.fetch();
    final defaultName = Stores.setting.tmuxSessionName.fetch();
    final sessionName = defaultName.isEmpty ? 'server_box' : defaultName;

    TmuxAttachChoice? choice;

    if (showSelector) {
      final sessions =
          preloadedSessions ?? await _loadTmuxSessions(tmuxSession);
      if (!mounted) return const TmuxLaunchPlan.none();

      choice = await showTmuxSessionSelectorWithSkip(
        context,
        sessions: sessions,
        tmuxSessionFactory: _createTmuxControlSession,
        defaultSessionName: sessionName,
      );
    } else {
      choice = TmuxAttachNew(sessionName: sessionName);
    }

    if (choice == null || choice is TmuxAttachSkip) {
      return const TmuxLaunchPlan.none();
    }

    return buildChosenTmuxLaunchPlan(choice, tmuxBin: tmuxBin, lang: lang);
  }

  Future<void> _showTmuxSwitcher() async {
    if (_client == null || !mounted) return;

    final tmuxSession = await _createTmuxControlSession();
    try {
      final available = await tmuxSession.isAvailable;
      if (!available || !mounted) {
        if (mounted) context.showSnackBar(context.l10n.tmuxNotAvailable);
        return;
      }
      final tmuxBin = tmuxSession.scanner.tmuxBin ?? 'tmux';

      final sessions = await tmuxSession.sessions;
      if (!mounted) return;

      final defaultName = Stores.setting.tmuxSessionName.fetch();
      final sessionName = defaultName.isEmpty ? 'server_box' : defaultName;

      final choice = await showTmuxSessionSelectorWithSkip(
        context,
        sessions: sessions,
        tmuxSessionFactory: _createTmuxControlSession,
        defaultSessionName: sessionName,
        initialSessionName: _tmuxCurrentSession,
      );

      if (choice == null || choice is TmuxAttachSkip) return;

      if (choice is TmuxAttachExisting) {
        if (_tmuxCurrentSession == null) {
          final plan = buildChosenTmuxLaunchPlan(
            choice,
            tmuxBin: tmuxBin,
            lang: _tmuxLang,
          );
          await _replaceForegroundWithLaunchPlan(plan);
          return;
        }
        final target = choice.windowIndex != null
            ? '${choice.sessionName}:${choice.windowIndex}'
            : choice.sessionName;
        await _switchTmuxClient(
          tmuxSession,
          target,
          nextSessionName: choice.sessionName,
          nextWindowIndex: choice.windowIndex,
        );
        widget.args.focusNode?.requestFocus();
        return;
      }

      if (choice is TmuxAttachNew) {
        if (_tmuxCurrentSession == null) {
          final plan = buildChosenTmuxLaunchPlan(
            choice,
            tmuxBin: tmuxBin,
            lang: _tmuxLang,
          );
          await _replaceForegroundWithLaunchPlan(plan);
          return;
        }
        await tmuxSession.runCommand(
          '${TmuxCommandBuilder.tmuxPrefix(tmuxBin: tmuxBin, lang: _tmuxLang)} new-session -d -s ${TmuxCommandBuilder.escapeArg(choice.sessionName)}',
        );
        await _switchTmuxClient(
          tmuxSession,
          choice.sessionName,
          nextSessionName: choice.sessionName,
        );
        widget.args.focusNode?.requestFocus();
        return;
      }
    } finally {
      await tmuxSession.dispose();
    }
  }

  /// Switch the terminal's tmux client to a different session/window.
  /// Dynamically finds this terminal's tmux client by session/window.
  Future<void> _switchTmuxClient(
    TmuxSession tmuxSession,
    String target, {
    required String nextSessionName,
    int? nextWindowIndex,
  }) async {
    final tmuxBin = tmuxSession.scanner.tmuxBin ?? 'tmux';
    final tty = await _resolveTmuxClientTty(
      tmuxSession,
      tmuxBin: tmuxBin,
      lang: _tmuxLang,
    );
    if (tty == null) {
      Loggers.app.warning('Failed to find tmux client tty for session switch');
      return;
    }
    final switchCmd = TmuxCommandBuilder.switchClient(
      tty,
      target,
      tmuxBin: tmuxBin,
      lang: _tmuxLang,
    );
    final ok = await tmuxSession.runCommand(switchCmd);
    if (!ok) {
      Loggers.app.warning('Failed to switch tmux client to target: $target');
    }
    if (ok) {
      _saveTmuxState(
        sessionName: nextSessionName,
        windowIndex: nextWindowIndex,
      );
    }
  }

  Future<String?> _resolveTmuxClientTty(
    TmuxSession tmuxSession, {
    required String tmuxBin,
    required String? lang,
  }) async {
    final clients = await _listTmuxClients(
      tmuxSession,
      tmuxBin: tmuxBin,
      lang: lang,
    );

    final currentSession = _tmuxCurrentSession;
    if (currentSession == null) return null;

    var candidates = clients
        .where((client) => client.sessionName == currentSession)
        .toList(growable: false);

    final currentWindow = _tmuxCurrentWindow;
    if (currentWindow != null) {
      candidates = candidates
          .where((client) => client.windowIndex == currentWindow)
          .toList(growable: false);
    }

    if (candidates.length == 1) {
      return candidates.single.tty;
    }

    final sorted = [...candidates]
      ..sort((a, b) => b.activity.compareTo(a.activity));
    if (sorted.isNotEmpty) {
      final latest = sorted.first;
      final latestCount = sorted
          .where((client) => client.activity == latest.activity)
          .length;
      if (latestCount == 1) {
        Loggers.app.info(
          '[TMUX] Resolved ambiguous client by activity: $latest',
        );
        return latest.tty;
      }
    }

    Loggers.app.warning(
      'Ambiguous tmux client for switch: clients=$clients '
      'currentSession=$currentSession currentWindow=$currentWindow',
    );
    return null;
  }

  Future<List<_TmuxClientCandidate>> _listTmuxClients(
    TmuxSession tmuxSession, {
    required String tmuxBin,
    required String? lang,
  }) async {
    final result = await tmuxSession.scanner.runCommandAndCapture(
      TmuxCommandBuilder.listClients(tmuxBin: tmuxBin, lang: lang),
    );
    if (result == null) return const [];

    return result
        .split('\n')
        .map(_TmuxClientCandidate.tryParse)
        .whereType<_TmuxClientCandidate>()
        .toList(growable: false);
  }
}

final class _TmuxClientCandidate {
  final String tty;
  final String sessionName;
  final int? windowIndex;
  final int activity;

  const _TmuxClientCandidate({
    required this.tty,
    required this.sessionName,
    required this.windowIndex,
    required this.activity,
  });

  static _TmuxClientCandidate? tryParse(String line) {
    final parts = line.trim().split('|');
    if (parts.length < 4) return null;

    final tty = parts[0].trim();
    final sessionName = parts[1].trim();
    final windowIndex = int.tryParse(parts[2].trim());
    final activity = int.tryParse(parts[3].trim());
    if (tty.isEmpty || sessionName.isEmpty || activity == null) return null;

    return _TmuxClientCandidate(
      tty: tty,
      sessionName: sessionName,
      windowIndex: windowIndex,
      activity: activity,
    );
  }

  @override
  String toString() =>
      '$tty $sessionName:${windowIndex ?? '?'} activity=$activity';
}

extension on SSHPageState {
  void _disconnectFromNotification() {
    // Mark as disconnected in session manager for immediate UI/notification feedback
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.disconnected);

    // Try to close the running SSH session, if any
    try {
      _session?.close();
    } catch (e, stackTrace) {
      Loggers.app.warning('Error closing SSH session: $e\n$stackTrace');
    }
  }
}
