import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';
import 'package:toolbox/data/model/sftp/sftp_side_status.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/widget/fade_in.dart';

class SFTPPage extends StatefulWidget {
  final ServerPrivateInfo? spi;
  const SFTPPage({this.spi, Key? key}) : super(key: key);

  @override
  _SFTPPageState createState() => _SFTPPageState();
}

class _SFTPPageState extends State<SFTPPage> {
  final SFTPSideViewStatus _status = SFTPSideViewStatus();

  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();

  late MediaQueryData _media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  void initState() {
    super.initState();
    if (widget.spi != null) {
      _status.setSpi(true, widget.spi!);
      _status.setSelect(true, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('SFTP'),
      ),
      body: Row(
        children: [
          _buildSingleColumn(true),
          const VerticalDivider(
            width: 2,
          ),
          _buildSingleColumn(false),
        ],
      ),
    );
  }

  Widget _buildSingleColumn(bool left) {
    return SizedBox(
      width: (_media.size.width - 2) / 2,
      child: _buildFileView(left),
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

  Widget _buildFileView(bool left) {
    if (!_status.selected(left)) {
      return ListView(
        children: [
          _buildDestSelector(left),
        ],
      );
    }
    final spi = _status.spi(left);
    final si =
        locator<ServerProvider>().servers.firstWhere((s) => s.info == spi);
    final client = si.client;
    if (client == null ||
        si.connectionState != ServerConnectionState.connected) {
      return centerCircleLoading;
    }

    if (_status.files(left) == null) {
      _status.setPath(left, AbsolutePath('/'));
      listDir(left, path: '/', client: client);
      return centerCircleLoading;
    } else {
      return RefreshIndicator(
          child: FadeIn(
            child: ListView.builder(
              itemCount: _status.files(left)!.length + 1,
              controller: left ? _leftScrollController : _rightScrollController,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildDestSelector(left);
                }
                final file = _status.files(left)![index - 1];
                final isDir = file.attr.mode?.isDirectory ?? true;
                return ListTile(
                  leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                  title: Text(file.filename),
                  subtitle:
                      isDir ? null : Text(convertBytes(file.attr.size ?? 0)),
                  onTap: () {
                    if (isDir) {
                      _status.path(left)?.update(file.filename);
                      listDir(left, path: _status.path(left)?.path);
                    } else {
                      onItemPress(context, left, file);
                    }
                  },
                  onLongPress: () => onItemPress(context, left, file),
                );
              },
            ),
            key: Key(_status.spi(left)!.name + _status.path(left)!.path),
          ),
          onRefresh: () => listDir(left, path: _status.path(left)?.path));
    }
  }

  void onItemPress(BuildContext context, bool left, SftpName file) {
    showRoundDialog(
        context,
        'Action',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => delete(context, left, file),
            ),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Create Folder'),
                onTap: () => mkdir(context, left)),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => rename(context, left, file),
            ),
          ],
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'))
        ]);
  }

  void delete(BuildContext context, bool left, SftpName file) {
    Navigator.of(context).pop();
    showRoundDialog(
        context, 'Confirm', Text('Are you sure to delete ${file.filename}?'), [
      TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel')),
      TextButton(
          onPressed: () {
            _status.client(left)!.remove(file.filename);
            Navigator.of(context).pop();
            listDir(left);
          },
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          )),
    ]);
  }

  void mkdir(BuildContext context, bool left) {
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
                _status.client(left)!.mkdir(
                    _status.path(left)!.path + '/' + textController.text);
                Navigator.of(context).pop();
                listDir(left);
              },
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.red),
              )),
        ]);
  }

  void rename(BuildContext context, bool left, SftpName file) {
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
                await _status
                    .client(left)!
                    .rename(file.filename, textController.text);
                Navigator.of(context).pop();
                listDir(left);
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

  Future<void> listDir(bool left, {String? path, SSHClient? client}) async {
    if (_status.isBusy(left)) {
      return;
    }
    _status.setBusy(left, true);
    if (client != null) {
      final sftpc = await client.sftp();
      _status.setClient(left, sftpc);
    }
    final fs = await _status
        .client(left)!
        .listdir(path ?? (_status.leftPath?.path ?? '/'));
    fs.sort((a, b) => a.filename.compareTo(b.filename));
    fs.removeAt(0);
    if (mounted) {
      setState(() {
        _status.setFiles(left, fs);
        _status.setBusy(left, false);
      });
    }
  }

  Widget _buildDestSelector(bool left) {
    final str = _status.path(left)?.path;
    return ExpansionTile(
        title: Text(_status.spi(left)?.name ?? 'Choose target'),
        subtitle: _status.selected(left)
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
            .map((e) => _buildDestSelectorItem(e.info, left))
            .toList());
  }

  Widget _buildDestSelectorItem(ServerPrivateInfo spi, bool left) {
    return ListTile(
      title: Text(spi.name),
      subtitle: Text('${spi.user}@${spi.ip}:${spi.port}'),
      onTap: () {
        _status.setSpi(left, spi);
        _status.setSelect(left, true);
        _status.setPath(left, AbsolutePath('/'));
        listDir(left,
            client: locator<ServerProvider>()
                .servers
                .firstWhere((s) => s.info == spi)
                .client,
            path: '/');
      },
    );
  }
}
