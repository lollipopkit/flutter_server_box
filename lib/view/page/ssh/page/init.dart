part of 'page.dart';

extension _Init on SSHPageState {
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
            context.pop();
          },
          child: Text(l10n.noPromptAgain),
        ),
      ],
    );
  }

  Future<void> _initTerminal() async {
    _writeLn(l10n.waitConnection);
    _client ??= await genClient(
      widget.args.spi,
      onStatus: (p0) {
        _writeLn(p0.toString());
      },
      onKeyboardInteractive: (_) => KeybordInteractive.defaultHandle(widget.args.spi, ctx: context),
    );

    _writeLn('${libL10n.execute}: Shell');
    final session = await _client?.shell(
      pty: SSHPtyConfig(width: _terminal.viewWidth, height: _terminal.viewHeight),
      environment: widget.args.spi.envs,
    );

    if (session == null) {
      _writeLn(libL10n.fail);
      return;
    }

    _terminal.buffer.clear();
    _terminal.buffer.setCursor(0, 0);

    _terminal.onOutput = (data) {
      session.write(utf8.encode(data));
    };
    _terminal.onResize = (width, height, pixelWidth, pixelHeight) {
      session.resizeTerminal(width, height);
    };

    _listen(session.stdout);
    _listen(session.stderr);

    // Hold the session for external control (disconnect)
    _session = session;
    // Mark status connected for notifications / live activities
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);

    final snippets = ref.read(snippetProvider.select((p) => p.snippets));
    for (final snippet in snippets) {
      if (snippet.autoRunOn?.contains(widget.args.spi.id) == true) {
        snippet.runInTerm(_terminal, widget.args.spi);
      }
    }

    final initCmd = widget.args.initCmd;
    if (initCmd != null) {
      _terminal.textInput(initCmd);
      _terminal.keyInput(TerminalKey.enter);
    }

    final initSnippet = widget.args.initSnippet;
    if (initSnippet != null) {
      initSnippet.runInTerm(_terminal, widget.args.spi);
    }

    widget.args.focusNode?.requestFocus();

    await session.done;
    if (mounted && widget.args.notFromTab) {
      context.pop();
    }
    widget.args.onSessionEnd?.call();
    TermSessionManager.remove(_sessionId);
  }

  void _listen(Stream<Uint8List>? stream) {
    if (stream == null) {
      return;
    }

    stream
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(
          _terminal.write,
          onError: (Object error, StackTrace stack) {
            // _terminal.write('Stream error: $error\n');
            Loggers.root.warning('Error in SSH stream', error, stack);
          },
          cancelOnError: false,
        );
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

  Future<void> _checkConnectionHealth() async {
    if (!mounted || _client == null || _isCheckingConnection) return;
    _isCheckingConnection = true;

    try {
      await _client!.ping().timeout(SSHPageState._connectionCheckTimeout);
      _missedKeepAliveCount = 0;
      if (_reportedDisconnected) {
        _reportedDisconnected = false;
        TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
      }
    } on TimeoutException catch (error) {
      _handleConnectionCheckFailure(error);
    } on Object catch (error, stackTrace) {
      _handleConnectionCheckFailure(error, stackTrace);
    } finally {
      _isCheckingConnection = false;
    }
  }

  void _handleConnectionCheckFailure(Object error, [StackTrace? stackTrace]) {
    Loggers.root.warning('SSH keep-alive failed', error, stackTrace);
    _missedKeepAliveCount += 1;

    if (_missedKeepAliveCount < SSHPageState._maxKeepAliveFailures) {
      return;
    }

    _missedKeepAliveCount = 0;
    _onConnectionLossSuspected();
  }

  void _onConnectionLossSuspected() {
    if (!mounted || _disconnectDialogOpen) return;

    _disconnectDialogOpen = true;
    _reportedDisconnected = true;
    _discontinuityTimer?.cancel();
    _writeLn('\n\nConnection lost\r\n');
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.disconnected);
    unawaited(_showDisconnectDialog());
  }

  Future<void> _showDisconnectDialog() async {
    final shouldLeave = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('${libL10n.disconnected}\n${l10n.goBackQ}'),
      barrierDismiss: false,
      actions: [
        TextButton(onPressed: () => context.pop(false), child: Text(libL10n.cancel)),
        TextButton(onPressed: () => context.pop(true), child: Text(libL10n.ok)),
      ],
    );

    if (!mounted) return;

    _disconnectDialogOpen = false;

    if (shouldLeave == true) {
      contextSafe?.pop(); // Pop the SSHPage
      return;
    }

    _reportedDisconnected = false;
    TermSessionManager.updateStatus(_sessionId, TermSessionStatus.connected);
    _setupDiscontinuityTimer();
  }

  void _writeLn(String p0) {
    _terminal.write('$p0\r\n');
  }
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
