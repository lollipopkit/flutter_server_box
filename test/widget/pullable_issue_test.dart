import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/pullable_issue.dart';

void main() {
  Future<int> pulls(WidgetTester tester, {String? detail}) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async => refreshed++,
            child: PullableIssueView(title: 'failed', detail: detail, onRetry: () {}),
          ),
        ),
      ),
    );
    await tester.fling(find.text('failed'), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    return refreshed;
  }

  testWidgets('a short issue fills the page and can be pulled', (tester) async {
    expect(await pulls(tester), 1);
    final page = tester.getSize(find.byType(Scaffold));
    final issue = tester.getSize(find.byType(PageIssueView));
    expect(issue.height, page.height);
  });

  testWidgets('a long detail scrolls with the page, which can still be pulled', (tester) async {
    final detail = List.filled(400, 'stderr line').join('\n');
    expect(await pulls(tester, detail: detail), 1);
    final page = tester.getSize(find.byType(Scaffold));
    expect(tester.getSize(find.byType(PageIssueView)).height, greaterThan(page.height));
  });
}
