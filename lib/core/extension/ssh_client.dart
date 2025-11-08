import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/data/helper/ssh_decoder.dart';
import 'package:server_box/data/model/server/system.dart';

import 'package:server_box/data/res/misc.dart';

typedef OnStdout = void Function(String data, SSHSession session);
typedef OnStdin = void Function(SSHSession session);

typedef PwdRequestFunc = Future<String?> Function(String? user);

extension SSHClientX on SSHClient {
  /// Create a persistent PowerShell session for Windows commands
  Future<(SSHSession, String)> execPowerShell(
    OnStdin onStdin, {
    SSHPtyConfig? pty,
    OnStdout? onStdout,
    OnStdout? onStderr,
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

  Future<(SSHSession, String)> exec(
    OnStdin onStdin, {
    String? entry,
    SSHPtyConfig? pty,
    OnStdout? onStdout,
    OnStdout? onStderr,
    bool stdout = true,
    bool stderr = true,
    Map<String, String>? env,
    SystemType? systemType,
  }) async {
    final session = await execute(
      entry ??
          switch (systemType) {
            SystemType.windows => 'powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass',
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
          final ctx = context ?? WidgetsBinding.instance.focusManager.primaryFocus?.context;
          if (ctx == null) return;
          final pwd = ctx.mounted ? await ctx.showPwdDialog(title: user, id: id) : null;
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

  /// Runs a command and decodes output safely with encoding fallback
  ///
  /// [systemType] - The system type (affects encoding choice)
  /// Runs a command and safely decodes the result
  Future<String> runSafe(
    String command, {
    SystemType? systemType,
    String? context,
  }) async {
    // Let SSH errors propagate with their original type (e.g., SSHError subclasses)
    final result = await run(command);
    
    // Only catch decoding failures and add context
    try {
      return SSHDecoder.decode(
        result,
        isWindows: systemType == SystemType.windows,
        context: context,
      );
    } on FormatException catch (e) {
      throw Exception(
        'Failed to decode command output${context != null ? " [$context]" : ""}: $e',
      );
    }
  }

  /// Executes a command with stdin and safely decodes stdout/stderr
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

    // Only catch decoding failures, let other errors propagate
    String stdout;
    try {
      stdout = SSHDecoder.decode(
        stdoutBytes,
        isWindows: systemType == SystemType.windows,
        context: context != null ? '$context (stdout)' : 'stdout',
      );
    } on FormatException catch (e) {
      throw Exception(
        'Failed to decode stdout${context != null ? " [$context]" : ""}: $e',
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
        'Failed to decode stderr${context != null ? " [$context]" : ""}: $e',
      );
    }

    return (stdout, stderr);
  }
}
