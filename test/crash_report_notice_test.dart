import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/crash_report_notice.dart';

/// The notice is a toast and not a dialog, which is the whole of what these
/// hold: the app has just started, and what the previous run did is not worth
/// standing in front of whatever this launch was opened to do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(CrashLog.resetForTest);

  /// Raises the notice the way `home.dart` does — once, from a callback, and
  /// not from a build that may run again.
  ///
  /// The toasts are cleared while the tree is still up: one raised here never
  /// times out, and `Toast` keeps its stack in a static that outlives a test.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Where the app puts it, and what a toast needs to appear at all.
        builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
        home: const Scaffold(body: SizedBox()),
      ),
    );
    addTearDown(() async {
      Toast.dismissAll();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    });

    CrashReportNotice.showIfNeeded(tester.element(find.byType(Scaffold)));
    // Counted out: the toast animates in, and a tree holding one always has
    // something scheduled.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a launch after a crash says so, without a dialog', (
    tester,
  ) async {
    CrashLog.reportPreviousRunCrashed();

    await pump(tester);

    expect(find.text(l10n.crashNoticeBody), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(libL10n.view), findsOneWidget);
  });

  testWidgets('and stays until it is dismissed', (tester) async {
    // A toast that timed out would lose the log: the marker is read once and
    // cleared, and outside a debug build the button on this notice is the only
    // way to the report.
    CrashLog.reportPreviousRunCrashed();

    await pump(tester);
    await tester.pump(const Duration(minutes: 1));

    expect(find.text(l10n.crashNoticeBody), findsOneWidget);
  });

  testWidgets('an ordinary launch says nothing', (tester) async {
    await pump(tester);

    expect(find.text(l10n.crashNoticeBody), findsNothing);
  });
}
