import 'dart:async';

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
