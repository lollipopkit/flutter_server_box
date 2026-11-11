/// A sheet's field is never built on a controller its caller disposed.
///
/// Installing a theme from the URL sheet rebuilt the whole app while the sheet
/// was leaving, and a controller disposed right after the answer was then
/// used by the field again: "A TextEditingController was used after being
/// disposed", and a red screen for good (duplicate GlobalKeys every frame
/// after). `showSheet` answers once the sheet is off the screen, so what a
/// caller does with the answer is never under its exit.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('the app rebuilds while the sheet leaves', (tester) async {
    final dark = ValueNotifier(false);
    addTearDown(dark.dispose);
    String? answer;
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: dark,
        builder: (_, isDark, _) => MaterialApp(
          theme: isDark ? ThemeData.dark() : ThemeData.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  final controller = TextEditingController(text: 'https://x');
                  answer = await context.showSheet<String>(
                    childBuilder: (_) => TextField(controller: controller, autofocus: true),
                    actionsBuilder: (sheetContext) => [
                      TextButton(
                        onPressed: () {
                          sheetContext.popSheet(controller.text);
                          // What installing a theme does, as the sheet starts
                          // to leave: the whole app rebuilds under its exit.
                          dark.value = true;
                        },
                        child: const Text('OK'),
                      ),
                    ],
                  );
                  controller.dispose();
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('OK'));
    await tester.pump();
    // Rebuilt with the field still there, and the caller not yet answered.
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).theme!.brightness, Brightness.dark);
    expect(find.byType(TextField), findsOneWidget);
    expect(answer, isNull);

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $i');
      // Not answered while any of it is still on the screen.
      if (find.byType(TextField).evaluate().isNotEmpty) {
        expect(answer, isNull, reason: 'frame $i');
      }
    }
    expect(find.byType(TextField), findsNothing);
    expect(answer, 'https://x');
  });
}
