import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/widget/group_title.dart';

/// The heading measures its name as `Text` draws it: with the inherited
/// style merged in, so a long summary leaves the rule its room.
void main() {
  testWidgets('an inherited style counts when the name is measured', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          // Wider than the heading's own style alone: what a configured
          // font does to the name.
          child: DefaultTextStyle(
            style: const TextStyle(wordSpacing: 60),
            child: GroupTitle(
              'a b c',
              right: 'x' * 200,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
    );

    // No overflow, and the rule keeps its minimum.
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(Divider)).width, closeTo(17, 1));
  });
}
