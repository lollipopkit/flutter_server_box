part of 'guest.dart';

/// Where a guest's console goes.
///
/// Which consoles there are comes from the guest's detail
/// (`VirtGuestDetail.consoles`); with both, a toggle picks between them. How
/// each is opened is [VirtConsoleConnect].
///
/// - **Text** opens the terminal page over the window, with its virtual keys,
///   theme and reconnect: the one terminal the app has, given a console
///   instead of a shell (PVE), or a shell on the host with `virsh console`
///   typed into it (libvirt).
/// - **Graphical** is the remote desktop viewer, in place here. Its toolbar
///   has reconnect, full screen and close; closing brings back "Connect".
///   The session is closed when this view goes — leaving the console, or the
///   guest stopping.
class VirtConsoleView extends StatelessWidget {
  const VirtConsoleView({
    super.key,
    required this.serverId,
    required this.guest,
    required this.state,
    required this.detail,
    this.onStart,
    this.onRetryDetail,
  });

  final String serverId;
  final VirtGuest guest;
  final VirtGuestState state;

  /// The guest's detail, which says which consoles it has.
  final Future<VirtGuestDetail>? detail;

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
          consoles: data.consoles,
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
    required this.consoles,
  });

  final String serverId;
  final VirtGuest guest;
  final Set<VirtConsoleKind> consoles;

  @override
  ConsumerState<_VirtConsoles> createState() => _VirtConsolesState();
}

class _VirtConsolesState extends ConsumerState<_VirtConsoles> {
  /// Graphical first where there is one: a VM's screen is what its console
  /// usually means, and its serial port is the fallback.
  late var _kind = widget.consoles.contains(VirtConsoleKind.vnc)
      ? VirtConsoleKind.vnc
      : VirtConsoleKind.text;

  var _opening = false;

  /// What the graphical session was last told about being on screen.
  var _shown = false;

  /// Kept from `initState`: [dispose] closes the session and may not use
  /// `ref`.
  late final RemoteDesktopSessions _sessions;

  late final String _vncId = VirtConsoleConnect.vncSessionId(
    widget.serverId,
    widget.guest.id,
  );

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(remoteDesktopSessionsProvider.notifier);
  }

  @override
  void didUpdateWidget(_VirtConsoles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.consoles.contains(_kind)) _kind = widget.consoles.first;
  }

  @override
  void dispose() {
    unawaited(_sessions.close(_vncId));
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
    final visible = vncOpen && onScreen && _kind == VirtConsoleKind.vnc;
    if (visible != _shown) {
      _shown = visible;
      // After the frame: a write to a provider may not happen while the tree
      // is being built.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sessions.setConsoleVisible(_vncId, visible);
      });
    }

    final body = switch (_kind) {
      VirtConsoleKind.vnc when vncOpen => RemoteDesktopViewer(
        sessionId: _vncId,
      ),
      VirtConsoleKind.vnc => _launcher(
        icon: Icons.desktop_windows_outlined,
        text: l10n.connect,
        onTap: _openVnc,
      ),
      VirtConsoleKind.text => _launcher(
        icon: Icons.terminal,
        text: libL10n.open,
        tip: switch (ref.watch(virtHostProvider(widget.serverId)).kind) {
          VirtHostKind.libvirt => l10n.virtConsoleSerialTip,
          _ => null,
        },
        onTap: _openText,
      ),
    };
    if (widget.consoles.length < 2) return body;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 0, 13, 7),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(
              spacing: 3,
              children: [
                for (final kind in VirtConsoleKind.values)
                  if (widget.consoles.contains(kind))
                    VirtPill(
                      key: ValueKey(kind),
                      label: kind.label,
                      icon: kind.icon,
                      active: kind == _kind,
                      onTap: () => setState(() => _kind = kind),
                    ),
              ],
            ),
          ),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _launcher({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    String? tip,
  }) {
    return EmptyPane(
      icon: icon,
      title: widget.guest.name,
      label: tip,
      action: _opening
          ? SizedLoading.medium
          : Btn.elevated(text: text, icon: Icon(icon), onTap: onTap),
    );
  }

  Future<void> _openText() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final args = await VirtConsoleConnect.textArgs(
        ProviderScope.containerOf(context),
        serverId: widget.serverId,
        guest: widget.guest,
      );
      if (!mounted) return;
      setState(() => _opening = false);
      // The whole window, as the terminal tab's pages have: the virtual keys
      // need the width, and a pane is a column of it.
      await SSHPage.route.go(context, args, target: NavTarget.root);
    } catch (e, s) {
      Loggers.app.warning('Opening a text console', e, s);
      Toast.error(libL10n.fail, body: VirtConsoleConnect.describe(e));
    } finally {
      if (mounted && _opening) setState(() => _opening = false);
    }
  }

  void _openVnc() {
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
