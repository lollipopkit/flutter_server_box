import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/sandbox_import.dart';
import 'package:server_box/view/page/backup.dart';

/// What the app has to say about the data it did or did not find.
///
/// Its first launch copies the retired App Store build's data in — see
/// [SandboxImport]. Silence is right when that worked and the app simply looks
/// like the one the user was already using; it is wrong when it did not, since
/// what they are looking at is an empty app that did not have to be one.
abstract final class SandboxImportNotice {
  /// Call once, after the first frame.
  static Future<void> showIfNeeded(BuildContext context) async {
    final result = SandboxImport.result;
    if (result == null) return;

    if (result == SandboxImportResult.imported) {
      // Named, not omitted. The downloads directory is not copied — it is
      // unbounded and a first launch that copies it looks like one that hung —
      // and a user who is not told where it went has lost files as far as they
      // can tell.
      final left = SandboxImport.leftBehind;
      Toast.show(
        left == null
            ? l10n.macDmgImported
            : l10n.macDmgImportedPartly(left),
      );
      return;
    }

    // Only worth a dialog when the user is left with less than they had.
    if (!result.needsExplaining) return;

    final denied = result == SandboxImportResult.denied;
    await context.showSheet(
      title: l10n.macDmgTitle,
      child: Text(denied ? l10n.macDmgImportDenied : l10n.macDmgImportFailed),
      actions: [
        if (denied)
          Btn.text(
            text: libL10n.setting,
            onTap: () {
              context.popSheet();
              // Full Disk Access. macOS decides whether one app may read
              // another's container, and only the user can change that answer.
              'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'
                  .launchUrl();
            },
          )
        else
          Btn.text(
            text: libL10n.restore,
            onTap: () {
              context.popSheet();
              BackupPage.route.go(context);
            },
          ),
        Btn.ok(),
      ],
    );
  }
}
