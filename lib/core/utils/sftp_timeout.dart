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
        Loggers.app.warning('Failed to close timed out SFTP session', closeError);
      }),
    );
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}
