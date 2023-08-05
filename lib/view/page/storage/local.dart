import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/data/model/sftp/req.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/editor.dart';
import 'package:toolbox/view/page/storage/sftp.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/picker.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../../core/extension/numx.dart';
import '../../../core/extension/stringx.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/app/path_with_prefix.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../widget/fade_in.dart';
import 'sftp_mission.dart';

class LocalStoragePage extends StatefulWidget {
  final bool isPickFile;
  final String? initDir;
  const LocalStoragePage({Key? key, this.isPickFile = false, this.initDir})
      : super(key: key);

  @override
  State<LocalStoragePage> createState() => _LocalStoragePageState();
}

class _LocalStoragePageState extends State<LocalStoragePage> {
  PathWithPrefix? _path;
  late S _s;

  @override
  void initState() {
    super.initState();
    if (widget.initDir != null) {
      setState(() {
        _path = PathWithPrefix(widget.initDir!);
      });
    } else {
      sftpDir.then((dir) {
        setState(() {
          _path = PathWithPrefix(dir.path);
        });
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.download),
        actions: [
          IconButton(
            icon: const Icon(Icons.downloading),
            onPressed: () =>
                AppRoute(const SftpMissionPage(), 'sftp downloading')
                    .go(context),
          )
        ],
      ),
      body: FadeIn(
        key: UniqueKey(),
        child: _buildBody(),
      ),
      bottomNavigationBar: SafeArea(child: _buildPath()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final path = await pickOneFile();
          if (path == null) return;
          final name = getFileName(path) ?? 'imported';
          await File(path).copy(pathJoin(_path!.path, name));
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPath() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          (_path?.path ?? _s.loadingFiles).omitStartStr(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_path == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    final dir = Directory(_path!.path);
    final files = dir.listSync();
    final canGoBack = _path!.canBack;
    if (files.isEmpty) {
      return const Center(
        child: Text('~'),
      );
    }
    return ListView.builder(
      itemCount: canGoBack ? files.length + 1 : files.length,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
      itemBuilder: (context, index) {
        if (index == 0 && canGoBack) {
          return RoundRectCard(ListTile(
            leading: const Icon(Icons.keyboard_arrow_left),
            title: const Text('..'),
            onTap: () {
              _path!.update('..');
              setState(() {});
            },
          ));
        }
        index = canGoBack ? index - 1 : index;
        var file = files[index];
        var fileName = file.path.split('/').last;
        var stat = file.statSync();
        var isDir = stat.type == FileSystemEntityType.directory;

        return RoundRectCard(ListTile(
          leading: isDir
              ? const Icon(Icons.folder)
              : const Icon(Icons.insert_drive_file),
          title: Text(fileName),
          subtitle: isDir ? null : Text(stat.size.convertBytes, style: grey),
          trailing: Text(
            stat.modified
                .toString()
                .substring(0, stat.modified.toString().length - 4),
            style: grey,
          ),
          onLongPress: () {
            if (!isDir) return;
            _showDirActionDialog(file);
          },
          onTap: () async {
            if (!isDir) {
              await _showFileActionDialog(file);
              return;
            }
            _path!.update(fileName);
            setState(() {});
          },
        ));
      },
    );
  }

  Future<void> _showDirActionDialog(FileSystemEntity file) async {
    showRoundDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            onTap: () {
              context.pop();
              _showRenameDialog(file);
            },
            title: Text(_s.rename),
            leading: const Icon(Icons.abc),
          ),
          ListTile(
            onTap: () {
              context.pop();
              _showDeleteDialog(file);
            },
            title: Text(_s.delete),
            leading: const Icon(Icons.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _showFileActionDialog(FileSystemEntity file) async {
    final fileName = file.path.split('/').last;
    if (widget.isPickFile) {
      await showRoundDialog(
          context: context,
          title: Text(_s.pickFile),
          child: Text(fileName),
          actions: [
            TextButton(
              onPressed: () {
                context.pop();
                context.pop(file.path);
              },
              child: Text(_s.ok),
            ),
          ]);
      return;
    }
    showRoundDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(_s.edit),
            onTap: () async {
              context.pop();
              final stat = await file.stat();
              if (stat.size > editorMaxSize) {
                showRoundDialog(
                  context: context,
                  title: Text(_s.attention),
                  child: Text(_s.fileTooLarge(fileName, stat.size, '1m')),
                );
                return;
              }
              final result = await AppRoute(
                EditorPage(
                  path: file.absolute.path,
                ),
                'sftp dled editor',
              ).go<String>(context);
              final f = File(file.absolute.path);
              if (result != null) {
                f.writeAsString(result);
                showSnackBar(context, Text(_s.saved));
                setState(() {});
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.abc),
            title: Text(_s.rename),
            onTap: () {
              context.pop();
              _showRenameDialog(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(_s.delete),
            onTap: () {
              context.pop();
              _showDeleteDialog(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(_s.upload),
            onTap: () async {
              context.pop();
              final serverProvider = locator<ServerProvider>();
              final ids = serverProvider.serverOrder;
              var idx = 0;
              await showRoundDialog(
                context: context,
                title: Text(_s.server),
                child: Picker(
                  items: ids.map((e) => Text(e)).toList(),
                  onSelected: (idx_) => idx = idx_,
                ),
                actions: [
                  TextButton(
                      onPressed: () => context.pop(), child: Text(_s.ok)),
                ],
              );
              final id = ids[idx];
              final spi = serverProvider.servers[id]?.spi;
              if (spi == null) {
                return;
              }
              final remotePath = await AppRoute(
                SftpPage(
                  spi,
                  selectPath: true,
                ),
                'SFTP page (select)',
              ).go<String>(context);
              if (remotePath == null) {
                return;
              }
              locator<SftpProvider>().add(SftpReq(
                spi,
                remotePath,
                file.absolute.path,
                SftpReqType.upload,
              ));
              showSnackBar(context, Text(_s.added2List));
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: Text(_s.open),
            onTap: () {
              shareFiles(context, [file.absolute.path]);
            },
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    showRoundDialog(
      context: context,
      title: Text(_s.rename),
      child: Input(
        controller: TextEditingController(text: fileName),
        onSubmitted: (p0) {
          context.pop();
          final newPath = '${file.parent.path}/$p0';
          try {
            file.renameSync(newPath);
          } catch (e) {
            showSnackBar(context, Text('${_s.failed}:\n$e'));
            return;
          }

          setState(() {});
        },
      ),
    );
  }

  void _showDeleteDialog(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    showRoundDialog(
      context: context,
      title: Text(_s.delete),
      child: Text(_s.sureDelete(fileName)),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () {
            context.pop();
            try {
              file.deleteSync(recursive: true);
            } catch (e) {
              showSnackBar(context, Text('${_s.failed}:\n$e'));
              return;
            }
            setState(() {});
          },
          child: Text(_s.ok),
        ),
      ],
    );
  }
}
