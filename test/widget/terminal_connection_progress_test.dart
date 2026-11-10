import 'package:fl_lib/generated/l10n/lib_l10n_en.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/generated/l10n/l10n_en.dart';
import 'package:server_box/view/page/ssh/widget/terminal_connection_progress.dart';

void main() {
  final en = AppLocalizationsEn();
  final libEn = LibLocalizationsEn();
  Future<void> pumpProgress(
    WidgetTester tester,
    TerminalConnectionStep step, {
    VoidCallback? onRetry,
    String? failureDetail,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        ...appLocalizationsDelegates,
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

    expect(find.text(libEn.terminal), findsOneWidget);
    expect(find.text(en.connecting), findsOneWidget);
    expect(find.text(en.status), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pumpProgress(tester, TerminalConnectionStep.openingShell);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text(en.userOpenShell), findsOneWidget);
    expect(find.text(en.status), findsNothing);
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

    expect(find.text('${en.userOpenShell} · ${libEn.fail}'), findsOneWidget);
    expect(find.text(en.status), findsNothing);
    expect(find.text('Terminal access is disabled'), findsOneWidget);
    await tester.tap(find.text(libEn.retry));
    expect(retries, 1);
  });
}
