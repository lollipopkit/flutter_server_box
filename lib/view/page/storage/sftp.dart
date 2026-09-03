import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/utils/local_files.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/core/utils/sftp_sudo.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/core/utils/ssh_file_backend.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_issue.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/file_transfer.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/storage/file_browser.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/show_transfers.dart';
import 'package:server_box/view/page/storage/transfer_announce.dart';

part 'sftp_helpers.dart';

final class SftpPageArgs {
  final Spi spi;

  /// Returning a directory rather than browsing one, for "upload to where?".
  final bool isSelect;

  final String? initPath;

  /// Where this page publishes its toolbar instead of drawing one.
  ///
  /// A host that already has a bar of its own — the file tab's strip of
  /// sessions — takes them so the screen does not carry two. Null means draw
  /// the usual app bar, which is what a pushed page does.
  final ValueNotifier<List<Widget>>? actionsSink;

  /// Told where the browser has moved to, after each successful listing.
  ///
  /// For a host that outlives the page — the file tab, which remembers where
  /// each of its sessions was so a relaunch reopens them there rather than at
  /// the home directory.
  final void Function(String path)? onPathChanged;

  const SftpPageArgs({
    required this.spi,
    this.isSelect = false,
    this.initPath,
    this.onPathChanged,
    this.actionsSink,
  });
}

/// A server's files.
///
/// A [FileBrowserPage] over whichever backend this server's SSH connection
/// carries — SFTP, or `scp` and a shell — plus what only a server has:
/// somewhere to escalate to, an archive that can be unpacked in place, an
/// editor that has to fetch the file first, and a transfer queue. None of that
/// depends on which protocol is underneath, which is why one page serves both.
class SftpPage extends ConsumerStatefulWidget {
  final SftpPageArgs args;

  const SftpPage({super.key, required this.args});

  @override
  ConsumerState<SftpPage> createState() => _SftpPageState();

  static const route = AppRouteArg<String, SftpPageArgs>(
    page: SftpPage.new,
    path: '/sftp',
  );
}

class _SftpPageState extends ConsumerState<SftpPage> {
  /// Resolved in [_open] rather than in `initState`, and not `final` because
  /// [_retry] resolves it again.
  late SSHClient _client;
  late SftpSudoHelper _sudoHelper;
  late _SudoEscalation _escalation;

  /// Whether every operation goes through sudo without trying first. Turned on
  /// by hand, and by an escalation that worked: the next file in the same
  /// directory is not going to be any more readable than the last.
  final _sudoMode = false.vn;

  /// The home directory, the remembered path, and the SFTP channel, because
  /// the browser wants a backend and a place to start and both of those take a
  /// round trip.
  ///
  /// Replaceable, so that a connection that failed can be tried again without
  /// closing the page and opening it.
  late Future<_SftpStart> _start = _open();

  /// The server this page was opened on, as the route named it.
  ///
  /// Its **id** is what this is for. Everything else about it is a snapshot
  /// taken when the tab opened, and a tab outlives an edit — see [_current].
  Spi get _spi => widget.args.spi;

  /// The server as it is now.
  ///
  /// Every transfer this page queues is built from this rather than from the
  /// snapshot: the queued job carries its own copy of the credentials and the
  /// transport into an isolate, so a tab left open across an edit was sending
  /// bytes with the address, key and protocol the server had when the tab was
  /// opened — while the listing beside it had already reconnected with the
  /// new ones. Switching a host from SFTP to SCP is where it shows: the
  /// browser lists, and every download queued from it fails on a host that has
  /// no SFTP subsystem.
  ///
  /// Falls back to the snapshot for a server that has since been deleted,
  /// which is the one case the provider has nothing to say about.
  Spi get _current {
    try {
      return ref.read(serverProvider(_spi.id)).spi;
    } catch (e) {
      Loggers.app.warning('No live server for ${_spi.id}', e);
      return _spi;
    }
  }

  /// [SshFileRef.forServer] on [_current].
  SshFileRef _refOf(String path) => SshFileRef.forServer(_current, path);

  @override
  void dispose() {
    _release(_start);
    _sudoMode.dispose();
    super.dispose();
  }

  /// Closes the channel this page opened, not the connection, which the server
  /// provider owns. Ignores a start that never got one.
  void _release(Future<_SftpStart> start) =>
      start.then((start) => start.backend.close()).ignore();

  void _retry() {
    _release(_start);
    final started = _open();
    setStateSafe(() {
      _start = started;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureWidget(
      future: _start,
      loading: _buildPlaceholder(UIs.centerLoading),
      error: (e, _) => _buildPlaceholder(
        PageIssueView(
          title: switch (classifyFileError(e)) {
            FileIssue.timeout => libL10n.timeout,
            FileIssue.denied => libL10n.permissionDenied,
            _ => l10n.serverUnreachable,
          },
          // Only for the one failure it can do anything about. A host with no
          // SFTP subsystem fails here on every visit and nothing else in the
          // app mentions that there is another way — see `SftpUnavailable`.
          explain: e is SftpUnavailable ? l10n.sftpUnavailableUseScp : null,
          detail: '$e',
          onRetry: _retry,
        ),
      ),
      success: (start) {
        if (start == null) return _buildPlaceholder(UIs.placeholder);
        return FileBrowserPage(
          args: FileBrowserArgs(
            backend: start.backend,
            // A server's files start at the top. Anywhere lower would be a
            // sandbox this app cannot enforce anyway.
            root: '/',
            initialPath: start.path,
            homePath: start.home,
            isPickDir: widget.args.isSelect,
            actionsSink: widget.args.actionsSink,
            onPathChanged: _onPathChanged,
            extraActions: _toolbarActions,
            createActions: _createActions,
            entryActions: _entryActions,
            pathTrailing: _sudoMode.listenVal(
              (on) => on
                  ? Icon(Icons.security, size: 16, color: UIs.primaryColor)
                  : UIs.placeholder,
            ),
            pathHistory: const _GotoHistory(),
            refOf: _refOf,
            onOpenFile: _openFile,
          ),
        );
      },
    );
  }

  /// The same chrome the browser would draw, around whatever is not a browser
  /// yet: without it a pushed page has no title and no way back while it
  /// connects.
  Widget _buildPlaceholder(Widget body) {
    if (widget.args.actionsSink != null) return Scaffold(body: body);
    return Scaffold(
      appBar: CustomAppBar(title: Text(_spi.name)),
      body: body,
    );
  }

  void _onPathChanged(String path) {
    widget.args.onPathChanged?.call(path);
    if (Stores.setting.sftpOpenLastPath.fetch()) {
      Stores.history.sftpLastPath.put(_spi.id, _normalizeSftpPath(path));
    }
  }
}

/// Where the browser opens, and on what.
class _SftpStart {
  const _SftpStart({
    required this.backend,
    required this.home,
    required this.path,
  });

  final FileBackend backend;

  /// This user's home directory, as the server reports it.
  final String home;

  /// Where to open: what the caller asked for, else where this server was left
  /// last time, else home.
  final String path;
}

extension _Open on _SftpPageState {
  Duration get _opTimeout =>
      sftpOperationTimeout(Stores.setting.timeout.fetch());

  Future<_SftpStart> _open() async {
    // [_current], not `_spi`, and read once for everything below. The page
    // holds the server as it was when the route was pushed, and a tab outlives
    // an edit — so opening has to use the settings the editor just wrote, on
    // this attempt and on every retry.
    //
    // Once, because it was three separate decisions and only one of them was
    // made this way: the transport came from `_current` while the sudo helper
    // and the home-directory guess still came off the snapshot. Changing a
    // server's SSH user and pressing Retry then opened the protocol the user
    // had chosen and asked for a password labelled with the account they had
    // just moved away from.
    final spi = _current;

    // `ensureShellClient`, not `state.client`: pressing a server's file button
    // is asking to reach it, so a server that is merely not connected yet
    // connects rather than reporting that it is not connected — and Retry
    // then does something, where re-reading a provider that has not changed
    // could only fail again.
    //
    // This is also where `initState` used to read `state.client!` and crash
    // the page red. The file tab restores its sessions on the first frame,
    // while the provider is still connecting, so a relaunch with a server tab
    // open hit that null every time. As a failure of `_open` it lands in the
    // error branch this page already draws.
    final client = await ref
        .read(serverProvider(spi.id).notifier)
        .ensureShellClient();
    _client = client;
    _sudoHelper = SftpSudoHelper(
      client: client,
      spi: spi,
      contextProvider: () => mounted ? context : null,
    );
    _escalation = _SudoEscalation(
      helper: _sudoHelper,
      mode: _sudoMode,
      contextProvider: () => mounted ? context : null,
    );

    final backend = await openSshFileBackend(
      _client,
      transport: spi.ssh?.fileTransport ?? SshFileTransport.sftp,
      escalation: _escalation,
      timeout: _opTimeout,
    );
    final home = await _homeDir(spi);
    return _SftpStart(
      backend: backend,
      home: home,
      // Checked like the other three. The file tab restores a session by
      // passing its saved directory as `initPath`, and one that has since been
      // deleted or become unreadable opened the browser straight onto a
      // listing error with nothing to press — for as long as the tab was
      // remembered, which is every launch.
      path:
          await _openable(backend, widget.args.initPath) ??
          await _lastPath(backend) ??
          await _openable(backend, home) ??
          '/',
    );
  }

  /// [path] if it can be listed, else null.
  ///
  /// The remembered path has always been checked this way; the home directory
  /// was not, and a home that cannot be listed is not rare — a user whose home
  /// is `/root` by way of the fallback below, an account with no home on this
  /// host, a chrooted SFTP subsystem. Unchecked it opened the browser onto a
  /// permission error every single time, with nothing to press: the roots
  /// offered by that error view come from a monitor agent, and this is SFTP.
  ///
  /// `/` is the last resort rather than a failure. It is the same place the
  /// browser's root already is, so going up from anywhere reaches it anyway.
  Future<String?> _openable(FileBackend backend, String? path) async {
    if (path == null) return null;
    try {
      await backend.list(path);
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Asked of the server rather than assumed: a user's home is wherever
  /// `passwd` says it is, and only the guess is `/home/<user>`.
  ///
  /// [spi] is passed in rather than read off the page, which held the snapshot
  /// the tab was opened with: after an edit the fallback named the old user's
  /// home even though the connection was the new user's.
  Future<String> _homeDir(Spi spi) async {
    final user = spi.ssh?.user ?? '';
    final fallback = user == 'root' ? '/root' : '/home/$user';
    try {
      final result = await _client.run(
        'getent passwd -- ${shellSingleQuote(user)}',
      );
      final home = result.string.trim().split(':').elementAtOrNull(5)?.trim();
      if (home != null && home.isNotEmpty && home.startsWith('/')) return home;
    } catch (_) {
      // A server without `getent`, or one that refused to run anything. The
      // guess is still better than refusing to open.
    }
    return fallback;
  }

  /// Where this server was left, if it is still listable — a remembered path
  /// that has since been deleted should not be what the browser opens into.
  Future<String?> _lastPath(FileBackend backend) async {
    if (!Stores.setting.sftpOpenLastPath.fetch()) return null;
    final remembered = Stores.history.sftpLastPath.fetch(_spi.id);
    if (remembered == null) return null;
    return _openable(backend, _normalizeSftpPath(remembered));
  }
}

extension _Actions on _SftpPageState {
  List<Widget> _toolbarActions(FileBrowserHandle handle) => [
    Btn.icon(text: libL10n.mission, 
      icon: const Icon(Icons.downloading),
      onTap: () => showTransfers(context),
    ),
    if (_sudoHelper.enabled)
      _sudoMode.listenVal(
        (on) => IconButton(
          tooltip: l10n.trySudo,
          onPressed: () {
            _sudoMode.value = !on;
            handle.refresh();
          },
          icon: Icon(Icons.security, color: on ? UIs.primaryColor : null),
        ),
      ),
  ];

  /// Uploading is done to the directory, not to a file in it.
  List<ContextMenuAction> _createActions(FileBrowserHandle handle) => [
    ContextMenuAction(
      icon: Icons.upload_file,
      text: libL10n.upload,
      onTap: () => _upload(handle),
    ),
  ];

  List<ContextMenuAction> _entryActions(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  ) => [
    if (!entry.isDir) ...[
      ContextMenuAction(
        icon: Icons.edit,
        text: libL10n.edit,
        onTap: () => _edit(handle, entry, fullPath),
      ),
      ContextMenuAction(
        icon: Icons.download,
        text: libL10n.download,
        onTap: () => _download(entry, fullPath),
      ),
      if (_canDecompress(entry.name))
        ContextMenuAction(
          icon: Icons.folder_zip,
          text: libL10n.decompress,
          onTap: () => _decompress(handle, entry, fullPath),
        ),
    ],
  ];

  void _openFile(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  ) => _edit(handle, entry, fullPath);

  /// Local file dir + server id + remote path.
  String _localPathFor(String remotePath) {
    final parts = remotePath.split('/').where((part) => part.isNotEmpty);
    return parts.fold(
      Paths.file.joinPath(_spi.id),
      (path, part) => path.joinPath(_safeLocalPathPart(part)),
    );
  }

  void _download(FileEntry entry, String fullPath) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text('${l10n.dl2Local(entry.name)}\n${l10n.keepForeground}'),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () async {
            context.popDialog();
            // The transfer worker creates the destination itself, but it runs
            // in an isolate — and on desktop the first write into
            // [Paths.file] is what raises the documents-folder prompt. Doing
            // it here means a refusal is answered by this page, in front of
            // the user who just asked for the download.
            try {
              await LocalFiles.ensure();
            } catch (e, s) {
              Loggers.app.warning('Prepare ${Paths.file}', e, s);
              if (mounted) context.showErrDialog(e, s);
              return;
            }
            if (!mounted) return;
            ref
                .read(fileTransferProvider.notifier)
                .add(
                  FileTransfer(
                    from: _refOf(fullPath),
                    to: LocalFileRef(_localPathFor(fullPath)),
                  ),
                );
          },
          child: Text(libL10n.download),
        ),
      ],
    );
  }

  Future<void> _upload(FileBrowserHandle handle) async {
    final from = await context.showRoundDialog<int>(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Btn.tile(
            icon: const Icon(Icons.open_in_new),
            text: libL10n.system,
            onTap: () => context.popDialog(1),
          ),
          Btn.tile(
            icon: const Icon(Icons.folder),
            text: libL10n.inner,
            onTap: () => context.popDialog(0),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final local = switch (from) {
      0 => await LocalFilePage.route.go(
        context,
        args: const LocalFilePageArgs(isPickFile: true),
      ),
      1 => await Pfs.pickFilePath(),
      _ => null,
    };
    if (local == null || !mounted) return;

    final name = local.split(Platform.pathSeparator).lastOrNull;
    if (name == null || name.isEmpty) return;
    final remote = '${handle.path}/$name';
    Loggers.app.info('SFTP upload local: $local, remote: $remote');

    if (!_sudoMode.value) {
      // Asked before the transfer starts rather than after it fails: an upload
      // is a queued job, and a job that dies on the far side reports its
      // refusal in a list nobody is looking at.
      if (await _canWrite(handle.path)) {
        ref
            .read(fileTransferProvider.notifier)
            .add(
              FileTransfer(
                from: LocalFileRef(local),
                to: _refOf(remote),
              ),
            );
        return;
      }
      if (!mounted || !await _escalation.confirmRetry()) return;
    }

    final ok = await _uploadViaSudo(local: local, remote: remote, name: name);
    if (ok) await handle.refresh();
  }

  Future<bool> _canWrite(String dir) async {
    final (code, _) = await _client.execWithPwd(
      'test -w ${shellSingleQuote(dir)}',
      context: context,
      id: '${_spi.id}_sftp_write_probe',
    );
    return code == 0;
  }

  /// Uploads somewhere this user cannot write: to `/tmp` as themselves, then
  /// into place as root. SFTP has no way to write a file it is refused, and
  /// piping the bytes through a shell would be a base64 round trip.
  Future<bool> _uploadViaSudo({
    required String local,
    required String remote,
    required String name,
  }) async {
    final pwd = await _sudoHelper.ensurePassword();
    if (pwd == null || !mounted) return false;

    final staging = '/tmp/serverbox-upload-'
        '${DateTime.now().microsecondsSinceEpoch}-$name';
    final completer = Completer<bool>();
    final reqId = ref
        .read(fileTransferProvider.notifier)
        .add(
          FileTransfer(
            from: LocalFileRef(local),
            to: _refOf(staging),
          ),
          completer: completer,
        );

    final (moved, err) = await context.showLoadingDialog(
      // No timeout: this waits for a transfer, whose length is the file's
      // business and not this dialog's.
      timeout: null,
      fn: () async {
        // The two checks answer different questions. A failed transfer leaves
        // its error on the row; a cancelled one takes the row with it, and
        // only the completer's own answer says so. Renaming after either would
        // put a partial file — or nothing at all — over the destination as
        // root.
        final finished = await completer.future;
        final status = ref.read(fileTransferProvider.notifier).get(reqId);
        if (status?.error != null) throw status!.error!;
        if (!finished) return false;
        await _sudoHelper.rename(staging, remote, password: pwd);
        return true;
      },
    );
    if (moved == true && err == null) {
      _sudoMode.value = true;
      return true;
    }

    try {
      await _sudoHelper.delete(
        staging,
        isDir: false,
        recursive: false,
        password: pwd,
      );
    } catch (_) {
      // Best effort: a leftover in `/tmp` is not worth a second error dialog
      // over the one the user is already reading.
    }
    return false;
  }

  Future<void> _decompress(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  ) async {
    final cmd = _getDecompressCmd(fullPath);
    if (cmd == null) {
      context.showRoundDialog(
        title: libL10n.error,
        child: Text('${libL10n.unsupported}: ${entry.name}'),
        actions: Btnx.oks,
      );
      return;
    }

    final confirm = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: SimpleMarkdown(data: '```sh\n$cmd\n```'),
      actions: Btnx.cancelRedOk,
    );
    if (confirm != true || !mounted) return;

    // In a terminal rather than silently: unpacking can take a while, can ask
    // about overwriting, and can fail in ways only its own output explains.
    await SSHPage.route.go(
      context,
      SshPageArgs(source: ServerSource(_spi), initCmd: 'cd ${shellSingleQuote(handle.path)} && $cmd'),
    );
    await handle.refresh();
  }
}

extension _Edit on _SftpPageState {
  /// Opens a file for editing.
  ///
  /// Three ways, in order: the terminal editor somebody configured (#489),
  /// then — for a file this user cannot read — a `cat` through sudo, and
  /// otherwise a plain download. All three end with the file back on the
  /// server if it was changed.
  Future<void> _edit(
    FileBrowserHandle handle,
    FileEntry entry,
    String remotePath,
  ) async {
    final useSudo = _sudoMode.value && _sudoHelper.enabled;

    final editor = Stores.setting.sftpEditor.fetch();
    if (editor.isNotEmpty) {
      final cmd =
          '${useSudo ? 'sudo ' : ''}$editor ${shellSingleQuote(remotePath)}';
      await SSHPage.route.go(
        context,
        SshPageArgs(source: ServerSource(_spi), initCmd: cmd),
      );
      await handle.refresh();
      return;
    }

    final size = await _sizeFor(entry, remotePath, useSudo: useSudo);
    if (size == null || !mounted) return;
    if (size > Miscs.editorMaxSize) {
      Toast.show(
        l10n.fileTooLarge(entry.name, size, Miscs.editorMaxSize),
      );
      return;
    }

    final localPath = _localPathFor(remotePath);
    if (!await _fetch(remotePath, localPath, useSudo: useSudo)) return;
    if (!mounted) return;

    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        path: localPath,
        onSave: (_) => _saveBack(handle, localPath, remotePath, useSudo),
        closeAfterSave: Stores.setting.closeAfterSave.fetch(),
        softWrap: Stores.setting.editorSoftWrap.fetch(),
        enableHighlight: Stores.setting.editorHighlight.fetch(),
        lightTheme: HighlightTheme.fromThemeMapKey(
          Stores.setting.editorTheme.fetch(),
        ),
        darkTheme: HighlightTheme.fromThemeMapKey(
          Stores.setting.editorDarkTheme.fetch(),
        ),
        fontFamily: () {
          final font = Stores.setting.editorFontFamily.fetch();
          return font.isEmpty ? null : font;
        }(),
      ),
    );
  }

  /// The size, or null if the user gave up on the way to finding it out.
  Future<int?> _sizeFor(
    FileEntry entry,
    String remotePath, {
    required bool useSudo,
  }) async {
    if (!useSudo) return entry.size ?? 0;
    final pwd = await _sudoHelper.ensurePassword();
    if (pwd == null || !mounted) return null;
    final (size, err) = await context.showLoadingDialog(
      fn: () => _sudoHelper.getFileSize(remotePath, password: pwd),
    );
    return err == null ? size : null;
  }

  Future<bool> _fetch(
    String remotePath,
    String localPath, {
    required bool useSudo,
  }) async {
    if (useSudo) {
      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null || !mounted) return false;
      final (_, err) = await context.showLoadingDialog(
        fn: () async {
          await _sudoHelper.downloadTextFile(
            remotePath,
            localPath,
            password: pwd,
          );
          return true;
        },
      );
      return err == null;
    }

    final completer = Completer<bool>();
    final id = ref
        .read(fileTransferProvider.notifier)
        .add(
          FileTransfer(
            from: _refOf(remotePath),
            to: LocalFileRef(localPath),
          ),
          completer: completer,
        );
    final (opened, err) = await context.showLoadingDialog(
      timeout: null,
      fn: () async {
        // The completer says "this transfer is over", not "it worked":
        // `dispose()` answers it on failure and on cancellation too. Without
        // both checks, a download that failed opened the editor on a file that
        // was missing or left over from a previous session — and saving it
        // uploaded that back. A cancelled one leaves no row to carry the
        // error, which is what the completer's own answer is for.
        final finished = await completer.future;
        final status = ref.read(fileTransferProvider.notifier).get(id);
        if (status?.error != null) throw status!.error!;
        return finished;
      },
    );
    return opened == true && err == null;
  }

  Future<void> _saveBack(
    FileBrowserHandle handle,
    String localPath,
    String remotePath,
    bool useSudo,
  ) async {
    if (!useSudo) {
      final id = ref
          .read(fileTransferProvider.notifier)
          .add(
            FileTransfer(
              from: LocalFileRef(localPath),
              to: _refOf(remotePath),
            ),
          );
      await announceQueued(context, ref, [id]);
      return;
    }

    final pwd = await _sudoHelper.ensurePassword();
    if (pwd == null || !mounted) return;
    final (_, err) = await context.showLoadingDialog(
      fn: () async {
        await _sudoHelper.uploadTextFile(localPath, remotePath, password: pwd);
        return true;
      },
    );
    if (err != null || !mounted) return;
    Toast.success(libL10n.success);
    await handle.refresh();
  }
}

/// [SftpEscalation] over the sudo helper.
///
/// The helper knows how to get a password and run a command with it; this says
/// when that is worth offering, and remembers that it worked.
final class _SudoEscalation implements SftpEscalation {
  const _SudoEscalation({
    required this.helper,
    required this.mode,
    required this.contextProvider,
  });

  final SftpSudoHelper helper;
  final ValueNotifier<bool> mode;
  final BuildContext? Function() contextProvider;

  @override
  bool get available => helper.enabled;

  @override
  bool get always => mode.value;

  @override
  Future<bool> confirmRetry() async {
    final context = contextProvider();
    if (context == null) return false;
    final retry = await context.showRoundDialog<bool>(
      title: l10n.trySudo,
      child: Text(
        '${libL10n.permissionDenied}\n${libL10n.askContinue(l10n.trySudo)}',
      ),
      actions: Btnx.cancelRedOk,
    );
    return retry == true;
  }

  @override
  Future<String> run(String command) => helper.runAsRoot(command);

  @override
  void onEscalated() => mode.value = true;
}

/// Where the goto dialog's suggestions come from.
final class _GotoHistory implements BrowsePathHistory {
  const _GotoHistory();

  @override
  List<String> get all => Stores.setting.recordHistory.fetch()
      ? Stores.history.sftpGoPath.all.cast<String>()
      : const [];

  @override
  void add(String path) {
    if (!Stores.setting.recordHistory.fetch()) return;
    Stores.history.sftpGoPath.add(path);
  }
}
