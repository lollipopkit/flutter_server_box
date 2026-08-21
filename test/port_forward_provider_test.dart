import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/provider/port_forward_provider.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/port_forward.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  test('clear closes a forward that finishes starting during deletion', () async {
    await openTestDb();
    final store = PortForwardStore.forTest();
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
        serverProvider(serverId).overrideWith(
          () => _FixedServerNotifier(serverState),
        ),
      ],
    );
    try {
      final notifier = container.read(portForwardProvider(serverId).notifier);

      final start = notifier.startForward(config.id);
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
      await SqliteDb.close();
    }
  });
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

  @override
  ServerState build(String serverId) => _serverState;
}
