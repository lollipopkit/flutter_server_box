import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/ssh/text_view.dart';
import 'package:xterm/core.dart';

void main() {
  testWidgets('shows the output and follows it', (tester) async {
    final terminal = Terminal()
      ..resize(40, 5)
      ..write('first\r\n');
    await tester.pumpWidget(
      MaterialApp(home: TerminalTextPage(args: terminal)),
    );
    expect(find.text('first'), findsOneWidget);

    terminal.write('second');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('second'), findsOneWidget);

    // Gone with the page, or a write here would rebuild a disposed state.
    await tester.pumpWidget(const SizedBox());
    terminal.write('\r\nthird');
    await tester.pump(const Duration(milliseconds: 300));
  });
}
