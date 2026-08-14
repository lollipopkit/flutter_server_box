import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/req.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/storage/file_browser.dart';
import 'package:server_box/view/page/storage/sftp.dart';
import 'package:server_box/view/page/storage/sftp_mission.dart';

final class LocalFilePageArgs {
  final bool? isPickFile;

  /// Where to open. Was the *root* until the browser told the two apart, which
  /// is why a tab reopened deep in a tree could not go up.
  final String? initDir;

  /// Where to put this page's toolbar, for a host that draws a bar of its own.
  final ValueNotifier<List<Widget>>? actionsSink;

  /// Told which directory is being shown, as it changes.
  final void Function(String path)? onPathChanged;

  const LocalFilePageArgs({
    this.isPickFile,
    this.initDir,
    this.actionsSink,
    this.onPathChanged,
  });
}

/// This device's files.
///
/// A [FileBrowserPage] over [LocalFileBackend], plus the four things that are
/// only true here: importing from the system picker, sharing out, opening the
/// editor, and knowing that a folder named after a server id is that server's
/// downloads.
class LocalFilePage extends ConsumerStatefulWidget {
  final LocalFilePageArgs? args;

  const LocalFilePage({super.key, this.args});

  static const route = AppRoute<String, LocalFilePageArgs>(
    page: LocalFilePage.new,
    path: '/files/local',
  );

  @override
  ConsumerState<LocalFilePage> createState() => _LocalFilePageState();
}

class _LocalFilePageState extends ConsumerState<LocalFilePage> {
  static const _backend = LocalFileBackend();

  bool get _isPickFile => widget.args?.isPickFile ?? false;

  @override
  Widget build(BuildContext context) {
    return FileBrowserPage(
      args: FileBrowserArgs(
        backend: _backend,
        // Everything this app writes lives under here, and there is nothing
        // above it worth browsing on a sandboxed platform.
        root: Paths.file,
        initialPath: widget.args?.initDir,
        isPickFile: _isPickFile,
        actionsSink: widget.args?.actionsSink,
        onPathChanged: widget.args?.onPathChanged,
        extraActions: _actions,
        bottomActions: _bottomActions,
        entryActions: _entryActions,
        labelOf: _labelOf,
        onOpenFile: _isPickFile ? null : _openEditor,
      ),
    );
  }

  List<Widget> _actions(FileBrowserHandle handle) => [
    IconButton(
      icon: const Icon(Icons.downloading),
      onPressed: () => SftpMissionPage.route.go(context),
    ),
  ];

  /// Beside the browser's own "new file / new folder", because bringing a file
  /// in from elsewhere on this device is the same kind of act as making one.
  List<Widget> _bottomActions(FileBrowserHandle handle) => [
    if (!_isPickFile)
      Btn.icon(
        icon: const Icon(Icons.file_download),
        onTap: () => _import(handle),
      ),
  ];

  List<Widget> _entryActions(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  ) => [
    if (!entry.isDir) ...[
      if (isMobile)
        Btn.tile(
          icon: const Icon(Icons.edit),
          text: libL10n.edit,
          onTap: () {
            context.popDialog();
            _openEditor(handle, entry, fullPath);
          },
        ),
      Btn.tile(
        icon: const Icon(Icons.upload),
        text: libL10n.upload,
        onTap: () {
          context.popDialog();
          _upload(entry, fullPath);
        },
      ),
      Btn.tile(
        icon: const Icon(Icons.open_in_new),
        text: libL10n.open,
        onTap: () {
          context.popDialog();
          Pfs.sharePaths(paths: [LocalFileBackend.nativePath(fullPath)]);
        },
      ),
    ],
  ];

  /// A directory directly under [Paths.file] named after a server id is that
  /// server's downloads, and its id is not what anyone calls it.
  String? _labelOf(FileEntry entry, String fullPath) {
    if (!entry.isDir) return null;
    final parent = fullPath.substring(0, fullPath.length - entry.name.length - 1);
    if (parent.replaceAll(r'\', '/') != Paths.file.replaceAll(r'\', '/')) {
      return null;
    }
    return ref.read(serversProvider).servers[entry.name]?.name;
  }

  Future<void> _import(FileBrowserHandle handle) async {
    final picked = await Pfs.pickFilePath();
    if (picked == null) return;
    final name = picked.getFileName() ?? 'imported';
    final destination = Directory(LocalFileBackend.nativePath(handle.path));
    if (!await destination.exists()) {
      await destination.create(recursive: true);
    }
    await File(picked).copy(
      LocalFileBackend.nativePath('${handle.path}/$name'),
    );
    await handle.refresh();
  }

  Future<void> _openEditor(
    FileBrowserHandle handle,
    FileEntry entry,
    String fullPath,
  ) async {
    final size = entry.size ?? (await _backend.stat(fullPath))?.size ?? 0;
    if (size > Miscs.editorMaxSize) {
      if (!mounted) return;
      context.showRoundDialog(
        title: libL10n.attention,
        child: Text(l10n.fileTooLarge(entry.name, size, '1m')),
      );
      return;
    }
    if (!mounted) return;

    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        path: LocalFileBackend.nativePath(fullPath),
        onSave: (_) {
          context.showSnackBar(libL10n.saved);
          handle.refresh();
        },
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

  Future<void> _upload(FileEntry entry, String fullPath) async {
    final spi = await context.showPickSingleDialog<Spi>(
      title: libL10n.select,
      items: ref.read(serversProvider).servers.values.toList(),
      display: (e) => e.name,
    );
    if (spi == null || !mounted) return;

    final remotePath = await SftpPage.route.go(
      context,
      SftpPageArgs(spi: spi, isSelect: true),
    );
    if (remotePath == null || !mounted) return;

    ref
        .read(sftpProvider.notifier)
        .add(
          SftpReq(
            spi,
            '$remotePath/${entry.name}',
            LocalFileBackend.nativePath(fullPath),
            SftpReqType.upload,
          ),
        );
    context.showSnackBar(l10n.added2List);
  }
}
