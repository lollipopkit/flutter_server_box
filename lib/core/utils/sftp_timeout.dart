import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';

Duration sftpOperationTimeout(int seconds) {
  return Duration(seconds: seconds <= 0 ? 5 : seconds);
}

Future<T> withSftpOpTimeout<T>(
  String operation,
  Future<T> future,
  Duration timeout,
) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException catch (e, s) {
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}

/// The gap between signs of life that says a transfer has stalled.
///
/// An operation timeout cannot bound a transfer: a large file over a slow link
/// is not a stalled one, and the same five seconds that is generous for a
/// `stat` would abort every download over a bad connection. What can be bounded
/// is how long the far side goes without acknowledging anything — [beat] is
/// called each time it does — which is the difference between a slow link and a
/// server that accepted the channel and then stopped answering.
///
/// The floor is deliberate: nothing configures this below a minute, because
/// below a minute it stops describing a stall.
class SftpIdleWatchdog {
  SftpIdleWatchdog(this.what, Duration idle)
    : idle = idle < minIdle ? minIdle : idle;

  static const minIdle = Duration(seconds: 60);

  final String what;
  final Duration idle;

  final _stalled = Completer<Never>();
  Timer? _timer;

  /// The far side did something. Starts the clock again.
  void beat() {
    if (_stalled.isCompleted) return;
    _timer?.cancel();
    _timer = Timer(idle, () {
      if (_stalled.isCompleted) return;
      final error = TimeoutException('SFTP $what stalled', idle);
      Loggers.app.warning(error.message);
      _stalled.completeError(error);
    });
  }

  /// [work], or a [TimeoutException] once nothing has called [beat] for [idle].
  ///
  /// Stops *waiting*, which is not the same as stopping the work: the caller
  /// closes whatever the work was running on, exactly as the download path
  /// does.
  Future<T> guard<T>(Future<T> work) {
    beat();
    return Future.any([work, _stalled.future]).whenComplete(cancel);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

Future<SftpClient> withSftpSessionOpenTimeout(
  String operation,
  Future<SftpClient> future,
  Duration timeout,
) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException catch (e, s) {
    unawaited(
      future.then((client) => client.close()).catchError((Object closeError) {
        Loggers.app.warning(
          'Failed to close timed out SFTP session',
          closeError,
        );
      }),
    );
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}

Future<T> withSftpLateCleanupTimeout<T>(
  String operation,
  Future<T> future,
  Duration timeout, {
  required FutureOr<void> Function(T value) cleanup,
}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException catch (e, s) {
    unawaited(
      future
          .then<void>((value) async {
            try {
              await cleanup(value);
            } catch (cleanupError, cleanupStack) {
              Loggers.app.warning(
                'Failed to clean up late SFTP $operation',
                cleanupError,
                cleanupStack,
              );
            }
          })
          .catchError((Object lateError, StackTrace lateStack) {
            Loggers.app.warning(
              'Timed out SFTP $operation later failed',
              lateError,
              lateStack,
            );
          }),
    );
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}

typedef SftpRename = Future<void> Function(String from, String to);
typedef SftpRemove = Future<void> Function(String path);

bool _isDefiniteSftpFailure(Object error) =>
    error is SftpStatusError &&
    error.code != SftpStatusCode.noConnection &&
    error.code != SftpStatusCode.connectionLost;

/// Replaces [destination] with [staging] without deleting the old path first.
///
/// A timed-out rename is still running underneath `Future.timeout`, so its
/// outcome is unknown. In that case no second rename, rollback, or cleanup may
/// race it; the caller should close the owning SFTP session before deciding
/// what can be cleaned up.
Future<void> replaceSftpPath({
  required String staging,
  required String destination,
  required String aside,
  required SftpRename rename,
  required SftpRemove remove,
}) async {
  late final Object firstFailure;
  late final StackTrace firstStack;
  try {
    await rename(staging, destination);
    return;
  } on TimeoutException {
    rethrow;
  } catch (e, s) {
    if (!_isDefiniteSftpFailure(e)) {
      Error.throwWithStackTrace(e, s);
    }
    firstFailure = e;
    firstStack = s;
  }

  try {
    await rename(destination, aside);
  } on TimeoutException {
    rethrow;
  } catch (e, s) {
    if (!_isDefiniteSftpFailure(e)) {
      Error.throwWithStackTrace(e, s);
    }
    Error.throwWithStackTrace(firstFailure, firstStack);
  }

  try {
    await rename(staging, destination);
  } on TimeoutException {
    rethrow;
  } catch (e, s) {
    if (!_isDefiniteSftpFailure(e)) {
      Error.throwWithStackTrace(e, s);
    }
    try {
      await rename(aside, destination);
    } on TimeoutException {
      rethrow;
    } catch (rollbackError, rollbackStack) {
      if (!_isDefiniteSftpFailure(rollbackError)) {
        Error.throwWithStackTrace(rollbackError, rollbackStack);
      }
    }
    Error.throwWithStackTrace(e, s);
  }

  try {
    await remove(aside);
  } catch (_) {
    // The replacement is complete. A visible leftover is safer than turning a
    // successful write into a failure.
  }
}
