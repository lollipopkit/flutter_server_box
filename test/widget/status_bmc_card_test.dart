import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/bmc_target.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/card.dart';
import 'package:server_box/view/page/server/bmc/common.dart';
import 'package:server_box/view/page/server/bmc/detail.dart';
import 'package:server_box/view/page/server/bmc/edit.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import '../helpers/rust_lib_helper.dart';
import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _cred = BmcCredential(id: 'c1', name: 'rack', user: 'root', pwd: 'pw');

RedfishTopology _topology(PowerState power, {String? health = 'OK'}) =>
    RedfishTopology(
      root: const RedfishRoot(systems: '/redfish/v1/Systems'),
      systemPath: '/redfish/v1/Systems/1',
      system: RedfishSystem(
        model: 'PowerEdge R750',
        powerState: power,
        health: health,
        resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
        resetTypes: const ['On', 'GracefulShutdown'],
      ),
      hasMultipleSystems: false,
    );

void main() {
  setUpAll(initRustLibForTest);

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    getIt.registerSingleton<BmcTargetStore>(BmcTargetStore());
    getIt.registerSingleton<ServerStore>(
      ServerStore(bmcTargets: Stores.bmcTarget),
    );
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());

    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.setting.globeEnabled.put(false);
    Stores.bmcCredential.put(_cred);
    ServerDensityPref.put(TagSwitcher.kDefaultTag, ServerListDensity.cards);
  });

  tearDown(() async {
    BmcSummaryNotifier.testReadSummary = null;
    BmcSummaryNotifier.testPower = null;
    await getIt.reset();
    await closeTestDb();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 16; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('BmcCard renders power, watts, and quick Power On across densities', (
    tester,
  ) async {
    final l10nEn = AppLocalizationsEn();
    const target = BmcTarget(
      id: 'b1',
      name: 'rack-bmc',
      addr: 'https://10.0.0.50',
      credId: 'c1',
    );
    Stores.bmcTarget.put(target);
    BmcSummaryNotifier.testReadSummary = (_, _) async => BmcSummary(
      topology: _topology(PowerState.off),
      watts: 15.0,
    );

    for (final density in const [
      ServerListDensity.cards,
      ServerListDensity.rows,
      ServerListDensity.grid,
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: const [...appLocalizationsDelegates],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BmcCard(
                target: target,
                density: density,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('rack-bmc'), findsOneWidget);
      if (density == ServerListDensity.cards) {
        expect(find.text('15 W'), findsOneWidget);
        expect(find.text(l10nEn.bmcPowerOff), findsOneWidget);
        expect(find.bySemanticsLabel(l10nEn.bmcPowerOnAction), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('BmcCard stays single-row without duplicate status when off with no telemetry', (
    tester,
  ) async {
    final l10nEn = AppLocalizationsEn();
    const target = BmcTarget(
      id: 'b-min',
      name: 'openbmc-e2e',
      addr: 'https://10.0.0.51',
      credId: 'c1',
    );
    Stores.bmcTarget.put(target);
    BmcSummaryNotifier.testReadSummary = (_, _) async => const BmcSummary(
      topology: RedfishTopology(
        root: RedfishRoot(systems: '/redfish/v1/Systems'),
        systemPath: '/redfish/v1/Systems/1',
        system: RedfishSystem(
          powerState: PowerState.off,
          health: 'OK',
          resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
          resetTypes: ['On'],
        ),
        hasMultipleSystems: false,
      ),
      watts: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: BmcCard(
              target: target,
              density: ServerListDensity.cards,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.text('openbmc-e2e'), findsOneWidget);
    expect(find.text(l10nEn.bmcPowerOff), findsOneWidget);
    expect(find.text('10.0.0.51'), findsNothing);
    expect(find.text('OK'), findsNothing);
    expect(find.bySemanticsLabel(l10nEn.bmcPowerOnAction), findsOneWidget);
  });

  testWidgets('Status tab shows standalone BMCs, hides linked duplicate, and marks offline linked host Powered Off', (
    tester,
  ) async {
    final l10nEn = AppLocalizationsEn();
    final srv = spiFixture(
      id: 'srv-1',
      name: 'host-one',
      ip: '10.0.0.1',
      autoConnect: false,
    );
    Stores.server.put(srv);
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'bmc-linked',
        name: 'host-one-bmc',
        addr: 'https://10.0.0.11',
        credId: 'c1',
        serverId: 'srv-1',
      ),
    );
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'bmc-solo',
        name: 'solo-oob',
        addr: 'https://10.0.0.12',
        credId: 'c1',
      ),
    );

    BmcSummaryNotifier.testReadSummary = (target, _) async => BmcSummary(
      topology: _topology(
        target.id == 'bmc-linked' ? PowerState.off : PowerState.on_,
      ),
      watts: target.id == 'bmc-linked' ? 8.0 : 120.0,
    );

    tester.view.physicalSize = const Size(500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const ServerPage();
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    await settle(tester);

    // Standalone BMC appears; linked BMC does NOT duplicate as a standalone card.
    expect(find.byType(ServerCard), findsOneWidget);
    expect(find.byType(BmcCard), findsOneWidget);
    expect(
      tester.getSize(find.byType(BmcCard)).height,
      moreOrLessEquals(ServerListDensity.cardBmc, epsilon: 10),
    );
    expect(find.text('solo-oob'), findsOneWidget);
    expect(find.text('host-one-bmc'), findsNothing);

    // Mark the server failed: its card queries the linked BMC and shows Powered Off + Power On.
    container
        .read(serverProvider('srv-1').notifier)
        .updateConnection(ServerConn.failed);
    await settle(tester);

    expect(find.text(l10nEn.bmcPowerOff), findsWidgets);
    expect(find.bySemanticsLabel(l10nEn.bmcPowerOnAction), findsOneWidget);
  });

  testWidgets('BmcCard rows density does not overflow on narrow screen with large font and multi-select', (
    tester,
  ) async {
    const target = BmcTarget(
      id: 'b-narrow',
      name: 'very-long-rack-bmc-hostname-01',
      addr: 'https://10.0.0.55',
      credId: 'c1',
    );
    Stores.bmcTarget.put(target);
    BmcSummaryNotifier.testReadSummary = (_, _) async => BmcSummary(
      topology: _topology(PowerState.on_, health: 'Warning'),
      watts: 1245.0,
    );

    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var tapped = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: BmcCard(
                target: target,
                density: ServerListDensity.rows,
                selected: true,
                onTap: () => tapped++,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(BmcCard), findsOneWidget);

    // Tapping the action area in multi-select toggles selection rather than refreshing.
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('BmcDetailPage shows power controls, locator toggle, busy indicator, and safely removes only its own route on delete', (
    tester,
  ) async {
    const target = BmcTarget(
      id: 'b-detail',
      name: 'lab-bmc',
      addr: 'https://10.0.0.60',
      credId: 'c1',
    );
    Stores.bmcTarget.put(target);

    final fake = _DetailFakeBmc(
      BmcState(
        topology: RedfishTopology(
          root: const RedfishRoot(systems: '/redfish/v1/Systems'),
          systemPath: '/redfish/v1/Systems/1',
          system: const RedfishSystem(
            model: 'PowerEdge R750',
            biosVersion: '2.4.1',
            powerState: PowerState.on_,
            health: 'OK',
            resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
            resetTypes: ['On', 'GracefulShutdown', 'ForceRestart', 'ForceOff'],
            logServices: '/redfish/v1/Systems/1/LogServices',
            storage: '/redfish/v1/Systems/1/Storage',
            locator: Locator(lit: false, legacy: false),
          ),
          hasMultipleSystems: false,
        ),
        sensors: const BmcSensors(
          temperatures: [BmcReading(name: 'Inlet', value: 26.5, unit: 'Cel')],
          fans: [BmcReading(name: 'Fan 1', value: 4200, unit: '')],
          watts: 142.0,
        ),
      ),
    );

    final navKey = GlobalKey<NavigatorState>();
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bmcProvider(target.id).overrideWith(() => fake)],
        child: MaterialApp(
          navigatorKey: navKey,
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
          home: Consumer(
            builder: (context, ref, _) {
              l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              container = ProviderScope.containerOf(context);
              return const Scaffold(body: Text('ROOT'));
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Push BmcDetailPage on top of ROOT.
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const BmcDetailPage(args: BmcTargetRequiredArgs(target)),
      ),
    );
    await settle(tester);

    expect(find.text('142 W'), findsOneWidget);
    expect(find.text('PowerEdge R750'), findsOneWidget);
    // Fan with empty unit must not leave trailing whitespace.
    expect(find.text('4200'), findsOneWidget);

    // Tapping the locator row text (not just the Switch) toggles locator with
    // the current endpointGeneration.
    await tester.tap(find.text(l10n.bmcLocator));
    await settle(tester);
    expect(fake.locatorCalls, [(true, 0)]);

    // When isPowering becomes true while PowerState.on_, show progress indicator.
    fake.setPowering(true);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Push a child route on top of BmcDetailPage, then delete the BMC target:
    // BmcDetailPage must remove ONLY its own route, leaving CHILD intact.
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('CHILD'))),
    );
    await settle(tester);
    expect(find.text('CHILD'), findsOneWidget);

    container.read(bmcTargetsProvider.notifier).delete(target.id);
    await settle(tester);

    expect(find.text('CHILD'), findsOneWidget);
    navKey.currentState!.pop();
    await settle(tester);
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('BmcTargetEditPage clears cert pin when URL changes and saves target', (
    tester,
  ) async {
    const existing = BmcTarget(
      id: 'b-edit',
      name: 'old-bmc',
      addr: 'https://10.0.0.10',
      credId: 'c1',
      certSha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      serverId: 'missing-server',
    );
    Stores.bmcTarget.put(existing);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const BmcTargetEditPage(
                args: BmcTargetEditArgs(target: existing),
              );
            },
          ),
        ),
      ),
    );
    await settle(tester);

    // Cert is initially pinned; stale `missing-server` shows no clear X icon.
    expect(find.textContaining('aaaaaaaaaaaaaaaa'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget); // only the cert clear button

    // Changing the URL immediately invalidates the old cert pin.
    final addrField = find.widgetWithText(TextField, 'https://10.0.0.10');
    await tester.enterText(addrField, 'https://10.0.0.20');
    await tester.pump();
    expect(find.text(l10n.bmcCertUnreviewed), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    final saved = Stores.bmcTarget.fetchOne('b-edit');
    expect(saved?.addr, 'https://10.0.0.20');
    expect(saved?.certSha256, isNull);
  });

  testWidgets('BmcTargetEditPage name-only edit preserves synced addr and certSha256', (
    tester,
  ) async {
    const original = BmcTarget(
      id: 'b-sync-edit',
      name: 'old-name',
      addr: 'https://10.0.0.10',
      credId: 'c1',
      certSha256: '1111111111111111111111111111111111111111111111111111111111111111',
    );
    Stores.bmcTarget.put(original);

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
          home: Consumer(
            builder: (context, ref, _) {
              l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              container = ProviderScope.containerOf(context);
              return const BmcTargetEditPage(
                args: BmcTargetEditArgs(target: original),
              );
            },
          ),
        ),
      ),
    );
    await settle(tester);

    // Background sync updates addr and certSha256 while editor is open.
    container.read(bmcTargetsProvider.notifier).update(
      original,
      original.copyWith(
        addr: 'https://10.0.0.99',
        certSha256: '2222222222222222222222222222222222222222222222222222222222222222',
      ),
    );
    await tester.pump();

    // User only edits the name and saves.
    final nameField = find.widgetWithText(TextField, 'old-name');
    await tester.enterText(nameField, 'renamed-bmc');
    await tester.pump();
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);

    final saved = Stores.bmcTarget.fetchOne('b-sync-edit');
    expect(saved?.name, 'renamed-bmc');
    expect(saved?.addr, 'https://10.0.0.99');
    expect(
      saved?.certSha256,
      '2222222222222222222222222222222222222222222222222222222222222222',
    );
  });
}

final class _DetailFakeBmc extends BmcNotifier {
  _DetailFakeBmc(this._initial);

  final BmcState _initial;
  final locatorCalls = <(bool, int?)>[];

  @override
  BmcState build(String targetId) => _initial;

  void setPowering(bool v) => state = state.copyWith(isPowering: v);

  @override
  Future<BmcPowerResult> setLocator(
    bool lit, {
    int? expectedGeneration,
  }) async {
    locatorCalls.add((lit, expectedGeneration));
    return BmcPowerResult.confirmed;
  }
}
