import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/bmc/bmc_credential.dart';
import 'package:server_box/data/provider/bmc/bmc_credential.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/bmc/credential/edit.dart';
import 'package:server_box/view/page/bmc/credential/list.dart';

final class _FakeBmcCredentialNotifier extends BmcCredentialNotifier {
  _FakeBmcCredentialNotifier({
    this.initialCreds = const [],
    this.usageCounts = const {},
  });

  final List<BmcCredential> initialCreds;
  final Map<String, int> usageCounts;

  @override
  BmcCredentialState build() => BmcCredentialState(creds: initialCreds);

  @override
  int serversUsing(String id) => usageCounts[id] ?? 0;
}

void main() {
  Future<void> pumpList(
    WidgetTester tester, {
    List<BmcCredential> creds = const [],
    Map<String, int> usageCounts = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bmcCredentialProvider.overrideWith(
            () => _FakeBmcCredentialNotifier(
              initialCreds: creds,
              usageCounts: usageCounts,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const BmcCredentialsListPage();
            },
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders empty state when no BMC credentials exist', (
    tester,
  ) async {
    await pumpList(tester);

    expect(find.text(libL10n.empty), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('renders credentials with shared count and opens edit page', (
    tester,
  ) async {
    const rack = BmcCredential(
      id: 'cred-1',
      name: 'Rack A',
      user: 'admin',
      pwd: 'secret',
    );
    const solo = BmcCredential(
      id: 'cred-2',
      name: 'Lab Box',
      user: 'root',
      pwd: 'secret',
    );
    await pumpList(
      tester,
      creds: const [rack, solo],
      usageCounts: const {'cred-1': 3, 'cred-2': 0},
    );

    expect(find.text('Rack A'), findsOneWidget);
    expect(
      find.text('admin - ${app_locale.l10n.bmcAccountShared(3)}'),
      findsOneWidget,
    );
    expect(find.text('Lab Box'), findsOneWidget);
    expect(find.text('root'), findsOneWidget);

    await tester.tap(find.text('Rack A'));
    await tester.pump();
    await tester.pump(Durations.medium4);

    expect(find.byType(BmcCredentialEditPage), findsOneWidget);
  });

  testWidgets('tapping FAB opens create credential page', (tester) async {
    await pumpList(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(Durations.medium4);

    expect(find.byType(BmcCredentialEditPage), findsOneWidget);
  });
}
