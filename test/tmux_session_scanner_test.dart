import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/ssh/persistent_shell.dart';
import 'package:server_box/data/ssh/tmux/tmux_session_scanner.dart';
import 'package:test/test.dart';

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
      expect(session.writes.last, contains('/opt/bin/tmux list-sessions'));
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
        contains("/opt/bin/tmux list-windows -t 'main'"),
      );
    });
  });
}

final class _FakePersistentShellSession implements PersistentShellSession {
  final stdoutController = StreamController<Uint8List>();
  final stderrController = StreamController<Uint8List>();
  final List<String> responses;
  final writes = <String>[];
  int responseIndex = 0;

  _FakePersistentShellSession({required this.responses});

  @override
  StreamSink<Uint8List> get stdin => _FakeSink((data) {
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
    final response = responses[responseIndex++];
    final commandId = RegExp(
      r'__SERVER_BOX_DONE__(\d+):%s',
    ).firstMatch(writes.last)?.group(1);
    return '$response\n__SERVER_BOX_DONE__$commandId:0\n';
  }
}

final class _FakeSink implements StreamSink<Uint8List> {
  final void Function(Uint8List data) _onAdd;

  _FakeSink(this._onAdd);

  @override
  void add(Uint8List data) => _onAdd(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}
}
