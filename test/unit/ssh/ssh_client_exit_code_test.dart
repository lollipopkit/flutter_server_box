import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/exec.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  // Windows OpenSSH sends the channel's EOF before `exit-status`, so the output
  // ends while the exit code is still unknown. Read at that point, a command
  // that exited 0 with anything on stderr was a failure (#1710).
  test('SshExec.run waits for an exit status that follows the EOF', () async {
    final result = await SshExec(
      _Client(_LateExitSession(0, stderr: 'progress')),
    ).run('cmd');

    expect(result.exitCode, 0);
    expect(result.succeeded, isTrue);
  });

  test('SshExec.runSudo waits for late exit status and detects sudo rejection', () async {
    final session = _LateExitSession(1, stderr: 'Sorry, try again.');
    final result = await SshExec(_Client(session)).runSudo('script');

    expect(result.exitCode, 1);
    expect(result.rejected, isTrue);
  });

  test('SshExec.run with isWindows decodes GBK bytes', () async {
    // GBK bytes for "中文"
    final gbkBytes = Uint8List.fromList([0xD6, 0xD0, 0xCE, 0xC4]);
    final session = _LateExitSession(0, stdoutBytes: gbkBytes);
    final result = await SshExec(_Client(session)).run(
      'ver',
      isWindows: true,
    );

    expect(result.exitCode, 0);
    expect(result.stdout, '中文');
  });
}

final class _Client implements SSHClient {
  _Client(this._session);

  final SSHSession _session;

  @override
  Future<SSHSession> execute(
    String command, {
    SSHPtyConfig? pty,
    SSHX11Config? x11,
    Map<String, String>? environment,
    bool forwardAgent = false,
  }) async => _session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Output ends at once; the exit status arrives a moment later.
final class _LateExitSession implements SSHSession {
  _LateExitSession(
    this._code, {
    String stderr = '',
    Uint8List? stdoutBytes,
  }) : stdout = stdoutBytes == null
           ? const Stream.empty()
           : Stream.value(stdoutBytes),
       stderr = Stream.value(Uint8List.fromList(stderr.codeUnits)) {
    stdin.stream.drain<void>();
  }

  final int _code;
  int? _exitCode;

  @override
  final Stream<Uint8List> stdout;

  @override
  final Stream<Uint8List> stderr;

  @override
  final StreamController<Uint8List> stdin = StreamController();

  @override
  Future<void> get done => Future.value();

  @override
  int? get exitCode => _exitCode;

  @override
  Future<int?> waitForExit({Duration? timeout}) =>
      Future.delayed(const Duration(milliseconds: 10), () => _exitCode = _code);

  @override
  void close() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
