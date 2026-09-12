import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/remote_desktop.dart';
import 'package:server_box/src/rust/api/remote_desktop.dart' as ffi;
import 'package:server_box/view/page/remote_desktop/viewer.dart';

class RemoteDesktopTabPage extends ConsumerStatefulWidget {
  const RemoteDesktopTabPage({super.key});

  @override
  ConsumerState<RemoteDesktopTabPage> createState() =>
      _RemoteDesktopTabPageState();
}

class _RemoteDesktopTabPageState extends ConsumerState<RemoteDesktopTabPage> {
  String? _shownCertificate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(remoteDesktopSessionsProvider.notifier).setSurfaceVisible(
        ref.read(currentHomeTabProvider) == AppTab.remoteDesktop,
      );
    });
  }

  @override
  void dispose() {
    ref.read(remoteDesktopSessionsProvider.notifier).setSurfaceVisible(false);
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
    if (active == null) return _empty();
    return LayoutBuilder(
      builder: (_, constraints) {
        final wide = remoteDesktopUsesWideLayout(constraints.maxWidth);
        if (wide) {
          return Row(
            children: [
              SizedBox(width: 260, child: _sessionList(state)),
              const VerticalDivider(width: 1),
              Expanded(child: RemoteDesktopViewer(sessionId: active.id)),
            ],
          );
        }
        return Scaffold(
          appBar: PreferredSize(
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
          ),
          body: RemoteDesktopViewer(sessionId: active.id),
        );
      },
    );
  }

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

  Widget _sessionList(RemoteDesktopSessionsState state) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Column(
      children: [
        SizedBox(
          height: SessionTabBar.height,
          child: Row(
            children: [
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Remote desktop',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text('${state.sessions.length}', style: UIs.text13Grey),
              const SizedBox(width: 14),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: state.ordered.length,
            itemBuilder: (_, index) => _sessionTile(state.ordered[index], state.activeId),
          ),
        ),
      ],
    ),
  );

  Widget _sessionTile(RemoteDesktopSessionView session, String? activeId) {
    final active = activeId == session.id;
    final color = switch (session.connectionState) {
      ffi.RemoteDesktopConnectionState.connected => Colors.green,
      ffi.RemoteDesktopConnectionState.connecting ||
      ffi.RemoteDesktopConnectionState.reconnecting => Colors.orange,
      ffi.RemoteDesktopConnectionState.disconnected => Colors.red,
    };
    return ListTile(
      selected: active,
      leading: Icon(Icons.circle, size: 10, color: color),
      title: Text(session.profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(session.profile.protocol.name.toUpperCase()),
      trailing: IconButton(
        tooltip: libL10n.close,
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => ref
            .read(remoteDesktopSessionsProvider.notifier)
            .close(session.id),
      ),
      onTap: () => ref
          .read(remoteDesktopSessionsProvider.notifier)
          .select(session.id),
    );
  }

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
                leading: const Icon(Icons.desktop_windows_outlined),
                title: Text(session.profile.name),
                subtitle: Text(session.profile.protocol.name.toUpperCase()),
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

bool remoteDesktopUsesWideLayout(double width) => width >= 800;
