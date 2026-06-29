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
        Loggers.app.warning('Failed to close timed out SFTP session', closeError);
      }),
    );
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}
