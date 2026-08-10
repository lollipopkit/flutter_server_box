part of 'tab.dart';

/// The strip of open terminals, with the add button at its head.
///
/// Takes the names and the selected index rather than the controller: it
/// renders a snapshot, and the page above it already listens for changes. Two
/// widgets watching one piece of state is how they end up disagreeing about it.
final class _TabBar extends StatelessWidget implements PreferredSizeWidget {
  const _TabBar({
    required this.names,
    required this.index,
    required this.onTap,
    required this.onClose,
    required this.sessionActions,
    required this.pickerActions,
  });

  /// Tab labels, the add button's included at index 0.
  final List<String> names;

  final int index;
  final void Function(int index) onTap;
  /// By position, not by label: the bar renders a snapshot, and a position is
  /// what it actually drew. Which session that is stays the page's business.
  final void Function(int index) onClose;

  /// Shown while a terminal is open.
  final List<Widget> sessionActions;

  /// Shown while the picker is open.
  final List<Widget> pickerActions;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  bool get _onPicker => index == 0;

  @override
  Widget build(BuildContext context) {
    final actions = _onPicker ? pickerActions : sessionActions;
    return Row(
      children: [
        _AddTabButton(selected: _onPicker, onTap: () => onTap(0)),
        const _TabDivider(),
        Expanded(
          child: ClipRect(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              itemCount: names.length - 1,
              separatorBuilder: (_, _) => const _TabDivider(),
              itemBuilder: (context, i) {
                // The list skips the add button, so its own index is one
                // behind the tab index everything else uses.
                final tabIndex = i + 1;
                return _TabItem(
                  name: names[tabIndex],
                  selected: index == tabIndex,
                  onTap: () => onTap(tabIndex),
                  onClose: () => onClose(tabIndex),
                );
              },
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const _TabDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final action in actions) ...[action, const SizedBox(width: 7)],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TabDivider extends StatelessWidget {
  const _TabDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 17),
      child: Container(
        color: Theme.of(context).dividerColor.withAlpha(61),
        width: 3,
      ),
    );
  }
}

class _AddTabButton extends StatelessWidget {
  const _AddTabButton({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _TabInk(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Icon(
          MingCute.add_circle_fill,
          size: 17,
          color: selected ? null : Colors.grey,
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final color = selected ? null : Colors.grey;
    final text = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: TextStyle(color: color),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: _TabInk(
        onTap: onTap,
        child: AnimatedContainer(
          // The close button only appears on the current tab, so the tab has
          // to make room for it as it becomes current.
          width: switch ((selected, isMobile)) {
            (true, true) => 90,
            (true, false) => 130,
            (false, true) => 60,
            (false, false) => 90,
          },
          duration: Durations.medium3,
          curve: Curves.fastEaseInToSlowEaseOut,
          child: selected
              ? Row(
                  children: [
                    Btn.icon(
                      icon: Icon(
                        MingCute.close_circle_fill,
                        color: color,
                        size: 17,
                      ),
                      onTap: onClose,
                      padding: null,
                    ),
                    Expanded(child: text),
                  ],
                )
              : Center(child: text),
        ),
      ),
    );
  }
}

class _TabInk extends StatelessWidget {
  const _TabInk({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  static final _radius = BorderRadius.circular(13);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: _radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(borderRadius: _radius, onTap: onTap, child: child),
    );
  }
}
