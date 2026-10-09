/// `MonitorPushEditPage` offers the settings of a channel's type that the
/// channel does not have yet, and saves one only once it is filled in — left
/// alone, the agent's default for it keeps applying.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/monitor_settings/push_edit.dart';

void main() {
  const entry = MonitorPushEntry(
    name: 'phone',
    pushType: 'bark',
    config: {'key': null, 'server': 'https://api.day.app'},
    fromIndex: 0,
  );

  Future<Future<MonitorPushEntry?>> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = MonitorHttpClient(
      MonitorHttpCredential(addr: 'http://127.0.0.1:9', user: 'a', pwd: 'b'),
    );
    addTearDown(client.dispose);

    late Future<MonitorPushEntry?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: ResponsivePoints.builder,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MonitorPushEditPage(
                  args: MonitorPushEditArgs(
                    entry: entry,
                    pushTypes: const ['webhook', 'bark', 'smtp'],
                    client: client,
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return result;
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  testWidgets("a type's settings the channel lacks are offered blank", (
    tester,
  ) async {
    await open(tester);
    expect(field('subtitle'), findsOneWidget);
    expect(field('cipher_key'), findsOneWidget);
    expect(
      tester.widget<TextField>(field('subtitle')).controller!.text,
      isEmpty,
    );
  });

  testWidgets('an offered setting is saved only once filled in', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.enterText(field('subtitle'), 'on {{name}}');
    await tester.tap(find.byIcon(Icons.save));
    await tester.pump(const Duration(milliseconds: 500));

    final saved = await result;
    expect(saved!.config, {
      'key': null,
      'server': 'https://api.day.app',
      'subtitle': 'on {{name}}',
    });
  });
}
