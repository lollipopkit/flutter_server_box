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

extension SSHClientX on SSHClient {
  Future<(SSHSession, String)> execPowerShell(
    OnStdin onStdin, {
    SSHPtyConfig? pty,
    OnStdout? onStdout,
    void Function(String data)? onStderr,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? env,
  }) async {
    final session = await execute(
      'powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass',
      pty: pty,
      environment: env,
    );

    final result = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      (e) {
        onStdout?.call(utf8.decode(e), session);
        if (stdout) result.add(e);
      },
      onDone: stdoutDone.complete,
      onError: (e) {
        if (!stdoutDone.isCompleted) stdoutDone.completeError(e);
      },
    );

    session.stderr.listen(
      (e) {
        onStderr?.call(utf8.decode(e));
        if (stderr) result.add(e);
      },
      onDone: stderrDone.complete,
      onError: (e) {
        if (!stderrDone.isCompleted) stderrDone.completeError(e);
      },
    );

    onStdin(session);

    await stdoutDone.future;
    await stderrDone.future;

    return (session, utf8.decode(result.takeBytes()));
  }

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
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      (e) {
        onStdout?.call(utf8.decode(e), session);
        if (stdout) result.add(e);
      },
      onDone: stdoutDone.complete,
      onError: stdoutDone.completeError,
    );

    session.stderr.listen(
      (e) {
        onStderr?.call(utf8.decode(e), session);
        if (stderr) result.add(e);
      },
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
    );

    onStdin(session);

    await stdoutDone.future;
    await stderrDone.future;

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
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    session.stdout.listen(
      (e) {
        if (stdout) result.add(e);
      },
      onDone: stdoutDone.complete,
      onError: (e) {
        if (!stdoutDone.isCompleted) stdoutDone.completeError(e);
      },
    );

    session.stderr.listen(
      (e) {
        if (stderr) result.add(e);
      },
      onDone: stderrDone.complete,
      onError: (e) {
        if (!stderrDone.isCompleted) stderrDone.completeError(e);
      },
    );

    session.stdin.add(Uint8List.fromList(utf8.encode('$script\n')));
    session.stdin.close();

    await stdoutDone.future;
    await stderrDone.future;

    return utf8.decode(result.takeBytes());
  }

  Future<String> runSafe(
    String command, {
    SystemType? systemType,
    String? context,
  }) async {
    final result = await run(command);

    try {
      return SSHDecoder.decode(
        result,
        isWindows: systemType == SystemType.windows,
        context: context,
      );
    } on FormatException catch (e) {
      throw Exception(
        'Failed to decode command output${context != null ? ' [$context]' : ''}: $e',
      );
    }
  }

  Future<(String stdout, String stderr)> execSafe(
    void Function(SSHSession session) callback, {
    required String entry,
    SystemType? systemType,
    String? context,
  }) async {
    final stdoutBuilder = BytesBuilder(copy: false);
    final stderrBuilder = BytesBuilder(copy: false);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();

    final session = await execute(entry);

    session.stdout.listen(
      (e) {
        stdoutBuilder.add(e);
      },
      onDone: stdoutDone.complete,
      onError: stdoutDone.completeError,
    );

    session.stderr.listen(
      (e) {
        stderrBuilder.add(e);
      },
      onDone: stderrDone.complete,
      onError: stderrDone.completeError,
    );

    callback(session);

    await stdoutDone.future;
    await stderrDone.future;

    final stdoutBytes = stdoutBuilder.takeBytes();
    final stderrBytes = stderrBuilder.takeBytes();

    String stdout;
    try {
      stdout = SSHDecoder.decode(
        stdoutBytes,
        isWindows: systemType == SystemType.windows,
        context: context != null ? '$context (stdout)' : 'stdout',
      );
    } on FormatException catch (e) {
      throw Exception(
        'Failed to decode stdout${context != null ? ' [$context]' : ''}: $e',
      );
    }

    String stderr;
    try {
      stderr = SSHDecoder.decode(
        stderrBytes,
        isWindows: systemType == SystemType.windows,
        context: context != null ? '$context (stderr)' : 'stderr',
      );
    } on FormatException catch (e) {
      throw Exception(
        'Failed to decode stderr${context != null ? ' [$context]' : ''}: $e',
      );
    }

    return (stdout, stderr);
  }
}
