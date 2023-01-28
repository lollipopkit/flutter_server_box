import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';

import '../../../core/extension/numx.dart';
import '../../../core/extension/stringx.dart';
import '../../../core/route.dart';
import '../../../core/utils.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/sftp/absolute_path.dart';
import '../../../data/model/sftp/browser_status.dart';
import '../../../data/model/sftp/download_item.dart';
import '../../../data/provider/server.dart';
import '../../../data/provider/sftp_download.dart';
import '../../../data/res/path.dart';
import '../../../data/store/private_key.dart';
import '../../../generated/l10n.dart';
import '../../../locator.dart';
import '../../widget/fade_in.dart';
import '../../widget/two_line_text.dart';
import 'downloading.dart';

class SFTPPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  const SFTPPage(this.spi, {Key? key}) : super(key: key);

  @override
  _SFTPPageState createState() => _SFTPPageState();
}

class _SFTPPageState extends State<SFTPPage> {
  final SftpBrowserStatus _status = SftpBrowserStatus();
  final ScrollController _scrollController = ScrollController();

  late MediaQueryData _media;
  late S _s;

  Server? _si;
  SSHClient? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
    _s = S.of(context);
  }

  @override
  void initState() {
    super.initState();
    final serverProvider = locator<ServerProvider>();
    _si = serverProvider.servers.firstWhere((s) => s.spi == widget.spi);
    _client = _si?.client;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: TwoLineText(up: 'SFTP', down: widget.spi.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.downloading),
            onPressed: () =>
                AppRoute(const SFTPDownloadingPage(), 'sftp downloading')
                    .go(context),
          ),
        ],
      ),
      body: _buildFileView(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildBottom() {
    return SafeArea(
        child: Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(),
          (_status.path?.path ?? _s.loadingFiles).omitStartStr(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                padding: const EdgeInsets.all(0),
                onPressed: () async {
                  await backward();
                },
                icon: const Icon(Icons.arrow_back),
              ),
              IconButton(
                onPressed: (() => showRoundDialog(
                      context,
                      _s.choose,
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                              leading: const Icon(Icons.folder),
                              title: Text(_s.createFolder),
                              onTap: () => mkdir(context)),
                          ListTile(
                              leading: const Icon(Icons.insert_drive_file),
                              title: Text(_s.createFile),
                              onTap: () => newFile(context)),
                        ],
                      ),
                      [
                        TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(_s.close))
                      ],
                    )),
                icon: const Icon(Icons.add),
              ),
              IconButton(
                padding: const EdgeInsets.all(0),
                onPressed: () async {
                  final p = await showRoundDialog<String?>(
                    context,
                    _s.goto,
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(
                            labelText: _s.path,
                            hintText: '/',
                          ),
                          onSubmitted: (value) =>
                              Navigator.of(context).pop(value),
                        ),
                      ],
                    ),
                    [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(_s.cancel))
                    ],
                  );

                  if (p != null) {
                    if (p.isEmpty) {
                      showSnackBar(context, Text(_s.fieldMustNotEmpty));
                      return;
                    }
                    _status.path?.update(p);
                    listDir(path: p);
                  }
                },
                icon: const Icon(Icons.gps_fixed),
              )
            ],
          )
        ],
      ),
    ));
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
    if (_client == null || _si?.cs != ServerConnectionState.connected) {
      return centerCircleLoading;
    }

    if (_status.isBusy) {
      return centerCircleLoading;
    }

    if (_status.files == null) {
      _status.path = AbsolutePath('/');
      listDir(path: '/', client: _client);
      return centerCircleLoading;
    } else {
      return RefreshIndicator(
        child: FadeIn(
          key: Key(widget.spi.name + _status.path!.path),
          child: ListView.builder(
            itemCount: _status.files!.length,
            controller: _scrollController,
            itemBuilder: (context, index) {
              final file = _status.files![index];
              final isDir = file.attr.isDirectory;
              return ListTile(
                leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                title: Text(file.filename),
                trailing: Text(
                  '${getTime(file.attr.modifyTime)}\n${getMode(file.attr.mode)}',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
                subtitle:
                    isDir ? null : Text((file.attr.size ?? 0).convertBytes),
                onTap: () {
                  if (isDir) {
                    _status.path?.update(file.filename);
                    listDir(path: _status.path?.path);
                  } else {
                    onItemPress(context, file, true);
                  }
                },
                onLongPress: () => onItemPress(context, file, false),
              );
            },
          ),
        ),
        onRefresh: () => listDir(path: _status.path?.path),
      );
    }
  }

  String getTime(int? unixMill) {
    return DateTime.fromMillisecondsSinceEpoch((unixMill ?? 0) * 1000)
        .toString()
        .replaceFirst('.000', '');
  }

  String getMode(SftpFileMode? mode) {
    if (mode == null) {
      return '---';
    }

    final user = getRoleMode(mode.userRead, mode.userWrite, mode.userExecute);
    final group =
        getRoleMode(mode.groupRead, mode.groupWrite, mode.groupExecute);
    final other =
        getRoleMode(mode.otherRead, mode.otherWrite, mode.otherExecute);

    return '$user$group$other';
  }

  String getRoleMode(bool r, bool w, bool x) {
    return '${r ? 'r' : '-'}${w ? 'w' : '-'}${x ? 'x' : '-'}';
  }

  void onItemPress(BuildContext context, SftpName file, bool showDownload) {
    showRoundDialog(
      context,
      _s.choose,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(_s.delete),
            onTap: () => delete(context, file),
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(_s.rename),
            onTap: () => rename(context, file),
          ),
          showDownload
              ? ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(_s.download),
                  onTap: () => download(context, file),
                )
              : const SizedBox()
        ],
      ),
      [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel))
      ],
    );
  }

  void download(BuildContext context, SftpName name) {
    showRoundDialog(
      context,
      _s.download,
      Text('${_s.dl2Local(name.filename)}\n${_s.keepForeground}'),
      [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel)),
        TextButton(
          onPressed: () async {
            Navigator.of(context).pop();
            final prePath = _status.path!.path;
            final remotePath =
                prePath + (prePath.endsWith('/') ? '' : '/') + name.filename;
            final local = '${(await sftpDownloadDir).path}$remotePath';
            final pubKeyId = widget.spi.pubKeyId;

            locator<SftpDownloadProvider>().add(
              DownloadItem(
                widget.spi,
                remotePath,
                local,
              ),
              key: pubKeyId == null
                  ? null
                  : locator<PrivateKeyStore>().get(pubKeyId).privateKey,
            );

            Navigator.of(context).pop();
          },
          child: Text(_s.download),
        )
      ],
    );
  }

  void delete(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    showRoundDialog(
      context,
      _s.attention,
      Text(_s.sureDelete(file.filename)),
      [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            _status.client!.remove(file.filename);
            Navigator.of(context).pop();
            listDir();
          },
          child: Text(
            _s.delete,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void mkdir(BuildContext context) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
      context,
      _s.createFolder,
      TextField(
        controller: textController,
        decoration: InputDecoration(
          labelText: _s.name,
        ),
      ),
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () {
            if (textController.text == '') {
              showRoundDialog(
                context,
                _s.attention,
                Text(_s.fieldMustNotEmpty),
                [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_s.ok)),
                ],
              );
              return;
            }
            _status.client!
                .mkdir('${_status.path!.path}/${textController.text}');
            Navigator.of(context).pop();
            listDir();
          },
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void newFile(BuildContext context) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
      context,
      _s.createFile,
      TextField(
        controller: textController,
        decoration: InputDecoration(
          labelText: _s.name,
        ),
      ),
      [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            if (textController.text == '') {
              showRoundDialog(
                context,
                _s.attention,
                Text(_s.fieldMustNotEmpty),
                [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_s.ok),
                  ),
                ],
              );
              return;
            }
            (await _status.client!
                    .open('${_status.path!.path}/${textController.text}'))
                .writeBytes(Uint8List(0));
            Navigator.of(context).pop();
            listDir();
          },
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void rename(BuildContext context, SftpName file) {
    Navigator.of(context).pop();
    final textController = TextEditingController();
    showRoundDialog(
      context,
      _s.rename,
      TextField(
        controller: textController,
        decoration: InputDecoration(
          labelText: _s.name,
        ),
      ),
      [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.cancel)),
        TextButton(
          onPressed: () async {
            if (textController.text == '') {
              showRoundDialog(
                context,
                _s.attention,
                Text(_s.fieldMustNotEmpty),
                [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_s.ok),
                  ),
                ],
              );
              return;
            }
            await _status.client!.rename(file.filename, textController.text);
            Navigator.of(context).pop();
            listDir();
          },
          child: Text(
            _s.rename,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
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
          await _status.client!.listdir(path ?? _status.path?.path ?? '/');
      fs.sort((a, b) => a.filename.compareTo(b.filename));
      fs.removeAt(0);
      if (mounted) {
        setState(() {
          _status.files = fs;
          _status.isBusy = false;
        });
      }
    } catch (e) {
      await showRoundDialog(
        context,
        _s.error,
        Text(e.toString()),
        [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(_s.ok),
          )
        ],
      );
      await backward();
    }
  }

  Future<void> backward() async {
    if (_status.path!.undo()) {
      await listDir();
    }
  }
}
