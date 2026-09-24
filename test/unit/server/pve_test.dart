import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/pve.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/pve.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';

/// The cluster listing both halves of this pair assert against: the Dart model
/// here, and `crates/sbm_parser/src/pve.rs` via `crates/sbm_parser/tests/
/// pve_compat.rs`. One file rather than two copies, so "the port agrees with
/// the implementation it replaces" is a claim about the same bytes.
String _clusterResources() =>
    File('test/fixtures/pve/cluster_resources.json').readAsStringSync();

void main() {
  test('parse pve', () {
    final list = json.decode(_clusterResources())['data'] as List;
    final pveItems = list.map((e) => PveResIface.fromJson(e)).toList();
    expect(pveItems.length, 8);
  });

  group('expired PVE sessions', () {
    const spi = Spi(
      name: 'pve',
      id: 'pve-id',
      custom: ServerCustom(pveAddr: 'https://pve.example.com:8006'),
    );

    ({
      ProviderContainer container,
      PveNotifier notifier,
      _StatusAdapter adapter,
      void Function() close,
    })
    harness(int statusCode) {
      final pve = _TestPveNotifier();
      final container = ProviderContainer(
        overrides: [
          pveProvider(spi).overrideWith(() => pve),
          serverProvider(
            spi.id,
          ).overrideWithValue(ServerState(spi: spi, status: InitStatus.status)),
        ],
      );
      final provider = pveProvider(spi);
      final subscription = container.listen(provider, (_, _) {});
      final notifier = container.read(provider.notifier) as _TestPveNotifier;
      final adapter = _StatusAdapter(statusCode);
      final dio = Dio()..httpClientAdapter = adapter;
      notifier.useSession(dio);
      return (
        container: container,
        notifier: notifier,
        adapter: adapter,
        close: () {
          subscription.close();
          container.dispose();
        },
      );
    }

    test('resource listing drops a session after HTTP 401', () async {
      final test = harness(401);
      try {
        await test.notifier.list();

        expect(test.notifier.state.isConnected, isFalse);
        expect(test.notifier.state.error?.type, PveErrType.loginFailed);
        expect(test.adapter.closed, isTrue);
      } finally {
        test.close();
      }
    });

    test('VM control drops a session after HTTP 403', () async {
      final test = harness(403);
      try {
        await expectLater(
          test.notifier.start('node', '100'),
          throwsA(isA<DioException>()),
        );

        expect(test.notifier.state.isConnected, isFalse);
        expect(test.notifier.state.error?.type, PveErrType.loginFailed);
        expect(test.adapter.closed, isTrue);
      } finally {
        test.close();
      }
    });
  });

  test('a client replacement reconnects after the stale init exits', () async {
    const spi = Spi(
      name: 'pve',
      id: 'pve-reconnect-id',
      custom: ServerCustom(pveAddr: 'https://pve.example.com:8006'),
    );
    final firstSocket = _IdleSshSocket();
    final secondSocket = _IdleSshSocket();
    final firstClient = SSHClient(firstSocket, username: 'first');
    final secondClient = SSHClient(secondSocket, username: 'second');
    final initial = ServerState(
      spi: spi,
      status: InitStatus.status,
      client: firstClient,
    );
    final container = ProviderContainer(
      overrides: [
        pveProvider(spi).overrideWith(() => _TestPveNotifier()),
        serverProvider(
          spi.id,
        ).overrideWith(() => _MutableServerNotifier(initial)),
      ],
    );
    final provider = pveProvider(spi);
    final subscription = container.listen(provider, (_, _) {});
    final notifier = container.read(provider.notifier) as _TestPveNotifier;
    final server =
        container.read(serverProvider(spi.id).notifier)
            as _MutableServerNotifier;
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    final secondStarted = Completer<void>();
    final releaseSecond = Completer<void>();
    var starts = 0;
    notifier.forwardAction = () async {
      starts++;
      if (starts == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      } else {
        secondStarted.complete();
        await releaseSecond.future;
      }
    };

    try {
      await firstStarted.future.timeout(const Duration(seconds: 2));
      server.replaceClient(secondClient);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(starts, 1, reason: 'the replacement must not overlap stale init');

      releaseFirst.complete();
      await secondStarted.future.timeout(const Duration(seconds: 2));
      expect(starts, 2);
    } finally {
      subscription.close();
      container.dispose();
      if (!releaseFirst.isCompleted) releaseFirst.complete();
      if (!releaseSecond.isCompleted) releaseSecond.complete();
      firstClient.close();
      secondClient.close();
      firstSocket.destroy();
      secondSocket.destroy();
    }
  });
}

class _TestPveNotifier extends PveNotifier {
  Future<void> Function()? forwardAction;

  void useSession(Dio session) {
    adoptSession(session);
    state = state.copyWith(
      error: null,
      isConnected: true,
      isBusy: false,
      loadingStep: PveLoadingStep.none,
    );
  }

  @override
  Future<void> forward(int generation) async {
    final action = forwardAction;
    if (action != null) return action();
    return super.forward(generation);
  }
}

class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.statusCode);

  final int statusCode;
  bool closed = false;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('denied', statusCode);
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _MutableServerNotifier extends ServerNotifier {
  _MutableServerNotifier(this.initial);

  final ServerState initial;

  @override
  ServerState build(String serverId) => initial;

  void replaceClient(SSHClient client) {
    state = state.copyWith(client: client);
  }
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
