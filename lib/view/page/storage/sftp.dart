import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/sftpfile.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/utils/comparator.dart';
import 'package:server_box/core/utils/host_key_helper.dart';
import 'package:server_box/core/utils/sftp_sudo.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/browser_status.dart';
import 'package:server_box/data/model/sftp/worker.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/sftp.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/ssh/page/page.dart';
import 'package:server_box/view/page/storage/local.dart';
import 'package:server_box/view/page/storage/sftp_mission.dart';
import 'package:server_box/view/widget/omit_start_text.dart';
import 'package:server_box/view/widget/unix_perm.dart';

final _sftpPermissionDeniedReg = RegExp(
  r'permission denied',
  caseSensitive: false,
);

final class SftpPageArgs {
  final Spi spi;
  final bool isSelect;
  final String? initPath;

  const SftpPageArgs({required this.spi, this.isSelect = false, this.initPath});
}

class SftpPage extends ConsumerStatefulWidget {
  final SftpPageArgs args;

  const SftpPage({super.key, required this.args});

  @override
  ConsumerState<SftpPage> createState() => _SftpPageState();

  static const route = AppRouteArg<String, SftpPageArgs>(
    page: SftpPage.new,
    path: '/sftp',
  );
}

class _SftpPageState extends ConsumerState<SftpPage> with AfterLayoutMixin {
  late final SftpBrowserStatus _status;
  late final SSHClient _client;
  late final SftpSudoHelper _sudoHelper;
  final _sortOption = _SortOption().vn;
  final _sudoMode = false.vn;
  int _filesVersion = 0;
  int _sortedFilesVersion = -1;
  _SortOption? _sortedFilesOption;
  bool? _sortedFilesShowFoldersFirst;
  List<SftpName>? _sortedFilesCache;

  bool get _useSudo => _sudoHelper.enabled && _sudoMode.value;

  @override
  void initState() {
    super.initState();
    final serverState = ref.read(serverProvider(widget.args.spi.id));
    _client = serverState.client!;
    _status = SftpBrowserStatus(_client);
    _sudoHelper = SftpSudoHelper(
      client: _client,
      spi: widget.args.spi,
      context: context,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _sortOption.dispose();
    _sudoMode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = [
      Btn.icon(
        icon: const Icon(Icons.downloading),
        onTap: () => SftpMissionPage.route.go(context),
      ),
      _buildSortMenu(),
      _buildSearchBtn(),
      if (_sudoHelper.enabled) _buildSudoBtn(),
    ];
    if (isDesktop) children.add(_buildRefreshBtn());

    return Scaffold(
      appBar: CustomAppBar(
        title: Text(widget.args.spi.name),
        actions: children,
      ),
      body: _buildFileView(),
      bottomNavigationBar: _buildBottom(),
    );
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    String initPath;

    try {
      final homeResult = await _client.run(
        'getent passwd -- ${_shellQuote(widget.args.spi.user)}',
      );
      final passwdEntry = homeResult.string.trim();
      final homePath = passwdEntry.split(':').elementAtOrNull(5)?.trim() ?? '';
      if (homePath.isNotEmpty && homePath.startsWith('/')) {
        initPath = homePath;
      } else {
        final user = widget.args.spi.user;
        initPath = user != 'root' ? '/home/$user' : '/root';
      }
    } catch (_) {
      final user = widget.args.spi.user;
      initPath = user != 'root' ? '/home/$user' : '/root';
    }

    if (Stores.setting.sftpOpenLastPath.fetch()) {
      final history = Stores.history.sftpLastPath.fetch(widget.args.spi.id);
      if (history != null) {
        SftpClient? sftp;
        try {
          final normalizedHistory = _normalizeSftpPath(history);
          sftp = await _client.sftp();
          await sftp.listdir(normalizedHistory);
          initPath = normalizedHistory;
        } catch (_) {
        } finally {
          sftp?.close();
        }
      }
    }

    _status.path.path = widget.args.initPath ?? initPath;
    unawaited(_listDir());
  }
}

extension _UI on _SftpPageState {
  Widget _buildSortMenu() {
    final options = [
      (_SortType.name, libL10n.name),
      (_SortType.size, l10n.size),
      (_SortType.time, l10n.time),
    ];
    return _sortOption.listenVal((value) {
      return PopupMenuButton<_SortType>(
        icon: const Icon(Icons.sort),
        itemBuilder: (context) {
          return options.map((r) {
            final (type, name) = r;
            final selected = type == value.sortBy;
            final title = selected
                ? "$name (${value.reversed ? '-' : '+'})"
                : name;
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
    });
  }

  Widget _buildBottom() {
    final children = widget.args.isSelect
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
            _sudoMode.listenVal((enabled) {
              return Row(
                children: [
                  Expanded(child: OmitStartText(_status.path.path)),
                  if (enabled) ...[
                    UIs.width7,
                    Icon(Icons.security, size: 16, color: UIs.primaryColor),
                  ],
                ],
              );
            }),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSudoBtn() {
    return _sudoMode.listenVal((enabled) {
      return IconButton(
        tooltip: l10n.trySudo,
        onPressed: () => _sudoMode.value = !enabled,
        icon: Icon(Icons.security, color: enabled ? UIs.primaryColor : null),
      );
    });
  }

  Widget _buildFileView() {
    if (_status.files.isEmpty) return Center(child: Text(libL10n.empty));

    return RefreshIndicator(
      onRefresh: _listDir,
      child: FadeIn(
        key: Key(widget.args.spi.name + _status.path.path),
        child: ValBuilder(
          listenable: _sortOption,
          builder: (sortOption) {
            final files = _getSortedFiles(sortOption);
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
    final double screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth < 350) {
      return CardX(
        child: ListTile(
          leading: Icon(
            isDir ? Icons.folder_outlined : Icons.insert_drive_file,
          ),
          title: Text(file.filename),
          subtitle: isDir
              ? Text(
                  '${_getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
                  style: UIs.textGrey,
                )
              : Text(
                  '${(file.attr.size ?? 0).bytes2Str}\n${_getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
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
    } else {
      return CardX(
        child: ListTile(
          leading: Icon(
            isDir ? Icons.folder_outlined : Icons.insert_drive_file,
          ),
          title: Text(file.filename),
          trailing: Text(
            '${_getTime(file.attr.modifyTime)}\n${file.attr.mode?.str ?? ''}',
            style: UIs.textGrey,
            textAlign: TextAlign.right,
          ),
          subtitle: isDir
              ? null
              : Text((file.attr.size ?? 0).bytes2Str, style: UIs.textGrey),
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
  }

  List<SftpName> _getSortedFiles(_SortOption sortOption) {
    final showFoldersFirst = Stores.setting.sftpShowFoldersFirst.fetch();
    final cachedFiles = _sortedFilesCache;
    if (cachedFiles != null &&
        _sortedFilesVersion == _filesVersion &&
        _sortedFilesOption == sortOption &&
        _sortedFilesShowFoldersFirst == showFoldersFirst) {
      return cachedFiles;
    }

    final sortedFiles = sortOption.sortBy.sort(
      _status.files,
      reversed: sortOption.reversed,
    );
    _sortedFilesVersion = _filesVersion;
    _sortedFilesOption = sortOption;
    _sortedFilesShowFoldersFirst = showFoldersFirst;
    _sortedFilesCache = sortedFiles;
    return sortedFiles;
  }
}

extension _Actions on _SftpPageState {
  String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  bool _isPermissionDeniedErr(Object? err) {
    final msg = '$err'.toLowerCase();
    return msg.contains('permission denied') ||
        msg.contains('access denied') ||
        msg.contains('code 3') ||
        msg.contains('failure');
  }

  Future<bool> _askRetryWithSudo() async {
    if (_useSudo || !_sudoHelper.enabled) return false;

    final retry = await context.showRoundDialog<bool>(
      title: l10n.trySudo,
      child: Text('Permission denied.\n${libL10n.askContinue(l10n.trySudo)}'),
      actions: Btnx.cancelRedOk,
    );
    return retry == true;
  }

  Future<void> _runShellCommand(String command) async {
    final (code, output) = await _client.execWithPwd(
      command,
      context: context,
      id: '${widget.args.spi.id}_sftp_cmd',
    );
    if (code != 0) {
      throw Exception(output.trim().isEmpty ? 'Command failed' : output.trim());
    }
  }

  Future<bool> _runWithSudoRetry({
    required Future<void> Function() normal,
    required Future<void> Function(String pwd) sudo,
  }) async {
    if (_useSudo) {
      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null) return false;
      final (suc, err) = await context.showLoadingDialog(
        fn: () async {
          await sudo(pwd);
          return true;
        },
      );
      return suc != null && err == null;
    }

    final (suc, err) = await context.showLoadingDialog(
      fn: () async {
        await normal();
        return true;
      },
    );
    if (suc != null && err == null) return true;
    if (!_isPermissionDeniedErr(err)) return false;

    final shouldRetry = await _askRetryWithSudo();
    if (!shouldRetry) return false;

    final pwd = await _sudoHelper.ensurePassword();
    if (pwd == null) return false;
    final (sudoSuc, sudoErr) = await context.showLoadingDialog(
      fn: () async {
        await sudo(pwd);
        return true;
      },
    );
    if (sudoSuc != null && sudoErr == null) {
      _sudoMode.value = true;
    }
    return sudoSuc != null && sudoErr == null;
  }

  Future<bool> _canWriteRemotePath(String remoteDir) async {
    final (code, _) = await _client.execWithPwd(
      'test -w ${_shellQuote(remoteDir)}',
      context: context,
      id: '${widget.args.spi.id}_sftp_write_probe',
    );
    return code == 0;
  }

  Future<bool> _uploadViaSudo({
    required String localPath,
    required String remotePath,
    required String fileName,
  }) async {
    final pwd = await _sudoHelper.ensurePassword();
    if (pwd == null) return false;

    final tmpPath =
        '/tmp/serverbox-upload-${DateTime.now().microsecondsSinceEpoch}-$fileName';
    final completer = Completer();
    final req = SftpReq(
      widget.args.spi,
      tmpPath,
      localPath,
      SftpReqType.upload,
    );
    final reqId = ref
        .read(sftpProvider.notifier)
        .add(req, completer: completer);

    final (uploaded, uploadErr) = await context.showLoadingDialog(
      fn: () async {
        await completer.future;
        final status = ref.read(sftpProvider.notifier).get(reqId);
        if (status?.error != null) {
          throw status!.error!;
        }
        await _sudoHelper.rename(tmpPath, remotePath, password: pwd);
        return true;
      },
    );

    if (uploaded != null && uploadErr == null) {
      _sudoMode.value = true;
      return true;
    }

    try {
      await _runShellCommand('rm -f ${_shellQuote(tmpPath)}');
    } catch (_) {}
    return false;
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
            final remotePath = _getRemotePath(file);
            final suc = await _runWithSudoRetry(
              normal: () => _runShellCommand(
                'chmod ${_shellQuote(permStr)} ${_shellQuote(remotePath)}',
              ),
              sudo: (pwd) =>
                  _sudoHelper.chmod(permStr, remotePath, password: pwd),
            );
            if (!suc) return;
            await _listDir();
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
            title: Text(libL10n.decompress),
            onTap: () => _decompress(file),
          ),
      ]);
    }
    context.showRoundDialog(
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Future<void> _edit(SftpName name) async {
    context.pop();

    final remotePath = _getRemotePath(name);
    final useSudoForEdit = _useSudo;

    // #489
    final editor = Stores.setting.sftpEditor.fetch();
    if (editor.isNotEmpty) {
      final sudoPrefix = useSudoForEdit ? 'sudo ' : '';
      // Use single quote to avoid escape
      final cmd = "$sudoPrefix$editor '$remotePath'";
      final args = SshPageArgs(spi: widget.args.spi, initCmd: cmd);
      await SSHPage.route.go(context, args);
      await _listDir();
      return;
    }

    int? size = name.attr.size;
    if (useSudoForEdit) {
      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null) return;
      final (ret, err) = await context.showLoadingDialog(
        fn: () => _sudoHelper.getFileSize(remotePath, password: pwd),
      );
      if (ret == null || err != null) return;
      size = ret;
    }

    if (size == null || size > Miscs.editorMaxSize) {
      context.showSnackBar(
        l10n.fileTooLarge(name.filename, size ?? 0, Miscs.editorMaxSize),
      );
      return;
    }

    final localPath = _getLocalPath(remotePath);
    if (useSudoForEdit) {
      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null) return;
      final (suc, err) = await context.showLoadingDialog(
        fn: () async {
          await _sudoHelper.downloadTextFile(
            remotePath,
            localPath,
            password: pwd,
          );
          return true;
        },
      );
      if (suc == null || err != null) return;
    } else {
      if (!await ensureHostKeyAcceptedForSftp(context, widget.args.spi)) {
        return;
      }

      final completer = Completer();
      final req = SftpReq(
        widget.args.spi,
        remotePath,
        localPath,
        SftpReqType.download,
      );
      ref.read(sftpProvider.notifier).add(req, completer: completer);
      final (suc, err) = await context.showLoadingDialog(
        fn: () => completer.future,
      );
      if (suc == null || err != null) return;
    }

    await EditorPage.route.go(
      context,
      args: EditorPageArgs(
        path: localPath,
        onSave: (_) async {
          if (useSudoForEdit) {
            final pwd = await _sudoHelper.ensurePassword();
            if (pwd == null) return;
            final (suc, err) = await context.showLoadingDialog(
              fn: () async {
                await _sudoHelper.uploadTextFile(
                  localPath,
                  remotePath,
                  password: pwd,
                );
                return true;
              },
            );
            if (suc == null || err != null) return;
            if (context.mounted) context.showSnackBar(libL10n.success);
            await _listDir();
            return;
          }

          if (!await ensureHostKeyAcceptedForSftp(context, widget.args.spi)) {
            return;
          }
          ref
              .read(sftpProvider.notifier)
              .add(
                SftpReq(
                  widget.args.spi,
                  remotePath,
                  localPath,
                  SftpReqType.upload,
                ),
              );
          context.showSnackBar(l10n.added2List);
        },
        closeAfterSave: Stores.setting.closeAfterSave.fetch(),
        softWrap: Stores.setting.editorSoftWrap.fetch(),
        enableHighlight: Stores.setting.editorHighlight.fetch(),
        fontFamily: () {
          final font = Stores.setting.editorFontFamily.fetch();
          return font.isEmpty ? null : font;
        }(),
      ),
    );
  }

  void _download(SftpName name) {
    context.showRoundDialog(
      title: libL10n.attention,
      child: Text('${l10n.dl2Local(name.filename)}\n${l10n.keepForeground}'),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.pop();
            final remotePath = _getRemotePath(name);

            if (!await ensureHostKeyAcceptedForSftp(context, widget.args.spi)) {
              return;
            }

            ref
                .read(sftpProvider.notifier)
                .add(
                  SftpReq(
                    widget.args.spi,
                    remotePath,
                    _getLocalPath(remotePath),
                    SftpReqType.download,
                  ),
                );

            context.pop();
          },
          child: Text(libL10n.download),
        ),
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
          ListTile(title: Text(text)),
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
        TextButton(onPressed: () => context.pop(), child: Text(libL10n.cancel)),
        TextButton(
          onPressed: () async {
            context.pop();
            final remotePath = _getRemotePath(file);
            final suc = await _runWithSudoRetry(
              normal: () async {
                if (useRmr) {
                  await _runShellCommand('rm -r ${_shellQuote(remotePath)}');
                } else if (file.attr.isDirectory) {
                  await _status.client!.rmdir(remotePath);
                } else {
                  await _status.client!.remove(remotePath);
                }
              },
              sudo: (pwd) => _sudoHelper.delete(
                remotePath,
                isDir: file.attr.isDirectory,
                recursive: useRmr,
                password: pwd,
              ),
            );
            if (!suc) return;

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
        context.showRoundDialog(child: Text(libL10n.empty), actions: Btnx.oks);
        return;
      }
      context.pop();
      final dir = '${_status.path.path}/$text';
      final suc = await _runWithSudoRetry(
        normal: () => _status.client!.mkdir(dir),
        sudo: (pwd) => _sudoHelper.mkdir(dir, password: pwd),
      );
      if (!suc) return;

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
      actions: Btn.ok(onTap: onSubmitted, red: true).toList,
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
      final path = '${_status.path.path}/$text';
      final suc = await _runWithSudoRetry(
        normal: () => _runShellCommand('touch ${_shellQuote(path)}'),
        sudo: (pwd) => _sudoHelper.touch(path, password: pwd),
      );
      if (!suc) return;

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
      final newName = textController.text;
      final suc = await _runWithSudoRetry(
        normal: () => _status.client!.rename(file.filename, newName),
        sudo: (pwd) => _sudoHelper.rename(
          _getRemotePath(file),
          _status.path.path.joinPath(newName, separator: '/'),
          password: pwd,
        ),
      );
      if (!suc) return;

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

    final args = SshPageArgs(spi: widget.args.spi, initCmd: cmd);
    await SSHPage.route.go(context, args);
    _listDir();
  }

  String _getRemotePath(SftpName name) {
    final prePath = _status.path.path;
    // Only support Linux as remote now, so the seperator is '/'
    return prePath.joinPath(name.filename, separator: '/');
  }

  /// Local file dir + server id + remote path
  String _getLocalPath(String remotePath) {
    var normalizedPath = remotePath.replaceAll('/', Pfs.seperator);
    if (normalizedPath.startsWith(Pfs.seperator)) {
      normalizedPath = normalizedPath.substring(1);
    }
    return Paths.file.joinPath(widget.args.spi.id).joinPath(normalizedPath);
  }

  /// Only return true if the path is changed
  Future<bool?> _listDir() async {
    final (ret, err) = await context.showLoadingDialog(
      fn: () async {
        final listPath = _status.path.path;
        final fs = await _listDirWithFallback(listPath);
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
          // ignore: invalid_use_of_protected_member
          setState(() {
            _status.files
              ..clear()
              ..addAll(fs);
            _filesVersion++;
            _sortedFilesCache = null;
            _sortedFilesShowFoldersFirst = null;
          });

          // Only update history when success
          if (Stores.setting.sftpOpenLastPath.fetch()) {
            final normalizedPath = _normalizeSftpPath(listPath);
            Stores.history.sftpLastPath.put(widget.args.spi.id, normalizedPath);
          }

          return true;
        }
        return false;
      },
      barrierDismiss: true,
    );
    return ret ?? err == null;
  }

  Future<List<SftpName>?> _listDirWithFallback(String listPath) async {
    if (_useSudo) {
      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null) return null;
      final items = await _sudoHelper.listDir(listPath, password: pwd);
      _sudoMode.value = true;
      return items;
    }

    try {
      _status.client ??= await _client.sftp();
      return await _status.client?.listdir(listPath);
    } on SftpStatusError catch (e) {
      final canFallback =
          _sudoHelper.enabled &&
          (e.code == 3 || _sftpPermissionDeniedReg.hasMatch(e.message));
      if (!canFallback) rethrow;

      final pwd = await _sudoHelper.ensurePassword();
      if (pwd == null) return null;
      final items = await _sudoHelper.listDir(listPath, password: pwd);
      _sudoMode.value = true;
      return items;
    }
  }

  Future<void> _backward() async {
    if (_status.path.undo()) {
      await _listDir();
    }
  }

  Widget _buildBackBtn() {
    return Btn.icon(onTap: _backward, icon: const Icon(Icons.arrow_back));
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
                text: libL10n.inner,
                onTap: () => context.pop(0),
              ),
            ],
          ),
        );
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
        if (fileName == null || fileName.isEmpty) return;
        final remotePath = '$remoteDir/$fileName';
        Loggers.app.info('SFTP upload local: $path, remote: $remotePath');
        if (!await ensureHostKeyAcceptedForSftp(context, widget.args.spi)) {
          return;
        }

        if (_useSudo) {
          await _uploadViaSudo(
            localPath: path,
            remotePath: remotePath,
            fileName: fileName,
          );
          await _listDir();
          return;
        }

        final writable = await _canWriteRemotePath(remoteDir);
        if (!writable) {
          final shouldRetry = await _askRetryWithSudo();
          if (shouldRetry) {
            final suc = await _uploadViaSudo(
              localPath: path,
              remotePath: remotePath,
              fileName: fileName,
            );
            if (suc) {
              await _listDir();
            }
          }
          return;
        }

        ref
            .read(sftpProvider.notifier)
            .add(
              SftpReq(widget.args.spi, remotePath, path, SftpReqType.upload),
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
                (e) => e.contains(val.text),
              );
            },
            fieldViewBuilder: (_, controller, node, _) {
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
    return Btn.icon(onTap: _listDir, icon: const Icon(Icons.refresh));
  }

  Widget _buildHomeBtn() {
    return IconButton(
      onPressed: () {
        final user = widget.args.spi.user;
        _status.path.path = user != 'root' ? '/home/$user' : '/root';
        _listDir();
      },
      icon: const Icon(Icons.home),
    );
  }
}

String _normalizeSftpPath(String path) => path.replaceAll(RegExp(r'/+'), '/');

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
  return DateTime.fromMillisecondsSinceEpoch(
    (unixMill ?? 0) * 1000,
  ).toString().replaceFirst('.000', '');
}

enum _SortType {
  name,
  time,
  size;

  List<SftpName> sort(List<SftpName> files, {bool reversed = false}) {
    final sortedFiles = List<SftpName>.of(files);
    var comparator = ChainComparator<SftpName>.create();
    if (Stores.setting.sftpShowFoldersFirst.fetch()) {
      comparator = comparator.thenTrueFirst((x) => x.attr.isDirectory);
    }
    switch (this) {
      case _SortType.name:
        sortedFiles.sort(
          comparator
              .thenWithComparator(
                (a, b) => Comparators.compareStringCaseInsensitive()(
                  a.filename,
                  b.filename,
                ),
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.time:
        sortedFiles.sort(
          comparator
              .thenCompareBy<num>(
                (x) => x.attr.modifyTime ?? 0,
                reversed: reversed,
              )
              .compare,
        );
        break;
      case _SortType.size:
        sortedFiles.sort(
          comparator
              .thenCompareBy<num>((x) => x.attr.size ?? 0, reversed: reversed)
              .compare,
        );
        break;
    }
    return sortedFiles;
  }
}

class _SortOption {
  final _SortType sortBy;
  final bool reversed;

  _SortOption({this.sortBy = _SortType.name, this.reversed = false});

  _SortOption copyWith({_SortType? sortBy, bool? reversed}) {
    return _SortOption(
      sortBy: sortBy ?? this.sortBy,
      reversed: reversed ?? this.reversed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _SortOption &&
        other.sortBy == sortBy &&
        other.reversed == reversed;
  }

  @override
  int get hashCode => Object.hash(sortBy, reversed);
}
