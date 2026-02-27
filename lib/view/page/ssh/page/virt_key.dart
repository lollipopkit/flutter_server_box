part of 'page.dart';

extension _VirtKey on SSHPageState {
  void _doVirtualKey(VirtKey item, VirtKeyboard virtKeyNotifier) {
    if (item.func != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyFunc(item.func!);
      return;
    }
    if (item.key != null) {
      HapticFeedback.mediumImpact();
      _doVirtualKeyInput(item.key!, virtKeyNotifier);
    }
    final inputRaw = item.inputRaw;
    if (inputRaw != null) {
      HapticFeedback.mediumImpact();
      _terminal.textInput(inputRaw);
    }
  }

  void _doVirtualKeyInput(TerminalKey key, VirtKeyboard virtKeyNotifier) {
    switch (key) {
      case TerminalKey.control:
        virtKeyNotifier.setCtrl(!virtKeyNotifier.ctrl);
        break;
      case TerminalKey.alt:
        virtKeyNotifier.setAlt(!virtKeyNotifier.alt);
        break;
      case TerminalKey.shift:
        virtKeyNotifier.setShift(!virtKeyNotifier.shift);
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
        await _onClipboardAction();
        break;
      case VirtualKeyFunc.snippet:
        final snippetState = ref.read(snippetProvider);
        final snippets = await context.showPickWithTagDialog<Snippet>(
          title: l10n.snippet,
          tags: snippetState.tags.vn,
          itemsBuilder: (e) {
            if (e == TagSwitcher.kDefaultTag) {
              return snippetState.snippets;
            }
            return snippetState.snippets
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
        // get $PWD from SSH session with unique markers
        const marker = 'ServerBoxOutput';
        const markerEnd = 'ServerBoxEnd';
        const pwdCommand = 'echo "$marker:\$PWD:$markerEnd"';
        _terminal.textInput(pwdCommand);
        _terminal.keyInput(TerminalKey.enter);

        // Wait for output with timeout
        String? initPath;
        await Future.delayed(const Duration(milliseconds: 700));
        final startTime = DateTime.now();
        final timeout = const Duration(seconds: 3);

        while (initPath == null) {
          // Check if we've exceeded timeout
          if (DateTime.now().difference(startTime) > timeout) {
            contextSafe?.showRoundDialog(title: libL10n.error, child: Text(libL10n.empty));
            return;
          }

          // Search for marked output in terminal buffer
          final cmds = _terminal.buffer.lines.toList();
          for (final line in cmds.reversed) {
            final lineStr = line.toString();
            if (lineStr.contains(marker) && lineStr.contains(markerEnd)) {
              // Extract path between markers
              final start = lineStr.indexOf(marker) + marker.length + 1; // +1 for ':'
              final end = lineStr.indexOf(markerEnd) - 1; // -1 for ':'
              if (start < end) {
                initPath = lineStr.substring(start, end);
                if (initPath.isEmpty || initPath == '\$PWD') {
                  initPath = null;
                } else {
                  break;
                }
              }
            }
          }

          // Short wait before checking again
          await Future.delayed(const Duration(milliseconds: 100));
        }

        if (!initPath.startsWith('/')) {
          context.showRoundDialog(title: libL10n.error, child: Text('${l10n.remotePath}: $initPath'));
          return;
        }

        final args = SftpPageArgs(spi: widget.args.spi, initPath: initPath);
        SftpPage.route.go(context, args);
        break;
    }
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
}
