import 'dart:io';

import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/colorx.dart';
import 'package:toolbox/core/extension/numx.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/app/path_with_prefix.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/path.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/view/page/sftp/downloading.dart';
import 'package:toolbox/view/widget/fade_in.dart';

class SFTPDownloadedPage extends StatefulWidget {
  const SFTPDownloadedPage({Key? key}) : super(key: key);

  @override
  State<SFTPDownloadedPage> createState() => _SFTPDownloadedPageState();
}

class _SFTPDownloadedPageState extends State<SFTPDownloadedPage> {
  PathWithPrefix? _path;
  String? _prefixPath;
  late S s;
  late ThemeData _theme;

  @override
  void initState() {
    super.initState();
    sftpDownloadDir.then((dir) {
      _path = PathWithPrefix(dir.path);
      _prefixPath = dir.path + '/';
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    s = S.of(context);
    _theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.download),
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
        child: _buildBody(),
        key: UniqueKey(),
      ),
      bottomNavigationBar: SafeArea(
        child: _buildPath(),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: (() {
          if (_path!.path == _prefixPath) {
            showSnackBar(context, Text(s.alreadyLastDir));
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
    final color = _theme.scaffoldBackgroundColor;
    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          (_path?.path ?? s.loadingFiles).omitStartStr(
            style: TextStyle(
                color:
                    color.isBrightColor ? Colors.black : Colors.white),
          )
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
        s.choose,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: Text(s.delete),
              onTap: () {
                Navigator.of(context).pop();
                showRoundDialog(
                    context, s.sureDelete(fileName), const SizedBox(), [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(s.cancel)),
                  TextButton(
                    onPressed: () {
                      file.deleteSync();
                      setState(() {});
                      Navigator.of(context).pop();
                    },
                    child: Text(s.ok),
                  ),
                ]);
              },
            ),
            ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(s.open),
                onTap: () {
                  shareFiles(context, [file.absolute.path]);
                }),
          ],
        ),
        [
          TextButton(
              onPressed: (() => Navigator.of(context).pop()),
              child: Text(s.close))
        ]);
  }
}
