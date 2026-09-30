import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';

import '../../helpers/fake_shell.dart';

void main() {
  group('PtyPersistentShellSession', () {
    test('drops what precedes the ready marker and keeps what follows', () async {
      final session = FakeShellSession();
      final opening = PtyPersistentShellSession.open((command) async {
        expect(command, PtyPersistentShellSession.command);
        return session;
      });
      final out = <String>[];
      await Future<void>.delayed(Duration.zero);
      session.emit('motd\r\n${PtyPersistentShellSession.readyMarker}\nfirst');
      final pty = await opening;
      pty.stdout.listen((data) => out.add(utf8.decode(data)));
      session.emit('second');
      await Future<void>.delayed(Duration.zero);
      expect(out.join(), 'firstsecond');

      pty.stdin.add(Uint8List.fromList(utf8.encode('echo hi\n')));
      expect(session.written.toString(), 'echo hi\n');
      pty.close();
    });

    test('finds a marker split across reads', () async {
      final session = FakeShellSession();
      final opening = PtyPersistentShellSession.open((_) async => session);
      await Future<void>.delayed(Duration.zero);
      const marker = PtyPersistentShellSession.readyMarker;
      session.emit(marker.substring(0, 5));
      session.emit('${marker.substring(5)}\n');
      await opening.then((pty) => pty.close());
    });

    test('fails, with what it printed, when the shell ends first', () async {
      final session = FakeShellSession();
      final opening = PtyPersistentShellSession.open((_) async => session);
      await Future<void>.delayed(Duration.zero);
      session.emit('sh: stty: not found\r\n');
      session.finish();
      await expectLater(
        opening,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('stty: not found'),
          ),
        ),
      );
    });

    test('fails and closes the shell when it never gets ready', () async {
      final session = FakeShellSession();
      await expectLater(
        PtyPersistentShellSession.open(
          (_) async => session,
          timeout: const Duration(milliseconds: 10),
        ),
        throwsA(isA<TimeoutException>()),
      );
      await session.done;
    });
  });

  // The same protocol on a real pseudo-terminal, which echoes, translates
  // newlines and makes `sh` interactive unless told otherwise. `script` is
  // what allocates one here without a native plugin.
  test(
    'PersistentShell reads clean output through a real pty',
    () async {
      final shell = PersistentShell(
        null,
        sessionFactory: () => PtyPersistentShellSession.open(_scriptPty),
      );
      addTearDown(shell.close);
      const timeout = Duration(seconds: 10);

      final first = await shell.run("printf 'a\\nb\\n'", timeout: timeout);
      expect(first.output, 'a\nb');
      expect(first.exitCode, 0);

      final second = await shell.run('echo oops >&2; exit 3', timeout: timeout);
      expect(second.output, 'oops');
      expect(second.exitCode, 3);
    },
    skip: Platform.isWindows ? 'no pty on Windows' : false,
  );
}

Future<ShellSession> _scriptPty(String command) async {
  final process = Platform.isMacOS
      ? await Process.start('script', ['-q', '/dev/null', 'sh', '-c', command])
      : await Process.start('script', ['-qfec', command, '/dev/null']);
  return _ProcessSession(process);
}

class _ProcessSession implements ShellSession {
  _ProcessSession(this._process);

  final Process _process;

  @override
  Stream<Uint8List> get stdout => _process.stdout.map(Uint8List.fromList);

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) => _process.stdin.add(data);

  @override
  void resizeTerminal(int width, int height) {}

  @override
  Future<void> get done => _process.exitCode;

  @override
  void close() => _process.kill();
}
