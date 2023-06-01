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
import 'package:toolbox/view/widget/input_field.dart';
import 'package:toolbox/view/widget/picker.dart';

import '../../../core/extension/numx.dart';
import '../../../core/extension/stringx.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/app/path_with_prefix.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../widget/fade_in.dart';
import 'downloading.dart';

class SFTPDownloadedPage extends StatefulWidget {
  final bool isPickFile;
  const SFTPDownloadedPage({Key? key, this.isPickFile = false})
      : super(key: key);

  @override
  State<SFTPDownloadedPage> createState() => _SFTPDownloadedPageState();
}

class _SFTPDownloadedPageState extends State<SFTPDownloadedPage> {
  PathWithPrefix? _path;
  String? _prefixPath;
  late S _s;

  @override
  void initState() {
    super.initState();
    sftpDir.then((dir) {
      _path = PathWithPrefix(dir.path);
      _prefixPath = '${dir.path}/';
      setState(() {});
    });
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
                AppRoute(const SFTPDownloadingPage(), 'sftp downloading')
                    .go(context),
          )
        ],
      ),
      body: FadeIn(
        key: UniqueKey(),
        child: _buildBody(),
      ),
      bottomNavigationBar: SafeArea(
        child: _buildPath(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: (() {
          if (_path!.path == _prefixPath) {
            showSnackBar(context, Text(_s.alreadyLastDir));
            return;
          }
          _path!.update('..');
          setState(() {});
        }),
        child: const Icon(Icons.keyboard_arrow_left),
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
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (context, index) {
        var file = files[index];
        var fileName = file.path.split('/').last;
        var stat = file.statSync();
        var isDir = stat.type == FileSystemEntityType.directory;

        return ListTile(
          leading: isDir
              ? const Icon(Icons.folder)
              : const Icon(Icons.insert_drive_file),
          title: Text(fileName),
          subtitle: isDir ? null : Text(stat.size.convertBytes),
          trailing: Text(
            stat.modified
                .toString()
                .substring(0, stat.modified.toString().length - 4),
            style: grey,
          ),
          onTap: () async {
            if (!isDir) {
              await showFileActionDialog(file);
              return;
            }
            _path!.update(fileName);
            setState(() {});
          },
        );
      },
    );
  }

  Future<void> showFileActionDialog(FileSystemEntity file) async {
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
                  child: Text(_s.fileTooLarge(fileName, stat.size, '1m')),
                );
                return;
              }
              final f = File(file.absolute.path);
              final data = await f.readAsString();
              final result = await AppRoute(
                EditorPage(
                  initCode: data,
                  path: fileName,
                ),
                'sftp dled editor',
              ).go<String>(context);
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
              showRoundDialog(
                context: context,
                title: Text(_s.rename),
                child: Input(
                  controller: TextEditingController(text: fileName),
                  onSubmitted: (p0) {
                    context.pop();
                    final newPath = '${file.parent.path}/$p0';
                    file.renameSync(newPath);
                    setState(() {});
                  },
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(_s.delete),
            onTap: () {
              context.pop();
              showRoundDialog(
                context: context,
                child: Text(_s.sureDelete(fileName)),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(_s.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      file.deleteSync();
                      setState(() {});
                      context.pop();
                    },
                    child: Text(_s.ok),
                  ),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: Text(_s.upload),
            onTap: () async {
              context.pop();
              final remotePath = await showRoundDialog(
                  context: context,
                  title: Text(_s.remotePath),
                  child: Input(
                    controller: TextEditingController(text: '/'),
                    onSubmitted: (p0) {
                      context.pop(p0);
                    },
                  ));
              if (remotePath == null) {
                showSnackBar(context, Text(_s.fieldMustNotEmpty));
                return;
              }
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
                showSnackBar(context, Text(_s.noResult));
                return;
              }
              locator<SftpProvider>().add(
                SftpReqItem(spi, remotePath, file.absolute.path),
                SftpReqType.upload,
              );
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
}
