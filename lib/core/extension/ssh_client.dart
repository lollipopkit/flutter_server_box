import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';

import '../../data/res/misc.dart';

typedef _OnStdout = void Function(String data, SSHSession session);
typedef _OnStdin = void Function(SSHSession session);

typedef PwdRequestFunc = Future<String?> Function(String? user);

extension SSHClientX on SSHClient {
  Future<SSHSession> exec(
    String cmd, {
    _OnStdout? onStderr,
    _OnStdout? onStdout,
    _OnStdin? stdin,
    bool redirectToBash = false, // not working yet. do not use
  }) async {
    final session = await execute(redirectToBash ? "head -1 | bash" : cmd);

    if (redirectToBash) {
      session.stdin.add("$cmd\n".uint8List);
    }

    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    if (onStdout != null) {
      session.stdout.listen(
        (e) => onStdout(e.string, session),
        onDone: stdoutDone.complete,
      );
    } else {
      stdoutDone.complete();
    }

    if (onStderr != null) {
      session.stderr.listen(
        (e) => onStderr(e.string, session),
        onDone: stderrDone.complete,
      );
    } else {
      stderrDone.complete();
    }

    if (stdin != null) {
      stdin(session);
    }

    await stdoutDone.future;
    await stderrDone.future;

    session.close();
    return session;
  }

  Future<int?> execWithPwd(
    String cmd, {
    BuildContext? context,
    _OnStdout? onStdout,
    _OnStdout? onStderr,
    _OnStdin? stdin,
    bool redirectToBash = false, // not working yet. do not use
    required String id,
  }) async {
    var isRequestingPwd = false;
    final session = await exec(
      cmd,
      redirectToBash: redirectToBash,
      onStderr: (data, session) async {
        onStderr?.call(data, session);
        if (isRequestingPwd) return;

        if (data.contains('[sudo] password for ')) {
          isRequestingPwd = true;
          final user = Miscs.pwdRequestWithUserReg.firstMatch(data)?.group(1);
          if (context == null) return;
          final pwd = context.mounted
              ? await context.showPwdDialog(title: user, id: id)
              : null;
          if (pwd == null || pwd.isEmpty) {
            session.kill(SSHSignal.TERM);
          } else {
            session.stdin.add('$pwd\n'.uint8List);
          }
          isRequestingPwd = false;
        }
      },
      onStdout: (data, sink) async {
        onStdout?.call(data, sink);
      },
      stdin: stdin,
    );
    return session.exitCode;
  }

  Future<Uint8List> runForOutput(
    String command, {
    bool runInPty = false,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? environment,
    Future<void> Function(SSHSession)? action,
  }) async {
    final session = await execute(
      command,
      pty: runInPty ? const SSHPtyConfig() : null,
      environment: environment,
    );

    final result = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      stdout ? result.add : (_) {},
      onDone: stdoutDone.complete,
      onError: stderrDone.completeError,
    );

    session.stderr.listen(
      stderr ? result.add : (_) {},
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
    );

    if (action != null) await action(session);

    await stdoutDone.future;
    await stderrDone.future;

    return result.takeBytes();
  }
}
