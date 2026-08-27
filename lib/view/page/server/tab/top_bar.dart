part of 'tab.dart';

/// The app's name and a way into its settings, above the server grid.
///
/// Only ever built on a phone — issue #657, which is that this is the one
/// layout with no other way in. Every wider one has the nav rail, and that
/// carries its own settings button.
///
/// So on a wide window there is no bar here at all. What else stood in it was
/// the tag switcher, and that floats over the bottom of the page now: it acts
/// on the whole list, so it belongs within reach the whole way down rather
/// than scrolling off after the first row of cards. Before it was a heading
/// counting the very cards under it, which says more over the tab's own icon
/// — see `ConnCountBadge`.
final class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () {
            SettingsPage.route.go(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            child: Row(
              // As wide as the name and the cog. [Flexible] hands down loose
              // constraints, so a row left at `max` took the whole width and
              // the ripple was drawn across all of it.
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(BuildData.name, style: TextStyle(fontSize: 19)),
                SizedBox(width: 5),
                Icon(Icons.settings, size: 17),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(TagSwitcher.kTagBtnHeight);
}
