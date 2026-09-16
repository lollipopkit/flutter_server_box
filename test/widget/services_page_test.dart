import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/service/service_manager.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/service_detail.dart';
import 'package:server_box/view/page/services.dart';

import '../helpers/spi_fixture.dart';

final class _Fixed extends ServicesNotifier {
  _Fixed(this._state);

  final ServicesState _state;

  @override
  ServicesState build(Spi spi) => _state;

  @override
  Future<void> getServices() async {}
}

ServiceUnit _unit(
  String name,
  ServiceState state, {
  ServiceUnitType type = ServiceUnitType.service,
  ServiceScope scope = ServiceScope.system,
  String? unitFileState = 'enabled',
  String? result,
  int? exitStatus,
  int? memory,
  Duration? since,
}) {
  return ServiceUnit(
    name: name,
    type: type,
    scope: scope,
    state: state,
    description: 'The $name unit, described at some length to test ellipsis',
    unitFileState: unitFileState,
    enabled: unitFileState == 'enabled',
    result: result,
    exitStatus: exitStatus,
    memoryBytes: memory,
    since: since == null ? null : DateTime.now().subtract(since),
    actions: serviceActions(state, enabled: unitFileState == 'enabled'),
  );
}

final _units = [
  _unit(
    'nginx',
    ServiceState.failed,
    result: 'exit-code',
    exitStatus: 1,
    since: const Duration(minutes: 3),
  ),
  _unit('docker', ServiceState.starting, since: const Duration(seconds: 4)),
  _unit(
    'postgresql@13-main-with-a-rather-long-instance-name',
    ServiceState.running,
    memory: 494 << 20,
    since: const Duration(days: 31),
  ),
  _unit('sshd', ServiceState.running, memory: 8 << 20),
  _unit(
    'gpg-agent',
    ServiceState.running,
    type: ServiceUnitType.socket,
    scope: ServiceScope.user,
  ),
  _unit('dirmngr', ServiceState.stopped, unitFileState: 'disabled'),
  _unit('apt-daily', ServiceState.running, type: ServiceUnitType.timer),
];

void main() {
  final spi = spiFixture(name: 'hk', id: 'hk', ip: '10.0.0.1');

  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          servicesProvider(spi).overrideWith(
            () => _Fixed(
              ServicesState(
                units: _units,
                manager: ServiceManagerType.systemd,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return page;
            },
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the search field keeps a frame scheduled.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final page = ServicesPage(args: SpiRequiredArgs(spi));

  testWidgets('phone: failed units first, as cards, and nothing overflows', (
    tester,
  ) async {
    await pump(tester, page, size: const Size(393, 852));

    expect(tester.takeException(), isNull);
    expect(find.text('需要处理'), findsOneWidget);
    expect(find.text('其余 5 个单元'), findsOneWidget);
    // A failed unit's card carries its restart.
    expect(find.widgetWithText(FilledButton, '重启'), findsOneWidget);
    expect(find.text('failed · exit-code · 退出状态 1'), findsOneWidget);
    // No column header on a phone.
    expect(find.text('单元'), findsNothing);
  });

  testWidgets('desktop: a table, and picking a count narrows it', (
    tester,
  ) async {
    await pump(tester, page, size: const Size(940, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('开机自启'), findsOneWidget);
    expect(find.text('1 failed'), findsOneWidget);

    await tester.tap(find.text('1 inactive'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('dirmngr.service'), findsOneWidget);
    expect(find.text('sshd.service'), findsNothing);
    // The heading would only repeat what the filter says.
    expect(find.text('需要处理'), findsNothing);
  });

  testWidgets('wide: a unit opens beside the list, which gives up its columns', (
    tester,
  ) async {
    await pump(tester, page, size: const Size(1240, 800));
    expect(find.text('单元'), findsOneWidget);

    await tester.tap(find.text('nginx.service'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(ServiceDetailView), findsOneWidget);
    // The list is stacked rows now: no column header, whose first column is
    // the one label the pane does not also use.
    expect(find.text('单元'), findsNothing);
    expect(find.text('类型'), findsOneWidget);

    await tester.tap(find.byTooltip(libL10n.close));
    await tester.pump();
    expect(find.byType(ServiceDetailView), findsNothing);
  });

  testWidgets('detail page on a phone fits', (tester) async {
    await pump(
      tester,
      ServiceDetailPage(
        args: ServiceDetailPageArgs(spi: spi, unitKey: 'system:nginx.service'),
      ),
      size: const Size(393, 852),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('开机自启'), findsOneWidget);
    expect(find.textContaining('failed · exit-code'), findsOneWidget);
  });
}
