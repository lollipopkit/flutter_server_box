part of 'page.dart';

extension _Init on SSHPageState {
  void _logTmuxInfo(String message) {
    Loggers.app.info('[TMUX] $message');
  }

  /// Whether tmux can be driven here. See [ShellBackend.supportsTmux].
  ///
  /// Asked before anything tmux is attempted rather than discovered by the
  /// control session throwing: a decision belongs where it can be read, and
  /// what used to happen instead was a null client, an exception, and a
  /// warning in the log that said tmux was unavailable without saying why.
  bool get _canTmux => _sess.backend?.supportsTmux ?? false;

  /// Connects a new source of shells. The provider's grant is a fallback hint;
  /// [TerminalSession.connect] asks the agent directly before opening a PTY.
  Future<ShellBackend> _connectBackend() => _sess.connect(
    granted: switch (widget.args.spi) {
      final spi? => ref.readPresentServer(spi.id)?.remoteAccess,
      null => null,
    },
    context: mounted ? context : null,
  );

  Map<String, String>? get _sshEnvironment => _sess.environment;

  void _bindForegroundSession(ShellSession session) {
    _sess.bindForeground(session);
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
  }

  void _onForegroundSessionDone(ShellSession session) {
    // A transport that closed under the session is a connection loss, not the
    // end of one — route it to the reconnect path rather than tearing the tab
    // down. Normal session end (shell exit) and user-initiated disconnect
    // leave the transport open, so they still take the path below.
    //
    // This used to require a tmux session, back when reconnecting only knew
    // how to re-attach one. It no longer does: a raw shell reconnects to a
    // fresh shell, which is the ordinary case for a link that dropped while
    // the app was in someone's pocket.
    final transportClosed = _backend != null && _backend!.isClosed;
    if (mounted && transportClosed) {
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
    if (!_canTmux || !plan.shouldLaunchTmux) return false;

    final oldSession = _session;
    TmuxControlShellSession? session;
    try {
      session = await _openTmuxControlSession(plan.command!);
    } catch (e, st) {
      Loggers.app.warning(
        'Failed to replace foreground session with tmux',
        e,
        st,
      );
      return false;
    }

    if (session == null) {
      Loggers.app.warning('Failed to replace foreground session with tmux');
      return false;
    }
    // Something else took the terminal while this was opening — a reconnect,
    // or the page going away. It is not this client's to replace.
    if (!mounted || !identical(_session, oldSession)) {
      _discardTmuxControlSession(session);
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
    _focusTerminal(keyboard: false);
    return true;
  }

  /// Returns to a raw shell after the attached tmux session exits cleanly.
  ///
  /// Closing the last window of a session destroys that session and this CC
  /// client. The terminal itself should stay alive so the user can keep working
  /// and use the tmux key again to attach to another session.
  Future<void> _fallbackToRawShellAfterTmuxExit() async {
    if (!mounted) return;

    final oldSession = _session;
    _clearTmuxState();

    // Unbind before the old channel reports done, or the page would treat
    // tmux's exit as the terminal ending and close the tab.
    _sess.unbindForeground();
    try {
      oldSession?.close();
    } catch (e, st) {
      Loggers.app.warning('Failed to close ended tmux session', e, st);
    }

    ShellSession? shell;
    try {
      shell = await _sess.openShell();
    } catch (e, st) {
      Loggers.app.warning(
        'Failed to fall back to raw shell after tmux exit',
        e,
        st,
      );
    }
    if (!mounted) {
      shell?.close();
      return;
    }

    // The user may have attached another tmux session while this raw shell was
    // opening. The foreground identity is the arbiter: never replace whatever
    // now owns the terminal with the stale fallback shell. An attach that is
    // still initializing has not claimed the foreground yet, so a successful
    // attach will safely replace this temporary raw shell.
    if (_session != null) {
      shell?.close();
      return;
    }
    if (shell == null) {
      _setConnectionStep(TerminalConnectionStep.shellFailed);
      TermSessionManager.updateStatus(
        _sessionId,
        TermSessionStatus.disconnected,
      );
      return;
    }

    _bindForegroundSession(shell);
    _focusTerminal(keyboard: false);
  }

  /// Starts the foreground `tmux -CC` client and initializes its first state.
  ///
  /// The underlying SSH session must have a PTY: without one tmux exits before
  /// speaking control mode. `_sess.execute` is the path that allocates one.
  Future<TmuxControlShellSession?> _openTmuxControlSession(
    String command,
  ) async {
    final sshSession = await _sess.execute(command);
    if (sshSession == null) return null;

    final client = TmuxControlClient(
      sshSession,
      maxScrollbackLines: _terminal.maxLines,
    );
    client.onCommandError = (failedCommand, error) {
      Loggers.app.warning('tmux control command failed: $failedCommand', error);
    };
    client.onStateError = (error) {
      Loggers.app.warning('tmux control state refresh failed', error);
    };
    final session = TmuxControlShellSession(client, sshSession);
    client.onClosed = (cleanExit) {
      // A dropped transport is reconnect's decision to make. tmux exiting is
      // not: the session is gone or deliberately detached, so restoration and
      // the native bar must not keep pointing at that client.
      //
      // Only while this client owns the terminal. One that exits during
      // [initialize] has not been bound yet, and falling back then would close
      // whatever shell is still in front.
      if (mounted &&
          cleanExit &&
          identical(_tmuxControl, client) &&
          identical(_session, session)) {
        unawaited(_fallbackToRawShellAfterTmuxExit());
      }
    };
    _attachTmuxControl(client);
    try {
      await client.initialize(captureActivePane: false);
      // An existing session can already have a larger desktop client attached.
      // Size this CC client's active window before capture, so 129-column pane
      // rows are not replayed into a 44-column phone screen.
      session.resizeTerminal(_terminal.viewWidth, _terminal.viewHeight);
      await client.refreshState(captureActivePane: true);
    } catch (_) {
      _discardTmuxControlSession(session);
      rethrow;
    }
    return session;
  }

  /// Closes a tmux client that will not be the foreground, and lets go of it
  /// only if the page still points at it — a newer client may have replaced it.
  void _discardTmuxControlSession(TmuxControlShellSession session) {
    if (identical(_tmuxControl, session.client)) _detachTmuxControl();
    session.close();
  }

  void _attachTmuxControl(TmuxControlClient client) {
    _tmuxPageController.attach(client);
  }

  void _detachTmuxControl() {
    _tmuxPageController.detach();
  }

  Future<void> _selectTmuxWindow(TmuxWindowId windowId) async {
    final control = _tmuxControl;
    if (control == null) return;
    try {
      await control.selectWindow(windowId);
    } catch (e, st) {
      Loggers.app.warning('Failed to select tmux window', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<void> _selectTmuxPane(TmuxPaneId paneId) async {
    final control = _tmuxControl;
    if (control == null) return;
    try {
      await control.selectPane(paneId);
    } catch (e, st) {
      Loggers.app.warning('Failed to select tmux pane', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<void> _closeTmuxPane(TmuxPaneId paneId) async {
    final control = _tmuxControl;
    if (control == null) return;
    try {
      await control.closePane(paneId);
    } catch (e, st) {
      Loggers.app.warning('Failed to close tmux pane', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<void> _createTmuxWindow() async {
    final control = _tmuxControl;
    if (control == null) return;
    try {
      await control.newWindow();
    } catch (e, st) {
      Loggers.app.warning('Failed to create tmux window', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<void> _closeTmuxWindow(TmuxWindowId windowId) async {
    final control = _tmuxControl;
    if (control == null) return;
    try {
      await control.closeWindow(windowId);
    } catch (e, st) {
      Loggers.app.warning('Failed to close tmux window', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<ShellSession?> _openForegroundSession() async {
    final plan = await _resolveForegroundLaunchPlan();

    if (plan.shouldLaunchTmux) {
      ShellSession? session;
      try {
        session = await _openTmuxControlSession(plan.command!);
      } catch (e, st) {
        Loggers.app.warning('Failed to open foreground tmux session', e, st);
        _clearTmuxState();
        rethrow;
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
    _terminalStyle = TerminalLook.styleOf(context);
  }

  Future<void> _showHelp() async {
    if (Stores.setting.sshTermHelpShown.fetch()) return;
    // Where there are virtual keys, the walkthrough says all of this and says
    // it beside the keys it is naming. This paragraph is what a desktop gets
    // instead, having no such row to point at.
    if (_virtKeysHeight > 0 && !Stores.setting.virtKeyIntroShown.fetch()) {
      Stores.setting.sshTermHelpShown.put(true);
      return;
    }

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
    if (_openingTerminal) return;
    // A session handed to this page is already connected and already running
    // something — the dialog that started it did all of this. Opening a second
    // shell here would replace what the user asked to carry on watching.
    if (_adopted) {
      // It may also have finished on the way here, in which case this tab is
      // the output and nothing more — said plainly rather than left looking
      // like a shell that stopped answering.
      TermSessionManager.updateStatus(
        _sessionId,
        _session != null
            ? TermSessionStatus.connected
            : TermSessionStatus.disconnected,
      );
      _focusTerminal(keyboard: false);
      return;
    }

    _openingTerminal = true;
    _retryInitialConnectionOnResume = false;
    _setConnectionStep(TerminalConnectionStep.connecting);
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connecting);
    try {
      // Startup may precede the network. Permission and auth failures are not
      // retried; only transport failures use these short backoffs.
      const retryDelays = [
        Duration.zero,
        Duration(milliseconds: 500),
        Duration(seconds: 2),
      ];
      for (final delay in retryDelays) {
        if (delay != Duration.zero) {
          await Future.delayed(delay);
          if (!mounted) return;
          _setConnectionStep(TerminalConnectionStep.connecting);
        }

        try {
          if (_backend?.isClosed == true) _sess.resetAfterFailedOpen();
          if (_backend == null) await _connectBackend();
          if (!mounted) {
            _sess.close();
            return;
          }

          _setConnectionStep(TerminalConnectionStep.openingShell);
          final session = await _openForegroundSession();
          if (!mounted) {
            session?.close();
            _sess.close();
            return;
          }
          if (session == null) {
            _sess.resetAfterFailedOpen();
            _setConnectionStep(TerminalConnectionStep.shellFailed);
            TermSessionManager.updateStatus(
              _sessionId,
              TermSessionStatus.disconnected,
            );
            return;
          }

          _bindForegroundSession(session);
          _setConnectionStep(TerminalConnectionStep.ready);
          break;
        } catch (error, stackTrace) {
          Loggers.app.warning('Failed to open terminal', error, stackTrace);
          _sess.resetAfterFailedOpen();
          final retryable = isRetryableTerminalConnectionError(error);
          if (delay != retryDelays.last && retryable) {
            continue;
          }
          _retryInitialConnectionOnResume = retryable;
          _setConnectionStep(
            _connectionStep == TerminalConnectionStep.openingShell
                ? TerminalConnectionStep.shellFailed
                : TerminalConnectionStep.connectionFailed,
            detail: switch (error) {
              TerminalRemoteAccessUnavailable() => l10n.monitorNoRemoteAccess,
              TerminalConsoleErr(:final message) => message,
              LocalServerErr() => error.solution,
              _ => null,
            },
          );
          TermSessionManager.updateStatus(
            _sessionId,
            TermSessionStatus.disconnected,
          );
          return;
        }
      }
    } finally {
      _openingTerminal = false;
    }

    // Not awaited: a snippet can `${sleep N}`, and the page must not wait for
    // it before taking keyboard input.
    if (_tmuxCurrentSession == null) unawaited(_runStartupInput());

    _focusTerminal(keyboard: false);
  }

  /// Auto-run snippets, then `initCmd`, then `initSnippet`, one after another:
  /// a snippet with placeholders types across awaits, so running them
  /// concurrently would interleave their input.
  ///
  /// All of it is for the shell that was in front when startup began. A
  /// snippet can wait (`${sleep N}`) through a reconnect or a switch to tmux,
  /// and what is left must not be typed into the shell that replaced it.
  Future<void> _runStartupInput() async {
    final shell = _session;
    bool current() =>
        mounted &&
        shell != null &&
        identical(_session, shell) &&
        _tmuxCurrentSession == null;

    // Snippets name the server they run on, and their scripts are written
    // against one. A terminal on this device has neither.
    final spi = widget.args.spi;
    final snippets = ref.read(snippetProvider.select((p) => p.snippets));
    if (spi != null) {
      for (final snippet in snippets) {
        if (snippet.autoRunOn?.contains(spi.id) == true) {
          if (!current()) return;
          await _runStartupSnippet(snippet, spi, current);
        }
      }
    }

    if (!current()) return;
    final initCmd = widget.args.initCmd;
    if (initCmd != null) {
      _terminal.textInput(initCmd);
      _terminal.keyInput(TerminalKey.enter);
      await _answerSudo();
    }

    final initSnippet = widget.args.initSnippet;
    if (initSnippet != null && (spi != null || !initSnippet.needsServer)) {
      if (!current()) return;
      await _runStartupSnippet(initSnippet, spi, current);
    }
  }

  Future<void> _runStartupSnippet(
    Snippet snippet,
    Spi? spi,
    bool Function() current,
  ) async {
    try {
      await snippet.runInTerm(_terminal, spi, alive: current);
    } catch (e, s) {
      if (!mounted) return;
      context.showErrDialog(e, s, '${libL10n.snippet}: ${snippet.name}');
    }
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

  /// Asks the far side whether it is still there.
  ///
  /// [immediate] means "answer now" — a resume, or the page becoming visible —
  /// rather than waiting for the timer's turn.
  ///
  /// It used to also mean "one missed reply is the verdict", which is the worst
  /// rule at the worst moment. A resume is when the radio is coldest, and
  /// `home.dart` starts a refresh of every configured server on the same frame;
  /// an SSH handshake is pure Dart on this isolate, so each server that cannot
  /// be reached costs a connect timeout of this isolate's attention. A few of
  /// those in the list were enough to push one ping past its ten seconds and
  /// close a session that was fine — which is how "I have servers that don't
  /// connect" turned into "switching apps drops my shell" (#1287).
  ///
  /// It now asks as many times as the timer would before concluding anything.
  /// It just does not wait a minute between the tries.
  Future<void> _checkConnectionHealth({bool immediate = false}) async {
    if (!mounted || _backend == null) return;
    if (_isCheckingConnection) {
      if (immediate) _hasPendingImmediateCheck = true;
      return;
    }
    _isCheckingConnection = true;

    try {
      final attempts = immediate ? SSHPageState._maxKeepAliveFailures : 1;
      Object? lastError;
      StackTrace? lastStackTrace;
      for (var attempt = 0; attempt < attempts; attempt++) {
        if (attempt > 0) {
          // Only ever paid by a link that is slow. One that is gone says so at
          // once, and the check below leaves the loop without waiting.
          await Future.delayed(SSHPageState._connectionCheckRetryDelay);
          if (!mounted || _backend == null) return;
        }
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
          return;
        } on Object catch (error, stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          // The transport itself says it is gone. Nothing to wait for.
          if (_backend?.isClosed ?? true) break;
        }
      }
      _handleConnectionCheckFailure(
        lastError ?? StateError('SSH keep-alive did not run'),
        stackTrace: lastStackTrace,
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

    // Always, not only when there is a tmux session to re-attach. Reconnecting
    // was gated on that because tmux is what makes a shell's *state* survive,
    // but a link that dropped while the app was in someone's pocket is the
    // ordinary case and it has no tmux — and being asked "go back?" is not an
    // answer to it. A fresh shell on the same server is; the reconnect path
    // already opened one as its own fallback for a tmux session that had gone.
    final restored = await _tryReconnect(tmuxSession: _tmuxCurrentSession);
    if (!mounted) return;
    if (restored) {
      _disconnectDialogOpen = false;
      _reportedDisconnected = false;
      return;
    }

    // Reconnect failed or was cancelled -> ask whether to leave.
    unawaited(_showDisconnectDialog());
  }

  /// Re-establish SSH, re-attaching [tmuxSession] when there is one, and
  /// showing a cancellable progress dialog while it runs.
  ///
  /// Returns `true` when the terminal was restored.
  Future<bool> _tryReconnect({String? tmuxSession}) async {
    _reconnectCancelled = false;
    if (mounted) _showReconnectingDialog();
    try {
      return await _reconnect(tmuxSession: tmuxSession);
    } catch (e, st) {
      Loggers.app.warning('SSH reconnect threw', e, st);
      _closeFailedReconnectClient();
      return false;
    } finally {
      // Not gated on `mounted`, which is what this used to be. The dialog is
      // on the root navigator and outlives the page that raised it, so a page
      // torn down mid-reconnect — its tab closed, the app moved on — left it
      // spinning over every tab with nothing able to close it: this pop was
      // skipped, and the cancel button did not close it either.
      //
      // Before returning, so the caller's next dialog goes up over an empty
      // navigator rather than over this one. See [_dismissReconnectingDialog].
      _dismissReconnectingDialog();
    }
  }

  /// Cancellable progress dialog shown while reconnecting.
  void _showReconnectingDialog() {
    // Captured now, while there is certainly a context to ask — see the field.
    _reconnectDialogNav = Navigator.of(context, rootNavigator: true);
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
            Expanded(child: Text(libL10n.reconnecting)),
            // Closes the dialog itself. An `onTap` replaces the pop `Btn`
            // would otherwise do from its own context, so a callback that only
            // set the flag left the button doing nothing anyone could see: the
            // loop reads the flag between attempts, and an attempt is a whole
            // SSH connect timeout long.
            Btn.cancel(
              onTap: () {
                _reconnectCancelled = true;
                _dismissReconnectingDialog();
              },
            ),
          ],
        ),
        barrierDismiss: false,
      ),
    );
  }

  /// Closes the reconnecting dialog, once. Safe when it is already gone.
  ///
  /// Now, not next frame. A pop takes whatever is on top of the root
  /// navigator, and the caller that closes this dialog is usually about to put
  /// another one up — [_onConnectionLossSuspected] asks "go back?" the moment
  /// the reconnect it was waiting on gives up. Scheduled, this pop landed
  /// after that question was already on screen and closed *it*: the spinner
  /// stayed, and the dialog meant to replace it was gone in a frame.
  ///
  /// [deferred] is for [dispose] alone, which runs inside the frame that is
  /// unmounting this page — popping a route from there is a `markNeedsBuild`
  /// during build. Nothing follows it, so nothing can be popped by mistake.
  void _dismissReconnectingDialog({bool deferred = false}) {
    final nav = _reconnectDialogNav;
    if (nav == null) return;
    _reconnectDialogNav = null;
    if (!deferred) {
      if (nav.mounted) nav.pop();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (nav.mounted) nav.pop();
    });
  }

  Future<void> _showDisconnectDialog() async {
    final shouldLeave = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('${libL10n.disconnected}\n${libL10n.goBackQ}'),
      barrierDismiss: false,
      actions: [
        TextButton(
          onPressed: () => context.popDialog(false),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => context.popDialog(true),
          child: Text(libL10n.ok),
        ),
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

  /// Reconnect SSH after a connection loss, re-attaching [tmuxSession] when
  /// there is one to re-attach.
  ///
  /// Returns `true` when a usable terminal was restored (either the tmux
  /// session was re-attached or, as a fallback, a raw shell was opened). Returns
  /// `false` only when the SSH transport itself could not be re-established, in
  /// which case the caller falls back to the disconnect prompt.
  Future<bool> _reconnect({String? tmuxSession}) async {
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

    if (tmuxSession != null && tmuxSession.isNotEmpty) {
      if (await _reattachTmux(sessionName: tmuxSession)) {
        if (!mounted || _reconnectCancelled) {
          _closeFailedReconnectClient();
          return false;
        }
        _setupDiscontinuityTimer();
        _focusTerminal(keyboard: false);
        return true;
      }
      if (!mounted || _reconnectCancelled) {
        _closeFailedReconnectClient();
        return false;
      }

      // tmux wasn't restorable (unavailable or session gone) — fall back to a
      // raw shell so the terminal remains usable instead of being left blank.
      _logTmuxInfo(
        'Previous tmux session "$tmuxSession" no longer available, '
        'falling back to a raw shell',
      );
      _clearTmuxState();
    }

    final shell = await _sess.openShell();
    if (shell == null || !mounted || _reconnectCancelled) {
      if (mounted) _writeLn(libL10n.fail);
      _closeFailedReconnectClient();
      return false;
    }
    _bindForegroundSession(shell);
    // A new shell is not the program the old one was running: what the
    // session is for is started again in it.
    if (_sess.reenter case final cmd?) {
      _terminal.textInput(cmd);
      _terminal.keyInput(TerminalKey.enter);
      unawaited(_answerSudo());
    }
    _setupDiscontinuityTimer();
    _focusTerminal(keyboard: false);
    return true;
  }

  /// Re-attach the previous tmux [sessionName] (+ window) after reconnecting.
  ///
  /// Verifies via a control channel that tmux is available and that the session
  /// still exists, then launches the attach command as the foreground session.
  Future<bool> _reattachTmux({required String sessionName}) async {
    final control = await _createTmuxDiscoverySession();
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
      TmuxSessionInfo? restoredSession;
      for (final session in sessions) {
        if (session.name == sessionName) {
          restoredSession = session;
          break;
        }
      }
      if (restoredSession == null) return false;

      final restoredWindowIndex = _tmuxCurrentWindow;
      final windows = restoredWindowIndex == null
          ? const <TmuxWindowInfo>[]
          : await control.tryListWindows(restoredSession.id.value) ??
                const <TmuxWindowInfo>[];
      final windowIndex = validateRestoredWindowIndex(
        restoredWindowIndex,
        windows,
      );
      final command = windowIndex != null
          ? TmuxCommandBuilder.attachSessionWindow(
              restoredSession.id.value,
              windowIndex,
              tmuxBin: tmuxBin,
            )
          : TmuxCommandBuilder.attachSession(
              restoredSession.id.value,
              tmuxBin: tmuxBin,
            );

      final session = await _openTmuxControlSession(command);
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
    _tmuxPageController.clear();
    widget.args.onTmuxStateChanged?.call();
  }

  void _closeFailedReconnectClient() => _sess.closeBackend();

  void _writeLn(String p0) => _sess.writeLn(p0);

  TmuxRestoreState get _restoreTmuxState {
    return resolveTmuxRestoreState(
      argsSession: widget.args.tmuxSession,
      argsWindow: widget.args.tmuxWindow,
      restorableSession: _tmuxPageController.restorableSessionName,
      restorableWindow: _tmuxPageController.restorableWindowIndex,
    );
  }

  void _saveTmuxState({required String sessionName, int? windowIndex}) {
    _tmuxPageController.saveState(
      sessionName: sessionName,
      windowIndex: windowIndex,
    );
    widget.args.onTmuxStateChanged?.call();
  }

  /// Only where [_canTmux] says so — every caller checks, and the null
  /// assertions below are what that check is protecting.
  Future<TmuxSession> _createTmuxDiscoverySession() async {
    final client = _client;
    return TmuxSession(
      PersistentShell(
        client,
        sessionFactory: () async {
          // An SSH exec channel carries the protocol as is; anything else is a
          // pseudo-terminal, which has to be quietened first.
          if (client != null) {
            final sh = await client.execute('sh', environment: _sshEnvironment);
            return SshPersistentShellSession(sh);
          }
          return PtyPersistentShellSession.open(
            (command) async => (await _sess.execute(command))!,
          );
        },
      ),
    );
  }

  Future<TmuxLaunchPlan> _resolveForegroundLaunchPlan() async {
    if (!Stores.setting.tmuxAuto.fetch() || !_canTmux) {
      return const TmuxLaunchPlan.none();
    }
    // A page opened to run something — a container's shell, a VM's serial
    // console, a command from the file browser — runs it in a plain shell.
    // [_initTerminal] types [SshPageArgs.initCmd] only when no tmux session
    // was attached, so with tmux on it was silently never run.
    if (widget.args.initCmd != null || widget.args.initSnippet != null) {
      return const TmuxLaunchPlan.none();
    }

    final TmuxSession tmuxSession;
    try {
      tmuxSession = await _createTmuxDiscoverySession().timeout(
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
      final sessions = await _loadTmuxSessions(tmuxSession);

      final restoredPlan = await _buildRestoredForegroundLaunchPlan(
        tmuxSession,
        sessions,
        tmuxBin: tmuxBin,
      );
      if (restoredPlan.shouldLaunchTmux) return restoredPlan;

      final plan = await _buildInitialForegroundLaunchPlan(
        sessions: sessions,
        tmuxBin: tmuxBin,
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
  }) async {
    final restoredState = _restoreTmuxState;
    if (!restoredState.hasSession) return const TmuxLaunchPlan.none();

    TmuxSessionInfo? restoredSession;
    for (final session in sessions) {
      if (session.name == restoredState.sessionName) {
        restoredSession = session;
        break;
      }
    }
    if (restoredSession == null) return const TmuxLaunchPlan.none();

    final windows = restoredState.windowIndex == null
        ? const <TmuxWindowInfo>[]
        : await tmuxSession.tryListWindows(restoredSession.id.value) ??
              const <TmuxWindowInfo>[];

    final restoredPlan = buildRestoredTmuxLaunchPlan(
      restoredState,
      sessions,
      windows: windows,
      tmuxBin: tmuxBin,
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

  Future<TmuxLaunchPlan> _buildInitialForegroundLaunchPlan({
    required List<TmuxSessionInfo> sessions,
    required String tmuxBin,
  }) async {
    final showSelector = Stores.setting.tmuxShowSelector.fetch();
    final defaultName = Stores.setting.tmuxSessionName.fetch();
    final sessionName = defaultName.isEmpty ? 'server_box' : defaultName;

    if (!showSelector) {
      return buildAutoTmuxLaunchPlan(
        sessions,
        defaultSessionName: sessionName,
        tmuxBin: tmuxBin,
      );
    }
    if (!mounted) return const TmuxLaunchPlan.none();

    final picked = await showTmuxSessionPickerSheet(
      context,
      sessions: [
        for (final session in sessions)
          TmuxPickerSession.fromDiscovery(session),
      ],
      defaultSessionName: sessionName,
      showSkip: true,
    );
    final choice = switch (picked) {
      TmuxPickExisting(:final sessionId, :final sessionName) =>
        TmuxAttachExisting(sessionName: sessionName, sessionId: sessionId),
      TmuxPickNew(:final sessionName) => TmuxAttachNew(
        sessionName: sessionName,
      ),
      TmuxPickSkip() || TmuxPickDetach() || null => null,
    };

    if (choice == null) {
      return const TmuxLaunchPlan.none();
    }

    return buildChosenTmuxLaunchPlan(choice, tmuxBin: tmuxBin);
  }

  Future<void> _showTmuxControlSessionSwitcher(
    TmuxControlClient control,
  ) async {
    try {
      await control.refreshState();
    } catch (e, st) {
      Loggers.app.warning('Failed to refresh tmux control state', e, st);
      if (mounted) Toast.show(context.l10n.tmuxNotAvailable);
      return;
    }
    if (!mounted) return;

    final snapshot = control.snapshot;
    final defaultName = Stores.setting.tmuxSessionName.fetch();
    final picked = await showTmuxSessionPickerSheet(
      context,
      sessions: [
        for (final session
            in snapshot?.sessions ?? const <TmuxControlSessionSummary>[])
          TmuxPickerSession.fromControl(session),
      ],
      defaultSessionName: defaultName.isEmpty ? 'server_box' : defaultName,
      selectedSessionId: snapshot?.session.id,
      showDetach: true,
    );
    if (picked == null || !mounted) return;

    try {
      switch (picked) {
        case TmuxPickExisting(:final sessionId):
          await control.switchSession(sessionId);
        case TmuxPickNew(:final sessionName):
          await control.createSession(sessionName);
        case TmuxPickDetach():
          await control.detach();
          return;
        case TmuxPickSkip():
          return;
      }
      _focusTerminal(keyboard: false);
    } catch (e, st) {
      Loggers.app.warning('Failed to switch tmux session', e, st);
      if (mounted) Toast.error(libL10n.fail);
    }
  }

  Future<void> _showTmuxSwitcher() async {
    // The first open may be attaching tmux itself; see [_switchingTmux].
    if (!_canTmux || !mounted || _openingTerminal || _switchingTmux) return;
    _switchingTmux = true;
    try {
      await _runTmuxSwitcher();
    } finally {
      _switchingTmux = false;
    }
  }

  Future<void> _runTmuxSwitcher() async {
    final control = _tmuxControl;
    if (control != null) {
      await _showTmuxControlSessionSwitcher(control);
      return;
    }

    final tmuxSession = await _createTmuxDiscoverySession();
    try {
      final available = await tmuxSession.isAvailable;
      if (!available || !mounted) {
        if (mounted) Toast.show(context.l10n.tmuxNotAvailable);
        return;
      }
      final tmuxBin = tmuxSession.scanner.tmuxBin ?? 'tmux';

      final sessions = await tmuxSession.sessions;
      if (!mounted) return;

      final defaultName = Stores.setting.tmuxSessionName.fetch();
      final sessionName = defaultName.isEmpty ? 'server_box' : defaultName;

      final picked = await showTmuxSessionPickerSheet(
        context,
        sessions: [
          for (final session in sessions)
            TmuxPickerSession.fromDiscovery(session),
        ],
        defaultSessionName: sessionName,
        showSkip: true,
      );
      final choice = switch (picked) {
        TmuxPickExisting(:final sessionId, :final sessionName) =>
          TmuxAttachExisting(sessionName: sessionName, sessionId: sessionId),
        TmuxPickNew(:final sessionName) => TmuxAttachNew(
          sessionName: sessionName,
        ),
        TmuxPickSkip() || TmuxPickDetach() || null => null,
      };

      if (choice == null) return;

      final plan = buildChosenTmuxLaunchPlan(choice, tmuxBin: tmuxBin);
      await _replaceForegroundWithLaunchPlan(plan);
    } finally {
      await tmuxSession.dispose();
    }
  }
}

extension on SSHPageState {
  void _disconnectFromNotification() {
    // Update observers before closing the channel so the UI and notification
    // respond immediately.
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.disconnected);

    try {
      _session?.close();
    } catch (e, stackTrace) {
      Loggers.app.warning('Error closing SSH session: $e\n$stackTrace');
    }
  }
}
