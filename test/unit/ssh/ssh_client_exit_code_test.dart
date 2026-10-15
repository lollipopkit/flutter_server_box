import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/ssh_client.dart';

import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  // Windows OpenSSH sends the channel's EOF before `exit-status`, so the output
  // ends while the exit code is still unknown. Read at that point, a command
  // that exited 0 with anything on stderr was a failure (#1710).
  test('execSafe waits for an exit status that follows the EOF', () async {
    final result = await _Client(_LateExitSession(0, stderr: 'progress'))
        .execSafe((_) {}, entry: 'cmd');

    expect(result.exitCode, 0);
    expect(result.succeeded, isTrue);
  });

  test('execWithPwd waits for an exit status that follows the EOF', () async {
    final (code, _) = await _Client(
      _LateExitSession(3),
    ).execWithPwd('script', id: 'id');

    expect(code, 3);
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
  }) async => _session;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Output ends at once; the exit status arrives a moment later.
final class _LateExitSession implements SSHSession {
  _LateExitSession(this._code, {String stderr = ''})
    : stderr = Stream.value(Uint8List.fromList(stderr.codeUnits));

  final int _code;
  int? _exitCode;

  @override
  final Stream<Uint8List> stdout = const Stream.empty();

  @override
  final Stream<Uint8List> stderr;

  @override
  final StreamController<Uint8List> stdin = StreamController();

  @override
  int? get exitCode => _exitCode;

  @override
  Future<int?> waitForExit({Duration? timeout}) =>
      Future.delayed(const Duration(milliseconds: 10), () => _exitCode = _code);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
