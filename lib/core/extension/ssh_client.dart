import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/extension/stringx.dart';
import 'package:toolbox/core/extension/uint8list.dart';

import '../../data/res/misc.dart';

typedef _OnStdout = void Function(String data, StreamSink<Uint8List> sink);
typedef _OnStdin = void Function(StreamSink<Uint8List> sink);

typedef PwdRequestFunc = Future<String?> Function(String? user);

extension SSHClientX on SSHClient {
  Future<int?> exec(
    String cmd, {
    _OnStdout? onStderr,
    _OnStdout? onStdout,
    _OnStdin? stdin,
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

  Future<int?> execWithPwd(
    String cmd, {
    BuildContext? context,
    _OnStdout? onStdout,
    _OnStdout? onStderr,
    _OnStdin? stdin,
  }) async {
    var isRequestingPwd = false;
    return await exec(
      cmd,
      onStderr: (data, sink) async {
        onStderr?.call(data, sink);
        if (isRequestingPwd) return;
        isRequestingPwd = true;
        if (data.contains('[sudo] password for ')) {
          final user = Miscs.pwdRequestWithUserReg.firstMatch(data)?.group(1);
          if (context == null) return;
          final pwd = await context.showPwdDialog(user);
          if (pwd == null || pwd.isEmpty) {
            // Add ctrl + c to exit.
            sink.add('\x03'.uint8List);
          } else {
            sink.add('$pwd\n'.uint8List);
          }
        }
      },
      onStdout: onStdout,
      stdin: stdin,
    );
  }
}
