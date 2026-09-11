import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/widget/agent_common.dart';

/// What a model proposes when it writes a script rather than a command: long
/// enough that an uncapped preview reaches the buttons that decide it (#1462).
final _longCommand = List.generate(
  60,
  (index) => "echo '>>> step $index' && sleep 1",
).join('\n');

void main() {
  group('askAiCommandPreviewMaxHeightFor', () {
    test('uses thirty percent of compact viewport heights', () {
      expect(askAiCommandPreviewMaxHeightFor(400), 120);
      expect(askAiCommandPreviewMaxHeightFor(600), 180);
    });

    test('caps tall viewport previews so review actions stay nearby', () {
      expect(askAiCommandPreviewMaxHeightFor(800), 240);
      expect(askAiCommandPreviewMaxHeightFor(1200), 240);
    });
  });

  group('AgentCommandPreview', () {
    /// The phone the report came from, sized the way `MediaQuery` reads it.
    void useReportedPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Widget dialogWith(Widget preview) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: AlertDialog(
              title: const Text('Run a high-risk command?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This may make changes that are hard to undo.'),
                  const SizedBox(height: 12),
                  preview,
                ],
              ),
              actions: [
                TextButton(onPressed: () {}, child: const Text('Cancel')),
                FilledButton(onPressed: () {}, child: const Text('Run')),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('keeps a long command clear of the dialog buttons', (
      tester,
    ) async {
      useReportedPhone(tester);

      await tester.pumpWidget(dialogWith(AgentCommandPreview(text: _longCommand)));
      await tester.pump();

      expect(tester.takeException(), isNull);

      final preview = tester.getRect(find.byType(AgentCommandPreview));
      expect(
        preview.height,
        lessThanOrEqualTo(askAiCommandPreviewMaxHeightFor(800)),
      );

      // The buttons are what the overflow landed on: text drawn past the
      // preview's box does not clip, so "below it" is the assertion that says
      // the labels are readable.
      for (final label in const ['Cancel', 'Run']) {
        expect(
          tester.getRect(find.text(label)).top,
          greaterThanOrEqualTo(preview.bottom),
          reason: '$label is drawn over by the command',
        );
      }
    });

    testWidgets('scrolls the part of the command it cannot show', (
      tester,
    ) async {
      useReportedPhone(tester);

      await tester.pumpWidget(dialogWith(AgentCommandPreview(text: _longCommand)));
      await tester.pump();

      final scrollView = find.descendant(
        of: find.byType(AgentCommandPreview),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scrollView, findsOneWidget);

      // `.first` is the outer one: a `SelectableText` carries a `Scrollable`
      // of its own, and that is the one that must not answer here.
      final scrollable = find
          .descendant(of: scrollView, matching: find.byType(Scrollable))
          .first;

      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.drag(scrollable, const Offset(0, -120));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('takes only the height a short command needs', (tester) async {
      useReportedPhone(tester);

      await tester.pumpWidget(dialogWith(const AgentCommandPreview(text: 'ls')));
      await tester.pump();

      expect(
        tester.getRect(find.byType(AgentCommandPreview)).height,
        lessThan(askAiCommandPreviewMaxHeightFor(800)),
      );
    });
  });
}
