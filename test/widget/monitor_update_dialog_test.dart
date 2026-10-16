/// The update dialog against a stand-in agent: the agent starts the update,
/// sudo's password is asked for and refused, the agent stops answering while
/// it restarts, and the dialog follows the update's log across that to the
/// new version.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/service/monitor_login_devices.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/monitor/update_agent.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/test_db.dart';

var _refreshed = 0;

class _RealHttp extends HttpOverrides {}

class _Server extends ServerNotifier {
  @override
  ServerState build(String id) => ServerState(
    spi: Stores.server.fetch().firstWhere((s) => s.id == id),
    status: InitStatus.status,
    conn: ServerConn.finished,
  );

  @override
  Future<void> refresh({bool interactive = false}) async => _refreshed++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initRustLibForTest);

  late HttpServer agent;
  late List<(String, String, Object?)> seen;

  /// `GET /update` requests waiting for the test to answer them: one at a
  /// time, so the dialog's polls are told apart whatever the clock does.
  late List<Completer<(int, Object?)>> asked;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    MonitorLoginDevices.store = MemoryDeviceTokenStore();
    MonitorLoginDevices.resetForTest();
    _refreshed = 0;
    seen = [];
    asked = [];
    agent = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    agent.listen((req) async {
      final raw = await utf8.decoder.bind(req).join();
      final body = raw.isEmpty ? null : jsonDecode(raw);
      seen.add((req.method, req.uri.path, body));
      if ((req.method, req.uri.path) == ('GET', '/api/v1/update')) {
        final answer = Completer<(int, Object?)>();
        asked.add(answer);
        final (status, out) = await answer.future;
        req.response.statusCode = status;
        if (out != null) {
          req.response
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(out));
        }
        await req.response.close();
        return;
      }
      final (int status, Object out) = switch ((req.method, req.uri.path)) {
        ('POST', '/api/v1/login') => (200, {'token': 't', 'device': 'sbd_1'}),
        ('POST', '/api/v1/update/run') when body is Map && body['password'] == 'right' => (202, {'run': null}),
        ('POST', '/api/v1/update/run') => (403, {'error': 'sudo_password'}),
        _ => (404, {'error': 'not_found'}),
      };
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(out));
      await req.response.close();
    });
  });

  tearDown(() async {
    await agent.close(force: true);
    await getIt.reset();
    await closeTestDb();
  });

  Map<String, Object?> says(String version, {String? state, List<String> lines = const [], int? exit}) => {
    'version': version,
    'latest': '0.4.0',
    'checked_at': '2026-10-14T06:00:00Z',
    'outdated': version != '0.4.0',
    'install': 'script',
    'needs_password': true,
    if (state != null)
      'run': {'state': state, 'started_at': '2026-10-14T06:00:00Z', 'exit': ?exit, 'lines': lines},
  };

  testWidgets('the agent runs it, and the dialog follows it across the restart', (tester) async {
    final spi = Spi(
      id: 'a',
      name: 'box',
      monitorHttp: MonitorHttpCredential(addr: 'http://127.0.0.1:${agent.port}', pwd: 'pw'),
    );
    Stores.server.put(spi);
    final container = ProviderContainer(overrides: [serverProvider.overrideWith2((_) => _Server())]);
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return Scaffold(
                body: TextButton(
                  onPressed: () => showMonitorUpdate(
                    context,
                    spi,
                    MonitorOutdated(
                      running: '0.3.0',
                      latest: '0.4.0',
                      update: MonitorUpdate.fromJson(says('0.3.0')),
                    ),
                    access: MonitorAccess.granted,
                  ),
                  child: const Text('open'),
                ),
              );
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final l10n = app_locale.l10n;

    // Their futures complete outside the test's fake clock.
    Future<void> settle() async {
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
    }

    // Real sockets: a request has to start on the real clock to finish (its
    // timeouts are timers), so the tap that starts one is made there, and
    // with a real HttpClient (the binding's answers every request with 400).
    // The dialog's poll timer is made in the same zone.
    Future<void> tap(String text) async {
      await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() => tester.tap(find.text(text)), _RealHttp()));
      await settle();
    }

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 500));
    // OpenRC without root: sudo's password, asked for up front.
    expect(find.text(l10n.monitorUpdateSudoPassword), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tap(l10n.monitorUpdateNow);
    expect(find.text(l10n.monitorUpdateSudoRefused), findsOneWidget);
    expect(seen.last.$3, {'password': 'wrong'});

    await tester.enterText(find.byType(TextField), 'right');
    await tap(l10n.monitorUpdateNow);
    expect(find.text(l10n.monitorUpdating), findsOneWidget);

    // The poll's timer fires on the real clock; its request waits for this.
    Future<void> answer(int status, Object? body) async {
      await tester.runAsync(() async {
        while (asked.isEmpty || asked.last.isCompleted) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
        asked.last.complete((status, body));
      });
      await settle();
    }

    await answer(200, says('0.3.0', state: 'running', lines: ['Downloading the package']));
    expect(find.textContaining('Downloading the package'), findsOneWidget);
    // The agent restarting, behind a proxy.
    await answer(503, null);
    expect(find.text(l10n.monitorUpdateRestarting), findsOneWidget);
    // What it said before is kept while it does not answer.
    expect(find.textContaining('Downloading the package'), findsOneWidget);
    await answer(200, says('0.4.0', state: 'done', lines: ['Downloading the package', 'Upgrade success'], exit: 0));
    expect(find.text(l10n.monitorUpdateDone('0.4.0')), findsOneWidget);
    expect(find.textContaining('Upgrade success'), findsOneWidget);
    // The server reconnects to the new agent.
    expect(_refreshed, 1);
    // sudo's password went to the start alone.
    expect(
      [for (final (_, path, body) in seen) if ('$body'.contains('wrong') || '$body'.contains('right')) path],
      ['/api/v1/update/run', '/api/v1/update/run'],
    );
  });
}
