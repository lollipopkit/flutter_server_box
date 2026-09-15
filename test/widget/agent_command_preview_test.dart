import 'package:fl_lib/fl_lib.dart';
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

  group('fenceAgentCommand', () {
    test('tags the block with the language it was given', () {
      expect(
        fenceAgentCommand('ls -la', language: 'shell'),
        '```shell\nls -la\n```',
      );
      expect(
        fenceAgentCommand('/etc/hosts', language: 'text'),
        '```text\n/etc/hosts\n```',
      );
    });

    test('outgrows a command that contains a fence of its own', () {
      // Command substitution is ordinary shell, and a run of three or more
      // backticks reaches a three-tick fence's length.
      expect(
        fenceAgentCommand('echo `date`', language: 'shell'),
        '```shell\necho `date`\n```',
      );
      expect(
        fenceAgentCommand('cat <<EOF\n```\nEOF', language: 'shell'),
        '````shell\ncat <<EOF\n```\nEOF\n````',
      );
      expect(
        fenceAgentCommand('echo "`````"', language: 'shell'),
        '``````shell\necho "`````"\n``````',
      );
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
      expect(find.byType(SimpleMarkdown), findsOneWidget);

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

      // `.first` is the outer one. A code block carries a horizontal scroll
      // view of its own, and that is not the one being asked about here.
      final scrollView = find
          .descendant(
            of: find.byType(AgentCommandPreview),
            matching: find.byType(SingleChildScrollView),
          )
          .first;
      final scrollable = find
          .descendant(of: scrollView, matching: find.byType(Scrollable))
          .first;

      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      await tester.drag(scrollable, const Offset(0, -120));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
    });

    testWidgets('renders the command as a block, fence and all kept out', (
      tester,
    ) async {
      useReportedPhone(tester);

      await tester.pumpWidget(
        dialogWith(const AgentCommandPreview(text: 'echo `date`')),
      );
      await tester.pump();

      Finder shows(String text) => find.descendant(
        of: find.byType(AgentCommandPreview),
        matching: find.textContaining(text),
      );

      // The command reaches the screen; the fence that carried it there and
      // the language it was tagged with do not.
      expect(shows('echo `date`'), findsOneWidget);
      expect(shows('```'), findsNothing);
      expect(shows('shell'), findsNothing);
    });

    testWidgets('scrolls one long line sideways instead of growing', (
      tester,
    ) async {
      useReportedPhone(tester);

      await tester.pumpWidget(
        dialogWith(AgentCommandPreview(text: 'echo ${'x' * 4000}')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // One line stays one line: the block scrolls sideways rather than
      // wrapping, so the cap is not what is holding it in.
      expect(
        tester.getRect(find.byType(AgentCommandPreview)).height,
        lessThan(askAiCommandPreviewMaxHeightFor(800)),
      );
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
