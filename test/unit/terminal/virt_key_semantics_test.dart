import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/view/widget/virt_key_semantics.dart';

Widget _key(VirtKey item, {bool armed = false}) => MaterialApp(
  home: Scaffold(
    body: VirtKeySemantics(
      item: item,
      armed: armed,
      child: InkWell(
        onTap: () {},
        child: ExcludeSemantics(
          child: item.icon != null ? Icon(item.icon) : Text(item.text),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a modifier says whether it is armed', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_key(VirtKey.ctrl, armed: true));
    expect(
      tester.getSemantics(find.byType(VirtKeySemantics)),
      matchesSemantics(
        label: 'Control',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('an icon key is named, once', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_key(VirtKey.up));
    expect(
      tester.getSemantics(find.byType(VirtKeySemantics)),
      isSemantics(
        label: 'Up arrow',
        isButton: true,
        hasToggledState: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  test('every key has a name', () {
    for (final key in VirtKey.values) {
      expect(key.semanticLabel, isNotEmpty, reason: key.name);
    }
  });
}
