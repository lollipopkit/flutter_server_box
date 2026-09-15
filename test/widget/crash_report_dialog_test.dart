import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/crash_report_dialog.dart';

/// The report is reached from a settings page now rather than from a toast, and
/// that move is what these are about.
///
/// `showRoundDialog` puts the dialog on the **root** navigator while the page
/// that opened it is on another, so a button that pops the wrong one closes the
/// page, leaves the dialog on screen and never completes the future the caller
/// is waiting on — which here decides whether the row that opened it stays.
/// Nothing about that shows up as an error.
///
/// Deliberately without `CrashLog.attach`: `CrashReport.savedPath` is then null
/// and dropping is a no-op, so the delete button's answer is exercised without
/// a real file write. A `testWidgets` body runs in a fake-async zone, and a
/// real file operation started there completes on a callback that zone never
/// pumps. What the drop actually does to the file is held by
/// `crash_report_collect_test.dart`, which is not a widget test.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const report = '### Environment\n\n- App: 1553\n\n### Log\n\n```\nboom\n```';

  /// A page on its own navigator, which is what a settings page is, with the
  /// dialog raised from it.
  ///
  /// Answers the list the dialog's result lands in — a list rather than a value
  /// so that "has not answered yet" and "answered false" stay distinguishable,
  /// which is the difference between a future that never completed and one that
  /// did.
  Future<List<bool>> open(WidgetTester tester) async {
    final answer = <bool>[];
    var pageAlive = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (ctx) {
              pageAlive = true;
              return Scaffold(
                body: Builder(
                  builder: (inner) => TextButton(
                    onPressed: () async {
                      answer.add(await CrashReportDialog.show(inner, report));
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(pageAlive, isTrue);
    return answer;
  }

  /// Lets the dialog's exit animation and the awaited future finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('shows the report and says to read it', (tester) async {
    await open(tester);

    expect(find.text(l10n.crashReportTitle), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    // The claim the report is not anonymous, which is the reason this is shown
    // rather than sent.
    expect(find.text(l10n.crashReportHint), findsOneWidget);
  });

  testWidgets('offers all three answers', (tester) async {
    await open(tester);

    expect(find.text(libL10n.delete), findsOneWidget);
    expect(find.text(libL10n.copy), findsOneWidget);
    expect(find.text(l10n.crashReportSubmit), findsOneWidget);
  });

  testWidgets('deleting closes the dialog, not the page, and answers false', (
    tester,
  ) async {
    final answer = await open(tester);

    await tester.tap(find.text(libL10n.delete));
    await settle(tester);

    // The page underneath is still there: a `context.pop()` here would have
    // closed it and left the dialog up.
    expect(find.text('open'), findsOneWidget);
    expect(find.text(l10n.crashReportTitle), findsNothing);
    // And the caller heard back, which a dialog popped on the wrong navigator
    // never lets happen — the row that opened this would have stayed on a
    // report that is gone.
    expect(answer, [false]);
  });

  testWidgets('dismissing it leaves the report alone', (tester) async {
    final answer = await open(tester);

    // Tapped outside, which is how a dialog is refused. The caller has to read
    // that as "still there" rather than as any of the three answers.
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    expect(find.text(l10n.crashReportTitle), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(answer, [true]);
  });
}
