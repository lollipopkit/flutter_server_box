import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/tab/selection_bar.dart';

void main() {
  // The narrowest phone width, with the text a user may have turned up. The
  // bar's buttons are fixed-size icons, so what grows is the count beside
  // them — and at 320pt it pushed the last of them past the edge even at the
  // default size.
  for (final scale in [1.0, 2.0]) {
    testWidgets('fits 320pt at text scale $scale with every action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            appBar: ServerSelectionBar(
              count: 128,
              total: 256,
              onClose: () {},
              onConnect: () {},
              onDisconnect: () {},
              onTag: () {},
              onMove: () {},
              onDelete: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      for (final icon in [
        Icons.close,
        Icons.link,
        Icons.link_off,
        MingCute.hashtag_line,
        Icons.swap_vert,
        Icons.delete,
      ]) {
        final rect = tester.getRect(find.byIcon(icon));
        expect(rect.right, lessThanOrEqualTo(320), reason: '$icon');
      }
    });
  }
}
