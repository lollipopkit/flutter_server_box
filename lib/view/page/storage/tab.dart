import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/sftp.dart';

/// This device's files, and one tab per server being browsed.
///
/// Remote browsing used to be a page pushed over whatever was on screen, so
/// opening two servers meant losing the first, and going back to compare
/// meant reconnecting. Sessions here behave like the terminal's: they stay
/// open, and the strip says what is open.
class FileTabPage extends ConsumerStatefulWidget {
  const FileTabPage({super.key});

  @override
  ConsumerState<FileTabPage> createState() => _FileTabPageState();
}

class _FileTabPageState extends ConsumerState<FileTabPage>
    with AutomaticKeepAliveClientMixin {
  late final _sessions = SessionTabsController<Spi>(
    leadingName: libL10n.file,
  );

  @override
  bool get wantKeepAlive => true;

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
      body: SessionTabsView<Spi>(
        controller: _sessions,
        leading: const LocalFilePage(),
        builder: (_, tab) => SftpPage(
          key: ValueKey(tab.id),
          args: SftpPageArgs(spi: tab.data),
        ),
      ),
    );
  }

  void _drainRequests() {
    final pending = ref.read(sftpRequestsProvider);
    if (pending.isEmpty) return;
    ref.read(sftpRequestsProvider.notifier).clear();
    for (final spi in pending) {
      final tab = _sessions.add(preferred: spi.name, build: (_, _, _) => spi);
      _sessions.select(_sessions.names.indexOf(tab.name));
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
  }
}
