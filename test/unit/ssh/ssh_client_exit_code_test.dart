import 'dart:async';
import 'dart:convert';
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

  test(
    'SshExec.run with isWindows preserves split UTF-8 and GBK sequences across chunks on both callbacks',
    () async {
      // UTF-8 for "中文🚀" split mid-character across chunks.
      final utf8Full = utf8.encode('中文🚀');
      final utf8Chunks = [
        Uint8List.fromList(utf8Full.sublist(0, 2)), // partial '中'
        Uint8List.fromList(utf8Full.sublist(2, 5)), // rest of '中' + partial '文'
        Uint8List.fromList(utf8Full.sublist(5, 8)), // rest of '文' + partial '🚀'
        Uint8List.fromList(utf8Full.sublist(8)), // rest of '🚀'
      ];

      // GBK for "中文" ([0xD6, 0xD0, 0xCE, 0xC4]) split byte-by-byte.
      final gbkChunks = [
        Uint8List.fromList([0xD6]),
        Uint8List.fromList([0xD0, 0xCE]),
        Uint8List.fromList([0xC4]),
      ];

      // Case 1: UTF-8 on stdout, GBK on stderr (independent per-stream state).
      final out1 = StringBuffer();
      final err1 = StringBuffer();
      final res1 = await SshExec(
        _Client(
          _LateExitSession(
            0,
            stdoutChunks: utf8Chunks,
            stderrChunks: gbkChunks,
          ),
        ),
      ).run(
        'cmd',
        isWindows: true,
        onStdout: out1.write,
        onStderr: err1.write,
      );
      expect(out1.toString(), '中文🚀');
      expect(err1.toString(), '中文');
      expect(res1.stdout, '中文🚀');
      expect(res1.stderr, '中文');

      // Case 2: GBK on stdout, UTF-8 on stderr.
      final out2 = StringBuffer();
      final err2 = StringBuffer();
      final res2 = await SshExec(
        _Client(
          _LateExitSession(
            0,
            stdoutChunks: gbkChunks,
            stderrChunks: utf8Chunks,
          ),
        ),
      ).run(
        'cmd',
        isWindows: true,
        onStdout: out2.write,
        onStderr: err2.write,
      );
      expect(out2.toString(), '中文');
      expect(err2.toString(), '中文🚀');
      expect(res2.stdout, '中文');
      expect(res2.stderr, '中文🚀');

      // Case 3: Trailing incomplete multibyte sequence is flushed at EOF
      // (not dropped when `asFuture` completes).
      final out3 = StringBuffer();
      final res3 = await SshExec(
        _Client(
          _LateExitSession(
            0,
            stdoutChunks: [
              Uint8List.fromList([0x61, 0xE4, 0xB8]), // 'a' + truncated UTF-8
            ],
          ),
        ),
      ).run('cmd', isWindows: true, onStdout: out3.write);
      expect(out3.toString(), startsWith('a'));
      expect(out3.toString().length, greaterThan(1));
      expect(res3.stdout, out3.toString());

      // Case 4: Trailing unpaired GBK lead byte (including 0xFF) preserves
      // preceding decoded text and flushes cleanly without RangeError.
      final out4 = StringBuffer();
      await SshExec(
        _Client(
          _LateExitSession(
            0,
            stdoutChunks: [
              Uint8List.fromList([0xD6, 0xD0, 0xFF]), // GBK '中' + trailing 0xFF
            ],
          ),
        ),
      ).run('cmd', isWindows: true, onStdout: out4.write);
      expect(out4.toString(), '中\uFFFD');
    },
  );
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
    List<Uint8List>? stdoutChunks,
    List<Uint8List>? stderrChunks,
  }) : stdout = stdoutChunks != null
           ? Stream.fromIterable(stdoutChunks)
           : stdoutBytes == null
           ? const Stream.empty()
           : Stream.value(stdoutBytes),
       stderr = stderrChunks != null
           ? Stream.fromIterable(stderrChunks)
           : Stream.value(Uint8List.fromList(stderr.codeUnits)) {
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
