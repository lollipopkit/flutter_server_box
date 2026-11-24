import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/scoped_token.dart';
import 'package:server_box/core/service/watch_sync.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

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
    String? fallbackAddr,
    String? pwd = 'secret',
    String? certSha256,
    bool allowInsecure = false,
  }) {
    return spiFixture(name: name, id: id).copyWith(
      monitorHttp: MonitorHttpCredential(
        addr: addr,
        fallbackAddr: fallbackAddr,
        pwd: pwd,
        certSha256: certSha256,
        allowInsecure: allowInsecure,
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
    test('carries the plaintext opt-in, which the watch checks before sending '
        'the token', () {
      final result = payload(
        selectedIds: ['a', 'b'],
        servers: [
          monitorSpi(id: 'a', name: 'Plain', addr: 'http://10.0.0.9:3770',
              allowInsecure: true),
          monitorSpi(id: 'b', name: 'Default', addr: 'http://10.0.0.8:3770'),
        ],
        tokens: {'a': tok('t-a', endpoint: 'http://10.0.0.9:3770'),
                 'b': tok('t-b', endpoint: 'http://10.0.0.8:3770')},
      );

      final servers = (result['servers'] as List).cast<Map<String, Object?>>();
      expect(servers.map((e) => e['allowInsecure']), [true, false]);
    });

    test('carries what it needs to reach the agent', () {
      final result = payload(
        selectedIds: ['a'],
        servers: [monitorSpi(id: 'a', name: 'Home', certSha256: 'abababababababababababababababababababababababababababababababab')],
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
          'certSha256': 'abababababababababababababababababababababababababababababababab',
          'allowInsecure': false,
        },
      ]);
      final server = (result['servers'] as List).single as Map;
      expect(server.containsKey('user'), isFalse);
      expect(server.containsKey('pwd'), isFalse);
    });

    test('carries the fallback, and leaves the key out when there is none', () {
      final result = payload(
        selectedIds: ['a', 'b'],
        servers: [
          monitorSpi(id: 'a', name: 'Two', fallbackAddr: ' https://100.64.0.1:3770 '),
          monitorSpi(id: 'b', name: 'One'),
        ],
        tokens: {'a': tok('t-a'), 'b': tok('t-b')},
      );

      final servers = (result['servers'] as List).cast<Map<String, Object?>>();
      expect(servers.first['fallbackAddr'], 'https://100.64.0.1:3770');
      expect(servers.last.containsKey('fallbackAddr'), isFalse);
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
        servers: [monitorSpi(id: 'a', name: 'A', pwd: '')],
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

  group('per-server revoke/issue coordination', () {
    setUp(() async {
      await openTestDb();
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
      getIt.registerSingleton<ServerStore>(ServerStore());
    });

    tearDown(() async {
      await getIt.reset();
      await closeTestDb();
    });

    List<Map<String, dynamic>> payloadServers(Map<String, dynamic> p) =>
        ((p['servers'] as List?) ?? const []).cast<Map<String, dynamic>>();

    for (final firstSucceeds in [true, false]) {
      test('a stale DELETE result (success=$firstSucceeds) leaves the new '
          'request its own attempts', () async {
        final server = monitorSpi(id: 'a', name: 'Alpha');
        Stores.server.put(server);
        final first = Completer<void>();
        final lastAttempt = Completer<void>();
        var attempts = 0;
        final sync = WatchSync.forTest(
          readContext: () async => null,
          writeContext: (_) async {},
          issueToken: (_, _) async => tok('unexpected'),
          revokeToken: (_, _) {
            attempts++;
            if (attempts == 1) return first.future;
            if (attempts == 4) lastAttempt.complete();
            return Future.error(StateError('monitor unreachable'));
          },
        );
        addTearDown(sync.dispose);

        await sync.updateExclusions(['a']);
        expect(attempts, 1);
        sync.revokeEditedServer(server);
        if (firstSucceeds) {
          first.complete();
        } else {
          first.completeError(StateError('stale failure'));
        }
        await lastAttempt.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);

        expect(attempts, 4);
        expect(sync.hasPendingRevokeFor('a'), isFalse);
      });
    }

    test('an exclusion during a backstop DELETE prevents a replacement mint',
        () async {
      final original = monitorSpi(id: 'a', name: 'Alpha');
      final moved = monitorSpi(
        id: 'a',
        name: 'Alpha',
        addr: 'https://10.0.0.2:3770',
      );
      Stores.server.put(original);
      final releaseBackstop = Completer<void>();
      final attempts = <String>[];
      var issueCalls = 0;
      final sync = WatchSync.forTest(
        now: () => now,
        readContext: () async => payload(
          selectedIds: ['a'],
          servers: [original],
          tokens: {'a': tok('original')},
        ),
        writeContext: (_) async {},
        issueToken: (_, endpoint) async {
          issueCalls++;
          return tok('unexpected', endpoint: endpoint);
        },
        revokeToken: (spi, endpoint) async {
          attempts.add(endpoint ?? spi.monitor!.addr);
          if (attempts.length == 1) await releaseBackstop.future;
        },
      );
      addTearDown(sync.dispose);

      expect(payloadServers(await sync.buildPayload()).single['token'], 'original');
      Stores.server.put(moved);
      expect(payloadServers(await sync.buildPayload()), isEmpty);
      expect(attempts, [addr]);
      await sync.updateExclusions(['a']);
      releaseBackstop.complete();
      await Future<void>.delayed(Duration.zero);

      expect(attempts, [addr, moved.monitor!.addr]);
      expect(issueCalls, 0);
    });

    test('a discarded mint revokes its endpoint alongside a different edit '
        'revoke after the monitor is removed', () async {
      final original = monitorSpi(id: 'a', name: 'Alpha', pwd: 'first');
      final moved = monitorSpi(
        id: 'a',
        name: 'Alpha',
        addr: 'https://10.0.0.2:3770',
        pwd: 'second',
      );
      Stores.server.put(original);
      final mint = Completer<ScopedToken>();
      final revokes = <(String, String?)>[];
      var issueCalls = 0;
      final sync = WatchSync.forTest(
        now: () => now,
        readContext: () async => null,
        writeContext: (_) async {},
        issueToken: (_, _) {
          issueCalls++;
          return mint.future;
        },
        revokeToken: (spi, endpoint) async {
          revokes.add((endpoint ?? spi.monitor!.addr, spi.monitor!.pwd));
        },
      );
      addTearDown(sync.dispose);

      expect(payloadServers(await sync.buildPayload()), isEmpty);
      expect(issueCalls, 1);
      Stores.server.put(spiFixture(id: 'a', name: 'Alpha', ip: '10.0.0.2'));
      sync.revokeEditedServer(moved);
      expect(sync.hasPendingRevokeFor('a'), isTrue);
      expect(payloadServers(await sync.buildPayload()), isEmpty);
      mint.complete(tok('stale'));
      await Future<void>.delayed(Duration.zero);

      expect(revokes, [(moved.monitor!.addr, 'second'), (addr, 'first')]);
      expect(issueCalls, 1);
      expect(sync.hasPendingRevokeFor('a'), isFalse);
    });

    testWidgets('a retry timer at the credential deadline sends no DELETE',
        (tester) async {
      final server = monitorSpi(id: 'a', name: 'Alpha');
      Stores.server.put(server);
      var currentTime = now;
      var attempts = 0;
      final sync = WatchSync.forTest(
        now: () => currentTime,
        readContext: () async => null,
        writeContext: (_) async {},
        issueToken: (_, _) async => tok('unexpected'),
        revokeToken: (_, _) async {
          attempts++;
          throw StateError('monitor unreachable');
        },
        revokeRetryDelay: const Duration(seconds: 3),
        revokeCredentialTtl: const Duration(seconds: 5),
      );
      addTearDown(sync.dispose);

      await sync.updateExclusions(['a']);
      await tester.pump();
      expect(attempts, 1);
      currentTime = now.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(attempts, 2);
      currentTime = now.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
      expect(attempts, 2);
      expect(sync.hasPendingRevokeFor('a'), isFalse);
    });

    test('a mint without an expiry does not schedule another mint', () async {
      Stores.server.put(monitorSpi(id: 'a', name: 'Alpha'));
      var issueCalls = 0;
      final writes = <Map<String, dynamic>>[];
      final sync = WatchSync.forTest(
        now: () => now,
        readContext: () async => null,
        writeContext: (payload) async => writes.add(payload),
        issueToken: (_, endpoint) async {
          issueCalls++;
          if (issueCalls > 1) throw StateError('unexpected second mint');
          return ScopedToken(token: 'no-expiry', endpoint: endpoint);
        },
        revokeToken: (_, _) async {},
      );
      addTearDown(sync.dispose);

      await sync.push();
      await Future<void>.delayed(Duration.zero);

      expect(issueCalls, 1);
      expect(payloadServers(writes.single), isEmpty);
    });

    test(
      're-including a server while its revoke is in flight never reuses the '
      'old token, issues only after revoke settles, and does not block others',
      () async {
        final serverA = monitorSpi(
          id: 'a',
          name: 'Alpha',
          addr: 'https://10.0.0.1:3770',
        );
        final serverB = monitorSpi(
          id: 'b',
          name: 'Beta',
          addr: 'https://10.0.0.2:3770',
        );
        Stores.server.put(serverA);
        Stores.server.put(serverB);

        final futureExpiry =
            DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
        Map<String, dynamic>? context = {
          'v': 3,
          'rev': 1,
          'servers': [
            {
              'id': 'a',
              'name': 'Alpha',
              'addr': 'https://10.0.0.1:3770',
              'token': 'tok-a-old',
              'expiresAt': futureExpiry,
            },
            {
              'id': 'b',
              'name': 'Beta',
              'addr': 'https://10.0.0.2:3770',
              'token': 'tok-b-old',
              'expiresAt': futureExpiry,
            },
          ],
        };

        final events = <String>[];
        final revokeAStarted = Completer<void>();
        final releaseRevokeA = Completer<void>();
        final deliveredNewA = Completer<Map<String, dynamic>>();
        final deliveredPayloads = <Map<String, dynamic>>[];
        var issuedForA = 0;

        final sync = WatchSync.forTest(
          readContext: () async => context,
          writeContext: (payload) async {
            context = payload;
            deliveredPayloads.add(payload);
            final aRow = payloadServers(payload)
                .where((e) => e['id'] == 'a')
                .firstOrNull;
            if (aRow?['token'] == 'tok-a-new' && !deliveredNewA.isCompleted) {
              deliveredNewA.complete(payload);
            }
          },
          issueToken: (spi, endpoint) async {
            events.add('issue:${spi.id}');
            if (spi.id == 'a') issuedForA++;
            return ScopedToken(
              token: 'tok-${spi.id}-new',
              endpoint: endpoint,
              expiresAt: futureExpiry,
            );
          },
          revokeToken: (spi, endpoint) async {
            events.add('revoke-start:${spi.id}');
            if (spi.id == 'a') {
              if (!revokeAStarted.isCompleted) revokeAStarted.complete();
              await releaseRevokeA.future;
            }
            events.add('revoke-done:${spi.id}');
          },
        );
        addTearDown(sync.dispose);

        // 1. Exclude A: persisted immediately, revoke starts in background.
        await sync.updateExclusions(['a']);
        expect(Stores.setting.watchExcludedServerIds.fetch(), ['a']);
        await revokeAStarted.future.timeout(const Duration(seconds: 2));

        // 2. Re-include A while its revoke is still suspended.
        await sync.updateExclusions([]);
        expect(Stores.setting.watchExcludedServerIds.fetch(), isEmpty);

        // 3. Trigger both normal push and watch `requestData` while A's revoke
        // is still in flight.
        await sync.push().timeout(const Duration(seconds: 2));
        final onAsk = await sync
            .handleWatchMessage({'action': 'requestData'})
            .timeout(const Duration(seconds: 2));

        // Old token for A must never be republished, A must not be issued yet,
        // and B must continue to be delivered without waiting on A.
        for (final p in [...deliveredPayloads, onAsk]) {
          final rows = payloadServers(p);
          expect(
            rows.where((e) => e['token'] == 'tok-a-old'),
            isEmpty,
            reason: 'revoking/revoked token must not be reused from context',
          );
          expect(
            rows.where((e) => e['id'] == 'b').single['token'],
            'tok-b-old',
          );
        }
        expect(issuedForA, 0);

        // 4. Release A's revoke: follow-up push now mints and delivers tok-a-new.
        releaseRevokeA.complete();
        final finalPayload = await deliveredNewA.future.timeout(
          const Duration(seconds: 2),
        );

        expect(issuedForA, 1);
        expect(
          events.indexOf('revoke-done:a'),
          lessThan(events.indexOf('issue:a')),
        );
        final finalA = payloadServers(finalPayload)
            .where((e) => e['id'] == 'a')
            .single;
        expect(finalA['token'], 'tok-a-new');
        expect(
          finalPayload['ts'] as int,
          greaterThan(onAsk['ts'] as int),
        );
      },
    );

    test(
      'a server that remains excluded is never re-issued after revoke finishes',
      () async {
        final serverA = monitorSpi(
          id: 'a',
          name: 'Alpha',
          addr: 'https://10.0.0.1:3770',
        );
        Stores.server.put(serverA);

        final futureExpiry =
            DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
        Map<String, dynamic>? context = {
          'v': 3,
          'rev': 1,
          'servers': [
            {
              'id': 'a',
              'name': 'Alpha',
              'addr': 'https://10.0.0.1:3770',
              'token': 'tok-a-old',
              'expiresAt': futureExpiry,
            },
          ],
        };

        final revokeAStarted = Completer<void>();
        final releaseRevokeA = Completer<void>();
        final postRevokeWrite = Completer<Map<String, dynamic>>();
        var revoked = false;
        var issuedForA = 0;

        final sync = WatchSync.forTest(
          readContext: () async => context,
          writeContext: (payload) async {
            context = payload;
            if (revoked && !postRevokeWrite.isCompleted) {
              postRevokeWrite.complete(payload);
            }
          },
          issueToken: (spi, endpoint) async {
            if (spi.id == 'a') issuedForA++;
            return ScopedToken(
              token: 'tok-a-unexpected',
              endpoint: endpoint,
              expiresAt: futureExpiry,
            );
          },
          revokeToken: (spi, endpoint) async {
            if (!revokeAStarted.isCompleted) revokeAStarted.complete();
            await releaseRevokeA.future;
            revoked = true;
          },
        );
        addTearDown(sync.dispose);

        await sync.updateExclusions(['a']);
        await revokeAStarted.future.timeout(const Duration(seconds: 2));

        releaseRevokeA.complete();
        final delivered = await postRevokeWrite.future.timeout(
          const Duration(seconds: 2),
        );

        expect(issuedForA, 0);
        expect(payloadServers(delivered), isEmpty);
      },
    );

    test(
      'an offline monitor minting slowly does not block publishing other servers',
      () async {
        final serverA = monitorSpi(
          id: 'a',
          name: 'Alpha',
          addr: 'https://10.0.0.1:3770',
        );
        final serverB = monitorSpi(
          id: 'b',
          name: 'Beta',
          addr: 'https://10.0.0.2:3770',
        );
        Stores.server.put(serverA);
        Stores.server.put(serverB);

        final futureExpiry =
            DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
        Map<String, dynamic>? context;

        final issueAStarted = Completer<void>();
        final releaseIssueA = Completer<void>();
        final deliveredB = Completer<Map<String, dynamic>>();
        final deliveredBoth = Completer<Map<String, dynamic>>();

        final sync = WatchSync.forTest(
          readContext: () async => context,
          writeContext: (payload) async {
            context = payload;
            final ids = payloadServers(payload).map((e) => e['id']).toSet();
            if (ids.contains('b') && !deliveredB.isCompleted) {
              deliveredB.complete(payload);
            }
            if (ids.containsAll({'a', 'b'}) && !deliveredBoth.isCompleted) {
              deliveredBoth.complete(payload);
            }
          },
          issueToken: (spi, endpoint) async {
            if (spi.id == 'a') {
              if (!issueAStarted.isCompleted) issueAStarted.complete();
              await releaseIssueA.future;
            }
            return ScopedToken(
              token: 'tok-${spi.id}-new',
              endpoint: endpoint,
              expiresAt: futureExpiry,
            );
          },
          revokeToken: (_, _) async {},
        );
        addTearDown(sync.dispose);

        await sync.push().timeout(const Duration(seconds: 2));
        await issueAStarted.future.timeout(const Duration(seconds: 2));

        // B is minted and delivered while A is still stuck.
        final payloadWithB = await deliveredB.future.timeout(
          const Duration(seconds: 2),
        );
        expect(payloadServers(payloadWithB).map((e) => e['id']), ['b']);

        // Once A finishes, a follow-up push delivers both.
        releaseIssueA.complete();
        final finalPayload = await deliveredBoth.future.timeout(
          const Duration(seconds: 2),
        );
        expect(payloadServers(finalPayload).map((e) => e['id']), ['a', 'b']);
      },
    );

    test(
      'concurrent push and requestData share one in-flight slot mint per server',
      () async {
        final serverA = monitorSpi(
          id: 'a',
          name: 'Alpha',
          addr: 'https://10.0.0.1:3770',
        );
        final serverB = monitorSpi(id: 'b', name: 'Beta');
        Stores.server.put(serverA);
        Stores.server.put(serverB);

        final futureExpiry =
            DateTime.now().add(const Duration(days: 60)).millisecondsSinceEpoch ~/
            1000;
        Map<String, dynamic>? context = payload(
          selectedIds: ['b'],
          servers: [serverB],
          tokens: {
            'b': ScopedToken(
              token: 'tok-b-reused',
              endpoint: addr,
              expiresAt: futureExpiry,
            ),
          },
        );

        final issueStarted = Completer<String>();
        final releaseIssueA = Completer<void>();
        final deliveredA = Completer<Map<String, dynamic>>();
        var issueCalls = 0;

        final sync = WatchSync.forTest(
          readContext: () async => context,
          writeContext: (payload) async {
            context = payload;
            if (payloadServers(payload).any((e) => e['id'] == 'a') &&
                !deliveredA.isCompleted) {
              deliveredA.complete(payload);
            }
          },
          issueToken: (spi, endpoint) async {
            issueCalls++;
            if (!issueStarted.isCompleted) issueStarted.complete(spi.id);
            await releaseIssueA.future;
            return ScopedToken(
              token: 'tok-a-$issueCalls',
              endpoint: endpoint,
              expiresAt: futureExpiry,
            );
          },
          revokeToken: (_, _) async {},
        );
        addTearDown(sync.dispose);

        await sync.push().timeout(const Duration(seconds: 2));
        expect(
          await issueStarted.future.timeout(const Duration(seconds: 2)),
          'a',
        );
        expect(issueCalls, 1);

        // Watch asks for data while A's slot is mid-mint: the reply waits for
        // that mint and does not start a second one.
        final replying = sync.handleWatchMessage({'action': 'requestData'});
        await Future<void>.delayed(Duration.zero);
        expect(issueCalls, 1);

        releaseIssueA.complete();
        final reply = await replying.timeout(const Duration(seconds: 2));
        expect(
          {for (final e in payloadServers(reply)) e['id']: e['token']},
          {'a': 'tok-a-1', 'b': 'tok-b-reused'},
        );
        final delivered = await deliveredA.future.timeout(
          const Duration(seconds: 2),
        );

        expect(issueCalls, 1);
        expect(payloadServers(delivered).first['token'], 'tok-a-1');
      },
    );

    test(
      'failed revoke retries bounded times then drops the pre-deletion Spi '
      'snapshot so old credentials are not retained indefinitely',
      () async {
        final doomed = monitorSpi(
          id: 'doomed',
          name: 'Doomed',
          addr: 'https://10.0.0.9:3770',
          pwd: 'old-password',
        );
        Stores.server.put(doomed);

        var attempts = 0;
        var issueCalls = 0;
        final doneRetrying = Completer<void>();
        final seenPwds = <String?>[];

        final sync = WatchSync.forTest(
          readContext: () async => null,
          writeContext: (_) async {},
          issueToken: (_, _) async {
            issueCalls++;
            throw StateError('must not mint');
          },
          revokeToken: (spi, _) async {
            attempts++;
            seenPwds.add(spi.monitor?.pwd);
            if (attempts == 3 && !doneRetrying.isCompleted) {
              doneRetrying.complete();
            }
            throw StateError('monitor unreachable');
          },
          revokeRetryDelay: Duration.zero,
        );
        addTearDown(sync.dispose);

        // Keep the row present through the final attempt, as local cleanup may
        // outlast revocation.
        await sync.revokeServer(doomed);

        // Initial attempt + 2 retries = 3 total attempts, all using old Spi.
        await doneRetrying.future.timeout(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);

        expect(attempts, 3);
        expect(issueCalls, 0);
        expect(seenPwds, ['old-password', 'old-password', 'old-password']);
        expect(sync.hasPendingRevokeFor(doomed.id), isFalse);
        Stores.server.deleteById(doomed.id);
        sync.finishServerDeletion(doomed.id);
      },
    );

    test('a reply to the watch stops waiting for a mint that never ends',
        () async {
      Stores.server.put(monitorSpi(id: 'a', name: 'Alpha'));
      Stores.server.put(
        monitorSpi(id: 'b', name: 'Beta', addr: 'https://10.0.0.2:3770'),
      );
      final sync = WatchSync.forTest(
        now: () => now,
        readContext: () async => null,
        writeContext: (_) async {},
        issueToken: (spi, endpoint) async {
          if (spi.id == 'a') return Completer<ScopedToken>().future;
          return tok('tok-b', endpoint: endpoint);
        },
        revokeToken: (_, _) async {},
        mintWait: const Duration(milliseconds: 50),
      );
      addTearDown(sync.dispose);

      final reply = await sync
          .handleWatchMessage({'action': 'requestData'})
          .timeout(const Duration(seconds: 1));
      expect(payloadServers(reply).map((e) => e['id']), ['b']);
    });

    test('a revoke queued behind slow work past its deadline is still sent',
        () async {
      final atA = monitorSpi(id: 'a', name: 'Alpha');
      final atB = monitorSpi(
        id: 'a',
        name: 'Alpha',
        addr: 'https://10.0.0.2:3770',
      );
      Stores.server.put(
        monitorSpi(id: 'a', name: 'Alpha', addr: 'https://10.0.0.3:3770'),
      );
      var currentTime = now;
      final releaseFirst = Completer<void>();
      final revoked = <String>[];
      final secondSent = Completer<void>();
      final sync = WatchSync.forTest(
        now: () => currentTime,
        readContext: () async => null,
        writeContext: (_) async {},
        issueToken: (_, endpoint) async => tok('new', endpoint: endpoint),
        revokeToken: (spi, _) async {
          revoked.add(spi.monitor!.addr);
          if (revoked.length == 1) await releaseFirst.future;
          if (revoked.length == 2) secondSent.complete();
        },
        revokeCredentialTtl: const Duration(seconds: 5),
      );
      addTearDown(sync.dispose);

      sync.revokeEditedServer(atA);
      await Future<void>.delayed(Duration.zero);
      sync.revokeEditedServer(atB);
      currentTime = now.add(const Duration(seconds: 10));
      releaseFirst.complete();
      await secondSent.future.timeout(const Duration(seconds: 1));

      expect(revoked, [atA.monitor!.addr, atB.monitor!.addr]);
    });

    test('a deleted server leaves no slot behind once its revoke is done',
        () async {
      final doomed = monitorSpi(id: 'a', name: 'Alpha');
      Stores.server.put(doomed);
      final revoked = Completer<void>();
      final sync = WatchSync.forTest(
        now: () => now,
        readContext: () async => null,
        writeContext: (_) async {},
        issueToken: (_, endpoint) async => tok('new', endpoint: endpoint),
        revokeToken: (_, _) async => revoked.complete(),
      );
      addTearDown(sync.dispose);

      await sync.revokeServer(doomed);
      await revoked.future.timeout(const Duration(seconds: 1));
      Stores.server.deleteById(doomed.id);
      sync.finishServerDeletion(doomed.id);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sync.hasSlotFor(doomed.id), isFalse);
    });
  });
}
