part of 'page.dart';

extension _VirtKey on SSHPageState {
  void _doVirtualKey(VirtKey item) {
    if (item.func != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyFunc(item.func!);
      return;
    }
    if (item.key != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyInput(item.key!);
    }
    final inputRaw = item.inputRaw;
    if (inputRaw != null) {
      HapticFeedback.mediumImpact();
      _terminal.textInput(inputRaw);
    }
  }

  void _doVirtualKeyInput(TerminalKey key) {
    switch (key) {
      case TerminalKey.control:
        _keyboard.ctrl = !_keyboard.ctrl;
        break;
      case TerminalKey.alt:
        _keyboard.alt = !_keyboard.alt;
        break;
      default:
        _terminal.keyInput(key);
        break;
    }
  }

  Future<void> _doVirtualKeyFunc(VirtualKeyFunc type) async {
    switch (type) {
      case VirtualKeyFunc.toggleIME:
        _termKey.currentState?.toggleFocus();
        break;
      case VirtualKeyFunc.backspace:
        _terminal.keyInput(TerminalKey.backspace);
        break;
      case VirtualKeyFunc.clipboard:
        final selected = terminalSelected;
        if (selected != null) {
          Pfs.copy(selected);
        } else {
          _paste();
        }
        break;
      case VirtualKeyFunc.snippet:
        final snippets = await context.showPickWithTagDialog<Snippet>(
          title: l10n.snippet,
          tags: SnippetProvider.tags,
          itemsBuilder: (e) {
            if (e == TagSwitcher.kDefaultTag) {
              return SnippetProvider.snippets.value;
            }
            return SnippetProvider.snippets.value
                .where((element) => element.tags?.contains(e) ?? false)
                .toList();
          },
          display: (e) => e.name,
        );
        if (snippets == null || snippets.isEmpty) return;

        final snippet = snippets.firstOrNull;
        if (snippet == null) return;
        snippet.runInTerm(_terminal, widget.args.spi);
        break;
      case VirtualKeyFunc.file:
        // get $PWD from SSH session
        _terminal.textInput(_echoPWD);
        _terminal.keyInput(TerminalKey.enter);
        final cmds = _terminal.buffer.lines.toList();
        // wait for the command to finish
        await Future.delayed(const Duration(milliseconds: 777));
        // the line below `echo $PWD` is the current path
        final idx = cmds.lastIndexWhere((e) => e.toString().contains(_echoPWD));
        final initPath = cmds.elementAtOrNull(idx + 1)?.toString();
        if (initPath == null || !initPath.startsWith('/')) {
          context.showRoundDialog(
            title: libL10n.error,
            child: Text('${l10n.remotePath}: $initPath'),
          );
          return;
        }
        final args = SftpPageArgs(spi: widget.args.spi, initPath: initPath);
        SftpPage.route.go(context, args);
        break;
    }
  }

  void _paste() {
    Clipboard.getData(Clipboard.kTextPlain).then((value) {
      final text = value?.text;
      if (text != null) {
        _terminal.textInput(text);
      } else {
        context.showRoundDialog(
          title: libL10n.error,
          child: Text(libL10n.empty),
        );
      }
    });
  }

  String? get terminalSelected {
    final range = _terminalController.selection;
    if (range == null) {
      return null;
    }
    return _terminal.buffer.getText(range);
  }

  void _initVirtKeys() {
    final virtKeys = VirtKeyX.loadFromStore();
    for (int len = 0; len < virtKeys.length; len += 7) {
      if (len + 7 > virtKeys.length) {
        _virtKeysList.add(virtKeys.sublist(len));
      } else {
        _virtKeysList.add(virtKeys.sublist(len, len + 7));
      }
    }
  }

  FutureOr<List<String>?> _onKeyboardInteractive(SSHUserInfoRequest req) {
    return KeybordInteractive.defaultHandle(widget.args.spi, ctx: context);
  }
}
