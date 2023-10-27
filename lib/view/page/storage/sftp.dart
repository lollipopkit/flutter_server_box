import 'dart:async';

import 'package:after_layout/after_layout.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/extension/context/snackbar.dart';
import 'package:toolbox/core/extension/sftpfile.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/misc.dart';
import 'package:toolbox/data/res/provider.dart';
import 'package:toolbox/data/res/store.dart';
import 'package:toolbox/view/widget/omit_start_text.dart';
import 'package:toolbox/view/widget/cardx.dart';

import '../../../core/extension/numx.dart';
import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../data/model/server/server_private_info.dart';
import '../../../data/model/sftp/absolute_path.dart';
import '../../../data/model/sftp/browser_status.dart';
import '../../../data/model/sftp/req.dart';
import '../../../data/res/path.dart';
import '../../../data/res/ui.dart';
import '../../widget/custom_appbar.dart';
import '../../widget/fade_in.dart';
import '../../widget/input_field.dart';
import '../../widget/two_line_text.dart';

class SftpPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initPath;
  final bool isSelect;

  const SftpPage({
    Key? key,
    required this.spi,
    required this.isSelect,
    this.initPath,
  }) : super(key: key);

  @override
  _SftpPageState createState() => _SftpPageState();
}

class _SftpPageState extends State<SftpPage> with AfterLayoutMixin {
  final _status = SftpBrowserStatus();
  late final _client = widget.spi.server?.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        leading: IconButton(
          icon: const BackButtonIcon(),
          onPressed: () {
            _status.path?.update('/');
            context.pop();
          },
        ),
        title: TwoLineText(up: 'SFTP', down: widget.spi.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.downloading),
            onPressed: () => AppRoute.sftpMission().go(context),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildBody() {
    return WillPopScope(
      onWillPop: () async {
        if (_status.path == null || _status.path?.path == '/') {
          return true;
        }
        await _backward();
        return false;
      },
      child: _buildFileView(),
    );
  }

  Widget _buildBottom() {
    final children = widget.isSelect
        ? [
            IconButton(
                onPressed: () => context.pop(_status.path?.path),
                icon: const Icon(Icons.done))
          ]
        : [
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
          ];
    if (isDesktop) children.add(_buildRefreshBtn());
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OmitStartText(_status.path?.path ?? l10n.loadingFiles),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildUploadBtn() {
    return IconButton(
        onPressed: () async {
          final idx = await context.showRoundDialog(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.system),
                onTap: () => context.pop(1),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: Text(l10n.inner),
                onTap: () => context.pop(0),
              ),
            ],
          ));
          final path = await () async {
            switch (idx) {
              case 0:
                return await AppRoute.localStorage(isPickFile: true)
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
            context.showSnackBar('remote path is null');
            return;
          }
          Pros.sftp.add(
            SftpReq(
              widget.spi,
              '$remotePath/${path.split('/').last}',
              path,
              SftpReqType.upload,
            ),
          );
        },
        icon: const Icon(Icons.upload_file));
  }

  Widget _buildAddBtn() {
    return IconButton(
      onPressed: (() => context.showRoundDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(l10n.createFolder),
                  onTap: _mkdir,
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(l10n.createFile),
                  onTap: _newFile,
                ),
              ],
            ),
          )),
      icon: const Icon(Icons.add),
    );
  }

  Widget _buildGotoBtn() {
    return IconButton(
      padding: const EdgeInsets.all(0),
      onPressed: () async {
        final p = await context.showRoundDialog<String>(
          title: Text(l10n.goto),
          child: Autocomplete<String>(
            optionsBuilder: (val) {
              if (!Stores.setting.recordHistory.fetch()) {
                return [];
              }
              return Stores.history.sftpGoPath.all.cast<String>().where(
                    (element) => element.contains(val.text),
                  );
            },
            fieldViewBuilder: (_, controller, node, __) {
              return Input(
                autoFocus: true,
                icon: Icons.abc,
                label: l10n.path,
                node: node,
                controller: controller,
                onSubmitted: (value) => context.pop(value),
              );
            },
          ),
        );

        if (p == null || p.isEmpty) {
          return;
        }

        _status.path?.update(p);
        final suc = await _listDir();
        if (suc && Stores.setting.recordHistory.fetch()) {
          Stores.history.sftpGoPath.add(p);
        }
      },
      icon: const Icon(Icons.gps_fixed),
    );
  }

  Widget _buildRefreshBtn() {
    return IconButton(
      onPressed: () => _listDir(),
      icon: const Icon(Icons.refresh),
    );
  }

  Widget _buildFileView() {
    if (_status.files == null) {
      return UIs.centerLoading;
    }

    if (_status.files!.isEmpty) {
      return const Center(
        child: Text('~'),
      );
    }

    return RefreshIndicator(
      child: FadeIn(
        key: Key(widget.spi.name + _status.path!.path),
        child: ListView.builder(
          itemCount: _status.files!.length,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          itemBuilder: (_, index) => _buildItem(_status.files![index]),
        ),
      ),
      onRefresh: () => _listDir(),
    );
  }

  Widget _buildItem(SftpName file) {
    final isDir = file.attr.isDirectory;
    final trailing = Text(
      '${_getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
      style: UIs.textGrey,
      textAlign: TextAlign.right,
    );
    return CardX(ListTile(
      leading: Icon(isDir ? Icons.folder : Icons.insert_drive_file),
      title: Text(file.filename),
      trailing: trailing,
      subtitle: isDir
          ? null
          : Text(
              (file.attr.size ?? 0).convertBytes,
              style: UIs.textGrey,
            ),
      onTap: () {
        if (isDir) {
          _status.path?.update(file.filename);
          _listDir();
        } else {
          _onItemPress(file, true);
        }
      },
      onLongPress: () => _onItemPress(file, !isDir),
    ));
  }

  void _onItemPress(SftpName file, bool notDir) {
    final children = [
      ListTile(
        leading: const Icon(Icons.delete),
        title: Text(l10n.delete),
        onTap: () => _delete(file),
      ),
      ListTile(
        leading: const Icon(Icons.abc),
        title: Text(l10n.rename),
        onTap: () => _rename(file),
      ),
    ];
    if (notDir) {
      children.addAll([
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(l10n.edit),
          onTap: () => _edit(file),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(l10n.download),
          onTap: () => _download(file),
        ),
        // Only show decompress option when the file is a compressed file
        if (_canDecompress(file.filename))
          ListTile(
            leading: const Icon(Icons.folder_zip),
            title: Text(l10n.decompress),
            onTap: () => _decompress(file),
          ),
      ]);
    }
    context.showRoundDialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  Future<void> _edit(SftpName name) async {
    final size = name.attr.size;
    if (size == null || size > Miscs.editorMaxSize) {
      context.showSnackBar(l10n.fileTooLarge(
        name.filename,
        size ?? 0,
        Miscs.editorMaxSize,
      ));
      return;
    }
    context.pop();

    final remotePath = _getRemotePath(name);
    final localPath = await _getLocalPath(remotePath);
    final completer = Completer();
    final req = SftpReq(
      widget.spi,
      remotePath,
      localPath,
      SftpReqType.download,
    );
    Pros.sftp.add(req, completer: completer);
    context.showLoadingDialog();
    await completer.future;
    context.pop();

    final result = await AppRoute.editor(path: localPath).go<bool>(context);
    if (result != null && result) {
      Pros.sftp
          .add(SftpReq(req.spi, remotePath, localPath, SftpReqType.upload));
      context.showSnackBar(l10n.added2List);
    }
  }

  void _download(SftpName name) {
    context.showRoundDialog(
      title: Text(l10n.attention),
      child: Text('${l10n.dl2Local(name.filename)}\n${l10n.keepForeground}'),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            final remotePath = _getRemotePath(name);

            Pros.sftp.add(
              SftpReq(
                widget.spi,
                remotePath,
                await _getLocalPath(remotePath),
                SftpReqType.download,
              ),
            );

            context.pop();
          },
          child: Text(l10n.download),
        )
      ],
    );
  }

  void _delete(SftpName file) {
    context.pop();
    final isDir = file.attr.isDirectory;
    final useRmr = Stores.setting.sftpRmrDir.fetch();
    final text = () {
      if (isDir && !useRmr) {
        return l10n
            .askContinue('${l10n.dirEmpty}\n${l10n.delete} ${file.filename}');
      }
      return l10n.askContinue('${l10n.delete} ${file.filename}');
    }();
    context.showRoundDialog(
      child: Text(text),
      title: Text(l10n.attention),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            context.showLoadingDialog();
            final remotePath = _getRemotePath(file);
            try {
              if (useRmr) {
                await _client!.run('rm -r "$remotePath"');
              } else if (file.attr.isDirectory) {
                await _status.client!.rmdir(remotePath);
              } else {
                await _status.client!.remove(remotePath);
              }
              context.pop();
            } catch (e) {
              context.pop();
              context.showRoundDialog(
                title: Text(l10n.error),
                child: Text(e.toString()),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.ok),
                  )
                ],
              );
              return;
            }
            _listDir();
          },
          child: Text(l10n.delete, style: UIs.textRed),
        ),
      ],
    );
  }

  void _mkdir() {
    context.pop();
    final textController = TextEditingController();
    context.showRoundDialog(
      title: Text(l10n.createFolder),
      child: Input(
        autoFocus: true,
        icon: Icons.folder,
        controller: textController,
        label: l10n.name,
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            if (textController.text.isEmpty) {
              context.showRoundDialog(
                child: Text(l10n.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              );
              return;
            }
            final dir = '${_status.path!.path}/${textController.text}';
            await _status.client!.mkdir(dir);
            context.pop();
            _listDir();
          },
          child: Text(l10n.ok, style: UIs.textRed),
        ),
      ],
    );
  }

  void _newFile() {
    context.pop();
    final textController = TextEditingController();
    context.showRoundDialog(
      title: Text(l10n.createFile),
      child: Input(
        autoFocus: true,
        icon: Icons.insert_drive_file,
        controller: textController,
        label: l10n.name,
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (textController.text.isEmpty) {
              context.showRoundDialog(
                title: Text(l10n.attention),
                child: Text(l10n.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              );
              return;
            }
            context.pop();
            final path = '${_status.path!.path}/${textController.text}';
            context.showLoadingDialog();
            await _client!.run('touch "$path"');
            context.pop();
            _listDir();
          },
          child: Text(l10n.ok, style: UIs.textRed),
        ),
      ],
    );
  }

  void _rename(SftpName file) {
    context.pop();
    final textController = TextEditingController(text: file.filename);
    context.showRoundDialog(
      title: Text(l10n.rename),
      child: Input(
        autoFocus: true,
        icon: Icons.abc,
        controller: textController,
        label: l10n.name,
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(l10n.cancel)),
        TextButton(
          onPressed: () async {
            if (textController.text.isEmpty) {
              context.showRoundDialog(
                title: Text(l10n.attention),
                child: Text(l10n.fieldMustNotEmpty),
                actions: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(l10n.ok),
                  ),
                ],
              );
              return;
            }
            await _status.client?.rename(file.filename, textController.text);
            context.pop();
            _listDir();
          },
          child: Text(l10n.rename, style: UIs.textRed),
        ),
      ],
    );
  }

  Future<void> _decompress(SftpName name) async {
    context.pop();
    final absPath = _getRemotePath(name);
    final cmd = _getDecompressCmd(absPath);
    if (cmd == null) {
      context.showRoundDialog(
        title: Text(l10n.error),
        child: Text('Unsupport file: ${name.filename}'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(l10n.ok),
          ),
        ],
      );
      return;
    }
    context.showLoadingDialog();
    await _client?.run(cmd);
    context.pop();
    _listDir();
  }

  String _getRemotePath(SftpName name) {
    final prePath = _status.path!.path;
    return pathJoin(prePath, name.filename);
  }

  Future<String> _getLocalPath(String remotePath) async {
    return '${await Paths.sftp}$remotePath';
  }

  /// Only return true if the path is changed
  Future<bool> _listDir() async {
    // Allow dismiss, because may this op will take a long time
    context.showLoadingDialog(barrierDismiss: true);
    if (_status.client == null) {
      final sftpc = await _client?.sftp();
      _status.client = sftpc;
    }
    try {
      final listPath = _status.path?.path ?? '/';
      final fs = await _status.client?.listdir(listPath);
      if (fs == null) {
        return false;
      }
      fs.sort((a, b) => a.filename.compareTo(b.filename));

      /// Issue #97
      /// In order to compatible with the Synology NAS
      /// which not has '.' and '..' in listdir
      if (fs.isNotEmpty && fs.first.filename == '.') {
        fs.removeAt(0);
      }

      /// Issue #96
      /// Due to [WillPopScope] added in this page
      /// There is no need to keep '..' folder in listdir
      /// So remove it
      if (fs.isNotEmpty && fs.first.filename == '..') {
        fs.removeAt(0);
      }
      if (mounted) {
        setState(() {
          _status.files = fs;
        });
        context.pop();

        // Only update history when success
        if (Stores.setting.sftpOpenLastPath.fetch()) {
          Stores.history.sftpLastPath.put(widget.spi.id, listPath);
        }

        return true;
      }
      return false;
    } catch (e, trace) {
      context.pop();
      Loggers.app.warning('List dir failed', e, trace);
      await _backward();
      Future.delayed(
        const Duration(milliseconds: 177),
        () => context.showRoundDialog(
          title: Text(l10n.error),
          child: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.ok),
            )
          ],
        ),
      );
      return false;
    }
  }

  Future<void> _backward() async {
    if (_status.path?.undo() ?? false) {
      await _listDir();
    }
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    var initPath = '/';
    if (Stores.setting.sftpOpenLastPath.fetch()) {
      final history = Stores.history.sftpLastPath.fetch(widget.spi.id);
      if (history != null) {
        initPath = history;
      }
    }
    _status.path = AbsolutePath(widget.initPath ?? initPath);
    _listDir();
  }
}

String? _getDecompressCmd(String filename) {
  for (final ext in _extCmdMap.keys) {
    if (filename.endsWith('.$ext')) {
      return _extCmdMap[ext]?.replaceAll('FILE', '"$filename"');
    }
  }
  return null;
}

bool _canDecompress(String filename) {
  for (final ext in _extCmdMap.keys) {
    if (filename.endsWith('.$ext')) {
      return true;
    }
  }
  return false;
}

/// Translate from
/// https://github.com/ohmyzsh/ohmyzsh/blob/03a0d5bbaedc732436b5c67b166cde954817cc2f/plugins/extract/extract.plugin.zsh
const _extCmdMap = {
  'tar.gz': 'tar zxvf FILE',
  'tgz': 'tar zxvf FILE',
  'tar.bz2': 'tar jxvf FILE',
  'tbz2': 'tar jxvf FILE',
  'tar.xz': 'tar --xz -xvf FILE',
  'txz': 'tar --xz -xvf FILE',
  'tar.lzma': 'tar --lzma -xvf FILE',
  'tlz': 'tar --lzma -xvf FILE',
  'tar.zst': 'tar --zstd -xvf FILE',
  'tzst': 'tar --zstd -xvf FILE',
  'tar': 'tar xvf FILE',
  'tar.lz': 'tar xvf FILE',
  'tar.lz4': 'lz4 -c -d FILE | tar xvf - ',
  'gz': 'gunzip FILE',
  'bz2': 'bunzip2 FILE',
  'xz': 'unxz FILE',
  'lzma': 'unlzma FILE',
  'z': 'uncompress FILE',
  'zip': 'unzip FILE',
  'war': 'unzip FILE',
  'jar': 'unzip FILE',
  'ear': 'unzip FILE',
  'sublime-package': 'unzip FILE',
  'ipa': 'unzip FILE',
  'ipsw': 'unzip FILE',
  'apk': 'unzip FILE',
  'xpi': 'unzip FILE',
  'aar': 'unzip FILE',
  'whl': 'unzip FILE',
  'rar': 'unrar x -ad FILE',
  'rpm': 'rpm2cpio FILE | cpio --quiet -id',
  '7z': '7za x FILE',
  // 'deb': 'mkdir -p "control" "data"'
  //     'ar vx FILE > /dev/null'
  //     'cd control; extract ../control.tar.*'
  //     'cd ../data; extract ../data.tar.*'
  //     'cd ..; rm *.tar.* debian-binary',
  'zst': 'unzstd FILE',
  'cab': 'cabextract FILE',
  'exe': 'cabextract FILE',
  'cpio': 'cpio -idmvF FILE',
  'obscpio': 'cpio -idmvF FILE',
  'zpaq': 'zpaq x FILE',
};

/// Return fmt: 2021-01-01 00:00:00
String _getTime(int? unixMill) {
  return DateTime.fromMillisecondsSinceEpoch((unixMill ?? 0) * 1000)
      .toString()
      .replaceFirst('.000', '');
}
