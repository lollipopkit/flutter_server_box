import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/view/page/server/card/notices.dart';
import 'package:server_box/view/page/server/metric_row.dart';

const _side = BorderSide(color: Color(0xFFFF0000), width: 2);

const _notice = ServerNotice(
  kind: ServerNoticeKind.plainHttp,
  glyph: Icons.error_outline,
  title: 'Failed',
  mono: 'SSHHandshakeError(Handshake timed out)',
);

void main() {
  // A theme whose cards are outlined, as some store themes are.
  Future<void> pump(WidgetTester tester, double openness) =>
      tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            cardTheme: const CardThemeData(
              shape: RoundedRectangleBorder(side: _side),
            ),
          ),
          home: Scaffold(
            body: ServerCardNotice(
              notice: _notice,
              form: ServerNoticeForm.page,
              openness: openness,
            ),
          ),
        ),
      );

  testWidgets("on the card, the machine's words have no outline of their own", (
    tester,
  ) async {
    await pump(tester, 0);
    expect(find.text(_notice.mono), findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(_notice.mono),
        matching: find.byType(FadingCard),
      ),
      findsNothing,
    );
  });

  testWidgets('on the page they are a card, outlined as the theme says', (
    tester,
  ) async {
    await pump(tester, 1);
    final card = tester.widget<Material>(
      find.descendant(
        of: find.ancestor(
          of: find.text(_notice.mono),
          matching: find.byType(FadingCard),
        ),
        matching: find.byType(Material),
      ),
    );
    expect((card.shape! as RoundedRectangleBorder).side, _side);
  });
}
