import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/extension/server.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/metric.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/server_power.dart';
import 'package:server_box/view/widget/server_share.dart';

/// What can be done to one machine without leaving the list.
///
/// One set, in one order, whatever the list is drawing — a card, a line, a
/// tile — and whatever summoned it: a long press, a right-click, or the menu
/// key. Three lists would be three chances for them to drift apart, and a
/// density is a view of the same machines rather than a different place.
///
/// Feature navigation stays on the server page. This menu contains actions on
/// the server record or connection, plus power controls when connected.
List<ContextMenuAction> serverActions(
  BuildContext context,
  WidgetRef ref,
  ServerState srv, {
  VoidCallback? onSelect,
}) {
  final spi = srv.spi;
  final connected = srv.conn == ServerConn.finished;

  return [
    // On touch devices, selection is available from the long-press menu.
    if (onSelect != null)
      ContextMenuAction(
        icon: Icons.check_box_outlined,
        text: libL10n.select,
        onTap: onSelect,
      ),
    ContextMenuAction(
      icon: Icons.edit,
      text: libL10n.edit,
      onTap: () => ServerEditPage.route.go(context, args: ServerEditArgs(spi)),
    ),
    ContextMenuAction(
      icon: Icons.copy,
      text: libL10n.copy,
      // What would go on the clipboard, which is the one thing in this list
      // that is worth reading before choosing it.
      note: spi.displayAddr,
      onTap: () => Pfs.copy(spi.displayAddr),
    ),
    ContextMenuAction(
      icon: Icons.ios_share,
      text: libL10n.share,
      onTap: () => ServerShareUi.send(context, spi),
    ),
    if (connected)
      ContextMenuAction(
        icon: Icons.link_off,
        text: l10n.disconnect,
        onTap: () =>
            ref.read(serversProvider.notifier).closeServer(id: spi.id),
      )
    else
      ContextMenuAction(
        icon: Icons.link,
        text: l10n.connect,
        onTap: () => ref.read(serversProvider.notifier).refresh(spi: spi),
      ),
    // Power controls require an active connection.
    if (connected)
      for (final func in ServerPower.funcs)
        ContextMenuAction(
          icon: ServerPower.icon(func),
          text: ServerPower.label(func),
          destructive: true,
          onTap: () => ServerPower.confirmAndRun(context, ref, spi, func),
        ),
    ContextMenuAction(
      icon: Icons.delete,
      text: libL10n.delete,
      destructive: true,
      onTap: () => _confirmDelete(context, ref, spi),
    ),
  ];
}

Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Spi spi,
) async {
  final confirmed = await context.showRoundDialog<bool>(
    title: libL10n.attention,
    child: Text(
      libL10n.askContinue('${libL10n.delete} ${libL10n.server}(${spi.name})'),
    ),
    actions: Btn.ok(red: true).toList,
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(serversProvider.notifier).delServer(spi.id);
  } catch (e, s) {
    if (context.mounted) context.showErrDialog(e, s);
  }
}

/// Identifies the server in a compact tile menu header.
Widget serverMenuHead(ServerState srv) {
  final line = srv.listLine ?? srv.spi.displayAddr;
  return Padding(
    padding: const EdgeInsets.fromLTRB(11, 5, 11, 7),
    child: Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: serverStateDot(srv),
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            srv.spi.name,
            style: const TextStyle(
              fontSize: 12,
              height: 1,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 9),
        // Keep long addresses from determining the menu width.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            line,
            style: const TextStyle(fontSize: 10, height: 1, color: Colors.grey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Raises [serverActions] the way the input that asked for them wants.
///
/// [at] is what the menu hangs off: where a pointer was, or the bottom of
/// whatever was long-pressed. The thing pressed stays where it is and says so
/// by its colour — see [ServerCard.highlighted] — which is what makes the
/// menu's own position readable as "this one".
///
/// [sheet] is the one window with nowhere to hang it: a single column under a
/// finger. [header] names the machine inside the menu — see [serverMenuHead].
///
/// How each of those is drawn is [showContextMenu]'s, not this file's: the
/// sheet and the popup are one menu in two places, and a set of rows written
/// out again here is how they stop being one.
Future<void> showServerActions(
  BuildContext context,
  WidgetRef ref,
  ServerState srv, {
  Offset? at,
  bool sheet = false,
  Widget? header,
  VoidCallback? onSelect,
}) {
  return showContextMenu(
    context,
    serverActions(context, ref, srv, onSelect: onSelect),
    title: srv.spi.name,
    header: header,
    at: at,
    sheet: sheet,
  );
}
