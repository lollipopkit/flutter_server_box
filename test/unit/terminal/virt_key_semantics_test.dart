import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/terminal/virtual_key.dart';
import 'package:server_box/view/page/ssh/widget/virtual_key_semantics.dart';

Widget _key(VirtualKey item, {bool armed = false}) => MaterialApp(
  home: Scaffold(
    body: VirtualKeySemantics(
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
    await tester.pumpWidget(_key(VirtualKey.ctrl, armed: true));
    expect(
      tester.getSemantics(find.byType(VirtualKeySemantics)),
      matchesSemantics(
        label: l10n.keyControl,
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
    await tester.pumpWidget(_key(VirtualKey.up));
    expect(
      tester.getSemantics(find.byType(VirtualKeySemantics)),
      isSemantics(
        label: l10n.keyArrowUp,
        isButton: true,
        hasToggledState: false,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a key named by what it does is not hinted the same', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    for (final item in [VirtualKey.ime, VirtualKey.sudo]) {
      await tester.pumpWidget(_key(item));
      final data = tester
          .getSemantics(find.byType(VirtualKeySemantics))
          .getSemanticsData();
      expect(data.label, item.semanticLabel, reason: item.name);
      expect(data.hint, isEmpty, reason: item.name);
    }
    await tester.pumpWidget(_key(VirtualKey.sftp));
    final sftp = tester
        .getSemantics(find.byType(VirtualKeySemantics))
        .getSemanticsData();
    expect(sftp.hint, VirtualKey.sftp.help);
    handle.dispose();
  });

  test('every key has a name', () {
    for (final key in VirtualKey.values) {
      expect(key.semanticLabel, isNotEmpty, reason: key.name);
    }
  });
}
