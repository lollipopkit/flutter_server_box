import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/view/page/server/edit/edit.dart';
import 'package:server_box/view/widget/server_func_btns.dart';
import 'package:server_box/view/widget/server_power.dart';
import 'package:server_box/view/widget/server_share.dart';

/// What can be done to one machine without leaving the list.
///
/// One set, in one order, whatever the list is drawing — a card, a line, a
/// tile — and whatever summoned it: a long press, a right-click, or the menu
/// key. Three lists would be three chances for them to drift apart, and a
/// density is a view of the same machines rather than a different place.
///
/// The row of functions on a server's own page is the same set of functions,
/// run through the same [runServerFunc]: a Terminal that behaves differently
/// depending on where it was opened from is two features.
List<ContextMenuAction> serverActions(
  BuildContext context,
  WidgetRef ref,
  ServerState srv, {
  VoidCallback? onSelect,
}) {
  final spi = srv.spi;
  final connected = srv.conn == ServerConn.finished;

  return [
    // First, and only on a device with no other way in: a long press already
    // means "the other things", so acting on several machines has to start
    // from inside that rather than replace it. A pointer holds a modifier.
    if (onSelect != null)
      ContextMenuAction(
        icon: Icons.check_box_outlined,
        text: libL10n.select,
        onTap: onSelect,
      ),
    ContextMenuAction(
      icon: Icons.edit,
      text: libL10n.edit,
      onTap: () => ServerEditPage.route.go(context, args: SpiRequiredArgs(spi)),
    ),
    // What this machine can be used for, in the order the user put them in on
    // the function row — the same list, so the two cannot disagree about what
    // this server offers.
    for (final entry in serverFuncBtnsFor(spi, srv.remoteAccess))
      if (entry.available)
        ContextMenuAction(
          icon: entry.btn.icon,
          text: entry.btn.toStr,
          onTap: () => runServerFunc(entry.btn, spi, context, ref),
        ),
    ContextMenuAction(
      icon: Icons.copy,
      text: '${libL10n.copy} · ${spi.displayAddr}',
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
    // Last, and only where it can be carried out: these end in the machine
    // going away, which is not something to offer beside "copy address" on a
    // server that is not even reachable.
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
  // Named, because this is reached from a list where several machines look
  // alike and the one under the finger is not always the one in mind.
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

/// Raises [serverActions] the way the input that asked for them wants.
///
/// [at] is where a pointer was, and null a long press — which has a finger
/// over the spot, so nothing is drawn under it. On a phone that is a sheet at
/// the bottom rather than a dialog in the middle: the middle of a phone is
/// where the card being acted on is, and the top half is out of a thumb's
/// reach.
Future<void> showServerActions(
  BuildContext context,
  WidgetRef ref,
  ServerState srv, {
  Offset? at,
  VoidCallback? onSelect,
}) async {
  final actions = serverActions(context, ref, srv, onSelect: onSelect);
  if (at != null || !isMobile) {
    return showContextMenu(context, actions, title: srv.spi.name, at: at);
  }

  final chosen = await showRowsSheet<ContextMenuAction>(
    context,
    rows: (ctx) => [
      ListTile(
        dense: true,
        title: Text(srv.spi.name, style: UIs.text13Grey),
        subtitle: Text(srv.spi.displayAddr, style: UIs.text11Grey),
      ),
      const Divider(height: 1),
      for (final action in actions)
        ListTile(
          leading: Icon(
            action.icon,
            color: action.destructive ? Colors.red : null,
          ),
          title: Text(
            action.text,
            style: action.destructive ? UIs.textRed : null,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Answered rather than run here: the sheet has to be gone before an
          // action that opens a dialog of its own runs, or the dialog opens
          // underneath it.
          onTap: () => Navigator.of(ctx).pop(action),
        ),
    ],
  );
  chosen?.onTap();
}
