import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';

/// The connection half of the server editor: two switches, an order, and what
/// happens to a method's configuration when it is switched off.
///
/// Off used to mean the fields were dropped on save, so turning a method back
/// on meant typing the host, the account and the key again. The whole point of
/// these tests is that the record keeps what the form is hiding.
void main() {
  const both = Spi(
    name: 'lkd',
    id: 'lkd-id',
    ssh: SshCredential(ip: '10.0.0.4', port: 22, user: 'root', pwd: 'pw'),
    monitorHttp: MonitorHttpCredential(addr: 'https://agent:3770'),
    preferredTransport: ServerTransport.monitorHttp,
  );

  /// Opens the editor on [server] and hands back what a save would persist,
  /// read through JSON the way storage reads it.
  Future<Spi? Function()> pumpEditor(WidgetTester tester, Spi server) async {
    FlutterSecureStorage.setMockInitialValues({});
    Spi? persisted;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serversProvider.overrideWith(
            () => _PersistingServersNotifier(server, (v) => persisted = v),
          ),
          privateKeyProvider.overrideWithValue(const PrivateKeyState()),
        ],
        child: MaterialApp(
          builder: ResponsivePoints.builder,
          locale: const Locale('en'),
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return ServerEditPage(args: SpiRequiredArgs(server));
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return () => persisted;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('both methods are listed, the leading one numbered 1', (
    tester,
  ) async {
    await pumpEditor(tester, both);

    expect(find.text('Monitor HTTP'), findsOneWidget);
    expect(find.text('SSH'), findsWidgets);
    expect(find.text(app_locale.l10n.connection.toUpperCase()), findsOneWidget);
    // The agent leads on this server, so it is the one that says so.
    expect(find.text(app_locale.l10n.transportDialledFirst), findsOneWidget);
    expect(find.text(app_locale.l10n.transportFallback), findsOneWidget);
  });

  testWidgets('switching a method off keeps its configuration', (tester) async {
    final persisted = await pumpEditor(tester, both);

    // The agent's switch. Both rows carry one, so it is found by its row.
    final agentRow = find.ancestor(
      of: find.text('Monitor HTTP'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: agentRow.first, matching: find.byType(Switch)).first,
    );
    await settle(tester);

    expect(find.text(app_locale.l10n.transportSectionOff), findsOneWidget);
    expect(find.text(app_locale.l10n.transportOffKept), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
    await settle(tester);

    final saved = persisted();
    expect(saved, isNotNull);
    expect(saved!.monitorEnabled, isFalse);
    expect(
      saved.monitorHttp?.addr,
      'https://agent:3770',
      reason: 'off keeps the settings — that is the whole of what off means',
    );
    expect(saved.monitorOn, isNull, reason: 'and nothing dials them');
    // The order survives too: turning SSH back on must not have to re-decide
    // which of the two leads.
    expect(saved.preferredTransport, ServerTransport.monitorHttp);
  });

  testWidgets('a server with both switched off is not saved', (tester) async {
    final persisted = await pumpEditor(tester, both);

    for (final label in ['Monitor HTTP', 'SSH']) {
      final row = find
          .ancestor(of: find.text(label), matching: find.byType(Row))
          .first;
      await tester.tap(
        find.descendant(of: row, matching: find.byType(Switch)).first,
      );
      await settle(tester);
    }

    // Said in the form rather than refused as a gesture: which of the two the
    // app objected to is not something a switch that will not move can say.
    expect(find.text(app_locale.l10n.transportNoneOn), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
    await settle(tester);

    expect(persisted(), isNull);
  });
}

final class _PersistingServersNotifier extends ServersNotifier {
  _PersistingServersNotifier(this.initialServer, this.onPersist);

  final Spi initialServer;
  final ValueChanged<Spi> onPersist;

  @override
  ServersState build() => ServersState(
    servers: {initialServer.id: initialServer},
    serverOrder: [initialServer.id],
  );

  @override
  Future<void> updateServer(Spi old, Spi newSpi) async {
    // Through JSON, because that is what the record goes through on its way to
    // storage: a field the model carries and the wire drops would pass a test
    // that only looked at the object.
    onPersist(
      Spi.fromJson(jsonDecode(jsonEncode(newSpi)) as Map<String, dynamic>),
    );
  }
}
