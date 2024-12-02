import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/worker.dart';
import 'package:server_box/data/provider/server.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/res/misc.dart';

import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/path_with_prefix.dart';
import 'package:server_box/view/page/editor.dart';

final class LocalFilePageArgs {
  final bool? isPickFile;
  final String? initDir;
  const LocalFilePageArgs({
    this.isPickFile,
    this.initDir,
  });
}

class LocalFilePage extends StatefulWidget {
  final LocalFilePageArgs? args;

  const LocalFilePage({super.key, this.args});

  static const route = AppRoute<String, LocalFilePageArgs>(
    page: LocalFilePage.new,
    path: '/local_file',
  );

  @override
  State<LocalFilePage> createState() => _LocalFilePageState();
}

class _LocalFilePageState extends State<LocalFilePage>
    with AutomaticKeepAliveClientMixin {
  late final _path = LocalPath(widget.args?.initDir ?? Paths.file);
  final _sortType = _SortType.name.vn;
  bool get isPickFile => widget.args?.isPickFile ?? false;

  @override
  void dispose() {
    super.dispose();
    _sortType.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final title = _path.path.fileNameGetter ?? libL10n.file;
    return Scaffold(
      appBar: CustomAppBar(
        title: AnimatedSwitcher(
          duration: Durations.short3,
          child: Text(title, key: ValueKey(title)),
        ),
        actions: [
          if (!isPickFile)
            IconButton(
              onPressed: () async {
                final path = await Pfs.pickFilePath();
                if (path == null) return;
                final name = path.getFileName() ?? 'imported';
                final destinationDir = Directory(_path.path);
                if (!await destinationDir.exists()) {
                  await destinationDir.create(recursive: true);
                }
                await File(path).copy(_path.path.joinPath(name));
                setState(() {});
              },
              icon: const Icon(Icons.add),
            ),
          if (!isPickFile) _buildMissionBtn(),
          _buildSortBtn(),
        ],
      ),
      body: _sortType.listen(_buildBody),
    );
  }

  Widget _buildBody() {
    Future<List<(FileSystemEntity, FileStat)>> getEntities() async {
      final files = await Directory(_path.path).list().toList();
      final sorted = _sortType.value.sort(files);
      final stats = await Future.wait(
        sorted.map((e) async => (e, await e.stat())),
      );
      return stats;
    }

    return FutureWidget(
      future: getEntities(),
      loading: UIs.placeholder,
      success: (items_) {
        final items = items_ ?? [];
        final len = _path.canBack ? items.length + 1 : items.length;
        return ListView.builder(
          itemCount: len,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
          itemBuilder: (context, index) {
            if (index == 0 && _path.canBack) {
              return CardX(
                child: ListTile(
                  leading: const Icon(Icons.arrow_back),
                  title: const Text('..'),
                  onTap: () {
                    _path.update('..');
                    setState(() {});
                  },
                ),
              );
            }

            if (_path.canBack) index--;

            final item = items[index];
            final file = item.$1;
            final fileName = file.path.split('/').last;
            final stat = item.$2;
            final isDir = stat.type == FileSystemEntityType.directory;

            return CardX(
              child: ListTile(
                leading: isDir
                    ? const Icon(Icons.folder_open)
                    : const Icon(Icons.insert_drive_file),
                title: Text(fileName),
                subtitle: isDir
                    ? null
                    : Text(stat.size.bytes2Str, style: UIs.textGrey),
                trailing: Text(
                  stat.modified.ymdhms(),
                  style: UIs.textGrey,
                ),
                onLongPress: () {
                  if (isDir) {
                    _showDirActionDialog(file);
                    return;
                  }
                  _showFileActionDialog(file);
                },
                onTap: () {
                  if (!isDir) {
                    _showFileActionDialog(file);
                    return;
                  }
                  _path.update(fileName);
                  setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDirActionDialog(FileSystemEntity file) async {
    context.showRoundDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              context.pop();
              _showRenameDialog(file);
            },
            title: Text(libL10n.rename),
            leading: const Icon(Icons.abc),
          ),
          ListTile(
            onTap: () {
              context.pop();
              _showDeleteDialog(file);
            },
            title: Text(libL10n.delete),
            leading: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showFileActionDialog(FileSystemEntity file) async {
    final fileName = file.path.split('/').last;
    if (isPickFile) {
      context.showRoundDialog(
        title: libL10n.file,
        child: Text(fileName),
        actions: [
          Btn.ok(onTap: () {
            context.pop();
            context.pop(file.path);
          }),
        ],
      );
      return;
    }
    context.showRoundDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Btn.tile(
            icon: const Icon(Icons.edit),
            text: libL10n.edit,
            onTap: () async {
              context.pop();
              final stat = await file.stat();
              if (stat.size > Miscs.editorMaxSize) {
                context.showRoundDialog(
                  title: libL10n.attention,
                  child: Text(l10n.fileTooLarge(fileName, stat.size, '1m')),
                );
                return;
              }
              final ret = await EditorPage.route.go(
                context,
                args: EditorPageArgs(path: file.absolute.path),
              );
              if (ret?.editExistedOk == true) {
                context.showSnackBar(l10n.saved);
                setState(() {});
              }
            },
          ),
          Btn.tile(
            icon: const Icon(Icons.abc),
            text: libL10n.rename,
            onTap: () {
              context.pop();
              _showRenameDialog(file);
            },
          ),
          Btn.tile(
            icon: const Icon(Icons.delete),
            text: libL10n.delete,
            onTap: () {
              context.pop();
              _showDeleteDialog(file);
            },
          ),
          Btn.tile(
            icon: const Icon(Icons.upload),
            text: l10n.upload,
            onTap: () async {
              context.pop();

              final spi = await context.showPickSingleDialog<Spi>(
                title: libL10n.select,
                items: ServerProvider.serverOrder.value
                    .map((e) => ServerProvider.pick(id: e)?.value.spi)
                    .whereType<Spi>()
                    .toList(),
                display: (e) => e.name,
              );
              if (spi == null) return;

              final remotePath = await AppRoutes.sftp(
                spi: spi,
                isSelect: true,
              ).go<String>(context);
              if (remotePath == null) {
                return;
              }

              SftpProvider.add(SftpReq(
                spi,
                '$remotePath/$fileName',
                file.absolute.path,
                SftpReqType.upload,
              ));
              context.showSnackBar(l10n.added2List);
            },
          ),
          Btn.tile(
            icon: const Icon(Icons.open_in_new),
            text: libL10n.open,
            onTap: () {
              Pfs.share(path: file.absolute.path);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileSystemEntity file) {
    final fileName = file.path.split(Pfs.seperator).last;
    final ctrl = TextEditingController(text: fileName);
    void onSubmit() async {
      final newName = ctrl.text;
      if (newName.isEmpty) {
        context.showSnackBar(libL10n.empty);
        return;
      }

      context.pop();
      final newPath = '${file.parent.path}${Pfs.seperator}$newName';
      await context.showLoadingDialog(fn: () => file.rename(newPath));

      setState(() {});
    }

    context.showRoundDialog(
      title: libL10n.rename,
      child: Input(
        autoFocus: true,
        icon: Icons.abc,
        label: libL10n.name,
        controller: ctrl,
        suggestion: true,
        maxLines: 3,
        onSubmitted: (p0) => onSubmit(),
      ),
      actions: Btn.ok(onTap: onSubmit).toList,
    );
  }

  void _showDeleteDialog(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    context.showRoundDialog(
      title: libL10n.delete,
      child: Text(libL10n.askContinue('${libL10n.delete} $fileName')),
      actions: Btn.ok(
        onTap: () async {
          context.pop();
          try {
            await file.delete(recursive: true);
          } catch (e) {
            context.showSnackBar('${libL10n.fail}:\n$e');
            return;
          }
          setState(() {});
        },
      ).toList,
    );
  }

  Widget _buildMissionBtn() {
    return IconButton(
      icon: const Icon(Icons.downloading),
      onPressed: () => AppRoutes.sftpMission().go(context),
    );
  }

  Widget _buildSortBtn() {
    return _sortType.listenVal(
      (value) {
        return PopupMenuButton<_SortType>(
          icon: const Icon(Icons.sort),
          itemBuilder: (_) => _SortType.values.map((e) => e.menuItem).toList(),
          onSelected: (value) {
            _sortType.value = value;
          },
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;
}

enum _SortType {
  name,
  size,
  time,
  ;

  List<FileSystemEntity> sort(List<FileSystemEntity> files) {
    switch (this) {
      case _SortType.name:
        files.sort((a, b) => a.path.compareTo(b.path));
        break;
      case _SortType.size:
        files.sort((a, b) => a.statSync().size.compareTo(b.statSync().size));
        break;
      case _SortType.time:
        files.sort(
            (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
        break;
    }
    return files;
  }

  String get i18n => switch (this) {
        name => libL10n.name,
        size => l10n.size,
        time => l10n.time,
      };

  IconData get icon => switch (this) {
        name => Icons.sort_by_alpha,
        size => Icons.sort,
        time => Icons.access_time,
      };

  PopupMenuItem<_SortType> get menuItem {
    return PopupMenuItem(
      value: this,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(icon),
          Text(i18n),
        ],
      ),
    );
  }
}
