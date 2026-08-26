import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

import 'helpers/spi_fixture.dart';

/// The watch app parses this payload (`PhoneConnMgr.parse`) and has no way to
/// ask for a correction, so its shape is the contract between two processes on
/// two devices that update independently.
void main() {
  const addr = 'https://10.0.0.1:3770';

  /// A fixed point to measure expiry against, so these never depend on when
  /// they run.
  final now = DateTime.utc(2026, 8, 26, 12);

  int inDays(int days) =>
      now.add(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;

  /// A token that is comfortably in date for [endpoint].
  ScopedToken tok(String token, {String endpoint = addr}) => ScopedToken(
    token: token,
    endpoint: endpoint,
    expiresAt: inDays(90),
  );

  Spi monitorSpi({
    required String id,
    required String name,
    String addr = addr,
    String? user = 'admin',
    String? pwd = 'secret',
    bool ignoreCert = false,
  }) {
    return spiFixture(name: name, id: id).copyWith(
      monitorHttp: MonitorHttpCredential(
        addr: addr,
        user: user,
        pwd: pwd,
        ignoreCert: ignoreCert,
      ),
    );
  }

  Map<String, dynamic> payload({
    required List<String> selectedIds,
    List<Spi> servers = const [],
    Map<String, ScopedToken> tokens = const {},
    int stamp = 1,
  }) {
    return WatchSync.payloadFrom(
      selectedIds: selectedIds,
      lookup: (id) => servers.where((e) => e.id == id).firstOrNull,
      tokens: tokens,
      stamp: stamp,
    );
  }

  Map<String, ScopedToken> reusable({
    required List<String> serverIds,
    required List<Spi> servers,
    required Map<String, ScopedToken> existing,
  }) {
    return reusableScopedTokens(
      serverIds: serverIds,
      lookup: (id) => servers.where((e) => e.id == id).firstOrNull,
      existing: existing,
      now: now,
    );
  }

  group('the payload the watch is handed', () {
    test('carries what it needs to reach the agent', () {
      final result = payload(
        selectedIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'Home', ignoreCert: true)],
        tokens: {'a': tok('watch-token')},
      );

      expect(result['v'], 3);
      expect(result['servers'], [
        {
          'id': 'a',
          'name': 'Home',
          'addr': addr,
          'token': 'watch-token',
          'expiresAt': inDays(90),
          'ignoreCert': true,
        },
      ]);
      final server = (result['servers'] as List).single as Map;
      expect(server.containsKey('user'), isFalse);
      expect(server.containsKey('pwd'), isFalse);
    });

    test('keeps the selection order, which is the order of the pages', () {
      final result = payload(
        selectedIds: ['c', 'a', 'b'],
        servers: [
          monitorSpi(id: 'a', name: 'A'),
          monitorSpi(id: 'b', name: 'B'),
          monitorSpi(id: 'c', name: 'C'),
        ],
        tokens: {'a': tok('a-token'), 'b': tok('b-token'), 'c': tok('c-token')},
      );

      final names = (result['servers'] as List).map((e) => e['name']).toList();
      expect(names, ['C', 'A', 'B']);
    });

    test('drops a picked server that no longer exists', () {
      final result = payload(
        selectedIds: ['gone', 'a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        tokens: {'a': tok('a-token')},
      );

      expect((result['servers'] as List).single['id'], 'a');
    });

    test('drops a picked server that lost its monitor config', () {
      // The watch has no SSH client, so an SSH-only server is an entry it could
      // never load — worse than not being listed at all.
      final result = payload(
        selectedIds: ['ssh', 'a'],
        servers: [
          spiFixture(name: 'SSH only', id: 'ssh', ip: '10.0.0.9'),
          monitorSpi(id: 'a', name: 'A'),
        ],
        tokens: {'a': tok('a-token'), 'ssh': tok('ssh-token')},
      );

      expect((result['servers'] as List).single['id'], 'a');
    });

    test('drops a server whose monitor address is blank', () {
      final result = payload(
        selectedIds: ['blank'],
        servers: [monitorSpi(id: 'blank', name: 'Blank', addr: '   ')],
        tokens: {'blank': tok('blank-token')},
      );

      expect(result['servers'], isEmpty);
    });

    test('drops a server when no scoped token could be issued', () {
      final result = payload(
        selectedIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A', user: '', pwd: '')],
      );

      expect(result['servers'], isEmpty);
    });

    test('trims the address so the watch can append paths to it', () {
      final result = payload(
        selectedIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A', addr: '  $addr ')],
        tokens: {'a': tok('a-token')},
      );

      expect((result['servers'] as List).single['addr'], addr);
    });

    test('no longer carries the pre-v2 url list', () {
      // It named the agent's Go-compat endpoint, which the agent answers 410
      // on. Emitting it would give an un-updated watch something that fails a
      // moment later instead of a list that is honestly empty.
      final result = payload(selectedIds: const []);

      expect(result.containsKey('urls'), isFalse);
      expect(result['servers'], isEmpty);
    });

    test('carries the stamp the watch orders deliveries by', () {
      // WatchConnectivity orders nothing between a queued userInfo, the
      // application context and a reply to `requestData`, so the watch drops a
      // payload older than the one it has already applied. Without this it can
      // only be told what arrived last, which is not the same as current.
      final result = payload(selectedIds: const [], stamp: 1737000000000);

      expect(result['ts'], 1737000000000);
    });
  });

  group('deciding which tokens survive a rebuild', () {
    test('reuses one only for the endpoint that issued it', () {
      // A token is meaningful against one agent. Point the server somewhere
      // else and the held credential is not stale, it is the wrong agent's.
      final servers = [
        monitorSpi(id: 'same', name: 'Same', addr: 'https://host:3770/'),
        monitorSpi(id: 'changed', name: 'Changed', addr: 'https://new:3770'),
      ];

      final result = reusable(
        serverIds: ['same', 'changed'],
        servers: servers,
        existing: {
          'same': tok('same-token', endpoint: 'https://host:3770'),
          'changed': tok('old-token', endpoint: 'https://old:3770'),
        },
      );

      expect(result.keys, ['same']);
      expect(result['same']!.token, 'same-token');
    });

    test('a trailing slash is the same endpoint', () {
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A', addr: '$addr/')],
        existing: {'a': tok('a-token')},
      );

      expect(result.keys, ['a']);
    });

    test('replaces one close enough to expiry to lapse before the next push', () {
      // The agent issues these for 90 days and this app only rebuilds the set
      // when something asks it to — a launch, a server edit, a watch
      // reconnecting. Holding a token to its last day means the first of those
      // to fall on the wrong side leaves the watch answering 401, on a device
      // with nothing to report it to and no way to renew for itself.
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        existing: {
          'a': ScopedToken(
            token: 'nearly-done',
            endpoint: addr,
            expiresAt: inDays(13),
          ),
        },
      );

      expect(result, isEmpty);
    });

    test('keeps one still comfortably in date', () {
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        existing: {
          'a': ScopedToken(
            token: 'plenty-left',
            endpoint: addr,
            expiresAt: inDays(15),
          ),
        },
      );

      expect(result.keys, ['a']);
    });

    test('replaces one already expired', () {
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        existing: {
          'a': ScopedToken(
            token: 'gone',
            endpoint: addr,
            expiresAt: inDays(-1),
          ),
        },
      );

      expect(result, isEmpty);
    });

    test('replaces one whose expiry was never recorded', () {
      // What every install carries today: the agent has always answered with
      // `expires_at` and this app threw it away, so the held token had no
      // deadline attached and was reused forever. Treating "unknown" as due
      // is what gets such an install onto a known expiry, at the cost of one
      // request per server, once.
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        existing: {
          'a': const ScopedToken(token: 'undated', endpoint: addr),
        },
      );

      expect(result, isEmpty);
    });

    test('has nothing to reuse for a server that lost its monitor', () {
      final result = reusable(
        serverIds: ['ssh'],
        servers: [spiFixture(name: 'SSH only', id: 'ssh', ip: '10.0.0.9')],
        existing: {'ssh': tok('ssh-token')},
      );

      expect(result, isEmpty);
    });

    test('an empty token is never reusable', () {
      final result = reusable(
        serverIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'A')],
        existing: {'a': tok('')},
      );

      expect(result, isEmpty);
    });
  });

  group('the revision snapshots are stamped with', () {
    test('never repeats, even called faster than the clock moves', () {
      // The watch treats an equal revision as already seen, so two snapshots
      // sharing one would silently drop the second. A thousand in a row take
      // well under a millisecond.
      final seen = [for (var i = 0; i < 1000; i++) WatchSync.nextRevision()];

      expect(seen.toSet().length, seen.length);
    });

    test('increases, so a later snapshot always outranks an earlier one', () {
      // Which is the whole point: the payload built from the newer selection
      // has to win regardless of which one finishes its token requests first.
      final first = WatchSync.nextRevision();
      final second = WatchSync.nextRevision();
      final third = WatchSync.nextRevision();

      expect(second, greaterThan(first));
      expect(third, greaterThan(second));
    });

    test('starts from the clock, so a restart does not look like the past', () {
      // A counter from zero would be older than everything the watch had
      // already applied, and every payload after a relaunch would be dropped.
      final before = DateTime.now().millisecondsSinceEpoch;

      expect(WatchSync.nextRevision(), greaterThanOrEqualTo(before));
    });
  });

  group('the client id a token is scoped to', () {
    test('names the server, so one can be revoked without the others', () {
      expect(WatchSync.watchClientId('abc'), 'watch:abc');
    });
  });
}
