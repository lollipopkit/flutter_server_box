import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/server_share.dart';

/// The ways a server gets onto this device.
///
/// An enum rather than three buttons so the list, the icons and the labels are
/// one thing — and so a platform that cannot offer one of them (a desktop has
/// no camera to scan with) drops it in a single place.
enum AddServerWay {
  manual,
  qr,
  file;

  bool get available => switch (this) {
    // `isMobile` matches where the scanner page can actually open one.
    AddServerWay.qr => isMobile,
    _ => true,
  };

  IconData get icon => switch (this) {
    AddServerWay.manual => Icons.edit,
    AddServerWay.qr => Icons.qr_code_scanner,
    AddServerWay.file => Icons.file_present,
  };

  String get label => switch (this) {
    AddServerWay.manual => libL10n.manual,
    AddServerWay.qr => l10n.shareScanQr,
    AddServerWay.file => l10n.shareImportFile,
  };
}

/// The menu a "+" for servers drops: the same ways from every tab that lists
/// servers, the server tab's bar and the Monitor rail alike.
List<ContextMenuAction> addServerMenu(BuildContext context, WidgetRef ref) => [
  for (final way in AddServerWay.values)
    if (way.available)
      ContextMenuAction(
        text: way.label,
        icon: way.icon,
        onTap: () => unawaited(addServer(context, ref, way)),
      ),
];

Future<void> addServer(BuildContext context, WidgetRef ref, AddServerWay way) async {
  if (!context.mounted) return;
  switch (way) {
    case AddServerWay.manual:
      unawaited(ServerEditPage.route.go(context));
    case AddServerWay.qr:
      await ServerShareUi.receiveFromQr(context, ref);
    case AddServerWay.file:
      await ServerShareUi.receiveFromFile(context, ref);
  }
}
