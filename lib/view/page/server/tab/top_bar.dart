part of 'tab.dart';

final class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueNotifier<Set<String>> tags;
  final void Function(String) onTagChanged;
  final String initTag;

  const _TopBar({
    required this.initTag,
    required this.onTagChanged,
    required this.tags,
  });

  @override
  Widget build(BuildContext context) {
    final breakpoints = ResponsiveBreakpoints.of(context);
    final isMobile = breakpoints.isMobile;
    final padding = EdgeInsets.only(
      left: isMobile ? 10 : 16,
      right: isMobile ? 0 : 16,
    );

    final tagSwitcher = TagSwitcher(
      tags: tags,
      onTagChanged: onTagChanged,
      initTag: initTag,
      singleLine: true,
      reversed: true,
    );

    // Nothing before the tags on a wide window. What stood there was the
    // connection count, a heading counting the very cards under it; it says
    // more over the tab's own icon, where it can be read from any tab — see
    // `ConnCountBadge`. The settings button below is a phone's only way in,
    // which is why that one stays.
    if (!isMobile) {
      return Padding(padding: padding, child: tagSwitcher);
    }

    // Keep this btn. For issue #657.
    final leading = InkWell(
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
          const SizedBox(width: 30),
          tagSwitcher.expanded(),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(TagSwitcher.kTagBtnHeight);
}
