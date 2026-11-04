import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/admin/command_output.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/storage.dart';
import 'package:server_box/data/model/server/sudo_error.dart';
import 'package:server_box/src/rust/api/storage.dart' as ffi;

/// Why a storage read or change did not happen. Sudo refusing the password
/// is [SudoRejected].
sealed class StorageFailure implements Exception {
  const StorageFailure();
}

/// `sbm_parser::storage` refused the action as given.
final class StorageInvalid extends StorageFailure {
  const StorageInvalid(this.error);

  final StorageError error;

  @override
  String toString() => error.name;
}

/// The machine, as read just before, does not allow it.
final class StorageRefused extends StorageFailure {
  const StorageRefused(this.refusal);

  final Refusal refusal;

  @override
  String toString() => refusal.error;
}

/// lsblk answered nothing the view could be read from.
final class StorageUnreadable extends StorageFailure {
  const StorageUnreadable();

  @override
  String toString() => 'Unable to read storage';
}

/// The command ran and failed; [detail] is the last line it printed.
final class StorageCommandFailed extends StorageFailure {
  const StorageCommandFailed(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

/// Runs the Rust storage parser and scripts; policy remains in `sbm_parser`.
abstract final class StorageManager {
  static Future<StorageView> view(CommandExec exec) async {
    final result = await exec.run(ffi.storageViewScript(), entry: 'sh');
    if (!result.succeeded) {
      throw StorageCommandFailed(lastOutputLine(result.combined, 'Unable to read storage'));
    }
    return await ffi.storageParseView(raw: result.stdout) ?? (throw const StorageUnreadable());
  }

  static Future<List<DiskHealth>> health(
    CommandExec exec, {
    required bool isRoot,
    String? password,
  }) async {
    final result = await PrivilegedExec.run(
      exec,
      ffi.storageHealthScript(),
      isRoot: isRoot,
      password: password,
    );
    _check(result, fallback: 'Unable to read disk health');
    return ffi.storageParseHealth(raw: result.stdout);
  }

  static Future<void> act(
    CommandExec exec,
    StorageAction action, {
    required bool isRoot,
    String? password,
    String? passphrase,
  }) async {
    // The page's view may be stale: the check reads the machine again.
    if (ffi.storageCheck(view: await view(exec), action: action) case final refusal?) {
      throw StorageRefused(refusal);
    }
    final String script;
    try {
      script = ffi.storageActionScript(action: action, passphrase: passphrase);
    } on StorageError catch (e) {
      throw StorageInvalid(e);
    }
    final result = await PrivilegedExec.run(
      exec,
      script,
      isRoot: isRoot,
      password: password,
    );
    _check(result, fallback: 'Storage action failed');
  }

  static void _check(ExecResult result, {required String fallback}) {
    if (result.succeeded) return;
    result.throwIfSudoRejected();
    throw StorageCommandFailed(lastOutputLine(result.combined, fallback));
  }
}
