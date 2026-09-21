import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';

/// What is being done to several machines at once, in the bar's place.
///
/// The bar's own controls are about the list — a tag, a search, an order —
/// and none of them means anything while a set is being built up. So the
/// whole strip becomes the set: how many, out of how many, and the things
/// that can be done to all of them.
///
/// The actions are the single-machine set minus everything that cannot be
/// done to several: there is no one terminal for three machines, and no one
/// address to copy.
class ServerSelectionBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ServerSelectionBar({
    super.key,
    required this.count,
    required this.total,
    required this.onClose,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTag,
    required this.onMove,
    required this.onDelete,
  });

  /// How many machines are in the set.
  final int count;

  /// How many machines the list shows, which is what [count] is out of.
  final int total;

  /// Stops choosing, leaving the machines as they were.
  final VoidCallback onClose;

  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onTag;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Size get preferredSize => const Size.fromHeight(SessionTabBar.height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: SessionTabBar.height,
      child: Row(
        children: [
          Btn.icon(
            text: libL10n.close,
            icon: const Icon(Icons.close, size: 18),
            onTap: onClose,
          ),
          Icon(Icons.check_box, size: 19, color: scheme.primary),
          const SizedBox(width: 9),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 7),
          // The one part that gives way on a narrow bar. The buttons after it
          // are fixed-size icons and all of them are needed; the total is the
          // least of what the bar says, and at 320pt with large text it was
          // what pushed them past the edge.
          Expanded(
            child: Text(
              '/ $total',
              style: UIs.text11Grey,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Btn.icon(
            text: l10n.connect,
            icon: const Icon(Icons.link, size: 18),
            onTap: onConnect,
          ),
          Btn.icon(
            text: l10n.disconnect,
            icon: const Icon(Icons.link_off, size: 18),
            onTap: onDisconnect,
          ),
          Btn.icon(
            text: libL10n.tag,
            icon: const Icon(MingCute.hashtag_line, size: 18),
            onTap: onTag,
          ),
          // The one action here that is about the list rather than about the
          // machines. Dragging is how one server is moved, and forty is
          // exactly where dragging stops being a way to do anything.
          Btn.icon(
            text: l10n.move,
            icon: const Icon(Icons.swap_vert, size: 18),
            onTap: onMove,
          ),
          Btn.icon(
            text: libL10n.delete,
            icon: const Icon(Icons.delete, size: 18),
            onTap: onDelete,
          ),
          const SizedBox(width: 7),
        ],
      ),
    );
  }
}
