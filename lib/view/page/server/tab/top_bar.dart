part of 'tab.dart';

final class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final ValueNotifier<Set<String>> tags;
  final void Function(String) onTagChanged;
  final String initTag;

  const _TopBar({
    required this.initTag,
    required this.onTagChanged,
    required this.tags,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isMobile = breakpoints.isMobile;
    final padding = EdgeInsets.only(
      left: isMobile ? 10 : 16,
      right: isMobile ? 0 : 16,
    );

    final Widget leading;
    if (isMobile) {
      // Keep this btn. For issue #657.
      leading = InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () {
          SettingsPage.route.go(context);
        },
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Row(
            // As wide as the name and the cog. [Flexible] hands down loose
            // constraints, so a row left at `max` took the whole width the
            // tags had not claimed and the ripple was drawn across all of it.
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(BuildData.name, style: TextStyle(fontSize: 19)),
              SizedBox(width: 5),
              Icon(Icons.settings, size: 17),
            ],
          ),
        ),
      );
    } else {
      leading = _ConnectionCountText();
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Allowed to give way. This bar sits above the server list wherever
          // that list is, and one of those places is a column the user can
          // drag down to `AdaptivePanes.minPrimaryWidth` — where a leading
          // sized to its own text takes the row past its width and the tags
          // beside it have nothing left to shrink into.
          Flexible(child: leading),
          SizedBox(width: isMobile ? 30 : 16),
          TagSwitcher(
            tags: tags,
            onTagChanged: onTagChanged,
            initTag: initTag,
            singleLine: true,
            reversed: true,
          ).expanded(),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(TagSwitcher.kTagBtnHeight);
}

final class _ConnectionCountText extends ConsumerWidget {
  const _ConnectionCountText();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(serversProvider.select((s) => s.serverOrder));
    var connected = 0;
    for (final id in order) {
      final conn = ref.watch(serverProvider(id).select((v) => v.conn));
      if (conn.index >= ServerConn.connected.index) connected++;
    }
    final text = '$connected/${order.length} ${context.libL10n.conn}';
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: context.l10n.connectionStats,
        child: InkWell(
          onTap: () => ConnectionStatsPage.route.go(context),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
