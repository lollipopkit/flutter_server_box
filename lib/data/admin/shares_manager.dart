import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/admin/command_output.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/shares.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/src/rust/api/shares.dart' as ffi;

/// Why a shares read or change did not happen. Sudo refusing the password
/// is [SudoRejected].
sealed class SharesFailure implements Exception {
  const SharesFailure();
}

/// `sbm_parser::shares` refused a share as given.
final class SharesInvalid extends SharesFailure {
  const SharesInvalid(this.error);

  final ShareError error;

  @override
  String toString() => error.name;
}

/// A share's path is not a folder on the machine.
final class SharesNotAFolder extends SharesFailure {
  const SharesNotAFolder(this.path);

  final String? path;

  @override
  String toString() => path ?? 'notAFolder';
}

/// Samba or `exportfs` refused the result; the previous file is back.
final class SharesRefused extends SharesFailure {
  const SharesRefused(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

/// The command ran and failed; [detail] is the last line it printed.
final class SharesCommandFailed extends SharesFailure {
  const SharesCommandFailed(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

/// Reads, parses and writes the machine's SMB and NFS configuration.
abstract final class SharesManager {
  static Future<Shares> read(CommandExec exec) async {
    final result = await exec.run(ffi.sharesReadScript(), entry: 'sh');
    if (!result.succeeded) {
      throw SharesCommandFailed(lastOutputLine(result.combined, 'Unable to read shares'));
    }
    return ffi.sharesParse(raw: result.stdout);
  }

  /// Writes only ServerBox-managed entries, keeping shares configured elsewhere.
  static Future<Shares> setSmb(
    CommandExec exec,
    List<SmbShare> shares, {
    required bool isRoot,
    String? password,
  }) async {
    final managed = shares.where((share) => share.managed).toList();
    final script = _build(() => ffi.sharesSmbScript(shares: managed));
    await _write(exec, script, isRoot: isRoot, password: password);
    return read(exec);
  }

  /// Writes only ServerBox-managed exports.
  static Future<Shares> setNfs(
    CommandExec exec,
    List<NfsExport> exports, {
    required bool isRoot,
    String? password,
  }) async {
    final managed = exports.where((export) => export.managed).toList();
    final script = _build(() => ffi.sharesNfsScript(exports: managed));
    await _write(exec, script, isRoot: isRoot, password: password);
    return read(exec);
  }

  static Future<void> setSmbPassword(
    CommandExec exec,
    String user,
    String password, {
    required bool isRoot,
    String? sudoPassword,
  }) async {
    final script = _build(() => ffi.sharesSmbPasswordScript(user: user, password: password));
    await _write(exec, script, isRoot: isRoot, password: sudoPassword);
  }

  static Future<void> install(
    CommandExec exec, {
    required bool nfs,
    required bool isRoot,
    String? password,
  }) => _write(exec, ffi.sharesInstallScript(nfs: nfs), isRoot: isRoot, password: password);

  static Future<Connections> connections(
    CommandExec exec, {
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
      result.throwIfSudoRejected();
      throw SharesCommandFailed(lastOutputLine(result.combined, 'Unable to read connections'));
    }
    return ffi.sharesParseConnections(raw: result.stdout);
  }

  static String _build(String Function() script) {
    try {
      return script();
    } on ShareError catch (e) {
      throw SharesInvalid(e);
    }
  }

  static Future<void> _write(
    CommandExec exec,
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
    result.throwIfSudoRejected();
    if (result.exitCode == ffi.sharesExitNotAFolder()) {
      throw SharesNotAFolder(firstOutputLine(result.stderr));
    }
    if (result.exitCode == ffi.sharesExitRefused()) {
      throw SharesRefused(lastOutputLine(result.stderr, 'The configuration was refused'));
    }
    throw SharesCommandFailed(lastOutputLine(result.combined, 'Share action failed'));
  }
}
