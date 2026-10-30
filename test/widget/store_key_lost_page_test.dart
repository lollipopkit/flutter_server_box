import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/store_key_lost.dart';

void main() {
  Future<List<bool>> pumpPage(WidgetTester tester, StoreUnreadableReason reason) async {
    final choices = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StoreKeyLostPage(
          err: StoreUnreadableException(reason, '/x/${SqliteDb.fileName}', null),
          onChoice: choices.add,
        ),
      ),
    );
    return choices;
  }

  testWidgets('keyLost asks with the missing-key text', (tester) async {
    await pumpPage(tester, StoreUnreadableReason.keyLost);
    expect(find.text(l10n.storeKeyLostAsk), findsOneWidget);
    expect(find.text(l10n.storeVaultFailedAsk), findsNothing);
  });

  testWidgets('vaultFailed asks with its own text, and both choices reach the caller', (tester) async {
    final choices = await pumpPage(tester, StoreUnreadableReason.vaultFailed);
    expect(find.text(l10n.storeVaultFailedAsk), findsOneWidget);
    expect(find.text(l10n.storeKeyLostAsk), findsNothing);

    for (final label in [libL10n.retry, l10n.storeKeyLostStartEmpty]) {
      // The longer text pushes the buttons below an 800x600 test view.
      await tester.ensureVisible(find.text(label));
      await tester.pump();
      await tester.tap(find.text(label));
    }
    expect(choices, [true, false]);
  });
}
