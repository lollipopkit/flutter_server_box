import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';

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
  const SFTPDownloadedPage({Key? key}) : super(key: key);

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
          onTap: () {
            if (!isDir) {
              showFileActionDialog(file);
              return;
            }
            _path!.update(fileName);
            setState(() {});
          },
        );
      },
    );
  }

  void showFileActionDialog(FileSystemEntity file) {
    final fileName = file.path.split('/').last;
    showRoundDialog(
      context,
      _s.choose,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(_s.delete),
            onTap: () {
              Navigator.of(context).pop();
              showRoundDialog(
                context,
                _s.sureDelete(fileName),
                const SizedBox(),
                [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_s.cancel),
                  ),
                  TextButton(
                    onPressed: () {
                      file.deleteSync();
                      setState(() {});
                      Navigator.of(context).pop();
                    },
                    child: Text(_s.ok),
                  ),
                ],
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
      [
        TextButton(
          onPressed: (() => Navigator.of(context).pop()),
          child: Text(_s.close),
        )
      ],
    );
  }
}
