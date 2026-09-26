/// PVE's termproxy protocol (`PveTermProxy`, `PveTermShellBackend`) against a
/// fake termproxy behind a real websocket on loopback: the framing of input,
/// resize and keep-alive, the `<user>:<ticket>\n` handshake and its `OK`, and
/// what a refusal or a closed socket becomes.
///
/// The fake speaks what `pve-xtermjs`'s `main.js` and `proxmox-termproxy`
/// agree on; see the comment on `PveTermProxy`.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/pve_termproxy.dart';
import 'package:server_box/data/model/app/error.dart';

/// One websocket endpoint that behaves like termproxy behind pveproxy.
class _FakeTermProxy {
  _FakeTermProxy._(this._server);

  final HttpServer _server;

  /// What to answer the ticket with; null closes the socket instead.
  List<List<int>>? answer = [ascii.encode('OK')];

  /// The subprotocols the client asked for.
  String? requestedProtocol;

  /// Every frame the client sent, as bytes.
  final frames = <List<int>>[];
  final _frameSeen = StreamController<List<int>>.broadcast();
  WebSocket? socket;

  Uri get url => Uri.parse('ws://127.0.0.1:${_server.port}/');

  static Future<_FakeTermProxy> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final fake = _FakeTermProxy._(server);
    server.listen((request) async {
      fake.requestedProtocol = request.headers.value('sec-websocket-protocol');
      final ws = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => protocols.first,
      );
      fake.socket = ws;
      var first = true;
      ws.listen((frame) {
        final bytes = frame is String ? utf8.encode(frame) : frame as List<int>;
        fake.frames.add(bytes);
        if (!fake._frameSeen.isClosed) fake._frameSeen.add(bytes);
        if (!first) return;
        first = false;
        final answer = fake.answer;
        if (answer == null) {
          unawaited(ws.close());
          return;
        }
        for (final chunk in answer) {
          ws.add(chunk);
        }
      });
    });
    return fake;
  }

  /// The next frame the client sends that [test] accepts.
  Future<String> next(bool Function(String frame) test) => _frameSeen.stream
      .map(utf8.decode)
      .firstWhere(test)
      .timeout(const Duration(seconds: 5));

  Future<void> close() async {
    await _frameSeen.close();
    await _server.close(force: true);
  }
}

void main() {
  group('framing', () {
    test('auth is user, ticket and a newline', () {
      expect(
        utf8.decode(PveTermProxy.auth('root@pam', 'PVEVNC:abc::def')),
        'root@pam:PVEVNC:abc::def\n',
      );
    });

    test('input counts UTF-8 bytes, not characters', () {
      expect(utf8.decode(PveTermProxy.input(utf8.encode('ls\r'))), '0:3:ls\r');
      // 中 is three bytes; the length is what termproxy reads up to.
      expect(
        utf8.decode(PveTermProxy.input(utf8.encode('a中'))),
        '0:4:a中',
      );
      // Bytes that are not UTF-8 pass untouched.
      expect(PveTermProxy.input(const [0xff, 0x00]), [
        ...ascii.encode('0:2:'),
        0xff,
        0x00,
      ]);
    });

    test('resize and keep-alive', () {
      expect(utf8.decode(PveTermProxy.resize(120, 40)), '1:120:40:');
      expect(utf8.decode(PveTermProxy.keepAlive), '2');
    });
  });

  group('session', () {
    late _FakeTermProxy fake;

    setUp(() async => fake = await _FakeTermProxy.start());
    tearDown(() => fake.close());

    Future<PveTermShellBackend> connect({
      Duration keepAlive = PveTermProxy.keepAliveInterval,
    }) async {
      final ws = await WebSocket.connect(
        fake.url.toString(),
        protocols: const ['binary'],
      );
      return PveTermShellBackend.start(
        ws,
        user: 'root@pam',
        ticket: 'PVEVNC:T',
        keepAlive: keepAlive,
      );
    }

    test('handshake, output after OK, input and resize', () async {
      fake.answer = [ascii.encode('OKwelcome\r\n')];
      final backend = await connect();
      addTearDown(backend.close);
      expect(fake.requestedProtocol, 'binary');
      expect(utf8.decode(fake.frames.first), 'root@pam:PVEVNC:T\n');
      expect(backend.supportsExec, isFalse);

      final shell = await backend.openShell(width: 80, height: 24);
      expect(await fake.next((f) => f.startsWith('1:')), '1:80:24:');

      final out = StringBuffer();
      final sub = shell.stdout!.listen((b) => out.write(utf8.decode(b)));
      addTearDown(sub.cancel);

      shell.write(utf8.encode('uptime\r'));
      expect(await fake.next((f) => f.startsWith('0:')), '0:7:uptime\r');
      shell.resizeTerminal(100, 30);
      expect(await fake.next((f) => f == '1:100:30:'), '1:100:30:');

      fake.socket!.add(Uint8List.fromList(utf8.encode(' 12:00 up')));
      await pumpUntil(() => out.toString().contains('up'));
      expect(out.toString(), 'welcome\r\n 12:00 up');

      await expectLater(
        backend.openShell(width: 1, height: 1),
        throwsStateError,
        reason: 'one ticket, one shell',
      );
    });

    test('an OK split across frames is still an OK', () async {
      fake.answer = [
        ascii.encode('O'),
        ascii.encode('K'),
        ascii.encode('login: '),
      ];
      final backend = await connect();
      addTearDown(backend.close);
      final shell = await backend.openShell(width: 80, height: 24);
      final first = await shell.stdout!.first;
      expect(utf8.decode(first), 'login: ');
    });

    test('keep-alive is 2, on its interval', () async {
      final backend = await connect(
        keepAlive: const Duration(milliseconds: 20),
      );
      addTearDown(backend.close);
      expect(await fake.next((f) => f == '2'), '2');
    });

    test('anything but OK is a refused ticket', () async {
      fake.answer = [ascii.encode('permission denied')];
      await expectLater(
        connect(),
        throwsA(
          isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.authFailed),
        ),
      );
    });

    test('a socket closed before OK is unreachable', () async {
      fake.answer = null;
      await expectLater(
        connect(),
        throwsA(
          isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unreachable),
        ),
      );
    });

    test('the far end closing ends the shell and the backend', () async {
      final backend = await connect();
      final shell = await backend.openShell(width: 80, height: 24);
      unawaited(shell.stdout!.drain<void>());
      expect(backend.isClosed, isFalse);
      await backend.ping();

      await fake.socket!.close();
      await shell.done.timeout(const Duration(seconds: 5));
      expect(backend.isClosed, isTrue);
      await expectLater(backend.ping(), throwsStateError);
    });

    test('closing the shell here hangs up, and is not a lost link', () async {
      final backend = await connect();
      final shell = await backend.openShell(width: 80, height: 24);
      shell.close();
      await shell.done.timeout(const Duration(seconds: 5));
      await fake.socket!.done.timeout(const Duration(seconds: 5));
      // The terminal page reconnects a closed backend; a disconnect the user
      // asked for must not be answered with a new console.
      expect(backend.isClosed, isFalse);
      backend.close();
      expect(backend.isClosed, isTrue);
    });
  });
}

Future<void> pumpUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
