/// The agent's settings page against its one account: the form and "change
/// password" when the connection is allowed, and only the reason — nothing
/// asked that would be refused — when the agent refuses plaintext.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/monitor_settings/view.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/test_db.dart';

void main() {
  // `MonitorHttpClient` names its protocol from Rust.
  setUpAll(initRustLibForTest);

  late HttpServer server;
  late List<String> asked;
  var ok = false;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    asked = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      final path = req.uri.path;
      asked.add('${req.method} $path');
      final refused = (403, {
        'error': 'forbidden',
        'message': 'insecure_transport',
      });
      final (int status, Object body) = switch (path) {
        '/api/v1/login' => (200, {'token': 't'}),
        '/api/v1/capabilities' => (200, {
          'access': ok
              ? {'ok': true}
              : {'ok': false, 'why': 'insecure_transport'},
        }),
        '/api/v1/settings' when !ok => refused,
        '/api/v1/settings' => (200, {
          'interval_seconds': 60,
          'idle_pause_enabled': true,
          'rules': [],
          'cors_allowed_origins': [],
          'live_fields': [],
        }),
        '/api/v1/push' when !ok => refused,
        '/api/v1/push' => (200, {'pushes': []}),
        _ => (404, {'error': 'not_found'}),
      };
      req.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await getIt.reset();
    await SqliteDb.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              return Scaffold(
                body: MonitorSettingsView(
                  monitor: MonitorHttpCredential(
                    addr: 'http://127.0.0.1:${server.port}',
                    pwd: 'pw',
                  ),
                ),
              );
            },
          ),
        ),
      );
      await _settle(tester);
    }, _RealHttp()));
    await tester.pump();
  }

  testWidgets('a refused connection gets the reason and nothing else', (
    tester,
  ) async {
    ok = false;
    await pump(tester);

    expect(find.text(app_locale.l10n.monitorNoRemoteAccess), findsOneWidget);
    // Nothing that would be refused: not asked, not shown.
    expect(asked, isNot(contains('GET /api/v1/settings')));
    expect(asked, isNot(contains('GET /api/v1/push')));
    expect(find.text(app_locale.l10n.monitorCollection), findsNothing);
    expect(find.text(app_locale.l10n.monitorChangePassword), findsNothing);
  });

  testWidgets('an allowed connection gets the form and the password', (
    tester,
  ) async {
    ok = true;
    await pump(tester);

    expect(find.text(app_locale.l10n.monitorCollection), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorChangePassword), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorNoRemoteAccess), findsNothing);
  });
}

/// The requests are real; lets them come back.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await tester.pump();
  }
}

/// `dart:io`'s own client. A widget test's binding answers every request with
/// a 400, and these are meant to reach the stand-in agent above.
class _RealHttp extends HttpOverrides {}
