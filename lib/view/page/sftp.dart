import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_connection_state.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
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
  /// Whether the Left/Right Destination is selected.
  final List<bool> _selectedDest = List<bool>.filled(2, false);
  final List<ServerPrivateInfo?> _destSpi =
      List<ServerPrivateInfo?>.filled(2, null);
  final List<List<SftpName>?> _files = List<List<SftpName>?>.filled(2, null);
  final List<String> _paths = List<String>.filled(2, '');
  final List<SftpClient?> _clients = List<SftpClient?>.filled(2, null);

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
      _destSpi[0] = widget.spi;
      _selectedDest[0] = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(_titleText),
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

  String get _titleText {
    List<String> titles = [
      '',
      '',
    ];
    if (_selectedDest[0]) {
      titles[0] = _destSpi[0]?.name ?? '';
    }
    if (_selectedDest[1]) {
      titles[1] = _destSpi[1]?.name ?? '';
    }
    return titles[0] == '' || titles[1] == '' ? 'SFTP' : titles.join(' - ');
  }

  Widget _buildSingleColumn(bool left) {
    Widget child;
    if (!_selectedDest[left ? 0 : 1]) {
      child = _buildDestSelector(left);
    } else {
      child = _buildFileView(left);
    }

    return SizedBox(
      width: (_media.size.width - 2) / 2,
      child: child,
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
    final spi = _destSpi[left ? 0 : 1];
    final si =
        locator<ServerProvider>().servers.firstWhere((s) => s.info == spi);
    final client = si.client;
    if (client == null ||
        si.connectionState != ServerConnectionState.connected) {
      return centerCircleLoading;
    }

    if (_files[left ? 0 : 1] == null) {
      updatePath('/', left);
      listDir(client, '/', left);
      return centerCircleLoading;
    } else {
      return RefreshIndicator(
          child: FadeIn(
            child: ListView.builder(
              itemCount: _files[left ? 0 : 1]!.length,
              controller: left ? _leftScrollController : _rightScrollController,
              itemBuilder: (context, index) {
                final file = _files[left ? 0 : 1]![index];
                final isDir = file.attr.mode?.isDirectory ?? true;
                return ListTile(
                    leading:
                        Icon(isDir ? Icons.folder : Icons.insert_drive_file),
                    title: Text(file.filename),
                    subtitle: isDir
                        ? null
                        : Text((convertBytes(file.attr.size ?? 0))),
                    onTap: () {
                      if (isDir) {
                        updatePath(file.filename, left);
                        listDir(client, _paths[left ? 0 : 1], left);
                      } else {
                        // downloadFile(client, file.name);
                      }
                    },
                    onLongPress: () => onItemLongPress(context, left, file));
              },
            ),
            key: Key(_paths[left ? 0 : 1]),
          ),
          onRefresh: () => listDir(client, _paths[left ? 0 : 1], left));
    }
  }

  void onItemLongPress(BuildContext context, bool left, SftpName file) {
    showRoundDialog(
        context,
        'Action',
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () => showRoundDialog(context, 'Confirm',
                  Text('Are you sure to delete ${file.filename}?'), [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    )),
              ]),
            ),
            ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Create Folder'),
                onTap: () => mkdir(context, left)),
            ListTile(
              leading: Icon(left ? Icons.arrow_forward : Icons.arrow_back),
              title: const Text('Copy'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () => rename(context, left, file),
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Download'),
              onTap: () {},
            ),
          ],
        ),
        [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'))
        ]);
  }

  void mkdir(BuildContext context, bool left) {
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
                _clients[left ? 0 : 1]!
                    .mkdir(_paths[left ? 0 : 1] + '/' + textController.text);
              },
              child: const Text(
                'Create',
                style: TextStyle(color: Colors.red),
              )),
        ]);
  }

  void rename(BuildContext context, bool left, SftpName file) {
    final textController = TextEditingController();
    showRoundDialog(
        context,
        'Create Folder',
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
                await _clients[left ? 0 : 1]!
                    .rename(file.filename, textController.text);
              },
              child: const Text(
                'Create',
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

  void updatePath(String filename, bool left) {
    if (filename == '..') {
      _paths[left ? 0 : 1] = _paths[left ? 0 : 1]
          .substring(0, _paths[left ? 0 : 1].lastIndexOf('/'));
      if (_paths[left ? 0 : 1] == '') {
        _paths[left ? 0 : 1] = '/';
      }
      return;
    }
    _paths[left ? 0 : 1] = _paths[left ? 0 : 1] +
        (_paths[left ? 0 : 1].endsWith('/') ? '' : '/') +
        filename;
  }

  Future<void> listDir(SSHClient client, String path, bool left) async {
    final sftpc = await client.sftp();
    _clients[left ? 0 : 1] = sftpc;
    final fs = await sftpc.listdir(path);
    fs.sort((a, b) => a.filename.compareTo(b.filename));
    fs.removeAt(0);
    if (mounted) {
      setState(() {
        _files[left ? 0 : 1] = fs;
      });
    }
  }

  Widget _buildDestSelector(bool left) {
    return Column(
      children: locator<ServerProvider>()
          .servers
          .map((e) => _buildDestSelectorItem(e.info, left))
          .toList(),
    );
  }

  Widget _buildDestSelectorItem(ServerPrivateInfo spi, bool left) {
    return ListTile(
      title: Text(spi.name),
      subtitle: Text('${spi.user}@${spi.ip}:${spi.port}'),
      onTap: () {
        setState(() {
          _destSpi[left ? 0 : 1] = spi;
          _selectedDest[left ? 0 : 1] = true;
        });
      },
    );
  }
}
