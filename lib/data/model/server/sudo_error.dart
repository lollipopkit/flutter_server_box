import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// Sudo refused the password it was given (or was given none), for a feature
/// whose failures are exceptions ([SudoRefusal.throwIfSudoRejected]); one that
/// hands back its result reads [SudoRejection.sudoRejected] instead.
final class SudoRejected implements Exception {
  const SudoRejected();

  @override
  String toString() => l10n.virtErrSudoRejected;
}

/// The user was asked for a sudo password and did not give one.
final class SudoCancelled implements Exception {
  const SudoCancelled();

  @override
  String toString() => libL10n.cancel;
}

extension SudoRefusal on ExecResult {
  /// Throws [SudoRejected] when sudo refused the password; only a
  /// [SudoExecResult] can say so, and only a non-root run is one.
  void throwIfSudoRejected() {
    if (sudoRejected) throw const SudoRejected();
  }
}
