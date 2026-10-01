import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/port_forward.dart';

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

    final socket = _IdleSshSocket();
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

      final socket = _IdleSshSocket();
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
          remoteAccess: const MonitorRemoteAccess(stream: true),
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
    ServerState agentLed(MonitorRemoteAccess? granted) => ServerState(
      spi: spiFixture(name: 'server', id: 's', ip: '127.0.0.1').copyWith(
        monitorHttp: const MonitorHttpCredential(addr: 'https://agent:3770'),
        preferredTransport: ServerTransport.monitorHttp,
      ),
      status: InitStatus.status,
      remoteAccess: granted,
    );

    test('an agent with full access off is told to turn it on', () {
      final reason = portForwardUnavailable(
        agentLed(MonitorRemoteAccess.none),
        listen: true,
      );
      expect(reason, contains('full_access'));
      expect(reason, isNot(l10n.portForwardRemoteNeedsAgent));
    });

    test('one that relays but cannot listen is told to update', () {
      expect(
        portForwardUnavailable(
          agentLed(
            const MonitorRemoteAccess(fullAccess: true, stream: true),
          ),
          listen: true,
        ),
        l10n.portForwardRemoteNeedsAgent,
      );
    });

    test('one that listens, or has not answered yet, is not held back', () {
      expect(
        portForwardUnavailable(
          agentLed(
            const MonitorRemoteAccess(
              fullAccess: true,
              stream: true,
              listen: true,
            ),
          ),
          listen: true,
        ),
        isNull,
      );
      expect(portForwardUnavailable(agentLed(null), listen: true), isNull);
    });
  });
}

/// Waits for the forward to take [port], which is what says it reached its
/// bind stage: binding it here stops working the moment it has.
///
/// Generous, because the deadline is not what the test is about. A second was
/// enough on a developer's machine and not on a loaded CI runner, where this
/// failed as "did not reach its local bind stage" — a real bind that was
/// simply late. The loop leaves as soon as the port is taken, so the only
/// thing a longer deadline costs is how long a genuine failure takes to
/// report.
Future<void> _waitUntilPortIsBound(int port) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    try {
      final socket = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
      );
      await socket.close();
    } on SocketException {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Port forward did not reach its local bind stage');
}

Future<int> _freeLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _IdleSshSocket implements SSHSocket {
  final _incoming = StreamController<Uint8List>();
  final _outgoing = StreamController<List<int>>();
  final _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> close() async {
    if (!_done.isCompleted) _done.complete();
    await _incoming.close();
    await _outgoing.close();
  }

  @override
  void destroy() {
    unawaited(close());
  }

  @override
  Future<void> flush() => Future.value();
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
