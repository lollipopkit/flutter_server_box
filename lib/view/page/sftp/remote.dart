import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/extension/sftpfile.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/view/page/editor.dart';
import 'package:toolbox/view/page/sftp/local.dart';

import '../../../core/extension/numx.dart';
import '../../../core/extension/stringx.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/ui.dart';
import '../../../data/model/server/server.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/sftp/absolute_path.dart';
import '../../../data/model/sftp/browser_status.dart';
import '../../../data/model/sftp/req.dart';
import '../../../data/provider/server.dart';
import '../../../data/provider/sftp.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../../locator.dart';
import '../../widget/fade_in.dart';
import '../../widget/input_field.dart';
import '../../widget/two_line_text.dart';
import 'mission.dart';

class SFTPPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initPath;
  const SFTPPage(this.spi, {Key? key, this.initPath}) : super(key: key);

  @override
  _SFTPPageState createState() => _SFTPPageState();
}

class _SFTPPageState extends State<SFTPPage> {
  final SftpBrowserStatus _status = SftpBrowserStatus();
  final ScrollController _scrollController = ScrollController();

  final _sftp = locator<SftpProvider>();

  late S _s;

  ServerState? _state;
  SSHClient? _client;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    final serverProvider = locator<ServerProvider>();
    _client = serverProvider.servers[widget.spi.id]?.client;
    _state = serverProvider.servers[widget.spi.id]?.state;
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
            onPressed: () => AppRoute(
              const SFTPDownloadingPage(),
              'sftp downloading',
            ).go(context),
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
                    await _backward();
                  },
                  icon: const Icon(Icons.arrow_back),
                ),
                _buildAddBtn(),
                _buildGotoBtn(),
                _buildUploadBtn(),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBtn() {
    return IconButton(
        onPressed: () async {
          final idx = await showRoundDialog(
              context: context,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.open_in_new),
                    title: Text(_s.system),
                    onTap: () => context.pop(1),
                  ),
                  ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(_s.inner),
                    onTap: () => context.pop(0),
                  ),
                ],
              ));
          final path = await () async {
            switch (idx) {
              case 0:
                return await AppRoute(
                        const SFTPDownloadedPage(
                          isPickFile: true,
                        ),
                        'sftp dled pick')
                    .go<String>(context);
              case 1:
                return await pickOneFile();
              default:
                return null;
            }
          }();
          if (path == null) {
            return;
          }
          final remotePath = _status.path?.path;
          if (remotePath == null) {
            showSnackBar(context, const Text('remote path is null'));
            return;
          }
          _sftp.add(
            SftpReqItem(widget.spi, remotePath, path),
            SftpReqType.upload,
          );
        },
        icon: const Icon(Icons.upload_file));
  }

  Widget _buildAddBtn() {
    return IconButton(
      onPressed: (() => showRoundDialog(
            context: context,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(_s.createFolder),
                    onTap: () => _mkdir(context)),
                ListTile(
                    leading: const Icon(Icons.insert_drive_file),
                    title: Text(_s.createFile),
                    onTap: () => _newFile(context)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(_s.close),
              )
            ],
          )),
      icon: const Icon(Icons.add),
    );
  }

  Widget _buildGotoBtn() {
    return IconButton(
      padding: const EdgeInsets.all(0),
      onPressed: () async {
        final p = await showRoundDialog<String>(
          context: context,
          title: Text(_s.goto),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Input(
                label: _s.path,
                onSubmitted: (value) => context.pop(value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(_s.close),
            )
          ],
        );

        // p == null || p.isEmpty
        if (p?.isEmpty ?? true) {
          return;
        }
        _status.path?.update(p!);
        _listDir(path: p);
      },
      icon: const Icon(Icons.gps_fixed),
    );
  }

  Widget _buildFileView() {
    if (_client == null || _state != ServerState.connected) {
      return centerLoading;
    }

    if (_status.isBusy) {
      return centerLoading;
    }

    if (_status.files == null) {
      final p_ = widget.initPath ?? '/';
      _status.path = AbsolutePath(p_);
      _listDir(path: p_, client: _client);
      return centerLoading;
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
                  '${getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.right,
                ),
                subtitle:
                    isDir ? null : Text((file.attr.size ?? 0).convertBytes),
                onTap: () {
                  if (isDir) {
                    _status.path?.update(file.filename);
                    _listDir(path: _status.path?.path);
                  } else {
                    _onItemPress(context, file, true);
                  }
                },
                onLongPress: () => _onItemPress(context, file, !isDir),
              );
            },
          ),
        ),
        onRefresh: () => _listDir(path: _status.path?.path),
      );
    }
  }

  void _onItemPress(BuildContext context, SftpName file, bool notDir) {
    showRoundDialog(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          notDir
              ? ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(_s.edit),
                  onTap: () => _edit(context, file),
                )
              : placeholder,
          ListTile(
            leading: const Icon(Icons.delete),
            title: Text(_s.delete),
            onTap: () => _delete(context, file),
          ),
          ListTile(
            leading: const Icon(Icons.abc),
            title: Text(_s.rename),
            onTap: () => _rename(context, file),
          ),
          notDir
              ? ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(_s.download),
                  onTap: () => _download(context, file),
                )
              : placeholder,
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, SftpName name) async {
    final size = name.attr.size;
    if (size == null || size > editorMaxSize) {
      showSnackBar(
          context,
          Text(_s.fileTooLarge(
            name.filename,
            size ?? 0,
            editorMaxSize,
          )));
      return;
    }
    context.pop();

    final remotePath = _getRemotePath(name);
    final localPath = await _getLocalPath(remotePath);
    final completer = Completer();
    final req = SftpReqItem(widget.spi, remotePath, localPath);
    _sftp.add(req, SftpReqType.download, completer: completer);
    await completer.future;

    final result = await AppRoute(
      EditorPage(path: localPath),
      'SFTP edit',
    ).go<String>(context);
    if (result != null) {
      _sftp.add(req, SftpReqType.upload);
    }
  }

  void _download(BuildContext context, SftpName name) {
    showRoundDialog(
      context: context,
      title: Text(_s.attention),
      child: Text('${_s.dl2Local(name.filename)}\n${_s.keepForeground}'),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            final remotePath = _getRemotePath(name);

            _sftp.add(
              SftpReqItem(
                widget.spi,
                remotePath,
                await _getLocalPath(remotePath),
              ),
              SftpReqType.download,
            );

            context.pop();
          },
          child: Text(_s.download),
        )
      ],
    );
  }

  void _delete(BuildContext context, SftpName file) {
    context.pop();
    final isDir = file.attr.isDirectory;
    final dirText = isDir ? '\n${_s.sureDirEmpty}' : '';
    final text = '${_s.sureDelete(file.filename)}$dirText';
    final child = Text(text);
    showRoundDialog(
      context: context,
      child: child,
      title: Text(_s.attention),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            showRoundDialog(
              context: context,
              child: centerSizedLoading,
              barrierDismiss: false,
            );
            final remotePath = _getRemotePath(file);
            try {
              if (file.attr.isDirectory) {
                await _status.client!.rmdir(remotePath);
              } else {
                await _status.client!.remove(remotePath);
              }
              context.pop();
            } catch (e) {
              context.pop();
              showRoundDialog(
                context: context,
                title: Text(_s.error),
                child: Text(e.toString()),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(_s.ok),
                  )
                ],
              );
              return;
            }
            _listDir();
          },
          child: Text(
            _s.delete,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void _mkdir(BuildContext context) {
    context.pop();
    final textController = TextEditingController();
    showRoundDialog(
      context: context,
      title: Text(_s.createFolder),
      child: Input(
        controller: textController,
        label: _s.name,
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () {
            if (textController.text == '') {
              showRoundDialog(
                context: context,
                child: Text(_s.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(_s.ok),
                  ),
                ],
              );
              return;
            }
            _status.client!
                .mkdir('${_status.path!.path}/${textController.text}');
            context.pop();
            _listDir();
          },
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void _newFile(BuildContext context) {
    context.pop();
    final textController = TextEditingController();
    showRoundDialog(
      context: context,
      title: Text(_s.createFile),
      child: Input(
        controller: textController,
        label: _s.name,
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(_s.cancel),
        ),
        TextButton(
          onPressed: () async {
            if (textController.text == '') {
              showRoundDialog(
                context: context,
                child: Text(_s.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(_s.ok),
                  ),
                ],
              );
              return;
            }
            (await _status.client!
                    .open('${_status.path!.path}/${textController.text}'))
                .writeBytes(Uint8List(0));
            context.pop();
            _listDir();
          },
          child: Text(
            _s.ok,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void _rename(BuildContext context, SftpName file) {
    context.pop();
    final textController = TextEditingController();
    showRoundDialog(
      context: context,
      title: Text(_s.rename),
      child: Input(
        controller: textController,
        label: _s.name,
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(_s.cancel)),
        TextButton(
          onPressed: () async {
            if (textController.text == '') {
              showRoundDialog(
                context: context,
                child: Text(_s.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(_s.ok),
                  ),
                ],
              );
              return;
            }
            await _status.client!.rename(file.filename, textController.text);
            context.pop();
            _listDir();
          },
          child: Text(
            _s.rename,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  String _getRemotePath(SftpName name) {
    final prePath = _status.path!.path;
    return pathJoin(prePath, name.filename);
  }

  Future<String> _getLocalPath(String remotePath) async {
    return '${(await sftpDir).path}$remotePath';
  }

  Future<void> _listDir({String? path, SSHClient? client}) async {
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
        context: context,
        title: Text(_s.error),
        child: Text(e.toString()),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(_s.ok),
          )
        ],
      );
      await _backward();
    }
  }

  Future<void> _backward() async {
    if (_status.path!.undo()) {
      await _listDir();
    }
  }
}
