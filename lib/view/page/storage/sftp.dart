import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/sftpfile.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/core/utils/comparator.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/browser_status.dart';
import 'package:server_box/data/model/sftp/worker.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/editor.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/widget/omit_start_text.dart';
import 'package:server_box/view/widget/two_line_text.dart';
import 'package:server_box/view/widget/unix_perm.dart';

import 'package:icons_plus/icons_plus.dart';

class SftpPage extends StatefulWidget {
  final Spi spi;
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
  late final _status = SftpBrowserStatus(_client);
  late final _client = widget.spi.server!.value.client!;
  final _sortOption = _SortOption().vn;

  @override
  void dispose() {
    super.dispose();
    _sortOption.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      Btn.icon(
        icon: const Icon(Icons.downloading),
        onTap: () => AppRoutes.sftpMission().go(context),
      ),
      _buildSortMenu(),
      _buildSearchBtn(),
    ];
    if (isDesktop) children.add(_buildRefreshBtn());

    return Scaffold(
      appBar: CustomAppBar(
        title: TwoLineText(up: 'SFTP', down: widget.spi.name),
        actions: children,
      ),
      body: _buildFileView(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  Widget _buildSortMenu() {
    final options = [
      (_SortType.name, libL10n.name),
      (_SortType.size, l10n.size),
      (_SortType.time, l10n.time),
    ];
    return ValBuilder(
      listenable: _sortOption,
      builder: (value) {
        return PopupMenuButton<_SortType>(
          icon: const Icon(Icons.sort),
          itemBuilder: (context) {
            return options.map((r) {
              final (type, name) = r;
              final selected = type == value.sortBy;
              final title =
                  selected ? "$name (${value.reversed ? '-' : '+'})" : name;
              return PopupMenuItem(
                value: type,
                child: Text(
                  title,
                  style: TextStyle(
                    color: selected ? UIs.primaryColor : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              );
            }).toList();
          },
          onSelected: (sortBy) {
            final old = _sortOption.value;
            if (old.sortBy == sortBy) {
              _sortOption.value = old.copyWith(reversed: !old.reversed);
            } else {
              _sortOption.value = old.copyWith(sortBy: sortBy);
            }
          },
        );
      },
    );
  }

  Widget _buildBottom() {
    final children = widget.isSelect
        ? [
            IconButton(
              onPressed: () => context.pop(_status.path.path),
              icon: const Icon(Icons.done),
            ),
            _buildSearchBtn(),
          ]
        : [
            _buildBackBtn(),
            _buildHomeBtn(),
            _buildAddBtn(),
            _buildGotoBtn(),
            _buildUploadBtn(),
          ];
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 7, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OmitStartText(_status.path.path),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildFileView() {
    if (_status.files.isEmpty) return Center(child: Text(libL10n.empty));

    return RefreshIndicator(
      onRefresh: _listDir,
      child: FadeIn(
        key: Key(widget.spi.name + _status.path.path),
        child: ValBuilder(
          listenable: _sortOption,
          builder: (sortOption) {
            final files = sortOption.sortBy.sort(
              _status.files,
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
            _status.path.path = file.filename;
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
        title: Text(libL10n.delete),
        onTap: () => _delete(file),
      ),
      ListTile(
        leading: const Icon(Icons.abc),
        title: Text(libL10n.rename),
        onTap: () => _rename(file),
      ),
      ListTile(
        leading: const Icon(MingCute.copy_line),
        title: Text(l10n.copyPath),
        onTap: () {
          context.pop();
          Pfs.copy(_getRemotePath(file));
          context.showSnackBar(libL10n.success);
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
            actions: Btnx.okReds,
          );

          final permStr = newPerm.perm;
          if (ok == true && permStr != perm.perm) {
            await context.showLoadingDialog(fn: () async {
              await _client.run('chmod $permStr "${_getRemotePath(file)}"');
              await _listDir();
            });
          }
        },
      ),
    ];
    if (notDir) {
      children.addAll([
        ListTile(
          leading: const Icon(Icons.edit),
          title: Text(libL10n.edit),
          onTap: () => _edit(file),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(libL10n.download),
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
    context.pop();

    // #489
    final editor = Stores.setting.sftpEditor.fetch();
    if (editor.isNotEmpty) {
      // Use single quote to avoid escape
      final cmd = "$editor '${_getRemotePath(name)}'";
      await AppRoutes.ssh(spi: widget.spi, initCmd: cmd).go(context);
      await _listDir();
      return;
    }

    final size = name.attr.size;
    if (size == null || size > Miscs.editorMaxSize) {
      context.showSnackBar(l10n.fileTooLarge(
        name.filename,
        size ?? 0,
        Miscs.editorMaxSize,
      ));
      return;
    }

    final remotePath = _getRemotePath(name);
    final localPath = _getLocalPath(remotePath);
    final completer = Completer();
    final req = SftpReq(
      widget.spi,
      remotePath,
      localPath,
      SftpReqType.download,
    );
    SftpProvider.add(req, completer: completer);
    final (suc, err) = await context.showLoadingDialog(
      fn: () => completer.future,
    );
    if (suc == null || err != null) return;

    final ret = await EditorPage.route.go(
      context,
      args: EditorPageArgs(path: localPath),
    );
    if (ret?.editExistedOk == true) {
      SftpProvider.add(SftpReq(
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
      title: libL10n.attention,
      child: Text('${l10n.dl2Local(name.filename)}\n${l10n.keepForeground}'),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();
            final remotePath = _getRemotePath(name);

            SftpProvider.add(
              SftpReq(
                widget.spi,
                remotePath,
                _getLocalPath(remotePath),
                SftpReqType.download,
              ),
            );

            context.pop();
          },
          child: Text(libL10n.download),
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
        return libL10n.askContinue('${libL10n.delete} ${file.filename}');
      }
      return libL10n.askContinue('${libL10n.delete} ${file.filename}');
    }();

    // Most users don't know that SFTP can't delete a directory which is not
    // empty, so we provide a checkbox to let user choose to use `rm -r` or not
    context.showRoundDialog(
      title: libL10n.attention,
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
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () async {
            context.pop();

            final (suc, err) = await context.showLoadingDialog(
              fn: () async {
                final remotePath = _getRemotePath(file);
                if (useRmr) {
                  await _client.run('rm -r "$remotePath"');
                } else if (file.attr.isDirectory) {
                  await _status.client!.rmdir(remotePath);
                } else {
                  await _status.client!.remove(remotePath);
                }
                return true;
              },
            );
            if (suc == null || err != null) return;

            _listDir();
          },
          child: Text(libL10n.delete, style: UIs.textRed),
        ),
      ],
    );
  }

  void _mkdir() {
    context.pop();
    final textController = TextEditingController();

    void onSubmitted() async {
      final text = textController.text.trim();
      if (text.isEmpty) {
        context.showRoundDialog(
          child: Text(libL10n.empty),
          actions: Btnx.oks,
        );
        return;
      }
      context.pop();

      final (suc, err) = await context.showLoadingDialog(
        fn: () async {
          final dir = '${_status.path.path}/$text';
          await _status.client!.mkdir(dir);
          return true;
        },
      );
      if (suc == null || err != null) return;

      _listDir();
    }

    context.showRoundDialog(
      title: libL10n.folder,
      child: Input(
        autoFocus: true,
        icon: Icons.folder,
        controller: textController,
        label: libL10n.name,
        suggestion: true,
        onSubmitted: (_) => onSubmitted(),
      ),
      actions: Btn.ok(
        onTap: onSubmitted,
        red: true,
      ).toList,
    );
  }

  void _newFile() {
    context.pop();
    final textController = TextEditingController();

    void onSubmitted() async {
      final text = textController.text.trim();
      if (text.isEmpty) {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(libL10n.empty),
          actions: Btnx.oks,
        );
        return;
      }
      context.pop();

      final (suc, err) = await context.showLoadingDialog(
        fn: () async {
          final path = '${_status.path.path}/$text';
          await _client.run('touch "$path"');
          return true;
        },
      );
      if (suc == null || err != null) return;

      _listDir();
    }

    context.showRoundDialog(
      title: libL10n.file,
      child: Input(
        autoFocus: true,
        icon: Icons.insert_drive_file,
        controller: textController,
        label: libL10n.name,
        suggestion: true,
        onSubmitted: (_) => onSubmitted(),
      ),
      actions: Btn.ok(onTap: onSubmitted, red: true).toList,
    );
  }

  void _rename(SftpName file) {
    context.pop();
    final textController = TextEditingController(text: file.filename);

    void onSubmitted() async {
      final text = textController.text.trim();
      if (text.isEmpty) {
        context.showRoundDialog(
          title: libL10n.attention,
          child: Text(libL10n.empty),
          actions: Btnx.oks,
        );
        return;
      }
      context.pop();

      final (suc, err) = await context.showLoadingDialog(
        fn: () async {
          final newName = textController.text;
          await _status.client?.rename(file.filename, newName);
          return true;
        },
      );
      if (suc == null || err != null) return;

      _listDir();
    }

    context.showRoundDialog(
      title: libL10n.rename,
      child: Input(
        autoFocus: true,
        icon: Icons.abc,
        controller: textController,
        label: libL10n.name,
        suggestion: true,
        onSubmitted: (_) => onSubmitted(),
      ),
      actions: [
        Btn.cancel(),
        Btn.ok(onTap: onSubmitted, red: true),
      ],
    );
  }

  Future<void> _decompress(SftpName name) async {
    context.pop();
    final absPath = _getRemotePath(name);
    final cmd = _getDecompressCmd(absPath);
    if (cmd == null) {
      context.showRoundDialog(
        title: libL10n.error,
        child: Text('Unsupport file: ${name.filename}'),
        actions: [Btn.ok()],
      );
      return;
    }

    final confirm = await context.showRoundDialog(
      title: libL10n.attention,
      child: SimpleMarkdown(data: '```sh\n$cmd\n```'),
      actions: Btnx.cancelRedOk,
    );
    if (confirm != true) return;

    await AppRoutes.ssh(spi: widget.spi, initCmd: cmd).go(context);
    _listDir();
  }

  String _getRemotePath(SftpName name) {
    final prePath = _status.path.path;
    // Only support Linux as remote now, so the seperator is '/'
    return prePath.joinPath(name.filename, separator: '/');
  }

  /// Local file dir + server id + remote path
  String _getLocalPath(String remotePath) {
    return Paths.file.joinPath(widget.spi.id).joinPath(remotePath);
  }

  /// Only return true if the path is changed
  Future<bool?> _listDir() async {
    final (ret, err) = await context.showLoadingDialog(
      fn: () async {
        _status.client ??= await _client.sftp();
        final listPath = _status.path.path;
        final fs = await _status.client?.listdir(listPath);
        if (fs == null) {
          return false;
        }
        fs.sort((a, b) => a.filename.compareTo(b.filename));

        /// Issue #97
        /// In order to compatible with the Synology NAS
        /// which not has '.' and '..' in listdir
        if (fs.firstOrNull?.filename == '.') {
          fs.removeAt(0);
        }

        if (fs.isNotEmpty &&
            fs.firstOrNull?.filename == '..' &&
            _status.path.path == '/') {
          fs.removeAt(0);
        }
        if (mounted) {
          setState(() {
            _status.files
              ..clear()
              ..addAll(fs);
          });

          // Only update history when success
          if (Stores.setting.sftpOpenLastPath.fetch()) {
            Stores.history.sftpLastPath.put(widget.spi.id, listPath);
          }

          return true;
        }
        return false;
      },
      barrierDismiss: true,
    );
    return ret ?? err == null;
  }

  Future<void> _backward() async {
    if (_status.path.undo()) {
      await _listDir();
    }
  }

  Widget _buildBackBtn() {
    return Btn.icon(
      onTap: _backward,
      icon: const Icon(Icons.arrow_back),
    );
  }

  Widget _buildSearchBtn() {
    return Btn.icon(
      onTap: () {
        Stream<SftpName> find(String query) async* {
          final fs = _status.files;
          for (final f in fs) {
            if (f.filename.contains(query)) yield f;
          }
        }

        showSearch(
          context: context,
          delegate: SearchPage(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            future: (q) => find(q).toList(),
            builder: (ctx, e) => _buildItem(e, beforeTap: ctx.pop),
          ),
        );
      },
      icon: const Icon(Icons.search),
    );
  }

  Widget _buildUploadBtn() {
    return Btn.icon(
      onTap: () async {
        final idx = await context.showRoundDialog(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Btn.tile(
              icon: const Icon(Icons.open_in_new),
              text: l10n.system,
              onTap: () => context.pop(1),
            ),
            Btn.tile(
              icon: const Icon(Icons.folder),
              text: l10n.inner,
              onTap: () => context.pop(0),
            ),
          ],
        ));
        final path = switch (idx) {
          0 => await LocalFilePage.route.go(
              context,
              args: const LocalFilePageArgs(isPickFile: true),
            ),
          1 => await Pfs.pickFilePath(),
          _ => null,
        };
        if (path == null) return;

        final remoteDir = _status.path.path;
        final fileName = path.split(Platform.pathSeparator).lastOrNull;
        final remotePath = '$remoteDir/$fileName';
        Loggers.app.info('SFTP upload local: $path, remote: $remotePath');
        SftpProvider.add(
          SftpReq(widget.spi, remotePath, path, SftpReqType.upload),
        );
      },
      icon: const Icon(Icons.upload_file),
    );
  }

  Widget _buildAddBtn() {
    return Btn.icon(
      onTap: () => context.showRoundDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Btn.tile(
              icon: const Icon(Icons.folder),
              text: libL10n.folder,
              onTap: _mkdir,
            ),
            Btn.tile(
              icon: const Icon(Icons.insert_drive_file),
              text: libL10n.file,
              onTap: _newFile,
            ),
          ],
        ),
      ),
      icon: const Icon(Icons.add),
    );
  }

  Widget _buildGotoBtn() {
    return Btn.icon(
      onTap: () async {
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
                label: libL10n.path,
                node: node,
                controller: controller,
                suggestion: true,
                onSubmitted: (value) => context.pop(value),
              );
            },
          ),
        );

        if (p == null || p.isEmpty) {
          return;
        }

        _status.path.path = p;
        final suc = await _listDir() ?? false;
        if (suc && Stores.setting.recordHistory.fetch()) {
          Stores.history.sftpGoPath.add(p);
        }
      },
      icon: const Icon(Icons.gps_fixed),
    );
  }

  Widget _buildRefreshBtn() {
    return Btn.icon(
      onTap: _listDir,
      icon: const Icon(Icons.refresh),
    );
  }

  Widget _buildHomeBtn() {
    return IconButton(
      onPressed: () {
        final user = widget.spi.user;
        _status.path.path = user != 'root' ? '/home/$user' : '/root';
        _listDir();
      },
      icon: const Icon(Icons.home),
    );
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

    _status.path.path = widget.initPath ?? initPath;
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

  _SortOption({this.sortBy = _SortType.name, this.reversed = false});

  _SortOption copyWith({
    _SortType? sortBy,
    bool? reversed,
  }) {
    return _SortOption(
      sortBy: sortBy ?? this.sortBy,
      reversed: reversed ?? this.reversed,
    );
  }
}
