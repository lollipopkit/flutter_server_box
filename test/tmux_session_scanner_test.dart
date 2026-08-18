import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_scanner.dart';
import 'package:test/test.dart';

import 'helpers/fake_stream_sink.dart';

void main() {
  group('TmuxSessionScanner', () {
    test('listSessions resolves tmux binary before listing', () async {
      final session = _FakePersistentShellSession(
        responses: ['/opt/bin/tmux\n', 'main|2|1|created|attached|activity\n'],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      final sessions = await scanner.listSessions();

      expect(sessions.single.name, 'main');
      expect(session.writes.first, contains('command -v tmux'));
      expect(session.writes.last, contains("'/opt/bin/tmux' list-sessions"));
    });

    test('listWindows resolves tmux binary before listing', () async {
      final session = _FakePersistentShellSession(
        responses: ['/opt/bin/tmux\n', '0|shell|1|1|activity\n'],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      final windows = await scanner.listWindows('main');

      expect(windows.single.index, 0);
      expect(session.writes.first, contains('command -v tmux'));
      expect(
        session.writes.last,
        contains("'/opt/bin/tmux' list-windows -t 'main'"),
      );
    });

    test('window mutations use the resolved binary and locale', () async {
      final session = _FakePersistentShellSession(
        responses: ['/opt/tmux builds/tmux\n', '', ''],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
        lang: 'zh_CN.UTF-8',
      );

      expect(await scanner.newWindow('main'), isTrue);
      expect(await scanner.killWindow('main', 2), isTrue);
      expect(
        session.writes[1],
        contains(
          "env LANG='zh_CN.UTF-8' LC_CTYPE='zh_CN.UTF-8' LC_ALL='zh_CN.UTF-8' '/opt/tmux builds/tmux' new-window -t 'main'",
        ),
      );
      expect(
        session.writes[2],
        contains("'/opt/tmux builds/tmux' kill-window -t 'main:2'"),
      );
    });

    test('window command failures remain distinguishable from empty lists', () async {
      final session = _FakePersistentShellSession(
        responses: ['/opt/bin/tmux\n', '', ''],
        exitCodes: [0, 1, 1],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      expect(await scanner.newWindow('main'), isFalse);
      expect(await scanner.tryListWindows('main'), isNull);
    });
  });
}
final class _FakePersistentShellSession implements PersistentShellSession {
  final stdoutController = StreamController<Uint8List>();
  final stderrController = StreamController<Uint8List>();
  final List<String> responses;
  final List<int> exitCodes;
  final writes = <String>[];
  int responseIndex = 0;

  _FakePersistentShellSession({
    required this.responses,
    List<int>? exitCodes,
  }) : exitCodes = exitCodes ?? List.filled(responses.length, 0);

  @override
  StreamSink<Uint8List> get stdin => FakeStreamSink((data) {
    writes.add(utf8.decode(data));
    stdoutController.add(utf8.encode(_nextResponse()));
  });

  @override
  Stream<Uint8List> get stdout => stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => stderrController.stream;

  @override
  void close() {
    unawaited(stdoutController.close());
    unawaited(stderrController.close());
  }

  String _nextResponse() {
    final response = responses[responseIndex];
    final exitCode = exitCodes[responseIndex++];
    final commandId = RegExp(
      r'__SERVER_BOX_DONE__(\d+):%s',
    ).firstMatch(writes.last)?.group(1);
    return '$response\n__SERVER_BOX_DONE__$commandId:$exitCode\n';
  }
}

