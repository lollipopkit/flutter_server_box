import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/data/helper/ssh_decoder.dart';
import 'package:server_box/data/model/server/system.dart';

typedef OnStdout = void Function(String data, SSHSession session);
typedef OnStderr = void Function(String data, SSHSession session);
typedef OnStdin = void Function(SSHSession session);

Future<void> _collectOutput(
  SSHSession session, {
  BytesBuilder? stdoutBuilder,
  BytesBuilder? stderrBuilder,
  void Function(List<int> data)? onStdoutData,
  void Function(List<int> data)? onStderrData,
}) {
  final stdoutDone = Completer<void>();
  final stderrDone = Completer<void>();

  session.stdout.listen(
    (e) {
      onStdoutData?.call(e);
      stdoutBuilder?.add(e);
    },
    onDone: stdoutDone.complete,
    onError: stdoutDone.completeError,
  );

  session.stderr.listen(
    (e) {
      onStderrData?.call(e);
      stderrBuilder?.add(e);
    },
    onDone: stderrDone.complete,
    onError: stderrDone.completeError,
  );

  return Future.wait([stdoutDone.future, stderrDone.future]);
}

String _decodeOutput(
  List<int> bytes, {
  required bool isWindows,
  String? context,
  String label = 'output',
}) {
  try {
    return SSHDecoder.decode(
      bytes,
      isWindows: isWindows,
      context: context != null ? '$context ($label)' : label,
    );
  } on FormatException catch (e) {
    throw Exception(
      'Failed to decode $label${context != null ? ' [$context]' : ''}: $e',
    );
  }
}

extension SSHClientX on SSHClient {
  Future<(SSHSession, String)> exec(
    OnStdin onStdin, {
    String? entry,
    SSHPtyConfig? pty,
    OnStdout? onStdout,
    OnStderr? onStderr,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? env,
    SystemType? systemType,
  }) async {
    final session = await execute(
      entry ??
          switch (systemType) {
            SystemType.windows =>
              'powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass',
            _ => 'cat | sh',
          },
      pty: pty,
      environment: env,
    );

    final result = BytesBuilder(copy: false);

    final done = _collectOutput(
      session,
      stdoutBuilder: stdout ? result : null,
      stderrBuilder: stderr ? result : null,
      onStdoutData: onStdout != null
          ? (e) => onStdout(utf8.decode(e, allowMalformed: true), session)
          : null,
      onStderrData: onStderr != null
          ? (e) => onStderr(utf8.decode(e, allowMalformed: true), session)
          : null,
    );

    onStdin(session);
    await done;

    return (session, utf8.decode(result.takeBytes()));
  }

  Future<(int?, String)> execWithPwd(
    String script, {
    String? entry,
    BuildContext? context,
    OnStdout? onStdout,
    OnStderr? onStderr,
    required String id,
  }) async {
    var hasPasswordError = false;

    final (session, output) = await exec(
      (sess) {
        sess.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
        sess.stdin.close();
      },
      onStderr: (data, sess) {
        onStderr?.call(data, sess);
        if (data.contains('Sorry, try again.') ||
            data.contains('incorrect password attempt') ||
            data.contains('a password is required')) {
          hasPasswordError = true;
        }
      },
      onStdout: onStdout,
      entry: entry,
      stderr: false,
    );

    if (hasPasswordError) {
      return (2, output);
    }
    return (session.exitCode, output);
  }

  Future<String> execForOutput(
    String script, {
    SSHPtyConfig? pty,
    bool stdout = true,
    bool stderr = true,
    String? entry,
    Map<String, String>? env,
  }) async {
    final session = await execute(
      entry ?? 'cat | sh',
      pty: pty,
      environment: env,
    );

    final result = BytesBuilder(copy: false);

    final done = _collectOutput(
      session,
      stdoutBuilder: stdout ? result : null,
      stderrBuilder: stderr ? result : null,
    );

    session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
    session.stdin.close();
    await done;

    return utf8.decode(result.takeBytes());
  }

  Future<String> runSafe(
    String command, {
    SystemType? systemType,
    String? context,
  }) async {
    final result = await run(command);
    return _decodeOutput(
      result,
      isWindows: systemType == SystemType.windows,
      context: context,
    );
  }

  Future<(String stdout, String stderr)> execSafe(
    void Function(SSHSession session) callback, {
    required String entry,
    SystemType? systemType,
    String? context,
  }) async {
    final stdoutBuilder = BytesBuilder(copy: false);
    final stderrBuilder = BytesBuilder(copy: false);

    final session = await execute(entry);

    final done = _collectOutput(
      session,
      stdoutBuilder: stdoutBuilder,
      stderrBuilder: stderrBuilder,
    );

    callback(session);
    await done;

    final isWindows = systemType == SystemType.windows;
    final stdout = _decodeOutput(
      stdoutBuilder.takeBytes(),
      isWindows: isWindows,
      context: context,
      label: 'stdout',
    );
    final stderr = _decodeOutput(
      stderrBuilder.takeBytes(),
      isWindows: isWindows,
      context: context,
      label: 'stderr',
    );

    return (stdout, stderr);
  }
}
