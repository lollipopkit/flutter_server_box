/// Turning the marks on puts the terms up first, and a "no" is a no.
///
/// Two ways this breaks and still looks right on screen: the dialog stops
/// being shown, so the setting flips with nothing on screen to have read; or
/// the answer is collected and the setting is written anyway. The dialog is
/// [confirmDistIconTerms] and the gate is `StoreSwitch`'s `validator`, which
/// writes nothing when it declines — both are exercised here.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/dist_icon.dart';

import 'helpers/test_db.dart';

/// The tile's shape: the same switch over the same property, behind the same
/// gate. The tile itself is `part of entry.dart` and cannot be built without
/// the whole settings page, so this is the closest thing that stays a unit.
Widget _app(SettingStore setting, {void Function()? onAsk}) => MaterialApp(
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
      return Scaffold(
        body: Center(
          child: StoreSwitch(
            prop: setting.showDistIcon,
            validator: (enabling) async {
              if (!enabling) return true;
              onAsk?.call();
              return confirmDistIconTerms(context);
            },
          ),
        ),
      );
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore.forTest()..init();
  });

  tearDown(SqliteDb.close);

  testWidgets('the terms go up, and nothing is written until answered', (
    tester,
  ) async {
    setting.showDistIcon.put(false);
    await tester.pumpWidget(_app(setting));

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    // The sentence that makes it a choice rather than a notice, and the terms
    // it is a choice about.
    expect(find.text(app_locale.l10n.distIconConsent), findsOneWidget);
    expect(find.textContaining('font-logos'), findsOneWidget);
    expect(
      setting.showDistIcon.fetch(),
      isFalse,
      reason: 'nothing may be written while the question is still on screen',
    );

    await tester.tap(find.text(libL10n.ok));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(setting.showDistIcon.fetch(), isTrue);
  });

  testWidgets('declining leaves them off', (tester) async {
    // The failure worth catching: collecting an answer and ignoring it.
    setting.showDistIcon.put(false);
    await tester.pumpWidget(_app(setting));

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(libL10n.cancel));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(setting.showDistIcon.fetch(), isFalse);
  });

  testWidgets('switching them off asks nothing', (tester) async {
    // Agreement is to displaying the marks. Stopping needs agreement to
    // nothing, and a dialog there would make "no longer show these" a second
    // decision to get through.
    setting.showDistIcon.put(true);
    var asked = false;
    await tester.pumpWidget(_app(setting, onAsk: () => asked = true));

    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 300));

    expect(asked, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(setting.showDistIcon.fetch(), isFalse);
  });
}
