import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/sftpfile.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/comparator.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/absolute_path.dart';
import 'package:server_box/data/model/sftp/browser_status.dart';
import 'package:server_box/data/model/sftp/req.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/provider.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/widget/omit_start_text.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/view/widget/two_line_text.dart';
import 'package:server_box/view/widget/unix_perm.dart';

class SftpPage extends StatefulWidget {
  final ServerPrivateInfo spi;
  final String? initPath;
  final bool isSelect;

  const SftpPage({
    super.key,
    required this.spi,
    required this.isSelect,
    this.initPath,
  });

  @override
  State<SftpPage> createState() => _SftpPageState();
}

class _SftpPageState extends State<SftpPage> with AfterLayoutMixin {
  final _status = SftpBrowserStatus();
  late final _client = widget.spi.server?.client;

  final _sortOption =
      ValueNotifier(_SortOption(sortBy: _SortType.name, reversed: false));

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
            onPressed: () => AppRoutes.sftpMission().go(context),
          ),
          ValBuilder(
            listenable: _sortOption,
            builder: (value) {
              return PopupMenuButton<_SortType>(
                icon: const Icon(Icons.sort),
                itemBuilder: (context) {
                  final currentSelectedOption = _sortOption.value;
                  final options = [
                    (_SortType.name, l10n.name),
                    (_SortType.size, l10n.size),
                    (_SortType.time, l10n.time),
                  ];
                  return options.map((r) {
                    final (type, name) = r;
                    return PopupMenuItem(
                      value: type,
                      child: Text(
                        type == currentSelectedOption.sortBy
                            ? "$name (${currentSelectedOption.reversed ? '-' : '+'})"
                            : name,
                        style: TextStyle(
                          color: type == currentSelectedOption.sortBy
                              ? UIs.primaryColor
                              : null,
                          fontWeight: type == currentSelectedOption.sortBy
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    );
                  }).toList();
                },
                onSelected: (sortBy) {
                  final oldValue = _sortOption.value;
                  if (oldValue.sortBy == sortBy) {
                    _sortOption.value = _SortOption(
                        sortBy: sortBy, reversed: !oldValue.reversed);
                  } else {
                    _sortOption.value =
                        _SortOption(sortBy: sortBy, reversed: false);
                  }
                },
              );
            },
          ),
        ],
      ),
      body: _buildFileView(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildBottom() {
    final children = widget.isSelect
        ? [
            IconButton(
              onPressed: () => context.pop(_status.path?.path),
              icon: const Icon(Icons.done),
            ),
            _buildSearchBtn(),
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
            _buildSearchBtn(),
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

  Widget _buildSearchBtn() {
    return IconButton(
      onPressed: () async {
        Stream<SftpName> find(String query) async* {
          final fs = _status.files;
          if (fs == null) return;
          for (final f in fs) {
            if (f.filename.contains(query)) yield f;
          }
        }

        final search = SearchPage(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          future: (q) => find(q).toList(),
          builder: (ctx, e) => _buildItem(e, beforeTap: () => ctx.pop()),
        );
        await showSearch(context: context, delegate: search);
      },
      icon: const Icon(Icons.search),
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
              return await AppRoutes.localStorage(isPickFile: true)
                  .go<String>(context);
            case 1:
              return await Pfs.pickFilePath();
            default:
              return null;
          }
        }();
        if (path == null) {
          return;
        }
        final remoteDir = _status.path?.path;
        if (remoteDir == null) {
          context.showSnackBar('remote path is null');
          return;
        }
        final remotePath = '$remoteDir/${path.split('/').last}';
        Loggers.app.info('SFTP upload local: $path, remote: $remotePath');
        Pros.sftp.add(
          SftpReq(widget.spi, remotePath, path, SftpReqType.upload),
        );
      },
      icon: const Icon(Icons.upload_file),
    );
  }

  Widget _buildAddBtn() {
    return IconButton(
      onPressed: () => context.showRoundDialog(
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
      ),
      icon: const Icon(Icons.add),
    );
  }

  Widget _buildGotoBtn() {
    return IconButton(
      padding: const EdgeInsets.all(0),
      onPressed: () async {
        final p = await context.showRoundDialog<String>(
          title: l10n.goto,
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
        child: ValBuilder(
          listenable: _sortOption,
          builder: (sortOption) {
            final files = sortOption.sortBy.sort(
              _status.files!,
              reversed: sortOption.reversed,
            );
            return ListView.builder(
              itemCount: files.length,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              itemBuilder: (_, index) => _buildItem(files[index]),
            );
          },
        ),
      ),
      onRefresh: () => _listDir(),
    );
  }

  Widget _buildItem(SftpName file, {VoidCallback? beforeTap}) {
    final isDir = file.attr.isDirectory;
    final trailing = Text(
      '${_getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
      style: UIs.textGrey,
      textAlign: TextAlign.right,
    );
    return CardX(
      child: ListTile(
        leading: Icon(isDir ? Icons.folder_outlined : Icons.insert_drive_file),
        title: Text(file.filename),
        trailing: trailing,
        subtitle: isDir
            ? null
            : Text(
                (file.attr.size ?? 0).bytes2Str,
                style: UIs.textGrey,
              ),
        onTap: () {
          beforeTap?.call();
          if (isDir) {
            _status.path?.update(file.filename);
            _listDir();
          } else {
            _onItemPress(file, true);
          }
        },
        onLongPress: () {
          beforeTap?.call();
          _onItemPress(file, !isDir);
        },
      ),
    );
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
      ListTile(
        leading: const Icon(MingCute.copy_line),
        title: Text(l10n.copyPath),
        onTap: () {
          Pfs.copy(_getRemotePath(file));
          context.pop();
          context.showSnackBar(l10n.success);
        },
      ),
      ListTile(
        leading: const Icon(Icons.security),
        title: Text(l10n.permission),
        onTap: () async {
          context.pop();

          final perm = file.attr.mode?.toUnixPerm() ?? UnixPerm.empty;
          var newPerm = perm.copyWith();
          final ok = await context.showRoundDialog(
            child: UnixPermEditor(perm: perm, onChanged: (p) => newPerm = p),
            actions: Btns.oks(onTap: () => context.pop(true)),
          );

          final permStr = newPerm.perm;
          if (ok == true && permStr != perm.perm) {
            await context.showLoadingDialog(
              fn: () async {
                await _client!.run('chmod $permStr "${_getRemotePath(file)}"');
                await _listDir();
              },
              onErr: (e, s) {
                context.showErrDialog(e: e, s: s, operation: l10n.permission);
              },
            );
          }
        },
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
    await context.showLoadingDialog(fn: () => completer.future);

    final result = await AppRoutes.editor(path: localPath).go<bool>(context);
    if (result != null && result) {
      Pros.sftp.add(SftpReq(
        req.spi,
        remotePath,
        localPath,
        SftpReqType.upload,
      ));
      context.showSnackBar(l10n.added2List);
    }
  }

  void _download(SftpName name) {
    context.showRoundDialog(
      title: l10n.attention,
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
    var useRmr = Stores.setting.sftpRmrDir.fetch();
    final text = () {
      if (isDir && !useRmr) {
        return l10n.askContinue('${l10n.delete} ${file.filename}');
      }
      return l10n.askContinue('${l10n.delete} ${file.filename}');
    }();

    // Most users don't know that SFTP can't delete a directory which is not
    // empty, so we provide a checkbox to let user choose to use `rm -r` or not
    context.showRoundDialog(
      title: l10n.attention,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(text),
          ),
          if (!useRmr)
            StatefulBuilder(
              builder: (_, setState) {
                return CheckboxListTile(
                  title: Text(l10n.sftpRmrDirSummary),
                  value: useRmr,
                  onChanged: (val) {
                    setState(() {
                      useRmr = val ?? false;
                    });
                  },
                );
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            try {
              await context.showLoadingDialog(
                fn: () async {
                  final remotePath = _getRemotePath(file);
                  if (useRmr) {
                    await _client!.run('rm -r "$remotePath"');
                  } else if (file.attr.isDirectory) {
                    await _status.client!.rmdir(remotePath);
                  } else {
                    await _status.client!.remove(remotePath);
                  }
                },
                onErr: (e, s) {},
              );
              _listDir();
            } catch (e, s) {
              context.showErrDialog(e: e, s: s, operation: l10n.delete);
            }
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
      title: l10n.createFolder,
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
            context.pop();
            try {
              await context.showLoadingDialog(
                fn: () async {
                  final dir = '${_status.path!.path}/${textController.text}';
                  await _status.client!.mkdir(dir);
                },
                onErr: (e, s) {},
              );
              _listDir();
            } catch (e, s) {
              context.showErrDialog(e: e, s: s, operation: l10n.createFolder);
            }
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
      title: l10n.createFile,
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
                title: l10n.attention,
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
            try {
              await context.showLoadingDialog(
                fn: () async {
                  final path = '${_status.path!.path}/${textController.text}';
                  await _client!.run('touch "$path"');
                },
                onErr: (e, s) {},
              );
              _listDir();
            } catch (e, s) {
              context.showErrDialog(e: e, s: s, operation: l10n.createFile);
            }
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
      title: l10n.rename,
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
                title: l10n.attention,
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
            try {
              await context.showLoadingDialog(
                fn: () async {
                  final newName = textController.text;
                  await _status.client?.rename(file.filename, newName);
                },
                onErr: (e, s) {},
              );
              _listDir();
            } catch (e, s) {
              context.showErrDialog(e: e, s: s, operation: l10n.rename);
            }
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
        title: l10n.error,
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
    await context.showLoadingDialog(fn: () async => _client?.run(cmd));
    _listDir();
  }

  String _getRemotePath(SftpName name) {
    final prePath = _status.path!.path;
    // Only support Linux as remote now, so the seperator is '/'
    return prePath.joinPath(name.filename, seperator: '/');
  }

  Future<String> _getLocalPath(String remotePath) async {
    return Paths.file.joinPath(remotePath);
  }

  /// Only return true if the path is changed
  Future<bool> _listDir() async {
    return context.showLoadingDialog(
      fn: () async {
        _status.client ??= await _client?.sftp();
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
          if (fs.isNotEmpty && fs.firstOrNull?.filename == '.') {
            fs.removeAt(0);
          }

          /// Issue #96
          /// Due to [WillPopScope] added in this page
          /// There is no need to keep '..' folder in listdir
          /// So remove it
          if (fs.isNotEmpty && fs.firstOrNull?.filename == '..') {
            fs.removeAt(0);
          }
          if (mounted) {
            setState(() {
              _status.files = fs;
            });

            // Only update history when success
            if (Stores.setting.sftpOpenLastPath.fetch()) {
              Stores.history.sftpLastPath.put(widget.spi.id, listPath);
            }

            return true;
          }
          return false;
        } catch (e, trace) {
          Loggers.app.warning('List dir failed', e, trace);
          await _backward();
          Future.delayed(
            const Duration(milliseconds: 177),
            () => context.showRoundDialog(
              title: l10n.error,
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
      },
      barrierDismiss: true,
    );
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

enum _SortType {
  name,
  time,
  size,
  ;

  List<SftpName> sort(List<SftpName> files, {bool reversed = false}) {
    var comparator = ChainComparator<SftpName>.create();
    if (Stores.setting.sftpShowFoldersFirst.fetch()) {
      comparator = comparator.thenTrueFirst((x) => x.attr.isDirectory);
    }
    switch (this) {
      case _SortType.name:
        files.sort(
          comparator
              .thenWithComparator(
                (a, b) => Comparators.compareStringCaseInsensitive()(
                    a.filename, b.filename),
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.time:
        files.sort(
          comparator
              .thenCompareBy<num>(
                (x) => x.attr.modifyTime ?? 0,
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.size:
        files.sort(
          comparator
              .thenCompareBy<num>(
                (x) => x.attr.size ?? 0,
                reversed: reversed,
              )
              .compare,
        );
        break;
    }
    return files;
  }
}

class _SortOption {
  final _SortType sortBy;
  final bool reversed;

  _SortOption({required this.sortBy, required this.reversed});
}
