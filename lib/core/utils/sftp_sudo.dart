import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

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
      label: spi.ssh?.user ?? '',
      id: '${spi.id}_sftp_sudo',
      remember: _rememberPwd,
    );
    if (pwd == null || pwd.isEmpty) return null;
    if (_rememberPwd) {
      _cachedPassword = pwd;
    }
    return pwd;
  }

  /// Runs [command] as root and answers what it printed.
  ///
  /// The general form of everything below, for callers holding a command
  /// rather than an intention — [SftpEscalation], whose whole contract is that
  /// the backend says what to run and this side decides how to get the rights
  /// to run it.
  Future<String> runAsRoot(String command) => _runAndRead(command);

  Future<int> getFileSize(String remotePath, {String? password}) async {
    final output = await _runAndRead(
      'wc -c < ${shellSingleQuote(remotePath)}',
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
      'cat ${shellSingleQuote(remotePath)}',
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
      "printf '%s' '$data' | base64 -d | tee ${shellSingleQuote(remotePath)} > /dev/null",
      password: password,
    );
  }

  Future<void> rename(
    String oldPath,
    String newPath, {
    String? password,
  }) async {
    await _runAndRead(
      'mv ${shellSingleQuote(oldPath)} ${shellSingleQuote(newPath)}',
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
      (true, true) => 'rm -r ${shellSingleQuote(remotePath)}',
      (true, false) => 'rmdir ${shellSingleQuote(remotePath)}',
      (false, _) => 'rm ${shellSingleQuote(remotePath)}',
    };
    await _runAndRead(cmd, password: password);
  }

  Future<String> _runAndRead(String innerCommand, {String? password}) async {
    final pwd = password ?? await ensurePassword();
    if (pwd == null) throw const SftpSudoCancelled();
    final context = contextProvider();
    if (context == null || !context.mounted) throw const SftpSudoCancelled();

    final (code, output) = await client.execWithPwd(
      _buildSudoCommand(innerCommand, pwd),
      context: context,
      id: '${spi.id}_sftp_sudo',
    );

    if (code == kSudoPasswordRejected) {
      _cachedPassword = null;
      final retryPwd = await ensurePassword(force: true);
      if (retryPwd == null) throw const SftpSudoCancelled();
      final retryContext = contextProvider();
      if (retryContext == null || !retryContext.mounted) {
        throw const SftpSudoCancelled();
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
    final wrapped = '($command) 2>&1';
    // Use shellSingleQuote for consistent escaping (see shell_quote.dart).
    final quotedWrapped = shellSingleQuote(wrapped);
    final quotedPwd = shellSingleQuote(password);
    // Use shell builtin printf to pipe password to sudo -S.
    // printf is a shell builtin so the password does not appear in
    // the process argument list (unlike external `echo`).
    // shellSingleQuote wraps in single quotes, so strip the outer quotes
    // for the printf %s argument and re-add with \n handling.
    // Simpler: use the quoted forms directly.
    return "printf '%s\\n' $quotedPwd | sudo -S -- sh -c $quotedWrapped";
  }
}

/// The user was asked for a password and did not give one.
///
/// Public and readable because it now reaches the browser, which reports what
/// a failed operation said: a class name in a snackbar is not an explanation.
final class SftpSudoCancelled implements Exception {
  const SftpSudoCancelled();

  @override
  String toString() => libL10n.cancel;
}
