import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/bmc/card_body.dart';
import 'package:server_box/view/page/bmc/detail_sections.dart';

import '../helpers/rust_lib_helper.dart';

final class _FakeBmcNotifier extends BmcNotifier {
  _FakeBmcNotifier(this._initial);
  final BmcState _initial;

  @override
  BmcState build(String targetId) => _initial;
}

void main() {
  setUpAll(initRustLibForTest);

  const target = BmcTarget(
    id: 'bmc-1',
    name: 'Rack Node',
    addr: 'https://10.0.0.5',
  );

  const system = RedfishSystem(
    powerState: PowerState.on_,
    resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
    resetTypes: ['GracefulShutdown', 'ForceRestart', 'On'],
    model: 'PowerEdge R750',
    health: 'Warning',
    logServices: '/redfish/v1/Systems/1/LogServices',
    storage: '/redfish/v1/Systems/1/Storage',
    locator: Locator(lit: true, legacy: false),
  );

  const topology = RedfishTopology(
    root: RedfishRoot(systems: '/redfish/v1/Systems'),
    systemPath: '/redfish/v1/Systems/1',
    system: system,
    hasMultipleSystems: false,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    BmcState bmcState = const BmcState(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bmcProvider(target.id).overrideWith(() => _FakeBmcNotifier(bmcState)),
        ],
        child: MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return Scaffold(body: SingleChildScrollView(child: child));
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('BmcCardBody renders watts, warning badge, and failure states', (
    tester,
  ) async {
    const powered = BmcSummaryState(
      watts: 185,
      topology: topology,
    );
    expect(BmcCardBody.hasContent(powered), isTrue);
    await pump(
      tester,
      const BmcCardBody(target: target, summary: powered),
    );
    expect(find.text('185 W'), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);

    const failed = BmcSummaryState(
      failure: RedfishFailure.unreachable,
      failureDetail: 'Connection refused',
    );
    await pump(
      tester,
      const BmcCardBody(target: target, summary: failed),
    );
    expect(find.text('Connection refused'), findsOneWidget);
  });

  testWidgets('BmcManageCard, BmcSensorsSection, and BmcPowerBar render data', (
    tester,
  ) async {
    const state = BmcState(
      topology: topology,
      sensorsTruncated: true,
      sensors: BmcSensors(
        watts: 210,
        temperatures: [BmcReading(name: 'Inlet', value: 24, unit: 'C')],
        fans: [BmcReading(name: 'Fan1', value: 4200, unit: 'RPM')],
      ),
    );
    expect(BmcManageCard.hasContent(state), isTrue);
    expect(BmcSensorsSection.hasContent(state), isTrue);

    await pump(
      tester,
      const Column(
        children: [
          BmcPowerBar(target: target, bmc: state, needsCert: false),
          BmcManageCard(target: target, bmc: state),
          BmcSensorsSection(bmc: state),
        ],
      ),
      bmcState: state,
    );

    expect(find.text(libL10n.logs), findsOneWidget);
    expect(find.text(app_locale.l10n.bmcDrives), findsOneWidget);
    expect(find.text(app_locale.l10n.bmcLocator), findsOneWidget);
    expect(find.text('Inlet'), findsOneWidget);
    expect(find.text('Fan1'), findsOneWidget);
    expect(find.text(app_locale.l10n.bmcSensorsTruncated), findsOneWidget);
  });
}
