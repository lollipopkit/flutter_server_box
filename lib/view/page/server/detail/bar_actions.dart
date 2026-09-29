import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/page/server/monitor_settings/page.dart';
import 'package:server_box/view/widget/server_share.dart';

/// What a server's own page offers in its bar: share, the agent's settings,
/// edit.
///
/// One list for both places that page is: pushed on its own, where it draws
/// its bar, and grown in place in the server tab, where the tab's bar is the
/// one on screen. Each draws the buttons in its own bar's style.
final class ServerPageAction {
  const ServerPageAction._(this.icon, this.label, this.onTap);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// [onDeleted] runs when the edit page deleted the server, for a caller that
  /// has to close something itself.
  static List<ServerPageAction> of(
    BuildContext context,
    Spi spi, {
    VoidCallback? onDeleted,
  }) {
    // Asked of `spi.monitorOn` rather than of the server's capabilities: this
    // opens *the agent's* settings, and a server with both transports answers
    // capability questions as the union of the two. The switch counts too: an
    // agent switched off is one this app does not talk to.
    final monitor = spi.monitorOn;
    return [
      ServerPageAction._(
        Icons.share,
        libL10n.share,
        () => ServerShareUi.send(context, spi),
      ),
      // Beside Edit: the two are the same kind of thing at different ends of
      // the wire — Edit is this app's record of the server, this is the
      // agent's own configuration — and Edit stays the rightmost.
      if (monitor != null)
        ServerPageAction._(
          MingCute.settings_2_line,
          context.l10n.monitorSettings,
          () => MonitorSettingsPage.route.go(
            context,
            MonitorSettingsArgs(monitor: monitor, subtitle: spi.name),
          ),
        ),
      ServerPageAction._(Icons.edit, libL10n.edit, () async {
        final delete = await ServerEditPage.route.go(
          context,
          args: ServerEditArgs(spi),
        );
        if (delete == true && context.mounted) onDeleted?.call();
      }),
    ];
  }
}
