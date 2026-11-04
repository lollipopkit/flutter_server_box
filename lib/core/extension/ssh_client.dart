import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/core/ssh/decoder.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

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
  String? logLabel,
  String label = 'output',
}) {
  try {
    return SSHDecoder.decode(
      bytes,
      isWindows: isWindows,
      context: logLabel != null ? '$logLabel ($label)' : label,
    );
  } on FormatException catch (e) {
    throw FormatException(
      'Failed to decode $label${logLabel != null ? ' [$logLabel]' : ''}: ${e.message}',
    );
  }
}

/// The remote exit code, once it has arrived.
///
/// The end of stdout/stderr is the channel's EOF, and `exit-status` may follow
/// it: Windows OpenSSH always sends it after. Reading [SSHSession.exitCode] as
/// soon as the output ends can therefore see `null` for a command that exited
/// 0 (#1710). The timeout keeps a server that never reports one from hanging.
Future<int?> _exitCodeOf(SSHSession session) =>
    session.waitForExit(timeout: const Duration(seconds: 5));

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

  /// [script] on the session's stdin, saying whether sudo rejected the
  /// password the script carries.
  Future<SudoExecResult> execWithPwd(
    String script, {
    String? entry,
    OnStdout? onStdout,
    OnStderr? onStderr,
  }) async {
    final stderr = StringBuffer();

    final (session, output) = await exec(
      (sess) {
        sess.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
        sess.stdin.close();
      },
      onStderr: (data, sess) {
        onStderr?.call(data, sess);
        stderr.write(data);
      },
      onStdout: onStdout,
      entry: entry,
      stderr: false,
    );

    final err = stderr.toString();
    return SudoExecResult(
      ExecResult(exitCode: await _exitCodeOf(session), stdout: output, stderr: err),
      // Read off the whole stream: a phrase can arrive split across two chunks.
      rejected: script_ffi.sudoPasswordRejected(stderr: err),
    );
  }

  Future<String> runSafe(
    String command, {
    SystemType? systemType,
    String? logLabel,
  }) async {
    final result = await run(command);
    return _decodeOutput(
      result,
      isWindows: systemType == SystemType.windows,
      logLabel: logLabel,
    );
  }

  Future<ExecResult> execSafe(
    void Function(SSHSession session) callback, {
    required String entry,
    SystemType? systemType,
    String? logLabel,
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
      logLabel: logLabel,
      label: 'stdout',
    );
    final stderr = _decodeOutput(
      stderrBuilder.takeBytes(),
      isWindows: isWindows,
      logLabel: logLabel,
      label: 'stderr',
    );

    return ExecResult(
      exitCode: await _exitCodeOf(session),
      stdout: stdout,
      stderr: stderr,
    );
  }
}
