part of 'page.dart';

extension _VirtKey on SSHPageState {
  void _reloadVirtKeys() {
    final pagesBefore = _virtKeyPages.length;
    _virtKeyRows = Stores.setting.virtKeyRows.fetch();
    _initVirtKeys();
    _updateVirtKeysHeight();
    // Only when the count changed, which is exactly when the `PageView` is
    // rebuilt from its key and starts at the first page again. Resetting
    // unconditionally moved the dots while the strip stayed where it was — a
    // key turned on or off within the same number of rows left page two
    // showing under a lit first dot.
    if (_virtKeyPages.length != pagesBefore) _virtKeyPage.value = 0;
  }

  /// Runs the walkthrough over the keys, once ever — on the terminal that is
  /// actually on screen.
  ///
  /// Every restored tab lays out, not only the one landed on, so this waits
  /// for its own page to be the visible one. Without that, the walkthrough is
  /// spent on whichever tab the `PageView` happened to build first and the
  /// user sees a flag that has already been set.
  void _startVirtKeyIntroWhenVisible() {
    final visible = widget.args.visibleListenable;
    if (visible == null || visible.value) return _startVirtKeyIntro();
    if (Stores.setting.virtKeyIntroShown.fetch()) return;

    void onVisible() {
      if (!mounted || !visible.value) return;
      visible.removeListener(onVisible);
      _introVisibilityListener = null;
      _startVirtKeyIntro();
    }

    _introVisibilityListener = onVisible;
    visible.addListener(onVisible);
  }

  /// Only where there are keys to walk through: a desktop has none, and a user
  /// who hid the lot has said what they think of them. [_showHelp] is what
  /// covers the terminal itself when this does not run.
  void _startVirtKeyIntro() {
    if (_virtKeysHeight == 0) return;
    if (Stores.setting.virtKeyIntroShown.fetch()) return;
    // Written now rather than at the end: a walkthrough that reappears because
    // the app was killed halfway through is worse than one seen once.
    Stores.setting.virtKeyIntroShown.put(true);
    setIntroStep(0, steps: VirtKeyIntroStep.of(context));
  }

  void _endVirtKeyIntro() {
    if (_introStep == null) return;
    setIntroStep(null);
  }

  /// The keys the step on screen is about, or null while none is.
  VirtKeyGroup? get _introGroup {
    final step = _introStep;
    final steps = _introSteps;
    if (step == null || steps == null || step >= steps.length) return null;
    return steps[step].group;
  }

  /// What a key does, for the ones where the label does not say.
  ///
  /// A dialog rather than a tooltip: this is reached by holding a key on a
  /// phone, where a tooltip appears under the finger that is covering it.
  void _showVirtKeyHelp(VirtKey item) {
    final help = item.help;
    if (help == null) return;
    HapticFeedback.selectionClick();
    context.showRoundDialog(
      title: item.text,
      child: Text(help),
      actions: [Btn.ok(onTap: context.popDialog)],
    );
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
        // The toolbar's picker, not a copy of it. The copy that used to be
        // here returned without a word when there was no server, so the key
        // did nothing at all on a shell on this device — while the button two
        // rows up ran the snippets that name no server perfectly well.
        await _pickSnippet();
        break;
      case VirtualKeyFunc.file:
        // Before anything is typed. This opens the files of the server the
        // shell is on, and this device has its own browser in the files tab —
        // so the key is not offered on a local shell at all (see
        // `_virtKeyWorksHere`) rather than echoing a probe command into the
        // session, polling for three seconds and giving up in silence.
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
        // `ServerFilePage`, not `SftpPage`: it is the one place that decides
        // how a server's files are reached, so this key now works on a server
        // reached through its monitor agent — which has files and no SFTP, and
        // where opening the SFTP page directly could only fail.
        ServerFilePage.route.go(context, args);
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
    // Filtered by what this session can do, not only by what the user hid.
    // Read from the server behind the terminal rather than from a connection
    // that may not be up yet: both questions are settled before the first key
    // is drawn, and a key that appeared once something connected would be a
    // strip rearranging itself under the user's thumb.
    final spi = widget.args.spi;
    final virtKeys = VirtKeyX.loadFromStore()
        .where((key) => !disabled.contains(key.name))
        .where((key) => key.worksOn(spi))
        .toList();
    for (var at = 0; at < virtKeys.length; at += kVirtKeysPerRow) {
      _virtKeysList.add(
        virtKeys.sublist(at, math.min(at + kVirtKeysPerRow, virtKeys.length)),
      );
    }
  }
}
