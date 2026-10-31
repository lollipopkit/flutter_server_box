import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/file_browser.dart';
import 'package:server_box/view/page/storage/file_edit.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/storage/show_transfers.dart';

/// Whether a server's files come from its agent rather than over SFTP.
///
/// [ServerFilePage] builds the browser and the function bar opens the SSH
/// connection the other branch needs, so the question is asked here once: two
/// call sites answering it differently means a bar that connects sshd for a
/// page that is not going to use it, or a page that opens with no connection.
///
/// The transport the user put first decides, the same as it does for a command
/// and for the terminal. When only one of the two can serve files at all there
/// is nothing to order: the agent alone answers with its file API, and SSH
/// alone with SFTP — which is also the tie-break for a server that names no
/// preference, since SFTP is end to end and carries permissions and sudo.
///
/// [granted] rather than `ServerCapabilities.files`: the capabilities of a
/// both-transports server are the union, and SFTP is files, so that question
/// answers true for every such server whatever the agent allows. What is being
/// asked here is whether the *agent* can serve them.
bool serverFilesUseAgent(Spi spi, MonitorAccess? granted) {
  if (spi.monitorOn == null || granted?.ok != true) return false;
  return spi.sshOn == null || spi.transport == ServerTransport.monitorHttp;
}

/// A server's files, whichever way they are reached.
///
/// The one place that decides. Which transport carries the bytes is not a
/// distinction anybody browsing files should be shown — the terminal does not
/// show whether it reached sshd directly or through the agent's tunnel — so
/// the file tab opens *a server*, and this answers how.
class ServerFilePage extends ConsumerWidget {
  const ServerFilePage({super.key, required this.args});

  final SftpPageArgs args;

  static const route = AppRouteArg<String, SftpPageArgs>(
    page: ServerFilePage.new,
    path: '/files/server',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The three answers alone: the whole state is new on every status poll,
    // and a rebuild here rebuilds the file browser under it.
    final (:files, :agent, :byteStream) = ref.watch(
      serverProvider(args.spi.id).select(
        (s) => (
          files: s.capabilities.files,
          agent: serverFilesUseAgent(args.spi, s.agentAccess),
          byteStream: s.capabilities.byteStream,
        ),
      ),
    );

    if (args.spi.local && files) return _LocalServerFilePage(args: args);
    if (agent) return _MonitorFilePage(args: args);
    if (byteStream) return SftpPage(args: args);

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

/// The files of a server that is this device (`Spi.local`).
///
/// [LocalFileBackend] over the whole filesystem, which is what separates it
/// from `LocalFilePage`: that one is the app's own files directory, where
/// downloads land and uploads are picked from. A server's file browser shows
/// the machine, so it opens at home and goes up to the root.
class _LocalServerFilePage extends StatelessWidget {
  const _LocalServerFilePage({required this.args});

  final SftpPageArgs args;

  /// `/`, or on Windows the drive holding home — `LocalFileBackend` takes
  /// forward slashes everywhere and has no view above the drive letters.
  static String get _root {
    final home = LocalShellBackend.homeDir;
    if (!isWindows || home == null) return '/';
    final drive = RegExp(r'^[A-Za-z]:').firstMatch(home)?.group(0);
    return drive == null ? '/' : '$drive/';
  }

  static String? get _home => LocalShellBackend.homeDir?.replaceAll(r'\', '/');

  @override
  Widget build(BuildContext context) {
    final spi = args.spi;
    final lastPath = Stores.setting.sftpOpenLastPath.fetch()
        ? Stores.history.sftpLastPath.fetch(spi.id)
        : null;
    return FileBrowserPage(
      args: FileBrowserArgs(
        backend: const LocalFileBackend(),
        root: _root,
        initialPath: args.initPath ?? lastPath ?? _home,
        homePath: _home,
        isPickDir: args.isSelect,
        actionsSink: args.actionsSink,
        onPathChanged: (path) {
          args.onPathChanged?.call(path);
          if (Stores.setting.sftpOpenLastPath.fetch()) {
            Stores.history.sftpLastPath.put(spi.id, path);
          }
        },
        extraActions: (_) => [
          BarAction(
            icon: Icons.downloading,
            label: libL10n.mission,
            onTap: () => showTransfers(context),
          ),
        ],
        // This device's files are this device's, whichever page lists them:
        // a transfer from here needs no server to reach them.
        refOf: LocalFileRef.new,
        onOpenFile: (handle, entry, path) => _edit(context, handle, entry, path),
        entryActions: (handle, entry, path) => [
          if (!entry.isDir)
            ContextMenuAction(
              icon: Icons.edit,
              text: libL10n.edit,
              onTap: () => _edit(context, handle, entry, path),
            ),
        ],
      ),
    );
  }

  /// In place: the file is already on this device.
  static Future<void> _edit(
    BuildContext context,
    FileBrowserHandle handle,
    FileEntry entry,
    String path,
  ) async {
    final size =
        entry.size ?? (await const LocalFileBackend().stat(path))?.size ?? 0;
    if (!fitsEditor(entry.name, size) || !context.mounted) return;
    await EditorPage.route.go(
      context,
      args: fileEditorArgs(
        path: LocalFileBackend.nativePath(path),
        onSave: (_) {
          Toast.show(libL10n.saved);
          handle.refresh();
        },
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
    // The agent itself. `serverFilesUseAgent` is what decided this page is the
    // right one, and it only says so for a server that has one — but reading
    // the credential from the spi rather than from a resolved transport is
    // what keeps that true whatever that branch grows into.
    final monitor = _spi.monitor;
    if (monitor == null) {
      throw StateError('${_spi.name} has no monitor agent to browse');
    }
    final server = ref.read(serverProvider(_spi.id));
    _backend = MonitorFileBackend(
      monitor,
      permissions: server.status.system != SystemType.windows,
    );
  }

  @override
  void dispose() {
    // The session, and the sockets under it. A file tab left open on several
    // servers would otherwise hold one connection pool per browser for as long
    // as the app runs.
    _backend.close().ignore();
    super.dispose();
  }

  /// Where this server was left, or null to open at the root.
  ///
  /// The same store and the same setting `SftpPage` uses. Both are named after
  /// SFTP because it was the only server backend when they were written; what
  /// they hold is "where this server id was last browsed", which is the same
  /// question here.
  ///
  /// Not checked before use, unlike SFTP's — that check costs a round trip
  /// before the page can be built, and the failure it would avoid is the one
  /// this page already handles well: a refusal offers the agent's roots as
  /// chips, which is one tap.
  String? get _lastPath {
    if (!Stores.setting.sftpOpenLastPath.fetch()) return null;
    return Stores.history.sftpLastPath.fetch(_spi.id);
  }

  void _onPathChanged(String path) {
    widget.args.onPathChanged?.call(path);
    if (Stores.setting.sftpOpenLastPath.fetch()) {
      Stores.history.sftpLastPath.put(_spi.id, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FileBrowserPage(
      args: FileBrowserArgs(
        backend: _backend,
        // The agent confines every request to the roots its operator named.
        // Still `/`, which is right where the roots are the whole machine and
        // is a refusal otherwise — and a refusal now offers those roots as
        // chips (see `FileBrowserPage`'s error view), so the way on is one tap
        // rather than a guess. Picking a root to open at instead would mean
        // holding the page back on a round trip, every time, for the case the
        // user can resolve in one.
        root: '/',
        // Where it was left, which `/` never is: the agent confines every
        // request to the roots its operator named, so opening at the root
        // means a refusal on every single visit. Nothing remembered still
        // opens at `/` and still offers those roots as chips — that is the
        // first visit, and it is one tap.
        initialPath: widget.args.initPath ?? _lastPath,
        isPickDir: widget.args.isSelect,
        actionsSink: widget.args.actionsSink,
        onPathChanged: _onPathChanged,
        extraActions: (_) => [
          BarAction(
            icon: Icons.downloading,
            label: libL10n.mission,
            onTap: () => showTransfers(context),
          ),
        ],
        refOf: (path) => MonitorFileRef.forServer(_spi, path),
        onOpenFile: _edit,
        entryActions: (handle, entry, path) => [
          if (!entry.isDir)
            ContextMenuAction(
              icon: Icons.edit,
              text: libL10n.edit,
              onTap: () => _edit(handle, entry, path),
            ),
        ],
      ),
    );
  }

  /// A copy on this device, edited there and written back only if the file
  /// on the server is still the one that was opened.
  Future<void> _edit(
    FileBrowserHandle handle,
    FileEntry entry,
    String path,
  ) async {
    final localPath = serverLocalPath(_spi.id, path);
    final (opened, err) = await context.showLoadingDialog(
      // A download, which takes as long as the link makes it.
      timeout: null,
      fn: () async {
        // A link lists without a size: what it points at decides.
        final size = entry.size ?? (await _backend.stat(path))?.size ?? 0;
        if (!fitsEditor(entry.name, size)) return null;
        // Before the bytes: a change in between then reads as a change at
        // save, never as one silently overwritten.
        final version = await _backend.versionOf(path);
        final file = File(localPath);
        await file.parent.create(recursive: true);
        final sink = file.openWrite();
        try {
          await sink.addStream(_backend.read(path));
        } finally {
          await sink.close();
        }
        return (version: version,);
      },
    );
    if (err != null || opened == null || !mounted) return;
    var version = opened.version;
    // The editor does not wait for a save, so two in a row would both name
    // the version the first one replaces: each waits for the one before.
    var saving = Future<void>.value();
    await EditorPage.route.go(
      context,
      args: fileEditorArgs(
        path: localPath,
        // Caught inside, so one failed save does not leave the chain failed
        // and skip every save after it.
        onSave: (_) => saving = saving.then((_) async {
          try {
            final saved = await _saveBack(entry.name, path, localPath, version);
            if (saved == null) return;
            version = saved.version;
            await handle.refresh();
          } catch (e, s) {
            Loggers.app.warning('Failed to save $path', e, s);
            Toast.error(libL10n.fail, body: '$e');
          }
        }),
      ),
    );
  }

  /// Writes [localPath] back to [path]; null when it was not written, which
  /// has already been said.
  Future<({String? version})?> _saveBack(
    String name,
    String path,
    String localPath,
    String? version,
  ) async {
    if (!mounted) return null;
    // A failure is the loading dialog's to show.
    Future<_SaveResult> write(String? expected) async {
      final (saved, err) = await context.showLoadingDialog(
        fn: () async {
          final bytes = await File(localPath).readAsBytes();
          try {
            final left = await _backend.writeIfUnchanged(path, bytes, expected);
            return _SaveResult.written(left);
          } on MonitorHttpErr catch (e) {
            if (e.type == MonitorHttpErrType.modified) {
              return const _SaveResult.modified();
            }
            rethrow;
          }
        },
      );
      return err != null || saved == null ? const _SaveResult.failed() : saved;
    }

    var result = await write(version);
    if (result.modified) {
      if (!mounted) return null;
      final overwrite = await context.showRoundDialog<bool>(
        title: libL10n.attention,
        child: Text(l10n.fileChangedOverwrite(name)),
        actions: Btnx.cancelRedOk,
      );
      if (overwrite != true || !mounted) return null;
      result = await write(null);
    }
    if (!result.written) return null;
    Toast.show(libL10n.saved);
    return (version: result.version);
  }
}

/// How a save back to the agent went.
final class _SaveResult {
  const _SaveResult.written(this.version) : written = true, modified = false;
  const _SaveResult.modified()
    : version = null,
      written = false,
      modified = true;
  const _SaveResult.failed()
    : version = null,
      written = false,
      modified = false;

  final bool written;

  /// The file had changed on the server since it was opened.
  final bool modified;

  /// What the write left, for the next save to name.
  final String? version;
}
