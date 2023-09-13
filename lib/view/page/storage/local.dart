import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/context.dart';
import 'package:toolbox/data/model/sftp/req.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/sftp.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/picker.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

import '../../../core/extension/numx.dart';
import '../../../core/extension/stringx.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../data/model/app/path_with_prefix.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/fade_in.dart';

class LocalStoragePage extends StatefulWidget {
  final bool isPickFile;
  final String? initDir;
  const LocalStoragePage({
    Key? key,
    required this.isPickFile,
    this.initDir,
  }) : super(key: key);

  @override
  State<LocalStoragePage> createState() => _LocalStoragePageState();
}

class _LocalStoragePageState extends State<LocalStoragePage> {
  LocalPath? _path;
  late S _s;

  @override
  void initState() {
    super.initState();
    if (widget.initDir != null) {
      setState(() {
        _path = LocalPath(widget.initDir!);
      });
    } else {
      sftpDir.then((dir) {
        setState(() {
          _path = LocalPath(dir);
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
      appBar: CustomAppBar(
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () {
            if (_path != null) {
              _path!.update('/');
            }
            context.pop();
          },
        ),
        title: Text(_s.files),
        actions: [
          IconButton(
            icon: const Icon(Icons.downloading),
            onPressed: () => AppRoute.sftpMission().go(context),
          )
        ],
      ),
      body: FadeIn(
        key: UniqueKey(),
        child: _wrapPopScope(),
      ),
      bottomNavigationBar: SafeArea(child: _buildPath()),
    );
  }

  Widget _buildPath() {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          (_path?.path ?? _s.loadingFiles).omitStartStr(),
          _buildBtns(),
        ],
      ),
    );
  }

  Widget _buildBtns() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          onPressed: () {
            _path?.update('..');
            setState(() {});
          },
          icon: const Icon(Icons.arrow_back),
        ),
        IconButton(
          onPressed: () async {
            final path = await pickOneFile();
            if (path == null) return;
            final name = getFileName(path) ?? 'imported';
            await File(path).copy(pathJoin(_path!.path, name));
            setState(() {});
          },
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _wrapPopScope() {
    return WillPopScope(
      onWillPop: () async {
        if (_path == null) return true;
        if (_path!.canBack) {
          _path!.update('..');
          setState(() {});
          return false;
        }
        return true;
      },
      child: _buildBody(),
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
    return ListView.builder(
      itemCount: files.length,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 7),
      itemBuilder: (context, index) {
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
    context.showRoundDialog(
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
      await context.showRoundDialog(
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
    context.showRoundDialog(
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
                context.showRoundDialog(
                  title: Text(_s.attention),
                  child: Text(_s.fileTooLarge(fileName, stat.size, '1m')),
                );
                return;
              }
              final result = await AppRoute.editor(
                path: file.absolute.path,
              ).go<String>(context);
              final f = File(file.absolute.path);
              if (result != null) {
                f.writeAsString(result);
                context.showSnackBar(_s.saved);
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
              await context.showRoundDialog(
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
              final remotePath = await AppRoute.sftp(
                spi: spi,
                isSelect: true,
              ).go<String>(context);
              if (remotePath == null) {
                return;
              }
              locator<SftpProvider>().add(SftpReq(
                spi,
                '$remotePath/$fileName',
                file.absolute.path,
                SftpReqType.upload,
              ));
              context.showSnackBar(_s.added2List);
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
    context.showRoundDialog(
      title: Text(_s.rename),
      child: Input(
        autoFocus: true,
        controller: TextEditingController(text: fileName),
        onSubmitted: (p0) {
          context.pop();
          final newPath = '${file.parent.path}/$p0';
          try {
            file.renameSync(newPath);
          } catch (e) {
            context.showSnackBar('${_s.failed}:\n$e');
            return;
          }

          setState(() {});
        },
      ),
    );
  }

  void _showDeleteDialog(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    context.showRoundDialog(
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
              context.showSnackBar('${_s.failed}:\n$e');
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
