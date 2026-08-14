part of 'page.dart';

extension _VirtKey on SSHPageState {
  void _reloadVirtKeys() {
    _horizonVirtKeys = Stores.setting.horizonVirtKey.fetch();
    _initVirtKeys();
    _updateVirtKeysHeight();
  }

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
        // Before the picker, not after it: a snippet's script is written
        // against a server, and browsing tags to choose one that is then
        // silently dropped is worse than the button doing nothing.
        final snippetSpi = widget.args.spi;
        if (snippetSpi == null) return;
        final snippetState = ref.read(snippetProvider);
        final snippets = await context.showPickWithTagDialog<Snippet>(
          title: libL10n.snippet,
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
        snippet.runInTerm(_terminal, snippetSpi);
        break;
      case VirtualKeyFunc.file:
        // Before anything is typed. SFTP is a file browser on a server and
        // this device already has one, so on a local shell there is nothing to
        // open — and asking afterwards meant echoing a probe command into the
        // user's session, polling for three seconds, and then giving up in
        // silence.
        final fileSpi = widget.args.spi;
        if (fileSpi == null) return;
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
            contextSafe?.showRoundDialog(
              title: libL10n.error,
              child: Text(libL10n.empty),
            );
            return;
          }

          // Search for marked output in terminal buffer
          final cmds = _terminal.buffer.lines.toList();
          for (final line in cmds.reversed) {
            final lineStr = line.toString();
            if (lineStr.contains(marker) && lineStr.contains(markerEnd)) {
              // Extract path between markers
              final start =
                  lineStr.indexOf(marker) + marker.length + 1; // +1 for ':'
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
          context.showRoundDialog(
            title: libL10n.error,
            child: Text('${l10n.remotePath}: $initPath'),
          );
          return;
        }

        final args = SftpPageArgs(spi: fileSpi, initPath: initPath);
        SftpPage.route.go(context, args);
        break;
      case VirtualKeyFunc.sudoPassword:
        await _insertSudoPassword();
        break;
      case VirtualKeyFunc.tmuxSwitch:
        await _showTmuxSwitcher();
        break;
    }
  }

  void _initVirtKeys() {
    _virtKeysList.clear();
    final disabled = Stores.setting.sshVirtKeysDisabled.fetch().toSet();
    final virtKeys = VirtKeyX.loadFromStore()
        .where((key) => !disabled.contains(key.index))
        .toList();
    for (int len = 0; len < virtKeys.length; len += 7) {
      if (len + 7 > virtKeys.length) {
        _virtKeysList.add(virtKeys.sublist(len));
      } else {
        _virtKeysList.add(virtKeys.sublist(len, len + 7));
      }
    }
  }
}
