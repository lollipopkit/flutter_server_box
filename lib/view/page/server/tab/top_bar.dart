part of 'tab.dart';

final class _TopBar extends ConsumerWidget implements PreferredSizeWidget {
  final ValueNotifier<Set<String>> tags;
  final void Function(String) onTagChanged;
  final String initTag;

  const _TopBar({required this.initTag, required this.onTagChanged, required this.tags});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isMobile = breakpoints.isMobile;
    final padding = EdgeInsets.only(left: isMobile ? 10 : 16, right: isMobile ? 0 : 16);

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
            children: [
              Text(BuildData.name, style: TextStyle(fontSize: 19)),
              SizedBox(width: 5),
              Icon(Icons.settings, size: 17),
            ],
          ),
        ),
      );
    } else {
      final servers = ref.watch(serversProvider);
      final order = servers.serverOrder;
      var connected = 0;
      for (final id in order) {
        final conn = ref.watch(serverProvider(id).select((value) => value.conn));
        if (conn.index >= ServerConn.connected.index) connected++;
      }
      final total = order.length;
      final connectionText = '$connected/$total ${context.libL10n.conn}';
      leading = InkWell(
        onTap: () => ConnectionStatsPage.route.go(context),
        child: Text(connectionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );
    }

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          leading,
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
