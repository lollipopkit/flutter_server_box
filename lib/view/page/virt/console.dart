part of 'guest.dart';

/// Where a guest's console goes.
///
/// Which consoles there are comes from the guest's detail
/// (`VirtGuestDetail.consoles`); with both, a toggle picks between them. How
/// each is opened is [VirtConsoleConnect].
///
/// - **Text** is the terminal page, in place here: the one terminal the app
///   has, with its virtual keys, theme and reconnect, given a console instead
///   of a shell (PVE), or a shell on the host with `virsh console` typed into
///   it (libvirt). A bar under it says what it is connected through, and that
///   a serial console prints nothing until it is sent something. Leaving it
///   leaves the console running ([VirtTextConsoles]), and coming back takes it
///   up again.
/// - **Graphical** is the remote desktop viewer, in place here. Its toolbar
///   has reconnect, full screen and close; closing brings back "Connect".
///
/// Either one left — this view gone, another guest, another tab — is closed
/// by [SessionKeepAlive] after the idle time the settings give, with a notice
/// first; coming back before then finds it as it was. A guest that stops
/// closes both at once (`_syncDetail` in guest.dart).
class VirtConsoleView extends StatelessWidget {
  const VirtConsoleView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.state,
    required this.detail,
    this.kind,
    this.onStart,
    this.onRetryDetail,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtGuestState state;

  /// The guest's detail, which says which consoles it has.
  final Future<VirtGuestDetail>? detail;

  /// The console asked for — the second level of the guest's Console
  /// segment. Null, or one the guest does not have, is [defaultKind].
  final VirtConsoleKind? kind;

  /// Graphical first where there is one: a VM's screen is what its console
  /// usually means, and its serial port is the fallback.
  static VirtConsoleKind defaultKind(Set<VirtConsoleKind> consoles) =>
      consoles.contains(VirtConsoleKind.vnc)
      ? VirtConsoleKind.vnc
      : VirtConsoleKind.text;

  /// Starts the guest, when that is on offer: a console of a guest that is
  /// off has nothing on it.
  final VoidCallback? onStart;

  /// Fetches [detail] again, after it failed.
  final VoidCallback? onRetryDetail;

  @override
  Widget build(BuildContext context) {
    if (!state.isActive) {
      return EmptyPane(
        icon: Icons.desktop_access_disabled_outlined,
        title: state.label,
        action: onStart == null
            ? null
            : Btn.elevated(
                mainAxisSize: MainAxisSize.min,
                text: libL10n.start,
                icon: const Icon(Icons.play_arrow),
                onTap: onStart,
              ),
      );
    }
    return FutureBuilder<VirtGuestDetail>(
      future: detail,
      builder: (context, snap) {
        if (snap.hasError) {
          final err = snap.error;
          return EmptyPane(
            icon: Icons.error_outline,
            title: err is VirtErr ? err.title : libL10n.fail,
            label: err is VirtErr ? err.detail : '$err',
            action: onRetryDetail == null
                ? null
                : Btn.elevated(
                    mainAxisSize: MainAxisSize.min,
                    text: libL10n.retry,
                    icon: const Icon(Icons.refresh),
                    onTap: onRetryDetail,
                  ),
          );
        }
        final data = snap.data;
        if (data == null) return const Center(child: SizedLoading.medium);
        if (data.consoles.isEmpty) {
          return EmptyPane(
            icon: Icons.desktop_access_disabled_outlined,
            title: l10n.virtConsoleNone,
          );
        }
        return _VirtConsoles(
          // A different guest is a different console: nothing of the last
          // one's state, and its graphical session closed.
          key: ValueKey(guest.id),
          serverId: serverId,
          guest: guest,
          kind: data.consoles.contains(kind)
              ? kind!
              : defaultKind(data.consoles),
        );
      },
    );
  }
}

class _VirtConsoles extends ConsumerStatefulWidget {
  const _VirtConsoles({
    super.key,
    required this.serverId,
    required this.guest,
    required this.kind,
  });

  final String serverId;
  final VirtGuest guest;

  /// The console shown: one the guest has.
  final VirtConsoleKind kind;

  @override
  ConsumerState<_VirtConsoles> createState() => _VirtConsolesState();
}

class _VirtConsolesState extends ConsumerState<_VirtConsoles> {
  VirtConsoleKind get _kind => widget.kind;

  var _opening = false;

  /// What the graphical session was last told about being on screen.
  var _shown = false;

  /// Kept from `initState`: [dispose] reports the session off screen and may
  /// not use `ref`.
  late final RemoteDesktopSessions _sessions;

  late final String _vncId = VirtConsoleConnect.vncSessionId(
    widget.serverId,
    widget.guest.id,
  );

  late final String _textId = VirtConsoleConnect.textSessionId(
    widget.serverId,
    widget.guest.id,
  );

  /// The text console on screen here: its page's arguments, null when there
  /// is none. Cleared whenever it leaves the screen — its page then hands the
  /// session to [VirtTextConsoles], and showing it again takes it back.
  SshPageArgs? _text;

  /// [_text]'s page is on screen, for the page's own keyboard and focus.
  final _textVisible = ValueNotifier(false);
  final _textFocus = FocusNode();

  /// Close, rather than park, the session the text page leaves behind next.
  var _endText = false;

  final _textPage = GlobalKey<SSHPageState>();

  /// Enter for a serial console that waits silently, on [_textPage]'s
  /// terminal. Null for a console that is not a serial port (a PVE
  /// container's) and while no terminal is shown.
  SerialWake? _wake;

  /// Whether [widget.guest]'s text console is a serial port: every libvirt
  /// one (`virsh console`), and a PVE VM's (`serialN`); a PVE container's is
  /// its own console, which draws a prompt when connected.
  bool get _serial => switch (ref.read(virtHostProvider(widget.serverId)).kind) {
    VirtHostKind.pve => widget.guest.kind == VirtGuestKind.qemu,
    _ => true,
  };

  /// How many of these are mounted per graphical session.
  ///
  /// Two at once is a layout change — the guest pushed as a page becoming a
  /// pane beside the list — and the one going says "off screen" after the
  /// frame the one arriving said "on screen" in. Only the last one to go may.
  static final _mounted = <String, int>{};

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(remoteDesktopSessionsProvider.notifier);
    _mounted.update(_vncId, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  void dispose() {
    // Not closed: [SessionKeepAlive] does that once it has been off screen
    // long enough. After the frame, as in [build].
    final id = _vncId;
    final sessions = _sessions;
    final left = (_mounted[id] ?? 1) - 1;
    if (left <= 0) {
      _mounted.remove(id);
    } else {
      _mounted[id] = left;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_mounted.containsKey(id)) sessions.setConsoleVisible(id, false);
    });
    _wake?.dispose();
    // After the page under them, which unmounts first and lets go of both.
    _textVisible.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onScreen = ref.watch(
      currentHomeTabProvider.select((tab) => tab == AppTab.virt),
    );
    final vncOpen = ref.watch(
      remoteDesktopSessionsProvider.select(
        (s) => s.consoles.containsKey(_vncId),
      ),
    );
    final textRunning = ref.watch(
      virtTextConsolesProvider.select((ids) => ids.contains(_textId)),
    );
    final visible = vncOpen && onScreen && _kind == VirtConsoleKind.vnc;
    if (visible != _shown) {
      _shown = visible;
      // After the frame: a write to a provider may not happen while the tree
      // is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sessions.setConsoleVisible(_vncId, visible);
      });
    }

    _syncText(
      shown: onScreen && _kind == VirtConsoleKind.text,
      running: textRunning,
    );

    final text = _text;
    final body = switch (_kind) {
      VirtConsoleKind.vnc when vncOpen => _buildVnc(),
      VirtConsoleKind.vnc => _launcher(
        icon: Icons.desktop_windows_outlined,
        text: l10n.connect,
        onTap: _openVnc,
      ),
      VirtConsoleKind.text when text != null && onScreen => _buildText(text),
      // Being taken back: the page comes with the next frame.
      VirtConsoleKind.text when textRunning => UIs.placeholder,
      VirtConsoleKind.text => _launcher(
        icon: Icons.terminal,
        text: l10n.connect,
        tip: switch (ref.watch(virtHostProvider(widget.serverId)).kind) {
          VirtHostKind.libvirt => l10n.virtConsoleSerialTip,
          _ => null,
        },
        onTap: _openText,
      ),
    };
    return body;
  }

  /// [onClose], given, is a second button: the session is running, and this
  /// ends it rather than waiting for it to be closed as idle.
  Widget _launcher({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    String? tip,
    VoidCallback? onClose,
  }) {
    final open = Btn.elevated(
      text: text,
      icon: Icon(icon),
      mainAxisSize: MainAxisSize.min,
      onTap: onTap,
    );
    return EmptyPane(
      icon: icon,
      title: widget.guest.name,
      label: tip,
      action: _opening
          ? SizedLoading.medium
          : onClose == null
          ? open
          : Wrap(
              spacing: 7,
              runSpacing: 7,
              alignment: WrapAlignment.center,
              children: [
                open,
                Btn.text(text: libL10n.close, onTap: onClose),
              ],
            ),
    );
  }

  /// Keeps [_text] to when it can be seen: gone from the screen, its page is
  /// let go (and parks the session); back, a parked session is taken up.
  void _syncText({required bool shown, required bool running}) {
    if (_textVisible.value != shown) {
      // After the frame: the page listening to it rebuilds on a change.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _textVisible.value = shown;
      });
    }
    if ((shown && _text != null) || _wake != null) {
      // The page is built (or gone) this frame; its terminal is there after.
      WidgetsBinding.instance.addPostFrameCallback((_) => _attachWake());
    }
    if (!shown && _text != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _text = null);
      });
    } else if (shown && _text == null && running && !_opening) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _text == null) _resumeText();
      });
    }
  }

  /// What a text page does with its session when it goes: back to
  /// [VirtTextConsoles] to be kept, or closed when the bar's close asked.
  ///
  /// Captured rather than read through `ref` when it runs: it runs after the
  /// page has gone, and this view may have too.
  void Function(TerminalSession) _leaveText() {
    final consoles = ref.read(virtTextConsolesProvider.notifier);
    final id = _textId;
    final name = widget.guest.name;
    final host =
        ref.read(serversProvider).servers[widget.serverId]?.name ??
        widget.serverId;
    return (session) {
      if (_endText) {
        _endText = false;
        session.close();
        return;
      }
      consoles.park(id, session, name: name, host: host);
    };
  }

  /// Watches the shown terminal for a silent serial console — a new one when
  /// the page shows another terminal, none once no page does.
  void _attachWake() {
    if (!mounted) return;
    final terminal = _text == null || !_textVisible.value
        ? null
        : _textPage.currentState?.terminal;
    if (identical(_wake?.terminal, terminal)) return;
    _wake?.dispose();
    _wake = terminal == null || !_serial
        ? null
        : (SerialWake(terminal)..addListener(_onWake));
  }

  void _onWake() {
    if (mounted) setState(() {});
  }

  SshPageArgs _embed(SshPageArgs args) => args.embeddedIn(
    AppTab.virt,
    visible: _textVisible,
    focusNode: _textFocus,
    restorationId: 'virt_$_textId',
    // The console hung up, or failed to connect: back to "Connect".
    onSessionEnd: () {
      if (mounted) setState(() => _text = null);
    },
  );

  void _resumeText() {
    final session = ref.read(virtTextConsolesProvider.notifier).take(_textId);
    if (session == null) return;
    setState(() {
      _text = _embed(
        VirtConsoleConnect.resumedTextArgs(session, onLeave: _leaveText()),
      );
    });
  }

  Future<void> _openText() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final args = await VirtConsoleConnect.textArgs(
        ProviderScope.containerOf(context),
        serverId: widget.serverId,
        guest: widget.guest,
        onLeave: _leaveText(),
      );
      if (!mounted) return;
      setState(() => _text = _embed(args));
    } catch (e, s) {
      Loggers.app.warning('Opening a text console', e, s);
      Toast.error(libL10n.fail, body: VirtConsoleConnect.describe(e));
    } finally {
      if (mounted && _opening) setState(() => _opening = false);
    }
  }

  /// The countdown to Enter on a silent serial console, with its two
  /// answers; otherwise the hint to press it — a serial port prints nothing
  /// until written to, whatever this saw.
  List<Widget> _buildWake() {
    final wake = _wake;
    final left = wake?.remaining;
    if (wake == null || left == null) {
      return [
        Flexible(
          child: Text(
            l10n.virtConsoleEnterTip,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: UIs.text12Grey,
          ),
        ),
        UIs.width7,
      ];
    }
    return [
      Flexible(
        child: Text(
          l10n.virtConsoleAutoEnter(left),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: UIs.text12Grey.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      Btn.text(text: l10n.virtConsoleEnterNow, onTap: wake.now),
      Btn.text(text: libL10n.cancel, onTap: wake.cancel),
    ];
  }

  /// Ends the text console: its page goes, and closes the session it leaves.
  void _closeText() {
    _endText = true;
    setState(() => _text = null);
  }

  /// The terminal, and under it what it is connected through.
  Widget _buildText(SshPageArgs args) {
    final spi = ref.watch(
      serversProvider.select((s) => s.servers[widget.serverId]),
    );
    final what = switch (args.source) {
      ServerSource() => 'virsh console',
      _ => 'termproxy',
    };
    final via = switch (spi?.transport) {
      ServerTransport.ssh => 'SSH',
      ServerTransport.monitorHttp => 'monitor',
      ServerTransport.local => 'localhost',
      null => null,
    };
    return Column(
      children: [
        Expanded(
          child: SSHPage(key: _textPage, args: args),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 5, 7, 5),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  [what, if (via != null) l10n.virtConsoleVia(via)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text12Grey,
                ),
              ),
              ..._buildWake(),
              // libvirt's: back to the host's shell, as Ctrl+] does.
              if (args.detachInput != null)
                Btn.icon(
                  icon: const Icon(Icons.link_off, size: 17),
                  text: l10n.disconnect,
                  onTap: () => _textPage.currentState?.detach(),
                ),
              Btn.icon(
                icon: const Icon(Icons.close, size: 17),
                text: libL10n.close,
                onTap: _closeText,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The viewer, and over it — when the display refused the connection for
  /// a password, which a libvirt display with one it could not read does —
  /// the way to give it.
  Widget _buildVnc() {
    final refused = ref.watch(
      remoteDesktopSessionsProvider.select(
        (s) =>
            s.consoles[_vncId]?.endReason ==
            ffi.RemoteDesktopEndReason.authenticationFailed,
      ),
    );
    final viewer = RemoteDesktopViewer(sessionId: _vncId);
    if (!refused) return viewer;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 7, 5),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 17,
                color: Theme.of(context).colorScheme.error,
              ),
              UIs.width7,
              Expanded(
                child: Text(
                  l10n.virtVncPasswordNeeded,
                  style: UIs.text13,
                ),
              ),
              Btn.text(text: libL10n.pwd, onTap: _askVncPassword),
            ],
          ),
        ),
        Expanded(child: viewer),
      ],
    );
  }

  /// Asks for the display's password and connects again with it — used for
  /// this connection only, kept nowhere.
  Future<void> _askVncPassword() async {
    final ctrl = TextEditingController();
    final password = await context.showRoundDialog<String>(
      title: 'VNC ${libL10n.pwd}',
      childBuilder: (dialogContext) => DisposeWith(
        notifiers: [ctrl],
        child: Input(
          controller: ctrl,
          hint: libL10n.pwd,
          obscureText: true,
          autoFocus: true,
          suggestion: false,
          onSubmitted: (value) => dialogContext.popDialog(value),
        ),
      ),
      actionsBuilder: (dialogContext) => [
        Btn.cancel(),
        Btn.text(
          text: l10n.connect,
          onTap: () => dialogContext.popDialog(ctrl.text),
        ),
      ],
    );
    if (password == null || password.isEmpty || !mounted) return;
    // A new opener, not a reconnect of the old one: that one has no password.
    await _sessions.close(_vncId);
    if (!mounted) return;
    _openVnc(password: password);
  }

  void _openVnc({String? password}) {
    final container = ProviderScope.containerOf(context);
    _sessions.openConsole(
      VirtConsoleConnect.vncProfile(
        serverId: widget.serverId,
        guest: widget.guest,
      ),
      target: VirtConsoleConnect.vncTarget(
        container,
        serverId: widget.serverId,
        guestId: widget.guest.id,
        password: password,
      ),
    );
  }
}

extension on VirtConsoleKind {
  String get label => switch (this) {
    VirtConsoleKind.text => libL10n.terminal,
    VirtConsoleKind.vnc => l10n.virtConsoleGraphical,
  };

  IconData get icon => switch (this) {
    VirtConsoleKind.text => Icons.terminal,
    VirtConsoleKind.vnc => Icons.desktop_windows_outlined,
  };
}
