import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/detail/info_card.dart';

/// A public IPv6 address in the About card at phone width.
///
/// The value is 39 characters masked or not, and it used to be laid out at
/// its own width inside the row, pushing the reveal button out of the card.
void main() {
  const ipv6 = '2001:0db8:85a3:0000:0000:8a2e:0370:7334';

  Future<void> pumpCard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ServerDetailInfoCard(
            icon: Icons.info_outline,
            title: 'About',
            rows: [(k: 'Public IP', v: ipv6, secret: true)],
          ),
        ),
      ),
    );
  }

  testWidgets('masked, it fits', (tester) async {
    await pumpCard(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shown, it fits too', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('copies the whole address while it is masked', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCard(tester);
    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pump();
    expect(copied, ipv6);
    // Let the toast finish before the tree goes.
    await tester.pump(const Duration(seconds: 5));
  });
}
