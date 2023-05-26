import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:toolbox/core/extension/uint8list.dart';

typedef OnStd = void Function(String data, StreamSink<Uint8List> sink);
typedef OnStdin = void Function(StreamSink<Uint8List> sink);

typedef PwdRequestFunc = Future<String> Function();
final pwdRequestWithUserReg = RegExp(r'\[sudo\] password for (.+):');

extension SSHClientX on SSHClient {
  Future<int?> exec(
    String cmd, {
    OnStd? onStderr,
    OnStd? onStdout,
    OnStdin? stdin,
  }) async {
    final session = await execute(cmd);

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    if (onStdout != null) {
      session.stdout.listen(
        (e) => onStdout(e.string, session.stdin),
        onDone: stdoutDone.complete,
      );
    } else {
      stdoutDone.complete();
    }

    if (onStderr != null) {
      session.stderr.listen(
        (e) => onStderr(e.string, session.stdin),
        onDone: stderrDone.complete,
      );
    } else {
      stderrDone.complete();
    }

    if (stdin != null) {
      stdin(session.stdin);
    }

    await stdoutDone.future;
    await stderrDone.future;

    session.close();
    return session.exitCode;
  }
}
