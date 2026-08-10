import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/sftp.dart';

/// This device's files, and one tab per server being browsed.
///
/// Remote browsing used to be a page pushed over whatever was on screen, so
/// opening two servers meant losing the first, and going back to compare meant
/// reconnecting. Sessions here behave like the terminal's: they stay open, and
/// the strip says what is open.
class FileTabPage extends ConsumerStatefulWidget {
  const FileTabPage({super.key});

  @override
  ConsumerState<FileTabPage> createState() => _FileTabPageState();
}

/// One server being browsed.
class _SftpSession {
  _SftpSession({required this.spi, this.initialPath});

  final Spi spi;

  /// Where the page opens. Separate from [currentPath] because the page reads
  /// it once, when it is created; changing it later would do nothing and
  /// pretending otherwise invites someone to try.
  final String? initialPath;

  /// Where the browser is now, reported as it moves. Null until the first
  /// listing lands.
  String? currentPath;

  String? get path => currentPath ?? initialPath;
}

class _FileTabPageState extends ConsumerState<FileTabPage>
    with AutomaticKeepAliveClientMixin, RestorationMixin {
  late final _sessions = SessionTabsController<_SftpSession>(
    leadingName: libL10n.file,
  );

  final _restorableSessions = RestorableString('');

  @override
  String get restorationId => 'file_tab_page';

  @override
  bool get wantKeepAlive => true;

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restorableSessions, 'sessions');
    if (!initialRestore || _restorableSessions.value.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _restore());
  }

  @override
  void initState() {
    super.initState();
    // Anything queued before this tab existed — tabs are built when first
    // visited, so a request from the server list arrives before there is
    // anything here to receive it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainRequests());
  }

  @override
  void dispose() {
    _restorableSessions.dispose();
    _sessions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen(sftpRequestsProvider, (_, _) => _drainRequests());

    return Scaffold(
      appBar: PreferredSizeListenBuilder(
        listenable: _sessions,
        builder: () => SessionTabBar(
          names: _sessions.names,
          index: _sessions.index,
          leadingIcon: MingCute.folder_fill,
          onTap: _sessions.select,
          onClose: _close,
          // The pages carry their own actions in their own bars; this strip
          // only says which one is showing.
          sessionActions: const [],
          leadingActions: const [],
        ),
      ),
      body: SessionTabsView<_SftpSession>(
        controller: _sessions,
        leading: const LocalFilePage(),
        builder: (_, tab) {
          final session = tab.data;
          return SftpPage(
            key: ValueKey(tab.id),
            args: SftpPageArgs(
              spi: session.spi,
              initPath: session.initialPath,
              onPathChanged: (path) {
                if (session.currentPath == path) return;
                session.currentPath = path;
                _save();
              },
            ),
          );
        },
      ),
    );
  }
}

extension _Sessions on _FileTabPageState {
  /// [select] is off while restoring: selecting each as it arrives would
  /// animate through every session to land on the last.
  void _open(Spi spi, {String? initialPath, bool select = true}) {
    final tab = _sessions.add(
      preferred: spi.name,
      build: (_, _, _) => _SftpSession(spi: spi, initialPath: initialPath),
    );
    if (!select) return;
    _save();
    _sessions.select(_sessions.names.indexOf(tab.name));
  }

  void _drainRequests() {
    final pending = ref.read(sftpRequestsProvider);
    if (pending.isEmpty) return;
    ref.read(sftpRequestsProvider.notifier).clear();
    for (final spi in pending) {
      _open(spi);
    }
  }

  Future<void> _close(int index) async {
    // Resolved now, while the position still means what the bar drew.
    final tab = _sessions.tabs.elementAtOrNull(index - 1);
    if (tab == null) return;

    final confirm = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: Text('${libL10n.close} SFTP(${tab.name}) ?'),
      actions: Btnx.okReds,
    );
    if (confirm != true) return;
    _sessions.remove(tab.id);
    if (mounted) _save();
  }

  void _save() {
    _restorableSessions.value = jsonEncode([
      for (final tab in _sessions.tabs)
        {'serverId': tab.data.spi.id, 'path': tab.data.path},
    ]);
  }

  /// Reopens the servers that were being browsed, where they were being
  /// browsed.
  ///
  /// Unlike a terminal there is nothing still alive on the far side — this
  /// reconnects. What it restores is the intent: which servers, and where in
  /// them.
  void _restore() {
    final List<dynamic> entries;
    try {
      entries = jsonDecode(_restorableSessions.value) as List;
    } catch (e, st) {
      Loggers.app.warning('Unreadable file tab state', e, st);
      return;
    }

    final servers = {for (final spi in Stores.server.fetch()) spi.id: spi};

    var restored = 0;
    for (final entry in entries) {
      if (entry is! Map) continue;
      final spi = servers[entry['serverId']];
      if (spi == null) continue;
      _open(spi, initialPath: entry['path'] as String?, select: false);
      restored++;
    }

    if (restored == 0) return;
    _save();
    _sessions.select(1);
  }
}
