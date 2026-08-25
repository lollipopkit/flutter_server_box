/// The terms that go up before a mark address is saved.
///
/// Shown when the marks switch is turned on, and not when it is turned off:
/// stopping is agreement to nothing.
///
/// The terms are `assets/distro/README.md` itself, so they cannot drift from
/// the record of which licence permits shipping which mark. The accept button
/// waits three seconds — a dialog whose only button is already under the thumb
/// is one that gets dismissed without a glance.
///
/// What can break silently: the terms stop being carried, the pause stops
/// being enforced, or agreement is reported for an answer that was not one —
/// a dismissal, or a cancel.
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

  testWidgets('the README is what goes up', (tester) async {
    await tester.pumpWidget(_app((_) {}));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));
    // The asset load is a future; give it a frame to land.
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget);
    // Lines only the README has, so a fallback to the short notice fails here.
    expect(find.textContaining('CC BY-SA'), findsWidgets);
    expect(find.textContaining('nominative use'), findsWidgets);
  });

  testWidgets('and the accept button waits before it can be pressed', (
    tester,
  ) async {
    // Three seconds. The countdown is on the label so the wait is explained
    // rather than looking like a dead button.
    bool? answer;
    await tester.pumpWidget(_app((v) => answer = v));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));

    final ok = find.byType(TextButton).last;
    expect(tester.widget<TextButton>(ok).onPressed, isNull);
    await tester.tap(ok);
    await tester.pump(const Duration(milliseconds: 300));
    expect(answer, isNull, reason: 'a tap during the pause answers nothing');
    expect(find.byType(AlertDialog), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<TextButton>(find.byType(TextButton).last).onPressed,
        isNotNull);
  });

  testWidgets('accepting answers yes', (tester) async {
    bool? answer;
    await tester.pumpWidget(_app((v) => answer = v));
    await tester.tap(find.text('ask'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.byType(TextButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, isFalse);
  });
}
