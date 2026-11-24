import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_sort.dart';
import 'package:server_box/data/model/status/card_item.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/sort.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/detail.dart';
import 'package:server_box/data/provider/uptimer/selection.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/edit.dart';

import '../../helpers/spi_fixture.dart';

final _userA = LkcUser(
  id: 'u-a',
  name: 'Alice',
  group: 'user',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
final _userB = LkcUser(
  id: 'u-b',
  name: 'Bob',
  group: 'user',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Map<String, dynamic> _pageJson({
  List<Map<String, dynamic>>? monitors,
  List<Map<String, dynamic>>? incidents,
  List<Map<String, dynamic>>? activeMaint,
}) => {
  'generated_at': 1700000000,
  'overall_status': 'up',
  'monitors':
      monitors ??
      [
        {
          'id': 1,
          'name': 'API',
          'type': 'http',
          'display_url': 'https://api.example.com/health',
          'group_name': 'prod',
          'group_sort_order': 0,
          'sort_order': 0,
          'is_public': true,
          'status': 'up',
          'last_checked_at': 1699999990,
          'last_latency_ms': 42,
          'heartbeats': [
            {'checked_at': 1699999990, 'status': 'up', 'latency_ms': 42},
            {'checked_at': 1699999930, 'status': 'down', 'latency_ms': null},
            {'checked_at': 1699999870, 'status': 'up', 'latency_ms': 38},
          ],
          'uptime_30d': {
            'total_sec': 1000,
            'downtime_sec': 10,
            'unknown_sec': 0,
            'uptime_sec': 990,
            'uptime_pct': 99.0,
          },
          'uptime_days': [
            {
              'day_start_at': 1699920000,
              'total_sec': 86400,
              'downtime_sec': 0,
              'unknown_sec': 0,
              'uptime_sec': 86400,
              'uptime_pct': 100.0,
            },
          ],
        },
        {
          'id': 2,
          'name': 'Backup Cron',
          'type': 'heartbeat',
          'display_url': null,
          'group_name': 'ops',
          'is_public': false,
          'status': 'down',
          'last_ping_at': 1699990000,
          'heartbeats': const [],
          'uptime_30d': {
            'total_sec': 1000,
            'downtime_sec': 500,
            'unknown_sec': 0,
            'uptime_sec': 500,
            'uptime_pct': 50.0,
          },
          'uptime_days': const [],
        },
      ],
  'active_incidents':
      incidents ??
      [
        {
          'id': 10,
          'title': 'Backup missed',
          'status': 'investigating',
          'impact': 'major',
          'message': 'Checking cron runner',
          'started_at': 1699995000,
          'resolved_at': null,
          'monitor_ids': [2],
          'updates': const [],
        },
      ],
  'maintenance_windows': {
    'active': activeMaint ?? const [],
    'upcoming': const [],
  },
};

Map<String, dynamic> _configJson(int id, {String name = 'API', String type = 'http'}) => {
  'id': id,
  'name': name,
  'type': type,
  'target': type == 'heartbeat' ? '' : 'https://api.example.com/health',
  'display_url': 'https://api.example.com',
  'interval_sec': 60,
  'timeout_ms': 10000,
  'grace_sec': type == 'heartbeat' ? 60 : null,
  'http_method': type == 'http' ? 'GET' : null,
  'follow_redirects': true,
  'group_name': 'prod',
  'show_on_status_page': true,
  'is_active': true,
  'status': 'up',
};

void main() {
  group('models & formatting', () {
    test('parses page data, orders heartbeats chronologically, and filters alerts', () {
      final page = UptimerPageData.fromJson(_pageJson());
      expect(page.monitors, hasLength(2));

      final api = page.monitors.first;
      expect(api.displayAddr, 'api.example.com');
      expect(api.recentChronological(2).map((b) => b.checkedAt), [
        1699999930,
        1699999990,
      ]);
      expect(api.recentChronological(10).map((b) => b.checkedAt), [
        1699999870,
        1699999930,
        1699999990,
      ]);
      expect(page.incidentsFor(1), isEmpty);
      expect(page.incidentsFor(2).single.title, 'Backup missed');

      final cron = page.monitors[1];
      expect(cron.displayAddr, 'Heartbeat');
    });

    test('formats uptime, latency, and duration cleanly', () {
      expect(formatUptimePct(null), '—');
      expect(formatUptimePct(100), '100%');
      expect(formatUptimePct(99.999), '100%');
      expect(formatUptimePct(99.9), '99.9%');
      expect(formatUptimePct(99.95), '99.95%');
      expect(formatUptimePct(0), '0%');

      expect(formatLatencyMs(null), '—');
      expect(formatLatencyMs(42), '42 ms');
      expect(formatLatencyMs(1250), '1.25 s');

      expect(formatDurationSec(45), '45s');
      expect(formatDurationSec(120), '2m');
      expect(formatDurationSec(125), '2m 5s');
      expect(formatDurationSec(3660), '1h 1m');
      expect(formatDurationSec(90000), '1d 1h');
    });

    test('roundtrips HTTP status code rules including inclusive ranges', () {
      final rules = UptimerStatusRule.fromJsonList([
        200,
        {'from': 201, 'to': 204},
      ]);
      expect(rules, [
        const UptimerStatusRule(200),
        const UptimerStatusRule(201, 204),
      ]);
      expect(UptimerStatusRule.formatList(rules), '200, 201-204');
      expect(
        UptimerStatusRule.parseInput('200, 201-204')?.map((r) => r.toJson()),
        [
          200,
          {'from': 201, 'to': 204},
        ],
      );
      expect(() => UptimerStatusRule.parseInput('299-200'), throwsFormatException);
      expect(() => UptimerStatusRule.parseInput('99'), throwsFormatException);
    });

    test('validates TCP targets strictly', () {
      expect(UptimerEditPage.isValidTcpTarget('example.com:443'), isTrue);
      expect(UptimerEditPage.isValidTcpTarget('[::1]:443'), isTrue);
      expect(UptimerEditPage.isValidTcpTarget('[2001:db8::1]:443'), isTrue);
      expect(UptimerEditPage.isValidTcpTarget('[foo:bar]:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('[::1::2]:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('::1:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('[2001:db8::1:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('[]:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('bad host:443'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('example.com:0'), isFalse);
      expect(UptimerEditPage.isValidTcpTarget('example.com:70000'), isFalse);
    });

    test('preserves outer whitespace on keyword patterns while treating blank as null', () {
      final cfg = UptimerMonitorConfig.fromJson({
        ..._configJson(1),
        'response_keyword': '  OK  ',
        'response_forbidden_keyword': '\tERROR\n',
      });
      expect(cfg.responseKeyword, '  OK  ');
      expect(cfg.responseForbiddenKeyword, '\tERROR\n');

      final blank = UptimerMonitorConfig.fromJson({
        ..._configJson(2),
        'response_keyword': '   ',
        'response_forbidden_keyword': '',
      });
      expect(blank.responseKeyword, isNull);
      expect(blank.responseForbiddenKeyword, isNull);
    });

    test('maps heartbeat strip slot indices to newest-count oldest-to-newest slots', () {
      // 60 heartbeats, newest-first (index 0 is newest: checkedAt 6000).
      final beats = [
        for (var i = 0; i < 60; i++)
          UptimerHeartbeat(
            checkedAt: (60 - i) * 100,
            status: 'up',
            latencyMs: 20 + i,
          ),
      ];
      // Newest beat (beats[0]) lands at the rightmost slot (44).
      final newest = UptimerHeartbeatStrip.slotOf(beats, 45, 6000);
      expect(newest?.index, 44);
      expect(newest?.beat.checkedAt, 6000);

      // Oldest visible beat (beats[44]) lands at the leftmost slot (0).
      final oldestVisible = UptimerHeartbeatStrip.slotOf(beats, 45, 1600);
      expect(oldestVisible?.index, 0);
      expect(oldestVisible?.beat.checkedAt, 1600);

      // Beat older than the 45-slot window is not highlighted.
      expect(UptimerHeartbeatStrip.slotOf(beats, 45, 1500), isNull);

      // When fewer than 45 beats exist, leading slots are padded on the left.
      final short = beats.take(3).toList();
      expect(UptimerHeartbeatStrip.slotOf(short, 45, 6000)?.index, 44);
      expect(UptimerHeartbeatStrip.slotOf(short, 45, 5800)?.index, 42);
    });
  });

  group('Uptimer provider', () {
    test('stays inactive when LKC is disabled', () async {
      var calls = 0;
      final user = ValueNotifier<LkcUser?>(_userA);
      addTearDown(user.dispose);

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: false, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (_, _, {query, body}) async {
                calls++;
                return _pageJson();
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(uptimerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(state.signedIn, isFalse);
      expect(state.monitors, isEmpty);
      expect(calls, 0);
    });

    test('loads on sign-in, drops stale refresh on sign-out, and clears selection', () async {
      final user = ValueNotifier<LkcUser?>(null);
      addTearDown(user.dispose);
      final firstPage = Completer<Object?>();
      var pageCalls = 0;

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (method, path, {query, body}) async {
                if (method == 'GET' && path == '/api/v1/me/page') {
                  pageCalls++;
                  if (pageCalls == 1) return firstPage.future;
                  return _pageJson();
                }
                return {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(uptimerProvider).signedIn, isFalse);

      // Sign in -> starts first refresh.
      user.value = _userA;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(uptimerProvider).signedIn, isTrue);
      expect(pageCalls, 1);

      // Sign out BEFORE first refresh completes -> stale reply must be ignored.
      container.read(uptimerSelectionProvider.notifier).select(1);
      user.value = null;
      firstPage.complete(_pageJson());
      await Future<void>.delayed(Duration.zero);

      final afterOut = container.read(uptimerProvider);
      expect(afterOut.signedIn, isFalse);
      expect(afterOut.monitors, isEmpty);
      expect(container.read(uptimerSelectionProvider), isNull);

      // Sign in as another account -> loads cleanly.
      user.value = _userB;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final afterB = container.read(uptimerProvider);
      expect(afterB.signedIn, isTrue);
      expect(afterB.monitors.keys, [1, 2]);
      expect(afterB.tags, {'prod', 'ops'});
    });

    test('create, pause, resume, test, rotate push token, assignGroup, delete', () async {
      final user = ValueNotifier<LkcUser?>(_userA);
      addTearDown(user.dispose);
      final calls = <String>[];
      var monitors = List<Map<String, dynamic>>.from(
        _pageJson()['monitors'] as List,
      );

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (method, path, {query, body}) async {
                calls.add('$method $path');
                if (method == 'GET' && path == '/api/v1/me/page') {
                  return _pageJson(monitors: monitors);
                }
                if (method == 'POST' && path == '/api/v1/me/monitors') {
                  monitors = [
                    ...monitors,
                    {
                      'id': 3,
                      'name': 'Cron 2',
                      'type': 'heartbeat',
                      'status': 'unknown',
                      'heartbeats': const [],
                      'uptime_30d': const {},
                      'uptime_days': const [],
                    },
                  ];
                  return {
                    'monitor': _configJson(3, name: 'Cron 2', type: 'heartbeat'),
                    'push_token': 'tok_once',
                  };
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/1/test') {
                  return {
                    'monitor': {'id': 1, 'name': 'API', 'type': 'http'},
                    'result': {
                      'status': 'up',
                      'latency_ms': 25,
                      'http_status': 200,
                      'error': null,
                      'attempts': 1,
                    },
                  };
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/1/pause') {
                  return {'monitor': _configJson(1)};
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/1/resume') {
                  return {'monitor': _configJson(1)};
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/3/push-token') {
                  return {
                    'monitor': _configJson(3, name: 'Cron 2', type: 'heartbeat'),
                    'push_token': 'tok_rotated',
                  };
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/groups/assign') {
                  return {'updated_monitors': 1};
                }
                if (method == 'GET' && path == '/api/v1/me/monitors') {
                  return {'monitors': [_configJson(1)]};
                }
                if (method == 'GET' && path == '/api/v1/me') {
                  return {
                    'quota': {'max_monitors': 20, 'min_interval_sec': 60},
                    'usage': {'monitors': monitors.length},
                  };
                }
                if (method == 'DELETE' && path == '/api/v1/me/monitors/3') {
                  monitors = monitors.where((m) => m['id'] != 3).toList();
                  return {'deleted': true};
                }
                return {};
              },
              pushUrlOf: (tok) => Uri.parse('https://up.lolli.tech/api/v1/push/$tok'),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(uptimerProvider.notifier).refresh(force: true);
      final notifier = container.read(uptimerProvider.notifier);

      final created = await notifier.createMonitor({
        'name': 'Cron 2',
        'type': 'heartbeat',
      });
      expect(created.pushToken, 'tok_once');
      expect(container.read(uptimerProvider).monitors.containsKey(3), isTrue);

      final testRes = await notifier.testMonitor(1);
      expect(testRes.isUp, isTrue);
      expect(testRes.latencyMs, 25);
      expect(testRes.httpStatus, 200);

      await notifier.pauseMonitor(1);
      await notifier.resumeMonitor(1);

      final rotated = await notifier.rotatePushToken(3);
      expect(rotated.pushToken, 'tok_rotated');

      await notifier.assignGroup([1], 'core');
      expect(container.read(uptimerProvider).quota?.maxMonitors, 20);

      container.read(uptimerSelectionProvider.notifier).select(3);
      await notifier.deleteMonitor(3);
      expect(container.read(uptimerProvider).monitors.containsKey(3), isFalse);
      expect(container.read(uptimerSelectionProvider), isNull);
      expect(calls, contains('POST /api/v1/me/monitors/groups/assign'));
    });

    test('drops out-of-order refresh snapshots and patches is_active on resume', () async {
      final user = ValueNotifier<LkcUser?>(_userA);
      addTearDown(user.dispose);
      final slowRefresh = Completer<Object?>();
      var pageCalls = 0;
      var patchedActive = false;
      var quotaCalls = 0;

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (method, path, {query, body}) async {
                if (method == 'GET' && path == '/api/v1/me/page') {
                  pageCalls++;
                  if (pageCalls == 1) return slowRefresh.future;
                  return _pageJson(monitors: [
                    {
                      'id': 1,
                      'name': 'Fresh',
                      'type': 'http',
                      'status': 'up',
                      'heartbeats': const [],
                      'uptime_30d': const {},
                      'uptime_days': const [],
                    },
                  ]);
                }
                if (method == 'POST' && path == '/api/v1/me/monitors/1/resume') {
                  return {
                    'monitor': {..._configJson(1), 'is_active': false},
                  };
                }
                if (method == 'PATCH' && path == '/api/v1/me/monitors/1') {
                  if ((body as Map)['is_active'] == true) patchedActive = true;
                  return {'monitor': _configJson(1)};
                }
                if (method == 'GET' && path == '/api/v1/me/monitors') {
                  return {'monitors': [_configJson(1)]};
                }
                if (method == 'GET' && path == '/api/v1/me') {
                  quotaCalls++;
                  if (quotaCalls == 1) {
                    return {
                      'quota': {'max_monitors': 15, 'min_interval_sec': 60},
                      'usage': {'monitors': 1},
                    };
                  }
                  throw const LkcException(status: 500, message: 'boom');
                }
                return {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Start initial slow refresh, then force a newer refresh before it settles.
      final f1 = container.read(uptimerProvider.notifier).refresh(force: true);
      final f2 = container.read(uptimerProvider.notifier).refresh(force: true);
      await f2;
      expect(container.read(uptimerProvider).monitors[1]?.name, 'Fresh');

      // Now complete stale f1 -> must NOT overwrite 'Fresh' with 'API'.
      slowRefresh.complete(_pageJson());
      await f1;
      expect(container.read(uptimerProvider).monitors[1]?.name, 'Fresh');

      // Resume a monitor whose is_active is false -> patches is_active: true.
      await container.read(uptimerProvider.notifier).resumeMonitor(1);
      expect(patchedActive, isTrue);

      // Quota is preserved when a later fetchAccount() fails.
      await container.read(uptimerProvider.notifier).loadConfigs(force: true);
      expect(container.read(uptimerProvider).quota?.maxMonitors, 15);
      await container.read(uptimerProvider.notifier).loadConfigs(force: true);
      expect(container.read(uptimerProvider).quota?.maxMonitors, 15);
    });
  });

  group('UptimerDetail provider', () {
    test('does not fire network requests when signed out', () async {
      final user = ValueNotifier<LkcUser?>(null);
      addTearDown(user.dispose);
      var calls = 0;

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (_, _, {query, body}) async {
                calls++;
                return {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(uptimerDetailProvider(1), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 0);
      expect(container.read(uptimerDetailProvider(1)).isLoading, isFalse);
    });
    test('ignores out-of-order range results and supports outage pagination', () async {
      final user = ValueNotifier<LkcUser?>(_userA);
      addTearDown(user.dispose);
      final slow24h = Completer<Object?>();

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (method, path, {query, body}) async {
                if (path == '/api/v1/me/page') return _pageJson();
                if (path == '/api/v1/me/monitors') {
                  return {'monitors': [_configJson(1)]};
                }
                if (path == '/api/v1/me') return {'quota': const {}, 'usage': const {}};
                if (path == '/api/v1/me/monitors/1/latency') {
                  return {
                    'range_start_at': 100,
                    'range_end_at': 200,
                    'avg_latency_ms': 40,
                    'p95_latency_ms': 75,
                    'points': [
                      {'checked_at': 120, 'status': 'up', 'latency_ms': 35},
                      {'checked_at': 180, 'status': 'up', 'latency_ms': 45},
                    ],
                  };
                }
                if (path == '/api/v1/me/monitors/1/uptime') {
                  final range = query?['range'];
                  if (range == '24h') return slow24h.future;
                  return {
                    'total_sec': 1000,
                    'downtime_sec': 0,
                    'unknown_sec': 0,
                    'uptime_sec': 1000,
                    'uptime_pct': range == '90d' ? 99.5 : 99.9,
                  };
                }
                if (path == '/api/v1/me/monitors/1/outages') {
                  final cursor = query?['cursor'];
                  if (cursor == 50) {
                    return {
                      'outages': [
                        {
                          'id': 49,
                          'monitor_id': 1,
                          'started_at': 1000,
                          'ended_at': 1120,
                          'last_error': 'timeout',
                        },
                      ],
                      'next_cursor': null,
                    };
                  }
                  return {
                    'outages': [
                      {
                        'id': 50,
                        'monitor_id': 1,
                        'started_at': 2000,
                        'ended_at': 2060,
                        'last_error': '502',
                      },
                    ],
                    'next_cursor': 50,
                  };
                }
                return {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Keep autoDispose alive during test.
      final sub = container.listen(uptimerDetailProvider(1), (_, _) {});
      addTearDown(sub.close);

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(container.read(uptimerDetailProvider(1)).latency?.avgLatencyMs, 40);
      expect(container.read(uptimerDetailProvider(1)).outages.single.id, 50);

      // Load page 2 of outages.
      await container.read(uptimerDetailProvider(1).notifier).loadMoreOutages();
      expect(container.read(uptimerDetailProvider(1)).outages.map((o) => o.id), [50, 49]);
      expect(container.read(uptimerDetailProvider(1)).nextOutageCursor, isNull);

      // Trigger slow 24h switch, then fast 90d switch before 24h finishes.
      final f24 = container.read(uptimerDetailProvider(1).notifier).setRange(UptimerRange.h24);
      final f90 = container.read(uptimerDetailProvider(1).notifier).setRange(UptimerRange.d90);
      await f90;
      slow24h.complete({
        'total_sec': 100,
        'downtime_sec': 50,
        'unknown_sec': 0,
        'uptime_sec': 50,
        'uptime_pct': 50.0,
      });
      await f24;

      final finalState = container.read(uptimerDetailProvider(1));
      expect(finalState.range, UptimerRange.d90);
      expect(finalState.currentUptime?.uptimePct, 99.5);
    });

    test(
      'clears loadingMoreOutages when refresh interrupts pagination and allows paginating again',
      () async {
        final user = ValueNotifier<LkcUser?>(_userA);
        addTearDown(user.dispose);
        final stalePage2 = Completer<Object?>();
        var cursor50Calls = 0;

        final container = ProviderContainer(
          overrides: [
            uptimerAuthSourceProvider.overrideWithValue((
              enabled: true,
              user: user,
            )),
            uptimerApiProvider.overrideWithValue(
              UptimerApi(
                call: (method, path, {query, body}) async {
                  if (path == '/api/v1/me/page') return _pageJson();
                  if (path == '/api/v1/me/monitors/1/latency') {
                    return {
                      'range_start_at': 100,
                      'range_end_at': 200,
                      'points': const [],
                    };
                  }
                  if (path == '/api/v1/me/monitors/1/uptime') {
                    return {
                      'total_sec': 1000,
                      'downtime_sec': 0,
                      'unknown_sec': 0,
                      'uptime_sec': 1000,
                      'uptime_pct': 100.0,
                    };
                  }
                  if (path == '/api/v1/me/monitors/1/outages') {
                    final cursor = query?['cursor'];
                    if (cursor == 50) {
                      cursor50Calls++;
                      if (cursor50Calls == 1) return stalePage2.future;
                      return {
                        'outages': [
                          {
                            'id': 49,
                            'monitor_id': 1,
                            'started_at': 1000,
                            'ended_at': 1120,
                            'last_error': 'timeout',
                          },
                        ],
                        'next_cursor': null,
                      };
                    }
                    return {
                      'outages': [
                        {
                          'id': 50,
                          'monitor_id': 1,
                          'started_at': 2000,
                          'ended_at': 2060,
                          'last_error': '502',
                        },
                      ],
                      'next_cursor': 50,
                    };
                  }
                  return {};
                },
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final sub = container.listen(uptimerDetailProvider(1), (_, _) {});
        addTearDown(sub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(uptimerDetailProvider(1)).nextOutageCursor, 50);

        // Start pagination (blocks on stalePage2), then interrupt with refresh().
        final staleLoad = container
            .read(uptimerDetailProvider(1).notifier)
            .loadMoreOutages();
        expect(
          container.read(uptimerDetailProvider(1)).loadingMoreOutages,
          isTrue,
        );

        final refreshF = container
            .read(uptimerDetailProvider(1).notifier)
            .refresh();
        expect(
          container.read(uptimerDetailProvider(1)).loadingMoreOutages,
          isFalse,
        );
        // Pagination is ignored while refresh is still in flight.
        await container.read(uptimerDetailProvider(1).notifier).loadMoreOutages();
        expect(cursor50Calls, 1);

        await refreshF;
        expect(
          container.read(uptimerDetailProvider(1)).loadingMoreOutages,
          isFalse,
        );

        // Starting pagination again succeeds even before stalePage2 completes.
        await container.read(uptimerDetailProvider(1).notifier).loadMoreOutages();
        expect(
          container.read(uptimerDetailProvider(1)).outages.map((o) => o.id),
          [50, 49],
        );
        expect(cursor50Calls, 2);

        // Completing the outdated pagination request does not corrupt state.
        stalePage2.complete({
          'outages': [
            {
              'id': 999,
              'monitor_id': 1,
              'started_at': 1,
              'ended_at': 2,
              'last_error': 'stale',
            },
          ],
          'next_cursor': null,
        });
        await staleLoad;
        expect(
          container.read(uptimerDetailProvider(1)).outages.map((o) => o.id),
          [50, 49],
        );
      },
    );

    test('tracks uptimeError separately from latencyError and outagesError', () async {
      final user = ValueNotifier<LkcUser?>(_userA);
      addTearDown(user.dispose);
      var failUptime = false;
      var failLatency = true;
      var failOutages = true;

      final container = ProviderContainer(
        overrides: [
          uptimerAuthSourceProvider.overrideWithValue((
            enabled: true,
            user: user,
          )),
          uptimerApiProvider.overrideWithValue(
            UptimerApi(
              call: (method, path, {query, body}) async {
                if (path == '/api/v1/me/page') return _pageJson();
                if (path == '/api/v1/me/monitors/1/latency') {
                  if (failLatency) {
                    throw const LkcException(status: 500, message: 'lat err');
                  }
                  return {
                    'range_start_at': 100,
                    'range_end_at': 200,
                    'points': const [],
                  };
                }
                if (path == '/api/v1/me/monitors/1/outages') {
                  if (failOutages) {
                    throw const LkcException(status: 500, message: 'out err');
                  }
                  return {'outages': const [], 'next_cursor': null};
                }
                if (path == '/api/v1/me/monitors/1/uptime') {
                  if (failUptime) {
                    throw const LkcException(status: 500, message: 'up err');
                  }
                  return {
                    'total_sec': 1000,
                    'downtime_sec': 0,
                    'unknown_sec': 0,
                    'uptime_sec': 1000,
                    'uptime_pct': 100.0,
                  };
                }
                return {};
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final sub = container.listen(uptimerDetailProvider(1), (_, _) {});
      addTearDown(sub.close);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final s1 = container.read(uptimerDetailProvider(1));
      expect(s1.uptimeError, isNull);
      expect(s1.latencyError, isNotNull);
      expect(s1.outagesError, isNotNull);

      failUptime = true;
      failLatency = false;
      failOutages = false;
      await container.read(uptimerDetailProvider(1).notifier).refresh();

      final s2 = container.read(uptimerDetailProvider(1));
      expect(s2.uptimeError, isNotNull);
      expect(s2.latencyError, isNull);
      expect(s2.outagesError, isNull);
    });
  });

  group('StatusCardItem & sorting', () {
    test('sorts Uptimer cards alongside Server and BMC cards', () {
      final spi = spiFixture(id: 's1', name: 'web-01', ip: '10.0.0.1');
      const bmc = BmcTarget(id: 'b1', name: 'rack-bmc', addr: 'https://10.0.0.2');
      const upDown = UptimerMonitorCard(
        id: 1,
        name: 'api-down',
        type: UptimerMonitorType.http,
        status: UptimerMonitorStatus.down,
        groupName: 'prod',
      );
      const upHealthy = UptimerMonitorCard(
        id: 2,
        name: 'blog-up',
        type: UptimerMonitorType.http,
        status: UptimerMonitorStatus.up,
      );

      final items = <StatusCardItem>[
        ServerCardItem(spi),
        const BmcCardItem(bmc),
        const UptimerCardItem(upHealthy),
        const UptimerCardItem(upDown),
      ];

      final byAlert = const ServerSortOrder(
        ServerSortField.alert,
        ascending: true,
      ).applyItems(
        items,
        serverStateOf: (_) => ServerState(
          spi: spi,
          status: InitStatus.status,
          conn: ServerConn.finished,
        ),
        bmcStateOf: (_) => const BmcSummaryState(),
      );
      expect(byAlert.first.cardKey, UptimerCardItem.keyOf(1));

      final byStatus = const ServerSortOrder(
        ServerSortField.status,
        ascending: true,
      ).applyItems(
        items,
        serverStateOf: (_) => ServerState(
          spi: spi,
          status: InitStatus.status,
          conn: ServerConn.finished,
        ),
        bmcStateOf: (_) => const BmcSummaryState(),
      );
      expect(byStatus.first.cardKey, UptimerCardItem.keyOf(1));
    });
  });
}
