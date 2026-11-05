import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/terminal/persistent_shell.dart';
import 'package:server_box/data/terminal/tmux/tmux_ids.dart';
import 'package:server_box/data/terminal/tmux/tmux_session_scanner.dart';
import 'package:test/test.dart';

import '../../helpers/fake_stream_sink.dart';
import '../../helpers/rust_lib_helper.dart';

void main() {
  setUpAll(initRustLibForTest);

  group('TmuxSessionScanner', () {
    test('tryListSessions resolves tmux binary before listing', () async {
      final session = _FakePersistentShellSession(
        responses: [
          '/opt/bin/tmux\n',
          r'$0	main|with:colon	2	1	1717200000	1717286400	1717372800',
        ],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      final sessions = (await scanner.tryListSessions())!;

      expect(sessions.single.id, TmuxSessionId(r'$0'));
      expect(sessions.single.name, 'main|with:colon');
      // Epoch seconds, as tmux prints them; the app formats them for display.
      expect(sessions.single.createdAt, 1717200000);
      expect(sessions.single.lastAttached, 1717286400);
      expect(sessions.single.activity, 1717372800);
      expect(session.writes.first, contains('command -v tmux'));
      expect(session.writes.last, contains("'/opt/bin/tmux' -u list-sessions"));
      expect(session.writes.last, contains('list-sessions -F "#{session_id}'));
      expect(session.writes.last, contains("\$(printf '\\t')"));
      expect(session.writes.last, contains('#{q:session_name}'));
      // The raw epoch variables: tmux dropped the `*_string` ones.
      expect(session.writes.last, contains('#{session_created}'));
      expect(session.writes.last, isNot(contains('session_created_string')));
    });

    test('a session with no time is mapped to null', () async {
      // tmux prints an empty `session_last_attached` for a session nobody has
      // attached to, and 0 for one that never saw output.
      final session = _FakePersistentShellSession(
        responses: ['/opt/bin/tmux\n', r'$0	main	1	0	1717200000		0'],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      final one = (await scanner.tryListSessions())!.single;

      expect(one.createdAt, 1717200000);
      expect(one.lastAttached, isNull);
      expect(one.activity, isNull);
    });

    test('tryListWindows resolves tmux binary before listing', () async {
      final session = _FakePersistentShellSession(
        responses: ['/opt/bin/tmux\n', '0\tshell\t1\t1\t1717372800\n'],
      );
      final scanner = TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );

      final windows = await scanner.tryListWindows('main');

      expect(windows, isNotNull);
      expect(windows!.single.activity, 1717372800);
      expect(windows.single.index, 0);
      expect(session.writes.first, contains('command -v tmux'));
      expect(
        session.writes.last,
        contains("'/opt/bin/tmux' -u list-windows -t 'main'"),
      );
    });

    TmuxSessionScanner scannerOf(List<String> responses, List<int> exitCodes) {
      final session = _FakePersistentShellSession(
        responses: responses,
        exitCodes: exitCodes,
      );
      return TmuxSessionScanner(
        PersistentShell(null, sessionFactory: () async => session),
      );
    }

    test('a failed session listing is null, not empty', () async {
      final scanner = scannerOf(
        ['/opt/bin/tmux\n', 'unknown option -- F'],
        [0, 1],
      );

      expect(await scanner.tryListSessions(), isNull);
    });

    test('a listing where no line reads as a session is null', () async {
      final scanner = scannerOf(['/opt/bin/tmux\n', 'garbage'], [0, 0]);

      expect(await scanner.tryListSessions(), isNull);
    });

    test('no server running is no sessions', () async {
      final scanner = scannerOf(
        ['/opt/bin/tmux\n', 'no server running on /tmp/tmux-1000/default'],
        [0, 1],
      );

      expect(await scanner.tryListSessions(), isEmpty);
    });

    test('no tmux is no sessions', () async {
      final scanner = scannerOf([''], [1]);

      expect(await scanner.tryListSessions(), isEmpty);
    });

    test(
      'window discovery failures remain distinguishable from empty lists',
      () async {
        final session = _FakePersistentShellSession(
          responses: ['/opt/bin/tmux\n', ''],
          exitCodes: [0, 1],
        );
        final scanner = TmuxSessionScanner(
          PersistentShell(null, sessionFactory: () async => session),
        );

        expect(await scanner.tryListWindows('main'), isNull);
      },
    );
  });
}

final class _FakePersistentShellSession implements PersistentShellSession {
  final stdoutController = StreamController<Uint8List>();
  final stderrController = StreamController<Uint8List>();
  final List<String> responses;
  final List<int> exitCodes;
  final writes = <String>[];
  int responseIndex = 0;

  _FakePersistentShellSession({required this.responses, List<int>? exitCodes})
    : exitCodes = exitCodes ?? List.filled(responses.length, 0);

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
