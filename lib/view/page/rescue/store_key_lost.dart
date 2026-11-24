import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/rescue/scaffold.dart';

/// The whole app, when the database exists and the vault has no key for it
/// (#1780), or cannot read the one it has (#1784).
///
/// Asked rather than decided: a keyring not yet unlocked looks the same as a
/// key that is gone, and starting empty makes a new key that would replace
/// the old one if it comes back.
class StoreKeyLostPage extends StatelessWidget {
  const StoreKeyLostPage({super.key, required this.err, required this.onChoice});

  final StoreUnreadableException err;

  /// True to try again, false to set the file aside and start with no data.
  final void Function(bool retry) onChoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return RescueScaffold(
      children: [
        RescueHeader(icon: Icons.key_off, title: l10n.storeUnreadableTitle),
        UIs.height13,
        Text(
          err.reason == StoreUnreadableReason.vaultFailed
              ? l10n.storeVaultFailedAsk
              : l10n.storeKeyLostAsk,
          textAlign: TextAlign.center,
        ),
        // #1784: a keystore module (TrickyStore) emulates decrypt for the apps it targets, and gets it wrong.
        if (isAndroid && err.reason == StoreUnreadableReason.vaultFailed) ...[
          UIs.height13,
          Text(l10n.storeVaultFailedRootHint, textAlign: TextAlign.center),
        ],
        UIs.height13,
        SelectableText('$err', style: UIs.textGrey),
        UIs.height13,
        FilledButton(
          onPressed: () => onChoice(true),
          child: Text(libL10n.retry),
        ),
        UIs.height13,
        OutlinedButton(
          onPressed: () => onChoice(false),
          child: Text(l10n.storeKeyLostStartEmpty),
        ),
      ],
    );
  }
}
