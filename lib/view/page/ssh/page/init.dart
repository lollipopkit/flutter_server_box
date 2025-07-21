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

    for (final snippet in SnippetProvider.snippets.value) {
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
    _discontinuityTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      var throwTimeout = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (throwTimeout) {
          _catchTimeout();
        }
      });
      await _client?.ping();
      throwTimeout = false;
    });
  }

  void _catchTimeout() {
    _discontinuityTimer?.cancel();
    if (!mounted) return;
    _writeLn('\n\nConnection lost\r\n');
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text('${l10n.disconnected}\n${l10n.goBackQ}'),
      barrierDismiss: false,
      actions: Btn.ok(
        onTap: () {
          contextSafe?.pop(); // Can't use tear-drop here
          contextSafe?.pop(); // Pop the SSHPage
        },
      ).toList,
    );
  }

  void _writeLn(String p0) {
    _terminal.write('$p0\r\n');
  }
}
