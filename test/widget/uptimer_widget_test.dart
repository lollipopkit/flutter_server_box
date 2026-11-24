import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/uptimer/uptimer.dart';
import 'package:server_box/data/provider/uptimer/client.dart';
import 'package:server_box/data/provider/uptimer/uptimer.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/tab/element_flight.dart';
import 'package:server_box/view/page/uptimer/card.dart';
import 'package:server_box/view/page/uptimer/common.dart';
import 'package:server_box/view/page/uptimer/detail.dart';
import 'package:server_box/view/page/uptimer/edit.dart';

final _user = LkcUser(
  id: 'u1',
  name: 'Lk',
  group: 'user',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _monitor = UptimerMonitorCard(
  id: 1,
  name: 'Prod API',
  type: UptimerMonitorType.http,
  displayUrl: 'https://api.example.com',
  groupName: 'prod',
  status: UptimerMonitorStatus.up,
  lastCheckedAt: 1700000000,
  lastLatencyMs: 42,
  heartbeats: [
    UptimerHeartbeat(checkedAt: 1700000000, status: 'up', latencyMs: 42),
    UptimerHeartbeat(checkedAt: 1699999940, status: 'down', latencyMs: null),
    UptimerHeartbeat(checkedAt: 1699999880, status: 'up', latencyMs: 39),
  ],
  uptime30d: UptimerTotals(
    totalSec: 1000,
    downtimeSec: 1,
    unknownSec: 0,
    uptimeSec: 999,
    uptimePct: 99.9,
  ),
  uptimeDays: [
    UptimerDay(
      dayStartAt: 1699920000,
      totals: UptimerTotals(
        totalSec: 86400,
        downtimeSec: 0,
        unknownSec: 0,
        uptimeSec: 86400,
        uptimePct: 100.0,
      ),
    ),
  ],
);

Widget _wrap({
  required Widget child,
  required ValueNotifier<LkcUser?> user,
  required UptimerApi api,
}) {
  return ProviderScope(
    overrides: [
      uptimerAuthSourceProvider.overrideWithValue((enabled: true, user: user)),
      uptimerApiProvider.overrideWithValue(api),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        LibLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          app_locale.l10n = AppLocalizations.of(context)!;
          return child;
        },
      ),
    ),
  );
}

UptimerApi _mockApi({
  void Function(Map<String, dynamic>)? onCreate,
}) {
  return UptimerApi(
    call: (method, path, {query, body}) async {
      if (method == 'GET' && path == '/api/v1/me/page') {
        return {
          'generated_at': 1700000000,
          'overall_status': 'degraded',
          'monitors': [
            {
              'id': 1,
              'name': 'Prod API',
              'type': 'http',
              'display_url': 'https://api.example.com',
              'group_name': 'prod',
              'is_public': true,
              'status': 'up',
              'last_checked_at': 1700000000,
              'last_latency_ms': 42,
              'heartbeats': [
                {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 42},
              ],
              'uptime_30d': {
                'total_sec': 1000,
                'downtime_sec': 1,
                'unknown_sec': 0,
                'uptime_sec': 999,
                'uptime_pct': 99.9,
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
          ],
          'active_incidents': [
            {
              'id': 7,
              'title': 'Elevated edge latency',
              'status': 'monitoring',
              'impact': 'minor',
              'started_at': 1699999000,
              'resolved_at': null,
              'monitor_ids': [1],
              'updates': const [],
            },
          ],
          'maintenance_windows': {'active': const [], 'upcoming': const []},
        };
      }
      if (method == 'GET' && path == '/api/v1/me/monitors') {
        return {
          'monitors': [
            {
              'id': 1,
              'name': 'Prod API',
              'type': 'http',
              'target': 'https://api.example.com/health',
              'display_url': 'https://api.example.com',
              'interval_sec': 60,
              'timeout_ms': 10000,
              'http_method': 'GET',
              'follow_redirects': true,
              'group_name': 'prod',
              'show_on_status_page': true,
              'is_active': true,
              'status': 'up',
            },
          ],
        };
      }
      if (method == 'GET' && path == '/api/v1/me') {
        return {
          'quota': {'max_monitors': 20, 'min_interval_sec': 60},
          'usage': {'monitors': 1},
        };
      }
      if (method == 'GET' && path == '/api/v1/me/monitors/1/latency') {
        return {
          'range_start_at': 1699913600,
          'range_end_at': 1700000000,
          'avg_latency_ms': 42,
          'p95_latency_ms': 71,
          'points': [
            {'checked_at': 1699950000, 'status': 'up', 'latency_ms': 38},
            {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 46},
          ],
        };
      }
      if (method == 'GET' && path == '/api/v1/me/monitors/1/uptime') {
        return {
          'total_sec': 86400,
          'downtime_sec': 120,
          'unknown_sec': 0,
          'uptime_sec': 86280,
          'uptime_pct': 99.86,
        };
      }
      if (method == 'GET' && path == '/api/v1/me/monitors/1/outages') {
        return {
          'outages': [
            {
              'id': 10,
              'monitor_id': 1,
              'started_at': 1699990000,
              'ended_at': 1699990120,
              'last_error': 'HTTP 502 Bad Gateway',
            },
          ],
          'next_cursor': null,
        };
      }
      if (method == 'POST' && path == '/api/v1/me/monitors/1/test') {
        return {
          'monitor': {'id': 1, 'name': 'Prod API', 'type': 'http'},
          'result': {
            'status': 'up',
            'latency_ms': 31,
            'http_status': 200,
            'error': null,
            'attempts': 1,
          },
        };
      }
      if (method == 'POST' && path == '/api/v1/me/monitors') {
        final payload = (body as Map).cast<String, dynamic>();
        onCreate?.call(payload);
        return {
          'monitor': {
            'id': 9,
            'name': payload['name'],
            'type': payload['type'],
            'target': payload['target'] ?? '',
            'interval_sec': payload['interval_sec'] ?? 60,
            'timeout_ms': payload['timeout_ms'] ?? 10000,
            'grace_sec': payload['grace_sec'],
            'follow_redirects': true,
            'show_on_status_page': false,
            'is_active': true,
            'status': 'unknown',
          },
          if (payload['type'] == 'heartbeat') 'push_token': 'tok_secret_once',
        };
      }
      return {};
    },
    pushUrlOf: (tok) => Uri.parse('https://up.lolli.tech/api/v1/push/$tok'),
  );
}

void main() {
  testWidgets('UptimerCard renders cleanly across all densities including narrow widths', (
    tester,
  ) async {
    final user = ValueNotifier<LkcUser?>(_user);
    addTearDown(user.dispose);
    final api = _mockApi();

    for (final width in [300.0, 360.0]) {
      for (final density in [
        ServerListDensity.cards,
        ServerListDensity.rows,
        ServerListDensity.grid,
      ]) {
        await tester.pumpWidget(
          _wrap(
            user: user,
            api: api,
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: UptimerCard(
                  monitor: _monitor,
                  density: density,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Prod API'), findsOneWidget);
        if (density == ServerListDensity.cards) {
          expect(find.text('42 ms'), findsOneWidget);
          expect(find.text('99.9%'), findsOneWidget);
          expect(find.text('Elevated edge latency'), findsOneWidget);
        }
      }
    }
  });

  testWidgets('UptimerDetailPage displays metrics, outages, and manual test result', (
    tester,
  ) async {
    final user = ValueNotifier<LkcUser?>(_user);
    addTearDown(user.dispose);
    final api = _mockApi();

    await tester.pumpWidget(
      _wrap(
        user: user,
        api: api,
        child: const UptimerDetailPage(args: UptimerDetailArgs(monitor: _monitor)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prod API'), findsOneWidget);
    expect(find.text('avg 42 ms · p95 71 ms'), findsOneWidget);
    expect(find.text('HTTP 502 Bad Gateway'), findsOneWidget);

    await tester.tap(find.text(app_locale.l10n.uptimerTest));
    await tester.pumpAndSettle();

    expect(
      find.text('${app_locale.l10n.uptimerStatusUp} · 31 ms · HTTP 200'),
      findsOneWidget,
    );
  });

  testWidgets('UptimerEditPage blocks save when full config fails to load', (
    tester,
  ) async {
    final user = ValueNotifier<LkcUser?>(_user);
    addTearDown(user.dispose);
    final failingApi = UptimerApi(
      call: (method, path, {query, body}) async {
        if (path == '/api/v1/me/monitors') {
          throw const LkcException(status: 500, message: 'Server unavailable');
        }
        return {'generated_at': 1, 'overall_status': 'up', 'monitors': const []};
      },
    );

    await tester.pumpWidget(
      _wrap(
        user: user,
        api: failingApi,
        child: const UptimerEditPage(args: UptimerEditArgs(card: _monitor)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server unavailable'), findsOneWidget);
    final saveBtn = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, libL10n.save),
    );
    expect(saveBtn.onPressed, isNull);
  });

  testWidgets('UptimerEditPage creates heartbeat monitor and shows one-time push URL', (
    tester,
  ) async {
    final user = ValueNotifier<LkcUser?>(_user);
    addTearDown(user.dispose);
    Map<String, dynamic>? created;
    final api = _mockApi(onCreate: (b) => created = b);

    await tester.pumpWidget(
      _wrap(
        user: user,
        api: api,
        child: const UptimerEditPage(),
      ),
    );
    await tester.pumpAndSettle();

    // Switch type to Heartbeat.
    await tester.tap(find.text('Heartbeat'));
    await tester.pumpAndSettle();

    // Fill name.
    await tester.enterText(find.byType(TextField).first, 'Nightly Backup');
    await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
    await tester.pumpAndSettle();

    expect(created?['name'], 'Nightly Backup');
    expect(created?['type'], 'heartbeat');
    expect(created?.containsKey('target'), isFalse);
    expect(
      find.text('https://up.lolli.tech/api/v1/push/tok_secret_once'),
      findsOneWidget,
    );
  });

  testWidgets(
    'StatusElementFlight tolerates coexisting anchors and cleans up overlays cleanly',
    (tester) async {
      final ctrl = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 200),
      );
      addTearDown(ctrl.dispose);

      var changedCount = 0;
      final flight = StatusElementFlight(
        progress: ctrl,
        onChanged: () => changedCount++,
      );
      addTearDown(flight.dispose);

      late BuildContext hostCtx;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) {
                hostCtx = ctx;
                return Stack(
                  children: [
                    // Two card anchors for the same cardKey coexisting (as in
                    // AnimatedSwitcher grid↔globe or empty↔grid transitions).
                    Positioned(
                      left: 16,
                      top: 20,
                      width: 120,
                      height: 14,
                      child: FlightAnchor(
                        binding: flight.cardBinding('uptimer:1'),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      top: 24,
                      width: 120,
                      height: 14,
                      child: FlightAnchor(
                        binding: flight.cardBinding('uptimer:1'),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    // Two detail anchors for different monitors coexisting (as
                    // in DirectionalSwap sidebar switches), given distinct
                    // bounds so the flight target is unambiguously verifiable.
                    Positioned(
                      left: 260,
                      top: 120,
                      width: 400,
                      height: 22,
                      child: FlightAnchor(
                        binding: flight.detailBinding('uptimer:1'),
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 40,
                      top: 360,
                      width: 180,
                      height: 36,
                      child: FlightAnchor(
                        binding: flight.detailBinding('uptimer:2'),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      final gen = flight.start(
        context: hostCtx,
        cardKey: 'uptimer:1',
        opening: true,
        departing: KeyedSubtree(
          key: const ValueKey('flight_proxy_departing'),
          child: UptimerHeartbeatStrip(
            heartbeats: _monitor.heartbeats,
            count: 12,
            height: 11,
            gap: 1.5,
            radius: 1.5,
          ),
        ),
        arriving: UptimerHeartbeatStrip(
          heartbeats: _monitor.heartbeats,
          count: 45,
          height: 22,
          gap: 2,
          radius: 2.5,
        ),
      );
      expect(gen, isNotNull);
      expect(flight.isFlying('uptimer:1'), isTrue);

      ctrl.value = 0.5;
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Mid-flight proxy rect should be halfway between the newest uptimer:1
      // card anchor (24, 24, 120x14) and uptimer:1 detail anchor
      // (260, 120, 400x22), NOT uptimer:2 (40, 360, 180x36).
      final proxyRect = tester.getRect(
        find.byKey(const ValueKey('flight_proxy_departing')),
      );
      expect(proxyRect.left, closeTo(142, 0.5));
      expect(proxyRect.top, closeTo(72, 0.5));
      expect(proxyRect.width, closeTo(260, 0.5));
      expect(proxyRect.height, closeTo(18, 0.5));

      flight.end(gen);
      await tester.pump();
      expect(flight.isFlying('uptimer:1'), isFalse);
      expect(changedCount, greaterThanOrEqualTo(2));

      // Starting on an unmounted card clears any stale state without throwing.
      final skipped = flight.start(
        context: hostCtx,
        cardKey: 'uptimer:999',
        opening: true,
        departing: const SizedBox.shrink(),
        arriving: const SizedBox.shrink(),
      );
      expect(skipped, isNull);
      expect(flight.isFlying('uptimer:999'), isFalse);
    },
  );

  testWidgets(
    'UptimerDetailPage shows refresh errors alongside cached latency/outages and ignores hidden strip hits',
    (tester) async {
      final user = ValueNotifier<LkcUser?>(_user);
      addTearDown(user.dispose);
      var failRefresh = false;

      final api = UptimerApi(
        call: (method, path, {query, body}) async {
          if (method == 'GET' && path == '/api/v1/me/page') {
            return {
              'generated_at': 1700000000,
              'overall_status': 'up',
              'monitors': [
                {
                  'id': 1,
                  'name': 'Prod API',
                  'type': 'http',
                  'display_url': 'https://api.example.com',
                  'group_name': 'prod',
                  'is_public': true,
                  'status': 'up',
                  'last_checked_at': 1700000000,
                  'last_latency_ms': 42,
                  'heartbeats': [
                    {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 42},
                    {'checked_at': 1699999940, 'status': 'down', 'latency_ms': null},
                    {'checked_at': 1699999880, 'status': 'up', 'latency_ms': 39},
                  ],
                  'uptime_30d': {
                    'total_sec': 1000,
                    'downtime_sec': 1,
                    'unknown_sec': 0,
                    'uptime_sec': 999,
                    'uptime_pct': 99.9,
                  },
                  'uptime_days': const [],
                },
              ],
              'active_incidents': const [],
              'maintenance_windows': {'active': const [], 'upcoming': const []},
            };
          }
          if (path == '/api/v1/me/monitors/1/latency') {
            if (failRefresh) {
              throw const LkcException(status: 500, message: 'latency fail');
            }
            return {
              'range_start_at': 1699913600,
              'range_end_at': 1700000000,
              'avg_latency_ms': 42,
              'p95_latency_ms': 71,
              'points': [
                {'checked_at': 1699950000, 'status': 'up', 'latency_ms': 38},
                {'checked_at': 1699960000, 'status': 'down', 'latency_ms': null},
                {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 46},
              ],
            };
          }
          if (path == '/api/v1/me/monitors/1/uptime') {
            if (failRefresh) {
              throw const LkcException(status: 500, message: 'uptime fail');
            }
            return {
              'total_sec': 86400,
              'downtime_sec': 120,
              'unknown_sec': 0,
              'uptime_sec': 86280,
              'uptime_pct': 99.86,
            };
          }
          if (path == '/api/v1/me/monitors/1/outages') {
            if (failRefresh) {
              throw const LkcException(status: 500, message: 'outages fail');
            }
            return {
              'outages': [
                {
                  'id': 10,
                  'monitor_id': 1,
                  'started_at': 1699990000,
                  'ended_at': 1699990120,
                  'last_error': 'HTTP 502 Bad Gateway',
                },
              ],
              'next_cursor': null,
            };
          }
          return {};
        },
      );

      await tester.pumpWidget(
        _wrap(
          user: user,
          api: api,
          child: const UptimerDetailPage(
            args: UptimerDetailArgs(monitor: _monitor),
            hideStrip: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Hidden heartbeat strip must ignore pointer hits during flight.
      final stripFinder = find.byType(UptimerHeartbeatStrip);
      expect(stripFinder, findsOneWidget);
      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: stripFinder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);

      // Cached latency & outage rows are present.
      expect(find.text('avg 42 ms · p95 71 ms'), findsOneWidget);
      expect(find.text('HTTP 502 Bad Gateway'), findsOneWidget);

      // Trigger a refresh failure -> cached data stays visible alongside errors.
      failRefresh = true;
      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pumpAndSettle();

      expect(find.text('uptime fail'), findsOneWidget);
      expect(find.text('latency fail'), findsOneWidget);
      expect(find.text('outages fail'), findsOneWidget);
      expect(find.text('HTTP 502 Bad Gateway'), findsOneWidget);
      expect(find.text('avg 42 ms · p95 71 ms'), findsOneWidget);
    },
  );

  testWidgets(
    'UptimerDetailPage latency chart snaps immediately when gap positions change and animates when unchanged',
    (tester) async {
      final user = ValueNotifier<LkcUser?>(_user);
      addTearDown(user.dispose);
      var phase = 0;

      final api = UptimerApi(
        call: (method, path, {query, body}) async {
          if (method == 'GET' && path == '/api/v1/me/page') {
            return {
              'generated_at': 1700000000,
              'overall_status': 'up',
              'monitors': [
                {
                  'id': 1,
                  'name': 'Prod API',
                  'type': 'http',
                  'display_url': 'https://api.example.com',
                  'group_name': 'prod',
                  'is_public': true,
                  'status': 'up',
                  'last_checked_at': 1700000000,
                  'last_latency_ms': 42,
                  'heartbeats': const [],
                  'uptime_30d': const {},
                  'uptime_days': const [],
                },
              ],
              'active_incidents': const [],
              'maintenance_windows': {'active': const [], 'upcoming': const []},
            };
          }
          if (path == '/api/v1/me/monitors/1/latency') {
            return {
              'range_start_at': 1699913600,
              'range_end_at': 1700000000,
              'avg_latency_ms': 42,
              'p95_latency_ms': 71,
              'points': switch (phase) {
                0 => [
                  {'checked_at': 1699950000, 'status': 'up', 'latency_ms': 38},
                  {'checked_at': 1699960000, 'status': 'up', 'latency_ms': 44},
                  {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 46},
                ],
                1 => [
                  {'checked_at': 1699950000, 'status': 'up', 'latency_ms': 50},
                  {'checked_at': 1699960000, 'status': 'up', 'latency_ms': 55},
                  {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 60},
                ],
                _ => [
                  {'checked_at': 1699950000, 'status': 'up', 'latency_ms': 50},
                  {'checked_at': 1699960000, 'status': 'down', 'latency_ms': null},
                  {'checked_at': 1700000000, 'status': 'up', 'latency_ms': 60},
                ],
              },
            };
          }
          if (path == '/api/v1/me/monitors/1/uptime') {
            return {
              'total_sec': 86400,
              'downtime_sec': 0,
              'unknown_sec': 0,
              'uptime_sec': 86400,
              'uptime_pct': 100.0,
            };
          }
          if (path == '/api/v1/me/monitors/1/outages') {
            return {'outages': const [], 'next_cursor': null};
          }
          return {};
        },
      );

      await tester.pumpWidget(
        _wrap(
          user: user,
          api: api,
          child: const UptimerDetailPage(
            args: UptimerDetailArgs(monitor: _monitor),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialKey = tester.widget<LineChart>(find.byType(LineChart)).key;
      final initialState = tester.state<AnimatedWidgetBaseState<LineChart>>(
        find.byType(LineChart),
      );

      // Refresh with updated values and same (empty) gap positions -> reuses
      // the LineChart State and starts an implicit animation.
      phase = 1;
      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
      final state1 = tester.state<AnimatedWidgetBaseState<LineChart>>(
        find.byType(LineChart),
      );
      expect(
        tester.widget<LineChart>(find.byType(LineChart)).key,
        equals(initialKey),
      );
      expect(identical(state1, initialState), isTrue);
      expect(state1.animation.status, AnimationStatus.forward);
      await tester.pumpAndSettle();

      // Refresh introducing a null latency gap -> outer AnimatedSwitcher does
      // not crossfade (still a single LineChart), while inner LineChart mounts
      // a fresh State at dismissed/0.0 so the gap renders on frame 1 with no
      // stale FlSpot.lerp interpolation.
      phase = 2;
      await tester.tap(find.byIcon(Icons.refresh).first);
      await tester.pump();
      await tester.pump();
      expect(find.byType(LineChart), findsOneWidget);
      final chartAfterGap = tester.widget<LineChart>(find.byType(LineChart));
      final state2 = tester.state<AnimatedWidgetBaseState<LineChart>>(
        find.byType(LineChart),
      );
      expect(chartAfterGap.key, isNot(equals(initialKey)));
      expect(identical(state2, initialState), isFalse);
      expect(state2.animation.status, AnimationStatus.dismissed);
      expect(state2.animation.value, 0.0);
      expect(
        chartAfterGap.data.lineBarsData.single.spots[1],
        equals(FlSpot.nullSpot),
      );
    },
  );

  testWidgets(
    'UptimerEditPage reconciles active baseline when resumeMonitor fails after updateMonitor',
    (tester) async {
      final user = ValueNotifier<LkcUser?>(_user);
      addTearDown(user.dispose);
      final patches = <Map<String, dynamic>>[];
      var resumeCalls = 0;
      var pauseCalls = 0;
      var persistedActive = false;
      var persistedStatus = 'paused';

      const initialConfig = UptimerMonitorConfig(
        id: 1,
        name: 'Paused API',
        type: UptimerMonitorType.http,
        target: 'https://api.example.com/health',
        displayUrl: 'https://api.example.com',
        intervalSec: 60,
        timeoutMs: 10000,
        httpMethod: 'GET',
        followRedirects: true,
        groupName: 'prod',
        showOnStatusPage: true,
        isActive: false,
        status: UptimerMonitorStatus.paused,
      );

      Map<String, dynamic> monitorJson() => {
        'id': 1,
        'name': 'Paused API',
        'type': 'http',
        'target': 'https://api.example.com/health',
        'display_url': 'https://api.example.com',
        'interval_sec': 60,
        'timeout_ms': 10000,
        'http_method': 'GET',
        'follow_redirects': true,
        'group_name': 'prod',
        'show_on_status_page': true,
        'is_active': persistedActive,
        'status': persistedStatus,
      };

      final api = UptimerApi(
        call: (method, path, {query, body}) async {
          if (method == 'GET' && path == '/api/v1/me/page') {
            return {
              'generated_at': 1700000000,
              'overall_status': 'up',
              'monitors': const [],
              'active_incidents': const [],
              'maintenance_windows': {'active': const [], 'upcoming': const []},
            };
          }
          if (method == 'GET' && path == '/api/v1/me/monitors') {
            return {'monitors': [monitorJson()]};
          }
          if (method == 'GET' && path == '/api/v1/me') {
            return {
              'quota': {'max_monitors': 20, 'min_interval_sec': 60},
              'usage': {'monitors': 1},
            };
          }
          if (method == 'PATCH' && path == '/api/v1/me/monitors/1') {
            final map = (body as Map).cast<String, dynamic>();
            patches.add(Map<String, dynamic>.from(map));
            if (map.containsKey('is_active')) {
              persistedActive = map['is_active'] as bool;
            }
            return {'monitor': monitorJson()};
          }
          if (method == 'POST' && path == '/api/v1/me/monitors/1/resume') {
            resumeCalls++;
            throw const LkcException(status: 500, message: 'resume failed');
          }
          if (method == 'POST' && path == '/api/v1/me/monitors/1/pause') {
            pauseCalls++;
            persistedActive = false;
            persistedStatus = 'paused';
            return {'monitor': monitorJson()};
          }
          return {};
        },
      );

      await tester.pumpWidget(
        _wrap(
          user: user,
          api: api,
          child: const UptimerEditPage(
            args: UptimerEditArgs(config: initialConfig),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Toggle Active ON and save: PATCH sets is_active=true, then resume fails.
      final activeTile = find.text(app_locale.l10n.uptimerActive);
      await tester.ensureVisible(activeTile);
      await tester.pumpAndSettle();
      await tester.tap(activeTile);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
      await tester.pumpAndSettle();

      expect(patches, hasLength(1));
      expect(patches.first['is_active'], isTrue);
      expect(resumeCalls, 1);
      expect(persistedActive, isTrue);

      // Form stayed open; toggle Active back OFF and save -> must send
      // is_active: false against the reconciled baseline.
      await tester.tap(activeTile);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
      await tester.pumpAndSettle();

      expect(patches, hasLength(2));
      expect(patches.last['is_active'], isFalse);
      expect(pauseCalls, 0);
      expect(persistedActive, isFalse);
    },
  );

  testWidgets('UptimerCard height matches ServerListDensity constants', (
    tester,
  ) async {
    final user = ValueNotifier<LkcUser?>(_user);
    addTearDown(user.dispose);

    // Without active incident/maintenance alert.
    final plainApi = UptimerApi(
      call: (method, path, {query, body}) async {
        if (method == 'GET' && path == '/api/v1/me/page') {
          return {
            'generated_at': 1700000000,
            'overall_status': 'up',
            'monitors': const [],
            'active_incidents': const [],
            'maintenance_windows': {'active': const [], 'upcoming': const []},
          };
        }
        return {};
      },
    );

    await tester.pumpWidget(
      _wrap(
        user: user,
        api: plainApi,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 338,
              child: UptimerCard(
                monitor: _monitor,
                density: ServerListDensity.cards,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(UptimerCard)).height,
      moreOrLessEquals(ServerListDensity.cardUptimer, epsilon: 10),
    );

    // With active incident banner (from _mockApi). Reset ProviderScope first so
    // the new API override triggers a fresh page load with active incidents.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      _wrap(
        user: user,
        api: _mockApi(),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 338,
              child: UptimerCard(
                monitor: _monitor,
                density: ServerListDensity.cards,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Elevated edge latency'), findsOneWidget);
    expect(
      tester.getSize(find.byType(UptimerCard)).height,
      moreOrLessEquals(ServerListDensity.cardUptimerAlert, epsilon: 10),
    );
  });
}
