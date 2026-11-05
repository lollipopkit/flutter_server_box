import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/src/rust/api/files.dart' as files;

final class SftpSudoHelper {
  final Spi spi;

  /// Runs a script on the server's stdin as this user (`execWithPwd`).
  final Future<SudoExecResult> Function(String script) exec;

  /// Asks for the sudo password; null when the user declines.
  final Future<String?> Function() askPassword;

  /// Whether a password may be kept in memory for a while.
  final bool Function() rememberPwd;

  String? _cachedPassword;
  Timer? _cacheTimer;

  static const _cacheTtl = Duration(minutes: 5);

  void _scheduleCacheExpiry() {
    _cacheTimer?.cancel();
    _cacheTimer = Timer(_cacheTtl, () {
      _cachedPassword = null;
      Loggers.app.info('SFTP sudo password cache expired for ${spi.id}');
    });
  }

  void clearCache() {
    _cachedPassword = null;
    _cacheTimer?.cancel();
    _cacheTimer = null;
  }

  SftpSudoHelper({
    required this.spi,
    required this.exec,
    required this.askPassword,
    required this.rememberPwd,
  });

  bool get enabled => !spi.isRoot;

  Future<String?> ensurePassword({bool force = false}) async {
    if (!enabled) return '';

    if (force) {
      clearCache();
    } else if (rememberPwd() && _cachedPassword != null) {
      return _cachedPassword;
    }

    final pwd = await askPassword();
    if (pwd == null || pwd.isEmpty) return null;
    if (rememberPwd()) {
      _cachedPassword = pwd;
      _scheduleCacheExpiry();
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

  /// Whether this user, without sudo, may create files in [dir].
  Future<bool> canWrite(String dir) async =>
      (await exec(files.filesWritableCommand(dir: dir))).exitCode == 0;

  Future<int> getFileSize(String remotePath, {String? password}) async {
    final output = await _runAndRead(
      files.filesSizeCommand(path: remotePath),
      password: password,
    );
    final size = files.filesParseSize(output: output);
    if (size == null) {
      final printed = output.trim();
      throw SftpSudoFailed(printed.isEmpty ? null : printed);
    }
    return size;
  }

  Future<void> downloadTextFile(
    String remotePath,
    String localPath, {
    String? password,
  }) async {
    final text = await _runAndRead(
      files.filesReadCommand(path: remotePath),
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
      files.filesWriteBase64Command(data: data, path: remotePath),
      password: password,
    );
  }

  Future<void> rename(
    String oldPath,
    String newPath, {
    String? password,
  }) async {
    // Refusing a destination that is a directory, as every other rename in
    // the browser does: a plain `mv` filed the source away inside it.
    await _runAndRead(
      files.filesRenameCommand(from: oldPath, to: newPath),
      password: password,
    );
  }

  Future<void> delete(
    String remotePath, {
    required bool isDir,
    required bool recursive,
    String? password,
  }) async {
    await _runAndRead(
      files.filesRemoveCommand(
        path: remotePath,
        isDir: isDir,
        recursive: recursive,
        force: false,
      ),
      password: password,
    );
  }

  /// Moves an upload staged at [staging] (somewhere this user can write) into
  /// [remote] as root once [staged] says the transfer finished. Answers whether
  /// [remote] now holds it; whatever else happens, the staging copy is removed.
  Future<bool> finishUploadAsRoot(
    String staging,
    String remote, {
    required Future<bool> staged,
    String? password,
  }) async {
    try {
      // Renaming after a failed or cancelled transfer would put a partial
      // file, or nothing at all, over the destination as root.
      if (await staged) {
        await rename(staging, remote, password: password);
        return true;
      }
    } catch (_) {
      await _discard(staging);
      rethrow;
    }
    await _discard(staging);
    return false;
  }

  /// The staging copy is this user's own, so no sudo: a cleanup never asks
  /// for a password.
  Future<void> _discard(String staging) async {
    try {
      final result = await exec(
        files.filesRemoveCommand(
          path: staging,
          isDir: false,
          recursive: false,
          force: true,
        ),
      );
      if (result.exitCode != 0) throw SftpSudoFailed(result.stdout.trim());
    } catch (e) {
      // A leftover in `/tmp` is not worth a second error over the first.
      Loggers.app.warning('SFTP sudo: staging $staging left behind', e);
    }
  }

  Future<String> _runAndRead(String innerCommand, {String? password}) async {
    final pwd = password ?? await ensurePassword();
    if (pwd == null) throw const SudoCancelled();

    var result = await exec(_buildSudoCommand(innerCommand, pwd));
    if (result.rejected) {
      clearCache();
      final retryPwd = await ensurePassword(force: true);
      if (retryPwd == null) throw const SudoCancelled();
      result = await exec(_buildSudoCommand(innerCommand, retryPwd));
      if (result.rejected) {
        clearCache();
        throw const SudoRejected();
      }
    }
    if (result.exitCode != 0) {
      final output = result.stdout.trim();
      throw SftpSudoFailed(output.isEmpty ? null : output);
    }
    return result.stdout;
  }

  static String _buildSudoCommand(String command, String password) =>
      files.filesSudoCommand(inner: command, password: password);
}

/// The command ran as root and failed; [output] is what it printed.
final class SftpSudoFailed implements Exception {
  const SftpSudoFailed(this.output);

  final String? output;

  @override
  String toString() => output ?? libL10n.fail;
}
