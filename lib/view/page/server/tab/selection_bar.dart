import 'package:fl_lib/fl_lib.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
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
  Size get preferredSize => const Size.fromHeight(SwitcherBar.height);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SwitcherBar(
      leading: Btn.icon(
        text: libL10n.close,
        icon: const Icon(Icons.close, size: 18),
        onTap: onClose,
      ),
      switcherMinWidth: 72,
      switcher: Row(
        children: [
          Icon(Icons.check_box, size: 19, color: scheme.primary),
          const SizedBox(width: 9),
          Text(
            '$count',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 7),
          // The part that gives way first: the total is the least of what the
          // bar says.
          Expanded(
            child: Text(
              '/ $total',
              style: UIs.text11Grey,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        BarAction(icon: Icons.link, label: l10n.connect, onTap: onConnect),
        BarAction(
          icon: Icons.link_off,
          label: l10n.disconnect,
          onTap: onDisconnect,
        ),
        BarAction(
          icon: MingCute.hashtag_line,
          label: libL10n.tag,
          onTap: onTag,
        ),
        // The one action here that is about the list rather than about the
        // machines. Dragging is how one server is moved, and forty is exactly
        // where dragging stops being a way to do anything.
        BarAction(icon: Icons.swap_vert, label: l10n.move, onTap: onMove),
        BarAction(icon: Icons.delete, label: libL10n.delete, onTap: onDelete),
      ],
    );
  }
}
