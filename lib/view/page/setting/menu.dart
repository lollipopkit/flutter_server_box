part of 'entry.dart';

/// One row of the settings menu.
///
/// A branch has children and opens; a leaf has a page and selects. Never both:
/// a row that expands *and* shows something is two meanings on one tap, and the
/// user has to learn which they got. A group whose own settings need a home
/// gets a [libL10n.setting] leaf under itself instead.
final class SettingsNode {
  final String id;
  final String title;
  final IconData icon;
  final List<SettingsNode> children;
  final Widget Function()? builder;

  const SettingsNode.leaf({
    required this.id,
    required this.title,
    required this.icon,
    required Widget Function() page,
  })  : builder = page,
        children = const [];

  const SettingsNode.branch({
    required this.id,
    required this.title,
    required this.icon,
    required this.children,
  }) : builder = null;

  bool get isLeaf => builder != null;

  /// The first leaf at or under this node, which is what selecting a branch
  /// means when the content has to show something.
  SettingsNode? get firstLeaf {
    if (isLeaf) return this;
    for (final child in children) {
      final leaf = child.firstLeaf;
      if (leaf != null) return leaf;
    }
    return null;
  }

  /// Depth-first, this node included.
  Iterable<SettingsNode> get flattened sync* {
    yield this;
    for (final child in children) {
      yield* child.flattened;
    }
  }
}

/// Height of the floating tab bar, and the gap around it.
const _kTabsHeight = 56.0;
const _kTabsMargin = 12.0;

/// Displacement springs past its mark and settles, as it does elsewhere.
/// Only the bar's own width: a size factor past 1 would be a gap.
const _kTabsCurve = Curves.easeOutBack;

/// Names the menu — the column beside the content, or the list a narrow
/// window starts on. Only ever one of them is in the tree.
const settingsMenuKey = ValueKey('settings_menu');

/// Names the floating tab bar. Several of its labels are also words in the
/// settings behind it, so finding one means saying which of the two is meant.
const settingsTabsKey = ValueKey('settings_tabs');

/// The same tree as [_SettingsMenu], one level at a time.
///
/// A narrow window has no room for a column beside the content, and a drawer
/// hides where you are the moment you have gone there. This shows the level you
/// are on, floating over the foot of the content, with the way back out at the
/// leading end of it.
final class _SettingsTabs extends StatelessWidget {
  /// The level being shown, which is the root or one branch's children.
  final List<SettingsNode> nodes;

  final String? selectedId;
  final bool canGoBack;
  final void Function(SettingsNode node) onTap;
  final VoidCallback onBack;

  const _SettingsTabs({
    super.key,
    required this.nodes,
    required this.selectedId,
    required this.canGoBack,
    required this.onTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bar = Material(
      key: settingsTabsKey,
      elevation: 6,
      color: scheme.surfaceContainerHigh,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(_kTabsHeight / 2),
      clipBehavior: Clip.antiAlias,
      // Around the row rather than inside it, so the bar itself is what springs
      // between one level's width and the next. Inside, the overshoot would be
      // a gap opening at the end of a bar that had already stopped growing.
      child: AnimatedSize(
        duration: Durations.medium2,
        curve: _kTabsCurve,
        alignment: Alignment.centerLeft,
        child: SizedBox(
          height: _kTabsHeight,
          child: Row(
            // As wide as what is on it. A level of two tabs is a short bar.
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canGoBack) ...[
                _TabButton(
                  icon: Icons.arrow_back,
                  onTap: onBack,
                  tooltip: libL10n.goBackQ,
                ),
                const VerticalDivider(width: 1, indent: 12, endIndent: 12),
              ],
              const SizedBox(width: 4),
              for (final node in nodes)
                _TabButton(
                  icon: node.icon,
                  label: node.title,
                  // A branch counts as on while what is showing is inside it,
                  // which is what says where the way back leads.
                  selected: node.flattened.any((e) => e.id == selectedId),
                  onTap: () => onTap(node),
                ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );

    // Centred while it fits and scrolled when it does not: the first level has
    // more tabs than a phone is wide, and the levels under it have three.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _kTabsMargin),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: math.max(0, constraints.maxWidth - _kTabsMargin * 2),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [bar]),
        ),
      ),
    );
  }
}

final class _TabButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;

  const _TabButton({
    required this.icon,
    this.label,
    this.selected = false,
    this.onTap,
    this.tooltip,
  });

  /// The pill behind the icon, at the measurements `NavigationBar` uses.
  static const _indicator = Size(56, 30);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    final button = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Around the icon and not the label, the way the rail on the home
            // page marks its own destination.
            AnimatedContainer(
              duration: Durations.short3,
              curve: Curves.easeOut,
              width: _indicator.width,
              height: _indicator.height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? scheme.secondaryContainer : null,
                borderRadius: BorderRadius.circular(_indicator.height / 2),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            if (label != null) ...[
              const SizedBox(height: 3),
              SizedBox(
                width: _indicator.width + 6,
                child: Text(
                  label!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final tooltip_ = tooltip;
    if (tooltip_ == null) return button;
    return Tooltip(message: tooltip_, child: button);
  }
}

/// One row of the menu, at either level.
///
/// A card with a tile in it, which is what every row of the settings *behind*
/// this menu is. Getting there and being there read the same way.
final class _SettingsRow extends StatelessWidget {
  final SettingsNode node;
  final bool selected;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.node,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CardX(
      color: selected ? scheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(
          node.icon,
          size: 20,
          color: selected ? scheme.onSecondaryContainer : null,
        ),
        title: Text(
          node.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? scheme.onSecondaryContainer : null,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}

/// The first thing a narrow window shows: what settings there are.
///
/// Flat, and every row goes somewhere. The wide menu opens a branch in place
/// because it has a column to open it into; here there is only the one screen,
/// so a branch is a door rather than a fold.
final class _SettingsList extends StatelessWidget {
  final List<SettingsNode> nodes;
  final void Function(SettingsNode node) onTap;

  const _SettingsList({required this.nodes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: settingsMenuKey,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      children: [
        for (final node in nodes)
          _SettingsRow(
            node: node,
            onTap: () => onTap(node),
            trailing: const Icon(Icons.chevron_right, size: 18),
          ),
      ],
    );
  }
}

/// One level's leaves, side by side.
///
/// A [PageView] rather than one page swapped for another: the tabs under it are
/// siblings, so moving between them is moving along a row, and it should look
/// like it. Dragging the content does the same thing as tapping a tab, which is
/// what having them side by side promises.
final class _SettingsPages extends StatefulWidget {
  final List<SettingsNode> leaves;
  final String selectedId;
  final void Function(SettingsNode node) onChanged;

  const _SettingsPages({
    super.key,
    required this.leaves,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_SettingsPages> createState() => _SettingsPagesState();
}

class _SettingsPagesState extends State<_SettingsPages> {
  late final PageController _controller = PageController(initialPage: _indexOf(widget.selectedId));

  int _indexOf(String id) {
    final index = widget.leaves.indexWhere((e) => e.id == id);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(_SettingsPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId == oldWidget.selectedId) return;
    final target = _indexOf(widget.selectedId);
    if (!_controller.hasClients || _controller.page?.round() == target) return;
    _controller.animateToPage(
      target,
      duration: Durations.medium2,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _controller,
      // Told rather than inferred: a drag that lands on another page has picked
      // it, and the tabs have to say so.
      onPageChanged: (index) => widget.onChanged(widget.leaves[index]),
      children: [for (final leaf in widget.leaves) leaf.builder!()],
    );
  }
}

/// The settings menu: a column of branches to open and leaves to select.
///
/// The rail the terminal, file, server and snippet pages have beside their
/// panes, with one difference — those index things that exist at one level, and
/// settings are grouped. So a branch is a row that turns its chevron and reveals
/// what is under it, rather than a heading that is always open.
final class _SettingsMenu extends StatelessWidget {
  final List<SettingsNode> nodes;
  final String? selectedId;
  final Set<String> expandedIds;
  final void Function(SettingsNode node) onSelect;
  final void Function(SettingsNode node) onToggle;

  const _SettingsMenu({
    required this.nodes,
    required this.selectedId,
    required this.expandedIds,
    required this.onSelect,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: settingsMenuKey,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      children: [for (final node in nodes) ..._buildNode(context, node, 0)],
    );
  }

  List<Widget> _buildNode(BuildContext context, SettingsNode node, int depth) {
    final expanded = expandedIds.contains(node.id);

    final selected = node.isLeaf && node.id == selectedId;
    void onTap() => node.isLeaf ? onSelect(node) : onToggle(node);
    final trailing = node.isLeaf
        ? null
        : AnimatedRotation(
            turns: expanded ? 0.25 : 0,
            duration: Durations.short3,
            child: const Icon(Icons.chevron_right, size: 18),
          );

    final row = Padding(
      // Indented by depth rather than by a fixed inset, so that a level added
      // later lines up without anyone having to remember this number.
      padding: EdgeInsets.only(left: depth * 14.0),
      // The first level is the rail this column has always been: it names the
      // subjects, and a card apiece would make a list of eight into a page of
      // its own. What opens under it is a card and a tile, as the settings it
      // leads to are.
      child: depth == 0
          ? SideBarTile(
              title: node.title,
              icon: node.icon,
              selected: selected,
              onTap: onTap,
              trailing: trailing,
            )
          : _SettingsRow(
              node: node,
              selected: selected,
              onTap: onTap,
              trailing: trailing,
            ),
    );

    return [
      row,
      if (!node.isLeaf)
        // Animated so that opening a branch reads as the rows below it moving
        // down, rather than as the menu becoming a different menu.
        AnimatedSize(
          duration: Durations.short4,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final child in node.children)
                      ..._buildNode(context, child, depth + 1),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
    ];
  }
}
