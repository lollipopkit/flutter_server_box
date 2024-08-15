import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';

import 'package:server_box/data/res/misc.dart';

typedef OnStdout = void Function(String data, SSHSession session);
typedef OnStdin = void Function(SSHSession session);

typedef PwdRequestFunc = Future<String?> Function(String? user);

extension SSHClientX on SSHClient {
  Future<(SSHSession, String)> exec(
    OnStdin onStdin, {
    String? entry,
    SSHPtyConfig? pty,
    OnStdout? onStdout,
    OnStdout? onStderr,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? env,
  }) async {
    final session = await execute(
      entry ?? 'cat | sh',
      pty: pty,
      environment: env,
    );

    final result = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      (e) {
        onStdout?.call(e.string, session);
        if (stdout) result.add(e);
      },
      onDone: stdoutDone.complete,
      onError: stderrDone.completeError,
    );

    session.stderr.listen(
      (e) {
        onStderr?.call(e.string, session);
        if (stderr) result.add(e);
      },
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
    );

    onStdin(session);

    await stdoutDone.future;
    await stderrDone.future;

    return (session, result.takeBytes().string);
  }

  Future<int?> execWithPwd(
    String script, {
    String? entry,
    BuildContext? context,
    OnStdout? onStdout,
    OnStdout? onStderr,
    required String id,
  }) async {
    var isRequestingPwd = false;
    final (session, _) = await exec(
      (sess) {
        sess.stdin.add('$script\n'.uint8List);
        sess.stdin.close();
      },
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
            session.stdin.close();
          } else {
            session.stdin.add('$pwd\n'.uint8List);
          }
          isRequestingPwd = false;
        }
      },
      onStdout: onStdout,
      entry: entry,
    );
    return session.exitCode;
  }

  Future<String> execForOutput(
    String script, {
    SSHPtyConfig? pty,
    bool stdout = true,
    bool stderr = true,
    String? entry,
    Map<String, String>? env,
  }) async {
    final ret = await exec(
      (session) {
        session.stdin.add('$script\n'.uint8List);
        session.stdin.close();
      },
      pty: pty,
      env: env,
      stdout: stdout,
      stderr: stderr,
      entry: entry,
    );
    return ret.$2;
  }
}
