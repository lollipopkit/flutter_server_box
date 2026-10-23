import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/store_recovery.dart';
import 'package:server_box/view/page/backup.dart';

/// Why this launch started with no data, when it did (#1780).
///
/// The launch has already moved the unreadable database aside and opened an
/// empty one — see [StoreRecovery]. Said once, by dialog: an empty app with no
/// explanation reads as the app having deleted everything.
abstract final class StoreUnreadableNotice {
  /// Call once, after the first frame.
  static Future<void> showIfNeeded(BuildContext context) async {
    final result = StoreRecovery.result;
    if (result == null) return;
    final (:err, :aside) = result;

    final reason = switch (err.reason) {
      StoreUnreadableReason.keyLost => l10n.storeUnreadableKeyLost,
      StoreUnreadableReason.keyRejected => l10n.storeUnreadableKeyRejected,
    };
    await context.showRoundDialog(
      title: l10n.storeUnreadableTitle,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            UIs.height13,
            SelectableText(l10n.storeUnreadableKept(aside)),
            UIs.height13,
            SelectableText('$err', style: UIs.textGrey),
          ],
        ),
      ),
      actions: [
        Btn.text(text: libL10n.copy, onTap: () => Pfs.copy('$err\n$aside')),
        Btn.text(
          text: libL10n.restore,
          onTap: () {
            context.popDialog();
            BackupPage.route.go(context);
          },
        ),
        Btn.ok(),
      ],
    );
  }
}
