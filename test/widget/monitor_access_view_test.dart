/// The agent's settings page on an agent with roles: an account that is not an
/// admin gets its own account and nothing it would be refused, and an admin
/// gets the accounts and roles besides the form.
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
import 'package:server_box/view/page/server/monitor_settings/access.dart';
import 'package:server_box/view/page/server/monitor_settings/view.dart';

import '../helpers/test_db.dart';

void main() {
  late HttpServer server;
  late List<String> asked;
  var admin = false;

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    asked = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      await req.drain<void>();
      final path = req.uri.path;
      asked.add('${req.method} $path');
      final (int status, Object body) = switch (path) {
        '/api/v1/login' => (200, {'token': 't'}),
        '/api/v1/capabilities' => (200, {
          'me': {
            'username': 'alice',
            'role': admin ? 'admin' : 'viewer',
            'admin': admin,
          },
          'grants': {
            'shell': {'ok': admin, 'why': admin ? null : 'not_granted'},
          },
        }),
        '/api/v1/settings' when !admin => (403, {'error': 'forbidden'}),
        '/api/v1/settings' => (200, {
          'interval_seconds': 60,
          'idle_pause_enabled': true,
          'rules': [],
          'cors_allowed_origins': [],
          'live_fields': [],
        }),
        '/api/v1/push' => (200, {'pushes': []}),
        '/api/v1/users' => (200, [
          {'username': 'alice', 'role': 'admin'},
          {'username': 'bob', 'role': 'viewer'},
        ]),
        '/api/v1/roles' => (200, [
          {'name': 'admin', 'admin': true, 'builtin': true, 'grants': {}},
          {'name': 'viewer', 'builtin': true, 'grants': {}},
        ]),
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
                    user: 'alice',
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

  testWidgets('an account that is not an admin sees its own account only', (
    tester,
  ) async {
    admin = false;
    await pump(tester);

    expect(find.text('alice'), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorChangePassword), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorNoAccessToSettings), findsOneWidget);
    // Nothing that would be refused: not asked, not shown.
    expect(asked, isNot(contains('GET /api/v1/settings')));
    expect(find.text(app_locale.l10n.monitorAccounts), findsNothing);
    expect(find.text(app_locale.l10n.monitorCollection), findsNothing);
  });

  testWidgets('an admin gets the accounts and the roles beside the form', (
    tester,
  ) async {
    admin = true;
    await pump(tester);

    expect(find.text(app_locale.l10n.monitorCollection), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorAccounts), findsOneWidget);
    expect(find.text(app_locale.l10n.monitorRoles), findsOneWidget);
  });

  testWidgets('the accounts page lists them, marking this one', (tester) async {
    admin = true;
    await pump(tester);
    await tester.runAsync(() => HttpOverrides.runWithHttpOverrides(() async {
      await tester.tap(find.text(app_locale.l10n.monitorAccounts));
      await _settle(tester);
    }, _RealHttp()));
    await tester.pump();

    expect(find.byType(MonitorAccountsPage), findsOneWidget);
    expect(
      find.text('alice (${app_locale.l10n.monitorYou})'),
      findsOneWidget,
    );
    expect(find.text('bob'), findsOneWidget);
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
