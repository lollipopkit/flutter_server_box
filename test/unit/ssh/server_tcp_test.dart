/// `ServerTcpDialer`: a TCP connection to an address as seen from a server,
/// over whichever way the server is reached.
///
/// Every case is asserted by bytes crossing a real socket — an echo server on
/// loopback — so what is covered is that the connection works, not only that
/// the right branch was taken. The SSH transport is the seam `ServerTcpSsh`
/// (building an authenticated SSH server here would test dartssh2); the
/// monitor relay is the real `MonitorTunnelChannel` against a fake agent that
/// speaks the real protocol.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  late _Echo echo;

  setUp(() async {
    echo = await _Echo.start();
  });

  tearDown(() => echo.close());

  group('SSH', () {
    test('a channel and a socket both go through forwardLocal', () async {
      final ssh = _FakeSsh();
      final dialer = ServerTcpDialer(spi: _sshOnly, ssh: ssh.link);
      addTearDown(dialer.close);

      final channel = await dialer.open('db.internal', 5432);
      addTearDown(channel.close);
      expect(channel.transport, ServerTransport.ssh);
      expect(await _roundTrip(channel, [1, 2, 3]), [1, 2, 3]);

      final socket = await dialer.connect('db.internal', 5432);
      addTearDown(socket.destroy);
      expect(await _socketRoundTrip(socket, [4, 5]), [4, 5]);

      expect(ssh.forwarded, ['db.internal:5432', 'db.internal:5432']);
    });

    test('the socket is a real dart:io one, ended with its channel', () async {
      final ssh = _FakeSsh();
      final dialer = ServerTcpDialer(spi: _sshOnly, ssh: ssh.link);
      addTearDown(dialer.close);

      final task = dialer.startConnect('db.internal', 5432);
      final socket = await task.socket;
      expect(socket.remoteAddress.isLoopback, isTrue);
      expect(await _socketRoundTrip(socket, [9]), [9]);

      socket.destroy();
      await ssh.channels.single.closed.future.timeout(
        const Duration(seconds: 5),
      );
    });

    test('a loopback tunnel carries each accepted socket', () async {
      final ssh = _FakeSsh();
      final dialer = ServerTcpDialer(spi: _sshOnly, ssh: ssh.link);
      addTearDown(dialer.close);

      final tunnel = await dialer.loopback('desktop', 5900);
      addTearDown(tunnel.close);
      expect(tunnel.address.isLoopback, isTrue);

      final socket = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(socket.destroy);
      expect(await _socketRoundTrip(socket, [7]), [7]);
      expect(ssh.forwarded, ['desktop:5900']);
    });

    test('a failed client is a dial error naming SSH', () async {
      final dialer = ServerTcpDialer(
        spi: _sshOnly,
        ssh: () async => throw const SocketException('refused'),
      );
      addTearDown(dialer.close);

      await expectLater(
        dialer.open('db.internal', 5432),
        throwsA(
          isA<ServerTcpErr>()
              .having((e) => e.type, 'type', ServerTcpErrType.dial)
              .having((e) => e.transport, 'transport', ServerTransport.ssh)
              .having((e) => e.cause, 'cause', isA<SocketException>())
              .having((e) => e.other, 'other', isNull),
        ),
      );
    });
  });

  group('monitor relay', () {
    test('the agent dials, and one login serves every connection', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);

      await _realHttp(() async {
        final dialer = ServerTcpDialer(
          spi: _agentOnly(agent),
          ssh: _noSsh,
          relayGrant: () => const MonitorRemoteAccess(stream: true),
        );
        addTearDown(dialer.close);

        final channel = await dialer.open('localhost', 8006);
        addTearDown(channel.close);
        expect(channel.transport, ServerTransport.monitorHttp);
        expect(await _roundTrip(channel, [1, 2]), [1, 2]);

        final socket = await dialer.connect('localhost', 8006);
        addTearDown(socket.destroy);
        expect(await _socketRoundTrip(socket, [3]), [3]);

        expect(agent.dialled, ['localhost:8006', 'localhost:8006']);
        expect(agent.logins, 1);
      });
    });

    test('a grant not yet read is not a refusal', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);

      await _realHttp(() async {
        final dialer = ServerTcpDialer(spi: _agentOnly(agent), ssh: _noSsh);
        addTearDown(dialer.close);

        final tunnel = await dialer.loopback('localhost', 5900);
        addTearDown(tunnel.close);
        final socket = await Socket.connect(tunnel.address, tunnel.port);
        addTearDown(socket.destroy);
        expect(await _socketRoundTrip(socket, [6]), [6]);
        expect(agent.dialled, ['localhost:5900']);
      });
    });

    test('a refused grant is typed, and nothing is dialled', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);

      final dialer = ServerTcpDialer(
        spi: _agentOnly(agent),
        ssh: _noSsh,
        relayGrant: () => const MonitorRemoteAccess(fullAccess: true),
      );
      addTearDown(dialer.close);

      await expectLater(
        dialer.open('localhost', 8006),
        throwsA(
          isA<ServerTcpErr>()
              .having(
                (e) => e.type,
                'type',
                ServerTcpErrType.relayNotGranted,
              )
              .having(
                (e) => e.transport,
                'transport',
                ServerTransport.monitorHttp,
              ),
        ),
      );
      expect(agent.logins, 0);
    });

    // Found against a real agent with `full_access` off, before the status
    // poll had read its grant: the refusal arrived as a dial failure, and the
    // Virtualization tab said the host could not be reached.
    test('a grant not yet read, refused by the agent, is typed the same',
        () async {
      final agent = await _FakeAgent.start(echo, noGrant: true);
      addTearDown(agent.close);

      await _realHttp(() async {
        final dialer = ServerTcpDialer(spi: _agentOnly(agent), ssh: _noSsh);
        addTearDown(dialer.close);

        await expectLater(
          dialer.open('localhost', 8006),
          throwsA(
            isA<ServerTcpErr>()
                .having(
                  (e) => e.type,
                  'type',
                  ServerTcpErrType.relayNotGranted,
                )
                .having(
                  (e) => (e.cause as MonitorHttpErr).type,
                  'cause',
                  MonitorHttpErrType.notGranted,
                ),
          ),
        );
        expect(agent.dialled, isEmpty);
      });
    });

    // Also found against a real agent: a refusal decided before dialling
    // failed `startConnect`'s future before `HttpClient` listened to it, which
    // the zone reports as uncaught — failing this test, and reaching the
    // app's crash reporting, although the request itself failed properly.
    test('a refusal through HttpClient is the request\'s error, and nothing '
        'is uncaught', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);

      await _realHttp(() async {
        final dialer = ServerTcpDialer(
          spi: _agentOnly(agent),
          ssh: _noSsh,
          relayGrant: () => const MonitorRemoteAccess(fullAccess: true),
        );
        addTearDown(dialer.close);
        final client = HttpClient()
          ..connectionFactory = (url, _, _) async =>
              dialer.startConnect(url.host, url.port);
        addTearDown(() => client.close(force: true));

        await expectLater(
          client.getUrl(Uri.parse('http://localhost:8006/')),
          throwsA(
            isA<ServerTcpErr>().having(
              (e) => e.type,
              'type',
              ServerTcpErrType.relayNotGranted,
            ),
          ),
        );
      });
    });
  });

  group('both transports', () {
    test('an agent that will not relay is skipped for SSH', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);
      final ssh = _FakeSsh();
      final dialer = ServerTcpDialer(
        spi: _both(agent, lead: ServerTransport.monitorHttp),
        ssh: ssh.link,
        relayGrant: () => const MonitorRemoteAccess(),
      );
      addTearDown(dialer.close);

      final channel = await dialer.open('localhost', 8006);
      addTearDown(channel.close);
      expect(channel.transport, ServerTransport.ssh);
      expect(agent.logins, 0);
    });

    test('a failed leading transport falls through to the other', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);

      await _realHttp(() async {
        var sshTried = 0;
        final dialer = ServerTcpDialer(
          spi: _both(agent, lead: ServerTransport.ssh),
          ssh: () async {
            sshTried++;
            throw const SocketException('sshd down');
          },
        );
        addTearDown(dialer.close);

        final socket = await dialer.connect('localhost', 8006);
        addTearDown(socket.destroy);
        expect(await _socketRoundTrip(socket, [8]), [8]);
        expect(sshTried, 1);
        expect(agent.dialled, ['localhost:8006']);
      });
    });

    test('both failing reports both, the last tried leading', () async {
      final agent = await _FakeAgent.start(echo, refuse: true);
      addTearDown(agent.close);

      await _realHttp(() async {
        final dialer = ServerTcpDialer(
          spi: _both(agent, lead: ServerTransport.ssh),
          ssh: () async => throw const SocketException('sshd down'),
        );
        addTearDown(dialer.close);

        await expectLater(
          dialer.open('localhost', 8006),
          throwsA(
            isA<ServerTcpErr>()
                .having((e) => e.type, 'type', ServerTcpErrType.dial)
                .having(
                  (e) => e.transport,
                  'transport',
                  ServerTransport.monitorHttp,
                )
                .having(
                  (e) => e.other?.transport,
                  'other',
                  ServerTransport.ssh,
                ),
          ),
        );
      });
    });

    test('a dial failure outranks a skipped fallback', () async {
      final agent = await _FakeAgent.start(echo);
      addTearDown(agent.close);
      final dialer = ServerTcpDialer(
        spi: _both(agent, lead: ServerTransport.ssh),
        ssh: () async => throw const SocketException('sshd down'),
        relayGrant: () => const MonitorRemoteAccess(),
      );
      addTearDown(dialer.close);

      await expectLater(
        dialer.open('localhost', 8006),
        throwsA(
          isA<ServerTcpErr>()
              .having((e) => e.type, 'type', ServerTcpErrType.dial)
              .having((e) => e.transport, 'transport', ServerTransport.ssh)
              .having(
                (e) => e.other?.type,
                'other',
                ServerTcpErrType.relayNotGranted,
              ),
        ),
      );
    });
  });

  group('local', () {
    const local = Spi(name: 'this-mac', id: 'local', local: true);

    test('a direct socket from this device', () async {
      final dialer = ServerTcpDialer(spi: local, ssh: _noSsh);
      addTearDown(dialer.close);

      final socket = await dialer.connect('127.0.0.1', echo.port);
      addTearDown(socket.destroy);
      // Not a pair: the peer is the echo server itself.
      expect(socket.remotePort, echo.port);
      expect(await _socketRoundTrip(socket, [1]), [1]);

      final channel = await dialer.open('127.0.0.1', echo.port);
      addTearDown(channel.close);
      expect(channel.transport, ServerTransport.local);
      expect(await _roundTrip(channel, [2]), [2]);

      final tunnel = await dialer.loopback('127.0.0.1', echo.port);
      addTearDown(tunnel.close);
      final viaTunnel = await Socket.connect(tunnel.address, tunnel.port);
      addTearDown(viaTunnel.destroy);
      expect(await _socketRoundTrip(viaTunnel, [3]), [3]);
      expect(echo.accepted, 3);
    }, skip: _localSkip);

    test('a caller that leaves local out is refused, typed', () async {
      final dialer = ServerTcpDialer(
        spi: local,
        ssh: _noSsh,
        transports: const {ServerTransport.ssh, ServerTransport.monitorHttp},
      );
      addTearDown(dialer.close);

      await expectLater(
        dialer.loopback('127.0.0.1', echo.port),
        throwsA(
          isA<ServerTcpErr>()
              .having((e) => e.type, 'type', ServerTcpErrType.notOffered)
              .having((e) => e.transport, 'transport', ServerTransport.local),
        ),
      );
      expect(echo.accepted, 0);
    });
  });
}

/// A local server on a platform that cannot stand for one is refused before
/// any socket; the desktop test hosts can.
final Object _localSkip =
    Platform.isMacOS || Platform.isLinux || Platform.isWindows
    ? false
    : 'local servers are desktop-only';

const _sshOnly = Spi(
  name: 'ssh-only',
  id: 'ssh',
  ssh: SshCredential(ip: '10.0.0.1'),
);

Spi _agentOnly(_FakeAgent agent) => Spi(
  name: 'agent-only',
  id: 'agent',
  monitorHttp: MonitorHttpCredential(addr: agent.url.toString()),
);

Spi _both(_FakeAgent agent, {required ServerTransport lead}) => Spi(
  name: 'both',
  id: 'both',
  ssh: const SshCredential(ip: '10.0.0.1'),
  monitorHttp: MonitorHttpCredential(addr: agent.url.toString()),
  preferredTransport: lead,
);

Future<ServerTcpSsh> _noSsh() async => fail('SSH must not be dialled');

/// Stands for an SSH client: every forward opens a real socket to [_Echo], so
/// the channel it returns carries bytes like a direct-tcpip one does.
class _FakeSsh {
  final forwarded = <String>[];
  final channels = <_SocketChannel>[];
  final _done = Completer<void>();

  Future<ServerTcpSsh> link() async => ServerTcpSsh(
    forward: (host, port) async {
      forwarded.add('$host:$port');
      final channel = _SocketChannel(
        await Socket.connect(InternetAddress.loopbackIPv4, _Echo.current.port),
      );
      channels.add(channel);
      return channel;
    },
    done: _done.future,
  );
}

class _SocketChannel implements SshTunnelChannel {
  _SocketChannel(this._socket) {
    _socket.done.whenComplete(() {
      if (!closed.isCompleted) closed.complete();
    });
  }

  final Socket _socket;
  final closed = Completer<void>();

  // Typed as `Stream<List<int>>` at runtime too, or piping it into another
  // socket fails: a `Stream<Uint8List>` wants a `StreamConsumer<Uint8List>`.
  @override
  Stream<List<int>> get stream => _socket.cast<List<int>>();

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> close() async {
    _socket.destroy();
    if (!closed.isCompleted) closed.complete();
  }
}

/// A loopback TCP echo server: the address every transport ends at.
class _Echo {
  _Echo._(this._server) {
    _server.listen((socket) {
      accepted++;
      socket.listen(socket.add, onDone: socket.destroy, onError: (_) {});
    });
  }

  /// The one started for the running test, which the fakes connect to.
  static late _Echo current;

  final ServerSocket _server;
  var accepted = 0;

  int get port => _server.port;

  static Future<_Echo> start() async {
    final echo = _Echo._(
      await ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    current = echo;
    return echo;
  }

  Future<void> close() => _server.close();
}

/// The agent's relay endpoint: logs in, mints a ticket, and on `open` dials
/// [_Echo] and relays bytes both ways — what the real agent does from its own
/// machine. With `refuse`, answers `error` instead.
class _FakeAgent {
  _FakeAgent._(this._server, this._echo, this._refuse, this._noGrant);

  final HttpServer _server;
  final _Echo _echo;
  final bool _refuse;

  /// Answers `/ws-ticket` as an agent with `full_access` off does.
  final bool _noGrant;

  final dialled = <String>[];
  var logins = 0;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}');

  static Future<_FakeAgent> start(
    _Echo echo, {
    bool refuse = false,
    bool noGrant = false,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _FakeAgent._(server, echo, refuse, noGrant).._serve();
  }

  void _serve() {
    _server.listen((request) async {
      if (request.uri.path == '/api/v1/login') {
        logins++;
        await request.drain<void>();
        return _json(request, {'token': 'test-token'});
      }
      if (request.uri.path == '/api/v1/ws-ticket') {
        await request.drain<void>();
        if (_noGrant) {
          // `issue_ws_ticket` in `monitor/src/api/server.rs`.
          request.response.statusCode = HttpStatus.forbidden;
          return _json(request, {'error': 'full access not available'});
        }
        return _json(request, {'ticket': 'id.secret', 'expires_in': 30});
      }
      final ws = await WebSocketTransformer.upgrade(
        request,
        protocolSelector: (protocols) => protocols.first,
      );
      Socket? target;
      ws.listen(
        (frame) async {
          if (frame is List<int>) {
            target?.add(frame);
            return;
          }
          final msg = jsonDecode(frame as String) as Map<String, dynamic>;
          if (msg['type'] != 'open') return;
          dialled.add('${msg['host']}:${msg['port']}');
          if (_refuse) {
            ws.add(jsonEncode({'type': 'error', 'message': 'refused'}));
            return;
          }
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            _echo.port,
          );
          target = socket;
          socket.listen(ws.add, onDone: ws.close, onError: (_) {});
          ws.add(jsonEncode({'type': 'ready'}));
        },
        onDone: () => target?.destroy(),
      );
    });
  }

  Future<void> _json(HttpRequest request, Map<String, Object?> body) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    await request.response.close();
  }

  Future<void> close() => _server.close(force: true);
}

/// The default `HttpOverrides`: a test binding may install one that answers
/// without opening a socket.
class _RealHttp extends HttpOverrides {}

Future<void> _realHttp(Future<void> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttp());

Future<List<int>> _roundTrip(SshTunnelChannel channel, List<int> bytes) async {
  final got = channel.stream.first;
  channel.sink.add(bytes);
  return (await got.timeout(const Duration(seconds: 10))).toList();
}

Future<List<int>> _socketRoundTrip(Socket socket, List<int> bytes) async {
  final got = socket.first;
  socket.add(bytes);
  return (await got.timeout(const Duration(seconds: 10))).toList();
}
