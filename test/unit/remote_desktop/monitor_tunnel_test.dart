/// How the app carries a TCP connection through a `monitor` agent.
///
/// The other half of the protocol is `monitor/src/api/ws/stream.rs`, and the
/// two are tested against each other on the Rust side (`tests/stream_ws.rs`).
/// What this covers is the Dart end: the frames it sends, what it does with
/// each reply, and that a socket it hands to `SshLocalTunnel` really carries
/// bytes in both directions — which is the whole of what a remote desktop
/// session needs from it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// A stand-in for the agent's relay endpoint.
///
/// Speaks the real protocol — `open`, `ready`, `error`, `exit`, binary bytes —
/// over a real WebSocket, so what is asserted is the wire format rather than a
/// mock's idea of it.
class _FakeAgent {
  _FakeAgent._(this._server, this._target);

  final HttpServer _server;

  /// What the relay dials when it is asked to. Set to null for a target that
  /// cannot be reached.
  final String? _target;

  /// Every `open` this agent was asked for, parsed.
  final requests = <Map<String, dynamic>>[];

  List<int>? lastBytes;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeAgent> start({String? target}) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final agent = _FakeAgent._(server, target);
    agent._serve();
    return agent;
  }

  void _serve() {
    _server.listen((request) async {
      // The login the client does before anything else, then the ticket it
      // exchanges that for. Both are the agent's real contract; only what is
      // interesting here — the relay — is faked beyond the shape of the reply.
      if (request.uri.path == '/api/v1/login') {
        await request.drain<void>();
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'token': 'test-token'}));
        await request.response.close();
        return;
      }
      if (request.uri.path == '/api/v1/ws-ticket') {
        await request.drain<void>();
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ticket': 'id.secret', 'expires_in': 30}));
        await request.response.close();
        return;
      }
      // The ticket rides the subprotocol, exactly as the real agent reads it —
      // and dart:io refuses an upgrade whose requested subprotocol the server
      // does not pick, which is the contract this asserts rather than works
      // around.
      final socket = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => protocols.first,
      );
      socket.listen((frame) {
        if (frame is String) {
          final msg = jsonDecode(frame) as Map<String, dynamic>;
          if (msg['type'] != 'open') return;
          requests.add(msg);
          if (_target == null) {
            socket.add(
              jsonEncode({
                'type': 'error',
                'code': 'connect_failed',
                'message': 'Could not reach the target',
              }),
            );
            return;
          }
          socket.add(jsonEncode({'type': 'ready'}));
          return;
        }
        // Bytes going the other way are echoed back with a marker, so a test
        // can tell a round trip from a local echo.
        lastBytes = (frame as List<int>).toList();
        socket.add([...lastBytes!, 0x21]);
      });
    });
  }

  Future<void> close() => _server.close(force: true);
}

/// A client pointed at [_FakeAgent] — the login is a ticket POST, and the
/// agent answers it.
MonitorHttpClient _clientFor(_FakeAgent agent) =>
    MonitorHttpClient(MonitorHttpCredential(addr: agent.url.toString()));

/// The default `HttpOverrides`, which is to say none at all.
///
/// `flutter_test` installs overrides that answer every request with a 400
/// without opening a socket, so a test that talks to a real local server has to
/// say so — see `rootfs_manifest_source_test.dart`, which names the same thing.
class _RealHttp extends HttpOverrides {}

/// Runs [body] with real sockets, rather than the test binding's stubs.
Future<void> realHttp(Future<void> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttp());

void main() {
  test('dials the address it was given, on the socket rather than in the URL',
      () async {
    final agent = await _FakeAgent.start(target: '127.0.0.1:3389');
    addTearDown(agent.close);

    await realHttp(() async {
      final channel = await MonitorTunnelChannel.dial(
        client: _clientFor(agent),
        remoteHost: '127.0.0.1',
        remotePort: 3389,
      );
      addTearDown(channel.close);

      expect(agent.requests, hasLength(1));
      expect(agent.requests.single['host'], '127.0.0.1');
      expect(agent.requests.single['port'], 3389);
    });
  });

  test('a refused target fails the handshake rather than the first byte',
      () async {
    // A remote desktop client writes its protocol header immediately, so a
    // failure that only lands once bytes are sent arrives too late to be
    // reported as "could not connect".
    final agent = await _FakeAgent.start();
    addTearDown(agent.close);

    await realHttp(() async {
      await expectLater(
        MonitorTunnelChannel.dial(
          client: _clientFor(agent),
          remoteHost: '127.0.0.1',
          remotePort: 3389,
        ),
        // The app's own transport error, not a bare `Exception`: a session
        // reports this one to the page, and `RemoteDesktopSessions` retries on
        // it rather than on the type.
        throwsA(isA<MonitorHttpErr>()),
      );
    });
  });

  test('bytes travel in both directions once it is open', () async {
    final agent = await _FakeAgent.start(target: '127.0.0.1:3389');
    addTearDown(agent.close);

    await realHttp(() async {
      final channel = await MonitorTunnelChannel.dial(
        client: _clientFor(agent),
        remoteHost: '127.0.0.1',
        remotePort: 3389,
      );
      addTearDown(channel.close);

      final received = channel.stream.first;
      channel.sink.add([1, 2, 3]);

      expect(
        await received.timeout(const Duration(seconds: 2)),
        [1, 2, 3, 0x21],
      );
      expect(agent.lastBytes, [1, 2, 3]);
    });
  });

  test('closing the channel closes what it was carrying', () async {
    final agent = await _FakeAgent.start(target: '127.0.0.1:3389');
    addTearDown(agent.close);

    await realHttp(() async {
      final channel = await MonitorTunnelChannel.dial(
        client: _clientFor(agent),
        remoteHost: '127.0.0.1',
        remotePort: 3389,
      );

      await channel.close();
      // The stream ends rather than hanging: `SshLocalTunnel` waits on this to
      // tear its accepted socket down.
      await channel.stream.drain<void>().timeout(const Duration(seconds: 2));
    });
  });
}
