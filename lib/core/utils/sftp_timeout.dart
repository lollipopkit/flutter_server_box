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
