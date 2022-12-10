import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:toolbox/core/extension/uint8list.dart';

typedef OnStd = void Function(String data, StreamSink<Uint8List> sink);
typedef OnStdin = void Function(StreamSink<Uint8List> sink);

typedef PwdRequestFunc = Future<String> Function();
final pwdRequestWithUserReg = RegExp(r'\[sudo\] password for (.+):');

extension SSHClientX on SSHClient {
  Future<int?> exec(String cmd,
      {OnStd? onStderr, OnStd? onStdout, OnStdin? stdin}) async {
    final session = await execute(cmd);

    if (onStderr != null) {
      await for (final data in session.stderr) {
        onStderr(data.string, session.stdin);
      }
    }
    if (onStdout != null) {
      await for (final data in session.stdout) {
        onStdout(data.string, session.stdin);
      }
    }
    if (stdin != null) {
      stdin(session.stdin);
    }

    session.close();
    return session.exitCode;
  }
}
