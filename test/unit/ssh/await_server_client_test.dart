/// A terminal restored at launch shares the status poller's connection while
/// that connection is still being made, rather than dialling a second one that
/// sshd may refuse ("Not allowed at this time").
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/await_client.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

import '../../helpers/spi_fixture.dart';

const _id = 'box';

void main() {
  late ProviderContainer container;
  late _Server server;

  ServerState state({SSHClient? client, required ServerConn conn}) =>
      ServerState(
        spi: spiFixture(name: 'box', id: _id, ip: '127.0.0.1'),
        status: InitStatus.status,
        client: client,
        conn: conn,
      );

  void start(ServerState initial) {
    server = _Server(initial);
    container = ProviderContainer(
      overrides: [serverProvider(_id).overrideWith(() => server)],
    );
    addTearDown(container.dispose);
  }

  Future<SSHClient?> wait({Duration? timeout}) => awaitServerClient(
    container.read(serverProvider(_id)),
    listen: (listener) => container.listen(serverProvider(_id), listener),
    timeout: timeout ?? const Duration(seconds: 20),
  );

  test('waits for the connection being made, and shares it', () async {
    start(state(conn: ServerConn.connecting));
    final shared = wait();
    final client = SSHClient(_IdleSocket(), username: 'test');
    addTearDown(client.close);

    server.set(state(client: client, conn: ServerConn.connecting));
    expect(await shared, same(client));
  });

  test('an open connection is shared at once', () async {
    final client = SSHClient(_IdleSocket(), username: 'test');
    addTearDown(client.close);
    start(state(client: client, conn: ServerConn.finished));
    expect(await wait(), same(client));
  });

  test('nothing to wait for when nothing is being made', () async {
    start(state(conn: ServerConn.disconnected));
    expect(await wait(), isNull);
  });

  test('a connect that fails leaves the caller to dial', () async {
    start(state(conn: ServerConn.connecting));
    final shared = wait();
    server.set(state(conn: ServerConn.failed));
    expect(await shared, isNull);
  });

  test('gives up after the timeout', () async {
    start(state(conn: ServerConn.connecting));
    expect(await wait(timeout: const Duration(milliseconds: 10)), isNull);
  });
}

class _Server extends ServerNotifier {
  _Server(this._initial);

  final ServerState _initial;

  @override
  ServerState build(String serverId) => _initial;

  void set(ServerState next) => state = next;
}

/// A socket nothing is said on: enough for an [SSHClient] that is not closed.
class _IdleSocket implements SSHSocket {
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
  void destroy() => unawaited(close());

  @override
  Future<void> flush() async {}
}
