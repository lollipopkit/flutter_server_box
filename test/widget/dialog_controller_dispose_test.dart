/// A dialog's controller outlives the dialog's answer.
///
/// `showRoundDialog` completes when the route is popped, while its fields are
/// still on screen animating out. Installing a theme from the URL dialog
/// rebuilt the whole app in that window, and a controller disposed in a
/// `finally` right after the answer was then used by the field again: "A
/// TextEditingController was used after being disposed", and a red screen for
/// good (duplicate GlobalKeys every frame after). The dialogs hand their
/// controllers to fl_lib's `DisposeWith` instead.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('an answer that rebuilds the app while the dialog leaves', (
    tester,
  ) async {
    final dark = ValueNotifier(false);
    addTearDown(dark.dispose);
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
                  final url = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      content: DisposeWith(
                        notifiers: [controller],
                        child: TextField(controller: controller, autofocus: true),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(controller.text),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  // What installing a theme does: the whole app rebuilds.
                  if (url != null) dark.value = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull, reason: 'frame $i');
    }
    expect(find.byType(TextField), findsNothing);
  });

  test('no dialog disposes its notifiers when it answers', () {
    // The shape that caused it: a `showRoundDialog` awaited in a `try` whose
    // `finally` disposes something — the field it built is still mounted.
    final shape = RegExp(
      r'showRoundDialog[\s\S]{0,2500}?\}\s*finally\s*\{\s*\w+\.dispose\(\);',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final text = f.readAsStringSync();
      for (final m in shape.allMatches(text)) {
        final between = m.group(0)!;
        // A later dialog in the same stretch is a different call.
        if ('showRoundDialog'.allMatches(between).length > 1) continue;
        offenders.add(
          '${f.path}:${text.substring(0, m.start).split('\n').length}',
        );
      }
    }
    expect(offenders, isEmpty, reason: 'use DisposeWith on the dialog child');
  });
}
