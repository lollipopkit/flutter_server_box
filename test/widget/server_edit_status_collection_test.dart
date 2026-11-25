import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/group_title.dart';

import '../helpers/test_db.dart';

void main() {
  setUp(() async {
    await openTestDb();
    if (!getIt.isRegistered<PveStore>()) {
      getIt.registerSingleton<PveStore>(PveStore());
    }
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore());
    }
  });
  tearDown(closeTestDb);

  const server = Spi(
    name: 'srv',
    id: 'srv-status-collection',
    ssh: SshCredential(ip: '10.0.0.5', port: 22, user: 'root', pwd: 'pw'),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Spi? Function()> pumpEditor(
    WidgetTester tester, {
    List<PrivateKeyInfo> keys = const [],
    Size size = const Size(900, 2400),
  }) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Spi? persisted;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serversProvider.overrideWith(
            () => _PersistingServersNotifier(server, (v) => persisted = v),
          ),
          privateKeyProvider.overrideWithValue(PrivateKeyState(keys: keys)),
        ],
        child: MaterialApp(
          builder: ResponsivePoints.builder,
          locale: const Locale('en'),
          localizationsDelegates: const [
            ...app_locale.appLocalizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const ServerEditPage(args: ServerEditArgs(server));
            },
          ),
        ),
      ),
    );
    await settle(tester);
    return () => persisted;
  }

  testWidgets('status collection uses GroupTitle and showRowsSheet', (
    tester,
  ) async {
    final saved = await pumpEditor(tester);

    final statusTile = find.text(app_locale.l10n.statusCollection);
    await tester.ensureVisible(statusTile);
    await tester.tap(statusTile);
    await settle(tester);

    expect(find.byType(CenterGreyTitle), findsNothing);
    expect(find.text(app_locale.l10n.customCmd.toUpperCase()), findsOneWidget);
    expect(find.text(libL10n.disk.toUpperCase()), findsOneWidget);
    expect(find.text(app_locale.l10n.specifyDev.toUpperCase()), findsOneWidget);

    final specifyTitle = tester.widget<GroupTitle>(
      find.ancestor(
        of: find.text(app_locale.l10n.specifyDev.toUpperCase()),
        matching: find.byType(GroupTitle),
      ),
    );
    expect(specifyTitle.tip, app_locale.l10n.specifyDevTip);
    expect(find.text(libL10n.note), findsNothing);

    // Tapping the temperature Celsius row toggles the switch.
    final tempUnitTitle = find.text('${libL10n.temperature} (°C)');
    await tester.ensureVisible(tempUnitTitle);
    await tester.tap(tempUnitTitle);
    await settle(tester);

    // Disabled commands open in a rows sheet with CheckboxListTile items.
    final disabledCmdTile = find.text('${libL10n.disabled} ${libL10n.cmd}');
    await tester.ensureVisible(disabledCmdTile);
    await tester.tap(disabledCmdTile);
    await settle(tester);

    final firstBox = find.byType(CheckboxListTile).first;
    expect(firstBox, findsOneWidget);
    final firstTile = tester.widget<CheckboxListTile>(firstBox);
    final firstDisplay = (firstTile.subtitle! as Text).data!;
    await tester.tap(firstBox);
    await settle(tester);
    await tester.tap(find.text(libL10n.ok));
    await settle(tester);

    await tester.tap(find.text(libL10n.save));
    await settle(tester);

    final result = saved();
    expect(result, isNotNull);
    expect(result!.custom?.tempIsCelsius, isTrue);
    expect(result.disabledCmdTypes, [firstDisplay]);
  });

  testWidgets(
    'private key supports ordered multi-select, warns on too many keys, and shows selection on tile',
    (tester) async {
      const keys = [
        PrivateKeyInfo(id: 'key-1', name: 'prod-ed25519', key: 'PEM-1'),
        PrivateKeyInfo(id: 'key-2', name: 'staging-rsa', key: 'PEM-2'),
        PrivateKeyInfo(id: 'key-3', name: 'backup-key', key: 'PEM-3'),
        PrivateKeyInfo(id: 'key-4', name: 'legacy-key', key: 'PEM-4'),
      ];
      final saved = await pumpEditor(tester, keys: keys);

      final keyAuthSwitch = find.descendant(
        of: find.widgetWithText(ListTile, app_locale.l10n.keyAuth),
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(keyAuthSwitch);
      await tester.tap(keyAuthSwitch);
      await settle(tester);

      final keyTile = find.widgetWithText(ListTile, app_locale.l10n.privateKey);
      expect(keyTile, findsOneWidget);
      expect(
        find.descendant(of: keyTile, matching: find.text(libL10n.empty)),
        findsOneWidget,
      );

      // Open sheet and pick 4 keys in custom order: warning appears on the 4th.
      await tester.tap(keyTile);
      await settle(tester);
      expect(find.byType(SheetChoiceTile), findsNWidgets(4));
      expect(find.text(libL10n.clear), findsNothing);
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsNothing);

      await tester.tap(find.text('staging-rsa'));
      await settle(tester);
      expect(find.text(libL10n.clear), findsOneWidget);
      await tester.tap(find.text('prod-ed25519'));
      await settle(tester);
      await tester.tap(find.text('backup-key'));
      await settle(tester);
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsNothing);

      await tester.tap(find.text('legacy-key'));
      await settle(tester);
      // Warning shown in the sheet header (and also under the tile behind it).
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsWidgets);

      // Close sheet: warning stays visible below the tile and trailing shows
      // first key + remaining count.
      await tester.tap(find.text(libL10n.ok));
      await settle(tester);
      expect(
        find.descendant(of: keyTile, matching: find.text('staging-rsa')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: keyTile, matching: find.text(' +3')),
        findsOneWidget,
      );
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsOneWidget);

      // Re-open, clear, then pick 2 keys: warning disappears and order is saved.
      await tester.tap(keyTile);
      await settle(tester);
      await tester.tap(find.text(libL10n.clear));
      await settle(tester);
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsNothing);

      await tester.tap(find.text('backup-key'));
      await settle(tester);
      await tester.tap(find.text('prod-ed25519'));
      await settle(tester);
      await tester.tap(find.text(libL10n.ok));
      await settle(tester);

      expect(
        find.descendant(of: keyTile, matching: find.text('backup-key')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: keyTile, matching: find.text(' +1')),
        findsOneWidget,
      );
      expect(find.text(app_locale.l10n.sshTooManyKeysWarning), findsNothing);

      await tester.tap(find.text(libL10n.save));
      await settle(tester);

      final result = saved();
      expect(result, isNotNull);
      expect(result!.ssh?.keyId, 'key-3');
      expect(result.ssh?.resolvedKeyIds, ['key-3', 'key-1']);
    },
  );

  testWidgets('private key tile handles narrow width and empty list without overflow', (
    tester,
  ) async {
    const keys = [
      PrivateKeyInfo(
        id: 'key-long',
        name: 'very-long-production-private-key-name-for-narrow-screen',
        key: 'PEM-LONG',
      ),
    ];
    await pumpEditor(tester, keys: keys, size: const Size(320, 1800));

    final keyAuthSwitch = find.descendant(
      of: find.widgetWithText(ListTile, app_locale.l10n.keyAuth),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(keyAuthSwitch);
    await tester.tap(keyAuthSwitch);
    await settle(tester);

    final keyTile = find.widgetWithText(ListTile, app_locale.l10n.privateKey);
    await tester.tap(keyTile);
    await settle(tester);
    await tester.tap(
      find.text('very-long-production-private-key-name-for-narrow-screen'),
    );
    await settle(tester);
    await tester.tap(find.text(libL10n.ok));
    await settle(tester);

    expect(tester.takeException(), isNull);
  });
}

final class _PersistingServersNotifier extends ServersNotifier {
  final Spi _initial;
  final void Function(Spi) _onUpdate;

  _PersistingServersNotifier(this._initial, this._onUpdate);

  @override
  ServersState build() => ServersState(servers: {_initial.id: _initial});

  @override
  Future<void> updateServer(Spi old, Spi newSpi) async {
    _onUpdate(newSpi);
  }
}
