import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_listener.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';

/// A remote forward through the agent, against a stand-in for its
/// `/api/v1/listen/ws`: the control socket's half of the protocol, with the
/// relay's half — claiming a connection — handed in.
void main() {
  late HttpServer server;
  late Completer<WebSocket> agentSide;

  setUp(() async {
    agentSide = Completer<WebSocket>();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      agentSide.complete(await WebSocketTransformer.upgrade(req));
    });
  });

  tearDown(() => server.close(force: true));

  Future<WebSocket> connect() =>
      WebSocket.connect('ws://127.0.0.1:${server.port}/');

  /// The agent's side: what it was asked, and a way to answer.
  Future<(WebSocket, Map<String, dynamic>)> agent() async {
    final socket = await agentSide.future;
    final asked = Completer<Map<String, dynamic>>();
    socket.listen((frame) {
      if (!asked.isCompleted) {
        asked.complete(jsonDecode(frame as String) as Map<String, dynamic>);
      }
    });
    return (socket, await asked.future);
  }

  test('asks for the address, and carries a claimed connection here', () async {
    // This device's end of the forward.
    final local = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(local.close);
    local.listen((socket) => socket.listen(socket.add));

    final claimed = <String>[];
    final starting = MonitorRemoteListener.start(
      socket: await connect(),
      bindHost: '127.0.0.1',
      bindPort: 8080,
      claim: (id) async {
        claimed.add(id);
        return _Channel();
      },
      connectLocal: () => Socket.connect(local.address, local.port),
    );
    final (agentSocket, asked) = await agent();
    expect(asked, {'type': 'listen', 'host': '127.0.0.1', 'port': 8080});

    agentSocket.add(jsonEncode({'type': 'ready', 'port': 8080}));
    final listener = await starting;
    addTearDown(listener.close);
    expect(listener.port, 8080);

    agentSocket.add(
      jsonEncode({'type': 'incoming', 'id': 'abc', 'peer': '10.0.0.2:5000'}),
    );
    await _until(() => claimed.isNotEmpty);
    expect(claimed, ['abc']);
    final channel = _Channel.made.last;
    channel.fromServer.add([7, 8, 9]);
    expect(await channel.toServer.stream.first, [7, 8, 9]);
  });

  test('a refusal before binding is what start throws', () async {
    final starting = MonitorRemoteListener.start(
      socket: await connect(),
      bindHost: '0.0.0.0',
      bindPort: 8080,
      claim: (_) async => _Channel(),
      connectLocal: () => throw UnimplementedError(),
    );
    final (agentSocket, _) = await agent();
    agentSocket.add(
      jsonEncode({
        'type': 'error',
        'code': 'not_permitted',
        'message': 'Binding a public address is off',
      }),
    );

    await expectLater(
      starting,
      throwsA(
        isA<MonitorHttpErr>().having(
          (e) => e.type,
          'type',
          MonitorHttpErrType.notGranted,
        ),
      ),
    );
  });

  test('the agent going away ends it', () async {
    final starting = MonitorRemoteListener.start(
      socket: await connect(),
      bindHost: '127.0.0.1',
      bindPort: 0,
      claim: (_) async => _Channel(),
      connectLocal: () => throw UnimplementedError(),
    );
    final (agentSocket, _) = await agent();
    agentSocket.add(jsonEncode({'type': 'ready', 'port': 40123}));
    final listener = await starting;
    expect(listener.port, 40123);

    await agentSocket.close();
    await listener.done.timeout(const Duration(seconds: 2));
  });

  test('a local end that is down closes the claimed connection', () async {
    // Rather than leave whoever connected waiting out the agent's timeout.
    final starting = MonitorRemoteListener.start(
      socket: await connect(),
      bindHost: '127.0.0.1',
      bindPort: 8080,
      claim: (_) async => _Channel(),
      connectLocal: () => throw const SocketException('refused'),
    );
    final (agentSocket, _) = await agent();
    agentSocket.add(jsonEncode({'type': 'ready', 'port': 8080}));
    final listener = await starting;
    addTearDown(listener.close);

    agentSocket.add(jsonEncode({'type': 'incoming', 'id': 'x', 'peer': ''}));
    await _until(() => _Channel.made.lastOrNull?.closed ?? false);
  });
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// The relay's half of a claimed connection: what the server's peer sends
/// arrives on [fromServer], and what is carried back lands in [toServer].
class _Channel implements SshTunnelChannel {
  _Channel() {
    made.add(this);
  }

  static final made = <_Channel>[];

  final fromServer = StreamController<List<int>>();
  final toServer = StreamController<List<int>>();
  var closed = false;

  @override
  Stream<List<int>> get stream => fromServer.stream;

  @override
  StreamSink<List<int>> get sink => toServer.sink;

  @override
  Future<void> close() async {
    closed = true;
    await fromServer.close();
  }
}
