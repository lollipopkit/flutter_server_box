import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

final _octalPermReg = RegExp(r'^[0-7]{3,4}$');

final class SftpSudoHelper {
  final SSHClient client;
  final Spi spi;
  final BuildContext? Function() contextProvider;

  String? _cachedPassword;

  SftpSudoHelper({
    required this.client,
    required this.spi,
    required this.contextProvider,
  });

  bool get enabled => !spi.isRoot;

  bool get _rememberPwd => Stores.setting.rememberPwdInMem.fetch();

  Future<String?> ensurePassword({bool force = false}) async {
    if (!enabled) return '';

    if (force) {
      _cachedPassword = null;
    } else if (_rememberPwd && _cachedPassword != null) {
      return _cachedPassword;
    }

    final context = contextProvider();
    if (context == null || !context.mounted) return null;

    final pwd = await context.showPwdDialog(
      title: l10n.trySudo,
      label: spi.user,
      id: '${spi.id}_sftp_sudo',
      remember: _rememberPwd,
    );
    if (pwd == null || pwd.isEmpty) return null;
    if (_rememberPwd) {
      _cachedPassword = pwd;
    }
    return pwd;
  }

  Future<int> getFileSize(String remotePath, {String? password}) async {
    final output = await _runAndRead(
      'wc -c < ${_shellQuote(remotePath)}',
      password: password,
    );
    return int.tryParse(output.trim()) ?? 0;
  }

  Future<void> downloadTextFile(
    String remotePath,
    String localPath, {
    String? password,
  }) async {
    final text = await _runAndRead(
      'cat ${_shellQuote(remotePath)}',
      password: password,
    );
    final file = File(localPath);
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }

  Future<void> uploadTextFile(
    String localPath,
    String remotePath, {
    String? password,
  }) async {
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final data = base64Encode(bytes);
    await _runAndRead(
      "printf '%s' '$data' | base64 -d | tee ${_shellQuote(remotePath)} > /dev/null",
      password: password,
    );
  }

  Future<void> chmod(String perm, String remotePath, {String? password}) async {
    if (!_octalPermReg.hasMatch(perm)) {
      throw ArgumentError.value(
        perm,
        'perm',
        'Permission must be a 3 or 4 digit octal string',
      );
    }
    await _runAndRead(
      'chmod $perm ${_shellQuote(remotePath)}',
      password: password,
    );
  }

  Future<void> mkdir(String remotePath, {String? password}) async {
    await _runAndRead('mkdir ${_shellQuote(remotePath)}', password: password);
  }

  Future<void> touch(String remotePath, {String? password}) async {
    await _runAndRead('touch ${_shellQuote(remotePath)}', password: password);
  }

  Future<void> rename(
    String oldPath,
    String newPath, {
    String? password,
  }) async {
    await _runAndRead(
      'mv ${_shellQuote(oldPath)} ${_shellQuote(newPath)}',
      password: password,
    );
  }

  Future<void> delete(
    String remotePath, {
    required bool isDir,
    required bool recursive,
    String? password,
  }) async {
    final cmd = switch ((isDir, recursive)) {
      (true, true) => 'rm -r ${_shellQuote(remotePath)}',
      (true, false) => 'rmdir ${_shellQuote(remotePath)}',
      (false, _) => 'rm ${_shellQuote(remotePath)}',
    };
    await _runAndRead(cmd, password: password);
  }

  Future<List<SftpName>> listDir(String remotePath, {String? password}) async {
    final output = await _runAndRead(
      'find ${_shellQuote(remotePath)} '
      '-mindepth 1 -maxdepth 1 '
      '-exec sh -c \''
      'for path do '
      'name=\${path##*/}; '
      'perm=\$(stat -c %a "\$path"); '
      'type=u; '
      '[ -d "\$path" ] && type=d; '
      '[ -L "\$path" ] && type=l; '
      '[ -f "\$path" ] && type=f; '
      'size=\$(stat -c %s "\$path"); '
      'mtime=\$(stat -c %Y "\$path"); '
      'printf "%s\\0%s\\0%s\\0%s\\0%s\\0" "\$name" "\$perm" "\$type" "\$size" "\$mtime"; '
      'done'
      '\' sh {} +',
      password: password,
    );

    final items = <SftpName>[
      SftpName(
        filename: '..',
        longname: '..',
        attr: SftpFileAttrs(
          size: 0,
          mode: const SftpFileMode.value(0x4000 | 0x1ED),
          modifyTime: 0,
        ),
      ),
    ];

    final parts = output.split('\u0000').where((e) => e.isNotEmpty).toList();
    for (var i = 0; i + 4 < parts.length; i += 5) {
      final filename = parts[i];
      final permOct = int.tryParse(parts[i + 1], radix: 8) ?? 0x1A4;
      final typeChar = parts[i + 2];
      final size = int.tryParse(parts[i + 3]) ?? 0;
      final modifyTime = double.tryParse(parts[i + 4])?.toInt() ?? 0;
      final mode = _buildMode(typeChar, permOct);

      items.add(
        SftpName(
          filename: filename,
          longname: filename,
          attr: SftpFileAttrs(size: size, mode: mode, modifyTime: modifyTime),
        ),
      );
    }

    return items;
  }

  Future<String> _runAndRead(String innerCommand, {String? password}) async {
    final pwd = password ?? await ensurePassword();
    if (pwd == null) throw const _SftpSudoCancelled();
    final context = contextProvider();
    if (context == null || !context.mounted) throw const _SftpSudoCancelled();

    final (code, output) = await client.execWithPwd(
      _buildSudoCommand(innerCommand, pwd),
      context: context,
      id: '${spi.id}_sftp_sudo',
    );

    if (code == 2) {
      _cachedPassword = null;
      final retryPwd = await ensurePassword(force: true);
      if (retryPwd == null) throw const _SftpSudoCancelled();
      final retryContext = contextProvider();
      if (retryContext == null || !retryContext.mounted) {
        throw const _SftpSudoCancelled();
      }

      final retry = await client.execWithPwd(
        _buildSudoCommand(innerCommand, retryPwd),
        context: retryContext,
        id: '${spi.id}_sftp_sudo',
      );
      if (retry.$1 == 2) {
        _cachedPassword = null;
        throw Exception('Incorrect sudo password');
      }
      if (retry.$1 != 0) {
        throw Exception(
          retry.$2.trim().isEmpty ? 'Sudo command failed' : retry.$2.trim(),
        );
      }
      return retry.$2;
    }

    if (code != 0) {
      throw Exception(
        output.trim().isEmpty ? 'Sudo command failed' : output.trim(),
      );
    }
    return output;
  }

  static String _buildSudoCommand(String command, String password) {
    final pwdBase64 = base64Encode(utf8.encode(password));
    final wrapped = '($command) 2>&1';
    final escapedWrapped = wrapped.replaceAll("'", "'\\''");
    return 'echo "$pwdBase64" | base64 -d | sudo -S -- sh -c \'$escapedWrapped\'';
  }

  static String _shellQuote(String value) {
    return "'${value.replaceAll("'", "'\\''")}'";
  }

  static SftpFileMode _buildMode(String typeChar, int permOct) {
    final typeFlag = switch (typeChar) {
      'd' => 0x4000,
      'l' => 0xA000,
      'b' => 0x6000,
      'c' => 0x2000,
      'p' => 0x1000,
      's' => 0xC000,
      _ => 0x8000,
    };
    return SftpFileMode.value(typeFlag | permOct);
  }
}

final class _SftpSudoCancelled implements Exception {
  const _SftpSudoCancelled();
}
