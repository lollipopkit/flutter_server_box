import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/viewer.dart';
import 'package:server_box/view/widget/pane_settings.dart';

class RemoteDesktopTabPage extends ConsumerStatefulWidget {
  const RemoteDesktopTabPage({super.key});

  @override
  ConsumerState<RemoteDesktopTabPage> createState() =>
      _RemoteDesktopTabPageState();
}

class _RemoteDesktopTabPageState extends ConsumerState<RemoteDesktopTabPage> {
  String? _shownCertificate;

  /// Read once and kept, because [dispose] cannot read it.
  ///
  /// `ref` resolves through this element's `BuildContext`, and by the time the
  /// element is unmounted that is gone — `ref.read` there throws
  /// `Using "ref" when a widget is about to or has been unmounted is unsafe`,
  /// which surfaced as an exception every time this tab left the tree. The
  /// provider is `keepAlive`, so the notifier outlives this page whichever way
  /// it is reached.
  late final RemoteDesktopSessions _sessions;

  @override
  void initState() {
    super.initState();
    _sessions = ref.read(remoteDesktopSessionsProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sessions.setSurfaceVisible(
        ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
      );
    });
  }

  @override
  void dispose() {
    _sessions.setSurfaceVisible(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(remoteDesktopSessionsProvider);
    ref.listen(currentHomeTabProvider, (_, tab) {
      ref
          .read(remoteDesktopSessionsProvider.notifier)
          .setSurfaceVisible(tab == AppTab.remoteDesktop);
    });
    ref.listen(
      remoteDesktopSessionsProvider.select((value) => value.active?.certificate),
      (_, certificate) {
        if (certificate == null) {
          _shownCertificate = null;
        } else if (_shownCertificate != certificate.sha256) {
          _shownCertificate = certificate.sha256;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_confirmCertificate(certificate));
          });
        }
      },
    );
    final active = state.active;
    // The same shape the terminal and file tabs have: a rail of what is open
    // beside the thing itself, and one column where there is no room for two.
    // The layout used to be laid out here — a `Row` with a fixed 260-point
    // list — which meant no drag, no fold, and a width the other tabs' rails
    // did not share.
    return SbPaneList(
      // Nothing open is nothing to put beside: the column is not reserved for
      // an empty surface.
      hasContent: active != null,
      sideBuilder: (_) => _sessionRail(state),
      builder: (_, split) => _buildSurface(state, split),
    );
  }

  Widget _buildSurface(RemoteDesktopSessionsState state, bool split) {
    final active = state.active;
    if (active == null) return _empty();
    return Scaffold(
      appBar: split ? _sessionBar(active) : _switcherBar(state, active),
      body: RemoteDesktopViewer(sessionId: active.id),
    );
  }

  /// The bar of a single column: which of the sessions is on screen, and the
  /// way to the rest of them.
  PreferredSizeWidget _switcherBar(
    RemoteDesktopSessionsState state,
    RemoteDesktopSessionView active,
  ) => PreferredSize(
    preferredSize: const Size.fromHeight(SessionTabBar.height),
    child: SizedBox(
      height: SessionTabBar.height,
      child: Row(
        children: [
          Expanded(
            child: SessionSwitcherLabel(
              name: active.profile.name,
              position: state.ordered.indexWhere((e) => e.id == active.id) + 1,
              total: state.sessions.length,
              icon: Icons.desktop_windows_outlined,
              onTap: () => _showSessions(state),
            ),
          ),
          IconButton(
            tooltip: libL10n.close,
            icon: const Icon(Icons.close),
            onPressed: () => ref
                .read(remoteDesktopSessionsProvider.notifier)
                .close(active.id),
          ),
          const SizedBox(width: 5),
        ],
      ),
    ),
  );

  /// The bar beside the rail: the rail switches sessions and starts them, so
  /// all this has to say is which one is on screen.
  PreferredSizeWidget _sessionBar(RemoteDesktopSessionView active) =>
      CustomAppBar(
        title: Text(active.profile.name),
        actions: [
          Btn.icon(
            text: libL10n.close,
            icon: const Icon(Icons.close, size: 18),
            onTap: () => ref
                .read(remoteDesktopSessionsProvider.notifier)
                .close(active.id),
          ),
          const SizedBox(width: 7),
        ],
      );

  Widget _empty() => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.desktop_windows_outlined, size: 72, color: Colors.grey),
            const SizedBox(height: 16),
            Text('No remote desktop sessions', style: UIs.textGrey),
            const SizedBox(height: 8),
            const Text(
              'Open a server and choose Remote desktop to start an RDP or VNC session.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );

  /// The rail: a name and whether it is connected, like every other rail here.
  Widget _sessionRail(RemoteDesktopSessionsState state) => ListView(
    padding: const EdgeInsets.only(top: 4, bottom: 77),
    children: [
      for (final session in state.ordered)
        SideBarTile(
          key: ValueKey(session.id),
          title: session.profile.name,
          icon: Icons.desktop_windows_outlined,
          selected: state.activeId == session.id,
          live: session.connectionState ==
              ffi.RemoteDesktopConnectionState.connected,
          onTap: () => ref
              .read(remoteDesktopSessionsProvider.notifier)
              .select(session.id),
          onMenu: (at) => _showSessionMenu(session, at),
        ),
    ],
  );

  void _showSessionMenu(RemoteDesktopSessionView session, Offset? at) {
    showContextMenu(
      context,
      [
        ContextMenuAction(
          text: libL10n.close,
          icon: Icons.close,
          destructive: true,
          onTap: () => ref
              .read(remoteDesktopSessionsProvider.notifier)
              .close(session.id),
        ),
      ],
      title: session.profile.name,
      at: at,
    );
  }

  String _connectionStateLabel(ffi.RemoteDesktopConnectionState state) => switch (state) {
    ffi.RemoteDesktopConnectionState.connected => libL10n.ready,
    ffi.RemoteDesktopConnectionState.connecting => context.l10n.pveLoadingConnect,
    ffi.RemoteDesktopConnectionState.reconnecting => libL10n.reconnecting,
    ffi.RemoteDesktopConnectionState.disconnected => libL10n.disconnected,
  };

  Future<void> _showSessions(RemoteDesktopSessionsState state) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final session in state.ordered)
              ListTile(
                selected: session.id == state.activeId,
                leading: Semantics(
                  label: _connectionStateLabel(session.connectionState),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: _connectionStateLabel(session.connectionState),
                    child: const Icon(Icons.desktop_windows_outlined),
                  ),
                ),
                title: Text(session.profile.name),
                subtitle: Text(
                  '${session.profile.protocol.name.toUpperCase()} · '
                  '${_connectionStateLabel(session.connectionState)}',
                ),
                trailing: IconButton(
                  tooltip: libL10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    ref
                        .read(remoteDesktopSessionsProvider.notifier)
                        .close(session.id);
                  },
                ),
                onTap: () {
                  ref
                      .read(remoteDesktopSessionsProvider.notifier)
                      .select(session.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCertificate(
    RemoteDesktopCertificatePrompt certificate,
  ) async {
    final state = ref.read(remoteDesktopSessionsProvider);
    final session = state.active;
    if (session == null || session.certificate?.sha256 != certificate.sha256) {
      return;
    }
    final replacing = certificate.replacesExisting;
    final accepted = await context.showRoundDialog<bool>(
      title: replacing ? 'Remote desktop certificate changed' : 'Trust certificate?',
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              replacing
                  ? 'The certificate fingerprint no longer matches the saved value. Verify the new fingerprint before replacing trust.'
                  : 'The system could not verify this certificate. Verify its SHA-256 fingerprint before continuing.',
            ),
            const SizedBox(height: 12),
            SelectableText('SHA-256\n${certificate.sha256}'),
            if (certificate.previousSha256 case final previous?) ...[
              const SizedBox(height: 8),
              SelectableText('Previously trusted\n$previous'),
            ],
            const SizedBox(height: 8),
            SelectableText('Subject: ${certificate.subject}'),
            SelectableText('Issuer: ${certificate.issuer}'),
            SelectableText('Valid: ${certificate.validFrom} – ${certificate.validTo}'),
          ],
        ),
      ),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () => context.popDialog(true),
          child: Text(replacing ? 'Replace trust' : 'Trust and reconnect'),
        ),
      ],
    );
    if (!mounted) return;
    if (accepted == true) {
      await ref
          .read(remoteDesktopSessionsProvider.notifier)
          .trustCertificate(session.id);
    } else {
      await ref.read(remoteDesktopSessionsProvider.notifier).close(session.id);
    }
  }
}
