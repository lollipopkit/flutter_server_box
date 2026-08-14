import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/storage/file_browser.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/storage/transfer_list.dart';
import 'package:server_box/view/widget/page_issue.dart';

/// A server's files, whichever way they are reached.
///
/// The one place that decides. Which transport carries the bytes is not a
/// distinction anybody browsing files should be shown — the terminal does not
/// show whether it reached sshd directly or through the agent's tunnel — so
/// the file tab opens *a server*, and this answers how.
///
/// The order is deliberate. SFTP first wherever there is a byte stream to run
/// it over: it is end to end, so an agent in the middle cannot read it, and it
/// carries permissions and sudo. The agent's own file API is the answer for
/// the case SFTP cannot serve at all — a host running the agent whose sshd
/// this app cannot reach.
class ServerFilePage extends ConsumerWidget {
  const ServerFilePage({super.key, required this.args});

  final SftpPageArgs args;

  static const route = AppRouteArg<String, SftpPageArgs>(
    page: ServerFilePage.new,
    path: '/files/server',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caps = ref.watch(serverProvider(args.spi.id)).capabilities;

    if (caps.byteStream) return SftpPage(args: args);
    if (caps.files) return _MonitorFilePage(args: args);

    return Scaffold(
      appBar: args.actionsSink != null
          ? null
          : CustomAppBar(title: Text(args.spi.name)),
      body: PageIssueView(
        title: l10n.serverUnreachable,
        // Named rather than left as "no": the two ways in are a reachable
        // sshd and an agent with its file API switched on, and neither is
        // something the app can turn on from here.
        explain: l10n.serverFilesUnavailableTip,
        icon: Icons.folder_off_outlined,
      ),
    );
  }
}

/// A server's files over its `monitor` agent.
///
/// Thin next to [SftpPage] because there is less to be peculiar about: the
/// agent runs as one account with no way to ask for another, so there is no
/// sudo; it has no shell to unpack an archive in; and a transfer is the same
/// `FileTransfer` every other pair uses.
class _MonitorFilePage extends ConsumerStatefulWidget {
  const _MonitorFilePage({required this.args});

  final SftpPageArgs args;

  @override
  ConsumerState<_MonitorFilePage> createState() => _MonitorFilePageState();
}

class _MonitorFilePageState extends ConsumerState<_MonitorFilePage> {
  late final MonitorFileBackend _backend;

  Spi get _spi => widget.args.spi;

  @override
  void initState() {
    super.initState();
    final credential = ServerConnectCredential.fromSpi(_spi);
    // Its own client rather than the polling one: a file listing and a status
    // poll have nothing to say to each other, and sharing a session would
    // couple a browse that stalls to the card that shows the machine is up.
    _backend = MonitorFileBackend(
      MonitorHttpClient(
        (credential as ServerConnectCredentialMonitorHttp).monitor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FileBrowserPage(
      args: FileBrowserArgs(
        backend: _backend,
        // The agent confines every request to the roots its operator named,
        // and does not say what they are. Starting at `/` and letting it
        // refuse is honest: the alternative is guessing a root and hiding
        // directories the agent would have served.
        root: '/',
        initialPath: widget.args.initPath,
        isPickDir: widget.args.isSelect,
        actionsSink: widget.args.actionsSink,
        onPathChanged: widget.args.onPathChanged,
        extraActions: (_) => [
          IconButton(
            icon: const Icon(Icons.downloading),
            onPressed: () => TransferListPage.route.go(context),
          ),
        ],
        refOf: (path) => MonitorFileRef.forServer(_spi, path),
      ),
    );
  }
}
