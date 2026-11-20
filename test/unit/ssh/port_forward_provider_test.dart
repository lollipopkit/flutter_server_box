import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/monitor/listener.dart';
import 'package:server_box/core/ssh/local_tunnel.dart';
import 'package:server_box/data/model/server/monitor/monitor_access.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/stores.dart';

import '../../helpers/idle_ssh_socket.dart';
import '../../helpers/rust_lib_helper.dart';
import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  test('clear closes a forward that finishes starting during deletion', () async {
    await openTestDb();
    final store = PortForwardStore();
    getIt.registerSingleton<PortForwardStore>(store);
    const serverId = 'server-id';
    SqliteDb.instance.execute(
      "INSERT INTO server (id, name, ssh_ip) VALUES ('$serverId', 'server', '127.0.0.1');",
    );
    final port = await _freeLoopbackPort();
    final config = PortForwardConfig(
      id: 'forward-id',
      serverId: serverId,
      name: 'test',
      type: PortForwardType.local,
      localHost: InternetAddress.loopbackIPv4.address,
      localPort: port,
      remoteHost: '127.0.0.1',
      remotePort: 22,
    );
    store.put(config);

    final socket = IdleSshSocket();
    final client = SSHClient(socket, username: 'test');
    final serverState = ServerState(
      spi: spiFixture(name: 'server', id: serverId, ip: '127.0.0.1'),
      status: InitStatus.status,
      client: client,
    );
    final container = ProviderContainer(
      overrides: [
        serverProvider(
          serverId,
        ).overrideWith(() => _FixedServerNotifier(serverState)),
      ],
    );
    try {
      final notifier = container.read(portForwardProvider(serverId).notifier);

      final start = notifier.startForward(config.id);
      await _waitUntilPortIsBound(port);
      final clear = notifier.clear();
      await Future.wait([start, clear]).timeout(const Duration(seconds: 5));

      expect(notifier.state.configs, isEmpty);
      expect(notifier.state.activeForwards, isEmpty);
      expect(store.fetchForServer(serverId), isEmpty);

      // A startup that overlaps cleanup cannot leave its listener behind.
      final rebound = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await rebound.close();
    } finally {
      container.dispose();
      client.close();
      socket.destroy();
      await getIt.reset();
      await closeTestDb();
    }
  });

  test(
    'clear cancels a Monitor remote listener stuck between listen and ready',
    () async {
      await initRustLibForTest();
      await openTestDb();
      final store = PortForwardStore();
      getIt.registerSingleton<PortForwardStore>(store);
      const serverId = 'monitor-server-id';
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('$serverId', 'mon', '127.0.0.1');",
      );

      final listenReceived = Completer<void>();
      final socketClosed = Completer<void>();
      var acceptRequests = 0;

      final fakeMonitor = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      unawaited(
        fakeMonitor.forEach((req) async {
          final path = req.uri.path;
          if (path == '/api/v1/health') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'protocol': 99, 'min_client_protocol': 1}));
            await req.response.close();
            return;
          }
          if (path == '/api/v1/login') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'token': 'fake-jwt', 'expires_at': 9999999999}));
            await req.response.close();
            return;
          }
          if (path == '/api/v1/ws-ticket') {
            req.response
              ..statusCode = HttpStatus.ok
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'ticket': 'fake-ticket'}));
            await req.response.close();
            return;
          }
          if (path == '/api/v1/stream/ws') {
            acceptRequests++;
            req.response.statusCode = HttpStatus.gone;
            await req.response.close();
            return;
          }
          if (path == '/api/v1/listen/ws') {
            final ws = await WebSocketTransformer.upgrade(
              req,
              protocolSelector: (protocols) => protocols.first,
            );
            ws.listen(
              (event) {
                if (event is String) {
                  final msg = jsonDecode(event) as Map<String, dynamic>;
                  if (msg['type'] == 'listen' && !listenReceived.isCompleted) {
                    listenReceived.complete();
                  }
                }
              },
              onDone: () {
                if (!socketClosed.isCompleted) socketClosed.complete();
              },
            );
            return;
          }
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }),
      );

      final config = PortForwardConfig(
        id: 'agent-remote-id',
        serverId: serverId,
        name: 'remote-via-monitor',
        type: PortForwardType.remote,
        localHost: InternetAddress.loopbackIPv4.address,
        localPort: 8080,
        remoteHost: '127.0.0.1',
        remotePort: 9090,
      );
      store.put(config);

      final spi = spiFixture(name: 'mon', id: serverId, ip: '127.0.0.1').copyWith(
        monitorHttp: MonitorHttpCredential(
          addr: 'http://127.0.0.1:${fakeMonitor.port}',
          pwd: 'secret',
          allowInsecure: true,
        ),
        preferredTransport: ServerTransport.monitorHttp,
      );
      final serverState = ServerState(
        spi: spi,
        status: InitStatus.status,
        agentAccess: MonitorAccess.granted,
      );
      final container = ProviderContainer(
        overrides: [
          serverProvider(
            serverId,
          ).overrideWith(() => _FixedServerNotifier(serverState)),
        ],
      );

      final savedHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        final notifier = container.read(portForwardProvider(serverId).notifier);
        // Start without awaiting: it will stall waiting for `ready`.
        final start = notifier.startForward(config.id);
        await listenReceived.future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail(
            'listen not received; error=${notifier.state.activeForwards[config.id]?.error}',
          ),
        );

        // Only await `clear()`, never `start`.
        await notifier.clear().timeout(const Duration(seconds: 2));
        await socketClosed.future.timeout(const Duration(seconds: 2));
        // `start` settles cleanly once its listener is canceled.
        await start.timeout(const Duration(seconds: 2));

        expect(notifier.state.configs, isEmpty);
        expect(notifier.state.activeForwards, isEmpty);
        expect(store.fetchForServer(serverId), isEmpty);
        expect(acceptRequests, 0);
      } finally {
        HttpOverrides.global = savedHttpOverrides;
        container.dispose();
        await fakeMonitor.close(force: true);
        await getIt.reset();
        await closeTestDb();
      }
    },
  );

  test(
    'MonitorRemoteListener local close rejects late ready and incoming even if remote close stalls',
    () async {
      final incoming = StreamController<dynamic>();
      final remoteCloseStall = Completer<void>();
      final socket = _FakeControlWebSocket(incoming, remoteCloseStall.future);

      var claimCount = 0;
      var connectLocalCount = 0;
      late MonitorRemoteListener created;

      final startFuture = MonitorRemoteListener.start(
        socket: socket,
        bindHost: '127.0.0.1',
        bindPort: 9090,
        claim: (_) async {
          claimCount++;
          throw StateError('must not claim after local close');
        },
        connectLocal: () async {
          connectLocalCount++;
          throw StateError('must not dial local after local close');
        },
        onCreated: (listener) => created = listener,
      );

      // `listen` frame was sent, `ready` has not arrived.
      expect(socket.sent.length, 1);
      expect(jsonDecode(socket.sent.single as String)['type'], 'listen');

      // Local close returns immediately without waiting for stalled remote close.
      await created.close(waitRemote: false).timeout(const Duration(seconds: 1));
      expect(created.isClosed, isTrue);
      expect(socket.closeCalled, isTrue);

      await expectLater(startFuture, throwsA(anything));

      // Late `ready` and `incoming` frames must be ignored completely.
      incoming.add(jsonEncode({'type': 'ready', 'port': 9090}));
      incoming.add(jsonEncode({'type': 'incoming', 'id': 'late-conn'}));
      await Future<void>.delayed(Duration.zero);

      expect(claimCount, 0);
      expect(connectLocalCount, 0);

      remoteCloseStall.complete();
      await created.done.timeout(const Duration(seconds: 1));
      await incoming.close();
    },
  );

  test(
    'MonitorRemoteListener close(waitRemote: false) does not stall on an active bridge whose channel close hangs',
    () async {
      final incoming = StreamController<dynamic>.broadcast();
      final remoteControlClose = Completer<void>();
      final controlSocket = _FakeControlWebSocket(
        incoming,
        remoteControlClose.future,
      );

      final localServer = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final peerClosed = Completer<void>();
      final peerAccepted = Completer<void>();
      unawaited(
        localServer.first.then((peer) {
          if (!peerAccepted.isCompleted) peerAccepted.complete();
          peer.listen(
            (_) {},
            onDone: () {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
            onError: (_) {
              if (!peerClosed.isCompleted) peerClosed.complete();
            },
          );
        }),
      );

      final channelCloseStall = Completer<void>();
      final channel = _FakeTunnelChannel(channelCloseStall.future);
      final localConnected = Completer<void>();

      final startFuture = MonitorRemoteListener.start(
        socket: controlSocket,
        bindHost: '127.0.0.1',
        bindPort: 9090,
        claim: (_) async => channel,
        connectLocal: () async {
          final s = await Socket.connect(
            InternetAddress.loopbackIPv4,
            localServer.port,
          );
          if (!localConnected.isCompleted) localConnected.complete();
          return s;
        },
      );

      incoming.add(jsonEncode({'type': 'ready', 'port': 9090}));
      final listener = await startFuture.timeout(const Duration(seconds: 2));

      // Establish an active bridge on this listener.
      incoming.add(jsonEncode({'type': 'incoming', 'id': 'active-conn'}));
      await Future.wait([
        localConnected.future,
        peerAccepted.future,
      ]).timeout(const Duration(seconds: 2));
      // Allow `_carry` to register the bridge into `_bridges`.
      await Future<void>.delayed(Duration.zero);

      // Must return immediately even though both control socket and bridge
      // channel remote closes are stalled.
      await listener.close(waitRemote: false).timeout(const Duration(seconds: 1));
      expect(listener.isClosed, isTrue);
      expect(controlSocket.closeCalled, isTrue);
      expect(channel.closeCalled, isTrue);
      await peerClosed.future.timeout(const Duration(seconds: 2));

      channelCloseStall.complete();
      remoteControlClose.complete();
      await listener.done.timeout(const Duration(seconds: 1));
      await channel.dispose();
      await incoming.close();
      await localServer.close();
    },
  );

  _reasons();

  group('a forward on a server with both SSH and an agent', () {
    /// Starts a forward of [type] on a server led by [preferred], hands it to
    /// [body], and stops it.
    Future<void> withForward(
      ServerTransport preferred,
      PortForwardType type,
      Future<void> Function(
        PortForwardNotifier forwards,
        _FixedServerNotifier server,
        String id,
      )
      body,
    ) async {
      await openTestDb();
      final store = PortForwardStore();
      getIt.registerSingleton<PortForwardStore>(store);
      const serverId = 'server-id';
      SqliteDb.instance.execute(
        "INSERT INTO server (id, name, ssh_ip) VALUES ('$serverId', 'server', '127.0.0.1');",
      );
      final config = PortForwardConfig(
        id: 'forward-id',
        serverId: serverId,
        name: 'test',
        type: type,
        localHost: InternetAddress.loopbackIPv4.address,
        localPort: await _freeLoopbackPort(),
        remoteHost: type == PortForwardType.dynamic ? null : '127.0.0.1',
        remotePort: type == PortForwardType.dynamic ? null : 22,
      );
      store.put(config);

      final socket = IdleSshSocket();
      final client = SSHClient(socket, username: 'test');
      final server = _FixedServerNotifier(
        ServerState(
          spi: spiFixture(name: 'server', id: serverId, ip: '127.0.0.1')
              .copyWith(
                monitorHttp: const MonitorHttpCredential(
                  addr: 'https://agent:3770',
                ),
                preferredTransport: preferred,
              ),
          status: InitStatus.status,
          client: client,
          agentAccess: MonitorAccess.granted,
        ),
      );
      final container = ProviderContainer(
        overrides: [serverProvider(serverId).overrideWith(() => server)],
      );
      try {
        final forwards = container.read(portForwardProvider(serverId).notifier);
        await forwards.startForward(config.id);
        expect(
          forwards.state.activeForwards[config.id]?.isActive,
          isTrue,
          reason: forwards.state.activeForwards[config.id]?.error,
        );
        await body(forwards, server, config.id);
        await forwards.stopForward(config.id);
      } finally {
        container.dispose();
        client.close();
        socket.destroy();
        await getIt.reset();
        await closeTestDb();
      }
    }

    for (final type in [PortForwardType.local, PortForwardType.dynamic]) {
      test('${type.name}: the agent leading, never touches SSH', () async {
        // An sshd that is down would otherwise fail a forward that never
        // needed it.
        await withForward(ServerTransport.monitorHttp, type, (_, server, _) async {
          expect(server.shellDials, 0);
        });
      });

      test('${type.name}: SSH leading, connects it before binding', () async {
        await withForward(ServerTransport.ssh, type, (_, server, _) async {
          expect(server.shellDials, greaterThan(0));
        });
      });
    }

    test('SSH going away leaves what the agent carries running', () async {
      await withForward(
        ServerTransport.monitorHttp,
        PortForwardType.local,
        (forwards, server, id) async {
          server.dropSession();
          await Future<void>.delayed(Duration.zero);
          expect(forwards.state.activeForwards[id]?.isActive, isTrue);
        },
      );
    });

    test('and stops what SSH carried', () async {
      await withForward(
        ServerTransport.ssh,
        PortForwardType.local,
        (forwards, server, id) async {
          server.dropSession();
          await Future<void>.delayed(Duration.zero);
          expect(forwards.state.activeForwards[id]?.isActive, isNot(isTrue));
        },
      );
    });
  });
}

void _reasons() {
  group('why a remote forward cannot be made', () {
    ServerState agentLed(MonitorAccess? granted) => ServerState(
      spi: spiFixture(name: 'server', id: 's', ip: '127.0.0.1').copyWith(
        monitorHttp: const MonitorHttpCredential(addr: 'https://agent:3770'),
        preferredTransport: ServerTransport.monitorHttp,
      ),
      status: InitStatus.status,
      agentAccess: granted,
    );

    test('an agent refusing plaintext says so', () {
      for (final listen in [true, false]) {
        expect(
          portForwardUnavailable(
            agentLed(
              const MonitorAccess(
                ok: false,
                why: MonitorAccessWhy.insecureTransport,
              ),
            ),
            listen: listen,
          ),
          l10n.funcNeedsAgentHttps(libL10n.portForward),
        );
      }
    });

    test('one that grants access, or has not answered yet, is not held back',
        () {
      for (final listen in [true, false]) {
        expect(
          portForwardUnavailable(agentLed(MonitorAccess.granted), listen: listen),
          isNull,
        );
        expect(portForwardUnavailable(agentLed(null), listen: listen), isNull);
      }
    });
  });
}

/// Waits for the forward to listen on [port], which is what says it reached
/// its bind stage.
///
/// Asked by connecting, never by binding the port here: a probe that bound it
/// held it for an instant every 10 ms, and a forward binding in that instant
/// failed with the address in use — so on a loaded CI runner it never bound
/// at all, and this reported "did not reach its local bind stage" after the
/// whole deadline. The connection it makes is closed at once; the forward's
/// dial for it is left to `clear`, which is what the test is about.
Future<void> _waitUntilPortIsBound(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        port,
        timeout: const Duration(seconds: 1),
      );
      socket.destroy();
      return;
    } on SocketException {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }
  fail('Port forward did not reach its local bind stage');
}

Future<int> _freeLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _FixedServerNotifier extends ServerNotifier {
  _FixedServerNotifier(this._serverState);

  final ServerState _serverState;

  /// How many times SSH was asked for. Refused, as an sshd that is down is.
  int shellDials = 0;

  @override
  ServerState build(String serverId) => _serverState;

  /// The SSH session ending, as [ServerNotifier] reports it.
  void dropSession() => state = state.copyWith(client: null);

  @override
  Future<SSHClient> ensureShellClient({VoidCallback? onDial}) {
    shellDials++;
    if (_serverState.client case final client?) return Future.value(client);
    return Future.error(const SocketException('sshd is down'));
  }
}

/// Minimal [WebSocket] stub that delivers frames from [_incoming] and stalls
/// [close] on [_closeGate] to model a blackholed network link.
class _FakeControlWebSocket extends Stream<dynamic> implements WebSocket {
  _FakeControlWebSocket(this._incoming, this._closeGate);

  final StreamController<dynamic> _incoming;
  final Future<void> _closeGate;
  final List<dynamic> sent = [];
  var closeCalled = false;

  @override
  void add(dynamic data) => sent.add(data);

  @override
  Future<dynamic> close([int? code, String? reason]) {
    closeCalled = true;
    return _closeGate;
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _incoming.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Minimal [SshTunnelChannel] stub whose [close] stalls on [_closeGate].
class _FakeTunnelChannel implements SshTunnelChannel {
  _FakeTunnelChannel(this._closeGate);

  final Future<void> _closeGate;
  final _in = StreamController<Uint8List>.broadcast();
  final _out = StreamController<List<int>>.broadcast();
  var closeCalled = false;

  @override
  Stream<Uint8List> get stream => _in.stream;

  @override
  StreamSink<List<int>> get sink => _out.sink;

  @override
  Future<void> close() {
    closeCalled = true;
    return _closeGate;
  }

  Future<void> dispose() async {
    await _in.close();
    await _out.close();
  }
}
