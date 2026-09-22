import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/terminal_connection_progress.dart';

void main() {
  Future<void> pumpProgress(
    WidgetTester tester,
    TerminalConnectionStep step, {
    VoidCallback? onRetry,
    String? failureDetail,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        LibLocalizations.delegate,
        ...AppLocalizations.localizationsDelegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TerminalConnectionProgress(
          step: step,
          failureDetail: failureDetail,
          onRetry: onRetry ?? () {},
        ),
      ),
    ),
  );

  testWidgets('waiting shows only the terminal connection', (tester) async {
    await pumpProgress(tester, TerminalConnectionStep.connecting);

    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpProgress(tester, TerminalConnectionStep.openingShell);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Open shell'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
  });

  testWidgets('failure identifies the terminal step and offers retry', (
    tester,
  ) async {
    var retries = 0;
    await pumpProgress(
      tester,
      TerminalConnectionStep.shellFailed,
      failureDetail: 'Terminal access is disabled',
      onRetry: () => retries++,
    );

    expect(find.text('Open shell · Failure'), findsOneWidget);
    expect(find.text('Status'), findsNothing);
    expect(find.text('Terminal access is disabled'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
