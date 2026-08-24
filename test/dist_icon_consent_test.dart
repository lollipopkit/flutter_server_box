/// The terms that go up before a mark address is saved.
///
/// The gate moved when the on/off switch did: there is no switch any more, so
/// the moment worth asking at is the one where an address is set and marks
/// start appearing. `_buildServerMarkUrl` calls this; what it must not do is
/// ask when the address is being *cleared*, which is how marks are turned off.
///
/// What can break silently: the dialog stops carrying the terms, or it returns
/// agreement for an answer that was not one — a dismissal, or a cancel.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/dist_icon.dart';

/// A button that asks, and a label showing what came back — so "what the user
/// tapped" and "what the caller was told" are two separate observations.
Widget _app(void Function(bool) onAnswer) => MaterialApp(
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
          child: TextButton(
            onPressed: () async => onAnswer(await confirmDistIconTerms(context)),
            child: const Text('ask'),
          ),
        ),
      );
    },
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the terms and the choice are both on screen', (tester) async {
    await tester.pumpWidget(_app((_) {}));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    // The sentence that makes it a choice rather than a notice...
    expect(find.text(app_locale.l10n.distIconConsent), findsOneWidget);
    // ...and the terms it is a choice about.
    expect(find.textContaining('trademark'), findsOneWidget);
  });

  testWidgets('accepting answers yes', (tester) async {
    bool? answer;
    await tester.pumpWidget(_app((v) => answer = v));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(libL10n.ok));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, isTrue);
  });

  testWidgets('cancelling answers no', (tester) async {
    // The failure worth catching: collecting an answer and reporting the
    // opposite, which would save the address anyway.
    bool? answer;
    await tester.pumpWidget(_app((v) => answer = v));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(libL10n.cancel));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, isFalse);
  });

  testWidgets('and dismissing it is not agreement', (tester) async {
    // Tapping outside pops nothing, so the dialog answers null. Read as `true`
    // that would be consent nobody gave.
    bool? answer;
    await tester.pumpWidget(_app((v) => answer = v));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, isFalse);
  });
}
