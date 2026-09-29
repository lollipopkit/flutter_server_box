import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/widget/agent_common.dart';
import 'package:server_box/view/widget/agent_entry_appear.dart';

/// What the Agent's timeline does when the device asks for less movement:
/// entries fade without lifting, and following the conversation jumps rather
/// than scrolls.
void main() {
  Widget wrap(Widget child, {required bool reduce}) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Scaffold(body: child),
    ),
  );

  Offset entryStart(WidgetTester tester) {
    final slide = tester.widget<SlideTransition>(
      find.descendant(
        of: find.byType(AgentEntryAppear),
        matching: find.byType(SlideTransition),
      ),
    );
    return slide.position.value;
  }

  group('AgentEntryAppear', () {
    testWidgets('lifts into place', (tester) async {
      await tester.pumpWidget(
        wrap(const AgentEntryAppear(child: Text('entry')), reduce: false),
      );
      expect(entryStart(tester).dy, greaterThan(0));
    });

    testWidgets('only fades under reduced motion', (tester) async {
      await tester.pumpWidget(
        wrap(const AgentEntryAppear(child: Text('entry')), reduce: true),
      );
      expect(entryStart(tester), Offset.zero);
      final fade = tester.widget<FadeTransition>(
        find.descendant(
          of: find.byType(AgentEntryAppear),
          matching: find.byType(FadeTransition),
        ),
      );
      expect(fade.opacity.value, lessThan(1));
    });
  });

  group('scheduleAgentAutoScroll', () {
    Future<ScrollController> pumpList(
      WidgetTester tester, {
      required bool reduce,
    }) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        wrap(
          ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 100; i++)
                SizedBox(height: 40, child: Text('$i')),
            ],
          ),
          reduce: reduce,
        ),
      );
      return controller;
    }

    testWidgets('scrolls to the bottom over several frames', (tester) async {
      final controller = await pumpList(tester, reduce: false);
      scheduleAgentAutoScroll(controller, force: true);
      await tester.pump();
      final max = controller.position.maxScrollExtent;
      expect(controller.offset, lessThan(max));
      await tester.pumpAndSettle();
      expect(controller.offset, max);
    });

    testWidgets('jumps to the bottom under reduced motion', (tester) async {
      final controller = await pumpList(tester, reduce: true);
      scheduleAgentAutoScroll(controller, force: true);
      await tester.pump();
      expect(controller.offset, controller.position.maxScrollExtent);
    });
  });
}
