import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/launch_failed.dart';
import 'package:server_box/view/page/rescue_app.dart';

/// What a launch that threw shows instead of no window at all (#1633).
void main() {
  const err = FormatException('Unexpected character (at character 1)');

  testWidgets('it says it failed, what was thrown, and where the logs are', (tester) async {
    await tester.pumpWidget(
      RescueApp(
        page: LaunchFailedPage(err: err, stack: StackTrace.empty, logDir: r'C:\ServerBox\logs'),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.launchFailedTitle), findsOneWidget);
    expect(find.textContaining('Unexpected character'), findsOneWidget);
    expect(find.text(l10n.launchFailedLogs(r'C:\ServerBox\logs')), findsOneWidget);
  });

  testWidgets('without a log directory, it leaves that line out', (tester) async {
    await tester.pumpWidget(
      RescueApp(page: LaunchFailedPage(err: err, stack: StackTrace.empty)),
    );
    await tester.pump();

    expect(find.text(l10n.launchFailedTitle), findsOneWidget);
    expect(find.textContaining(l10n.launchFailedLogs('')), findsNothing);
  });
}
