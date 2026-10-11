import 'dart:convert';

import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/shares.dart';
import 'package:server_box/src/rust/api/shares.dart' as ffi;

final class SharesManagerException implements Exception {
  const SharesManagerException(this.code, {this.path, this.detail});

  final String code;
  final String? path;
  final String? detail;

  @override
  String toString() => detail ?? code;
}

/// Reads, parses and writes the machine's SMB and NFS configuration.
abstract final class SharesManager {
  static Future<SharesView> read(ServerExec exec) async {
    final result = await exec.run(ffi.sharesReadScript(), entry: 'sh');
    if (!result.succeeded) {
      throw SharesManagerException(
        'failed',
        detail: _lastLine(result.combined, 'Unable to read shares'),
      );
    }
    try {
      final json = await ffi.parseSharesJson(raw: result.stdout);
      return SharesView.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on ffi.SharesFfiError catch (e) {
      throw SharesManagerException(e.code);
    }
  }

  /// Writes only ServerBox-managed entries, keeping shares configured elsewhere.
  static Future<SharesView> setSmb(
    ServerExec exec,
    List<SmbShare> shares, {
    required bool isRoot,
    String? password,
  }) async {
    final managed = shares.where((share) => share.managed).toList();
    final script = _smbScript(managed);
    await _write(exec, script, isRoot: isRoot, password: password);
    return read(exec);
  }

  /// Writes only ServerBox-managed exports.
  static Future<SharesView> setNfs(
    ServerExec exec,
    List<NfsExport> exports, {
    required bool isRoot,
    String? password,
  }) async {
    final managed = exports.where((export) => export.managed).toList();
    final script = _nfsScript(managed);
    await _write(exec, script, isRoot: isRoot, password: password);
    return read(exec);
  }

  static Future<void> setSmbPassword(
    ServerExec exec,
    String user,
    String password, {
    required bool isRoot,
    String? sudoPassword,
  }) async {
    final script = _passwordScript(user, password);
    await _write(exec, script, isRoot: isRoot, password: sudoPassword);
  }

  static Future<void> install(
    ServerExec exec, {
    required bool nfs,
    required bool isRoot,
    String? password,
  }) async {
    await _write(
      exec,
      ffi.sharesInstallScript(nfs: nfs),
      isRoot: isRoot,
      password: password,
    );
  }

  static Future<ShareConnections> connections(
    ServerExec exec, {
    required bool isRoot,
    String? password,
  }) async {
    final result = await PrivilegedExec.run(
      exec,
      ffi.sharesConnectionsScript(),
      isRoot: isRoot,
      password: password,
    );
    if (!result.succeeded) {
      throw SharesManagerException(
        !isRoot && result.exitCode == kSudoPasswordRejected
            ? 'sudo_rejected'
            : 'failed',
        detail: _lastLine(result.combined, 'Unable to read connections'),
      );
    }
    try {
      final json = await ffi.parseSharesConnectionsJson(raw: result.stdout);
      return ShareConnections.fromJson(jsonDecode(json) as Map<String, Object?>);
    } on ffi.SharesFfiError catch (e) {
      throw SharesManagerException(e.code);
    }
  }

  static String _smbScript(List<SmbShare> shares) {
    try {
      return ffi.sharesSmbScript(
        sharesJson: jsonEncode([for (final share in shares) share.toJson()]),
      );
    } on ffi.SharesFfiError catch (e) {
      throw SharesManagerException(e.code);
    }
  }

  static String _nfsScript(List<NfsExport> exports) {
    try {
      return ffi.sharesNfsScript(
        exportsJson: jsonEncode([for (final export in exports) export.toJson()]),
      );
    } on ffi.SharesFfiError catch (e) {
      throw SharesManagerException(e.code);
    }
  }

  static String _passwordScript(String user, String password) {
    try {
      return ffi.sharesSmbPasswordScript(user: user, password: password);
    } on ffi.SharesFfiError catch (e) {
      throw SharesManagerException(e.code);
    }
  }

  static Future<void> _write(
    ServerExec exec,
    String script, {
    required bool isRoot,
    String? password,
  }) async {
    final result = await PrivilegedExec.run(
      exec,
      script,
      isRoot: isRoot,
      password: password,
    );
    if (result.succeeded) return;
    if (!isRoot && result.exitCode == kSudoPasswordRejected) {
      throw const SharesManagerException('sudo_rejected');
    }
    if (result.exitCode == ffi.sharesExitNotAFolder()) {
      throw SharesManagerException(
        'notAFolder',
        path: _firstLine(result.stderr),
      );
    }
    if (result.exitCode == ffi.sharesExitRefused()) {
      throw SharesManagerException(
        'refused',
        detail: _lastLine(result.stderr, 'The configuration was refused'),
      );
    }
    throw SharesManagerException(
      'failed',
      detail: _lastLine(result.combined, 'Share action failed'),
    );
  }

  static String? _firstLine(String output) {
    final line = output.split('\n').first;
    final value = line.endsWith('\r') ? line.substring(0, line.length - 1) : line;
    return value.isEmpty ? null : value;
  }

  static String _lastLine(String output, String fallback) {
    final lines = output.trim().split('\n').where((line) => line.trim().isNotEmpty);
    return lines.isEmpty ? fallback : lines.last.trim();
  }
}
