import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';
import 'package:toolbox/data/model/sftp/sftp_side_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/center_loading.dart';
import 'package:toolbox/view/widget/fade_in.dart';
import 'package:toolbox/view/widget/two_line_text.dart';

class SFTPPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SFTPPage(this.spi, {Key? key}) : super(key: key);

  @override
  _SFTPPageState createState() => _SFTPPageState();
}

class _SFTPPageState extends State<SFTPPage> {
  final SFTPSideViewStatus _status = SFTPSideViewStatus();

  final ScrollController _scrollController = ScrollController();

  late MediaQueryData _media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    _status.spi = widget.spi;
    _status.selected = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'SFTP', down: widget.spi.name),
      ),
      body: _buildFileView(),
    );
  }

  Widget get centerCircleLoading => Center(
        child: Column(
          children: [
            SizedBox(
              height: _media.size.height * 0.4,
            ),
            const CircularProgressIndicator(),
          ],
        ),
      );

  Widget _buildFileView() {
    if (!_status.selected) {
      return ListView(
        children: [
          _buildDestSelector(),
        ],
      );
    }
    final spi = _status.spi;
    final si =
        locator<ServerProvider>().servers.firstWhere((s) => s.info == spi);
    final client = si.client;
    if (client == null ||
        si.connectionState != ServerConnectionState.connected) {
      return centerCircleLoading;
    }

    if (_status.files == null) {
      _status.path = AbsolutePath('/');
      listDir(path: '/', client: client);
      return centerCircleLoading;
    } else {
      return RefreshIndicator(
          child: FadeIn(
            child: ListView.builder(
              itemCount: _status.files!.length + 1,
              controller: _scrollController,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDestSelector();
                }
                final file = _status.files![index - 1];
                final isDir = file.attr.mode?.isDirectory ?? true;
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                  title: Text(file.filename),
                  trailing: Text(
                    DateTime.fromMillisecondsSinceEpoch(
                            (file.attr.modifyTime ?? 0) * 1000)
                        .toString()
                        .replaceFirst('.000', ''),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  subtitle:
                      isDir ? null : Text(convertBytes(file.attr.size ?? 0)),
                  onTap: () {
                    if (isDir) {
                      _status.path?.update(file.filename);
                      listDir(path: _status.path?.path);
                    } else {
                      onItemPress(context, file);
                    }
                  },
                  onLongPress: () => onItemPress(context, file),
                );
              },
            ),
            key: Key(_status.spi!.name + _status.path!.path),
          ),
          onRefresh: () => listDir(path: _status.path?.path));
    }
  }

  void onItemPress(BuildContext context, SftpName file) {
    showRoundDialog(
        context,
        'Action',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => delete(context, file),
            ),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Create Folder'),
                onTap: () => mkdir(context)),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => rename(context, file),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () => download(context, file),
            )
          ],
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'))
        ]);
  }

  void download(BuildContext context, SftpName name) {
    showRoundDialog(
        context, 'Download', Text('Download ${name.filename} to local?'), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      TextButton(
          onPressed: () async {
            var result = '';
            try {
              Navigator.of(context).pop();
              showRoundDialog(context, name.filename, centerSizedLoading, [],
                  barrierDismiss: false);
              final path = await getApplicationDocumentsDirectory();
              final localFile = File('${path.path}/${name.filename}');
              final remotePath = _status.path!.path + '/' + name.filename;
              final file = await _status.client?.open(remotePath);
              localFile.writeAsBytes(await file!.readBytes());
              Navigator.of(context).pop();
            } catch (e) {
              result = e.toString();
            } finally {
              if (result.isEmpty) {
                result = 'Donwloaded successfully.';
              }
              showRoundDialog(context, 'Result', Text(result), [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'))
              ]);
            }
          },
          child: const Text('Download'))
    ]);
  }

  void delete(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    showRoundDialog(
        context, 'Confirm', Text('Are you sure to delete ${file.filename}?'), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      TextButton(
          onPressed: () {
            _status.client!.remove(file.filename);
            Navigator.of(context).pop();
            listDir();
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          )),
    ]);
  }

  void mkdir(BuildContext context) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
        context,
        'Create Folder',
        TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
          ),
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () {
                if (textController.text == '') {
                  showRoundDialog(context, 'Attention',
                      const Text('You need input a name.'), [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK')),
                  ]);
                  return;
                }
                _status.client!
                    .mkdir(_status.path!.path + '/' + textController.text);
                Navigator.of(context).pop();
                listDir();
              },
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.red),
              )),
        ]);
  }

  void rename(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
        context,
        'Rename',
        TextField(
          controller: textController,
          decoration: const InputDecoration(
            labelText: 'New Name',
          ),
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () async {
                if (textController.text == '') {
                  showRoundDialog(context, 'Attention',
                      const Text('You need input a name.'), [
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK')),
                  ]);
                  return;
                }
                await _status.client!
                    .rename(file.filename, textController.text);
                Navigator.of(context).pop();
                listDir();
              },
              child: const Text(
                'Rename',
                style: TextStyle(color: Colors.red),
              )),
        ]);
  }

  String convertBytes(int bytes) {
    const suffix = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int squareTimes = 0;
    for (; value / 1024 > 1 && squareTimes < 3; squareTimes++) {
      value /= 1024;
    }
    var finalValue = value.toStringAsFixed(1);
    if (finalValue.endsWith('.0')) {
      finalValue = finalValue.replaceFirst('.0', '');
    }
    return '$finalValue ${suffix[squareTimes]}';
  }

  Future<void> listDir({String? path, SSHClient? client}) async {
    if (_status.isBusy) {
      return;
    }
    _status.isBusy = true;
    if (client != null) {
      final sftpc = await client.sftp();
      _status.client = sftpc;
    }
    try {
      final fs =
          await _status.client!.listdir(path ?? (_status.path?.path ?? '/'));
      fs.sort((a, b) => a.filename.compareTo(b.filename));
      fs.removeAt(0);
      if (mounted) {
        setState(() {
          _status.files = fs;
          _status.isBusy = false;
        });
      }
    } catch (e) {
      await showRoundDialog(context, 'Error', Text(e.toString()), [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'))
      ]);
      if (_status.path!.undo()) {
        await listDir();
      }
    }
  }

  Widget _buildDestSelector() {
    final str = _status.path?.path;
    return ExpansionTile(
        title: Text(_status.spi?.name ?? 'Choose target'),
        subtitle: _status.selected
            ? LayoutBuilder(builder: (context, size) {
                bool exceeded = false;
                int len = 0;
                for (; !exceeded && len < str!.length; len++) {
                  // Build the textspan
                  var span = TextSpan(
                    text: '...' + str.substring(str.length - len),
                    style: TextStyle(
                        fontSize:
                            Theme.of(context).textTheme.bodyText1?.fontSize ??
                                14),
                  );

                  // Use a textpainter to determine if it will exceed max lines
                  var tp = TextPainter(
                    maxLines: 1,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                    text: span,
                  );

                  // trigger it to layout
                  tp.layout(maxWidth: size.maxWidth);

                  // whether the text overflowed or not
                  exceeded = tp.didExceedMaxLines;
                }

                return Text(
                  (exceeded ? '...' : '') + str!.substring(str.length - len),
                  overflow: TextOverflow.clip,
                  maxLines: 1,
                  style: const TextStyle(color: Colors.grey),
                );
              })
            : null,
        children: locator<ServerProvider>()
            .servers
            .map((e) => _buildDestSelectorItem(e.info))
            .toList());
  }

  Widget _buildDestSelectorItem(ServerPrivateInfo spi) {
    return ListTile(
      title: Text(spi.name),
      subtitle: Text('${spi.user}@${spi.ip}:${spi.port}'),
      onTap: () {
        _status.spi = spi;
        _status.selected = true;
        _status.path = AbsolutePath('/');
        listDir(
            client: locator<ServerProvider>()
                .servers
                .firstWhere((s) => s.info == spi)
                .client,
            path: '/');
      },
    );
  }
}
