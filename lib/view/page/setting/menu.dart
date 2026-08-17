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
    required this.nodes,
    required this.selectedId,
    required this.canGoBack,
    required this.onTap,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: settingsTabsKey,
      elevation: 6,
      color: scheme.surfaceContainerHigh,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(_kTabsHeight / 2),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: _kTabsHeight,
        child: Row(
          children: [
            // Always in the row, lit only when there is a level to go back to:
            // a button that comes and goes moves every tab beside it.
            _TabButton(
              icon: Icons.arrow_back,
              onTap: canGoBack ? onBack : null,
              tooltip: libL10n.goBackQ,
            ),
            const VerticalDivider(width: 1, indent: 12, endIndent: 12),
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                children: [
                  for (final node in nodes)
                    _TabButton(
                      icon: node.icon,
                      label: node.title,
                      // A branch counts as on while what is showing is inside
                      // it, which is what says where the way back leads.
                      selected: node.flattened.any((e) => e.id == selectedId),
                      onTap: () => onTap(node),
                    ),
                ],
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch ((onTap, selected)) {
      (null, _) => scheme.onSurfaceVariant.withValues(alpha: 0.35),
      (_, true) => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };

    final button = InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: label == null ? 14 : 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(
                label!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.1,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
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
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [for (final node in nodes) ..._buildNode(context, node, 0)],
    );
  }

  List<Widget> _buildNode(BuildContext context, SettingsNode node, int depth) {
    final expanded = expandedIds.contains(node.id);

    final row = Padding(
      // Indented by depth rather than by a fixed inset, so that a level added
      // later lines up without anyone having to remember this number.
      padding: EdgeInsets.only(left: depth * 14.0),
      child: SideBarTile(
        title: node.title,
        icon: node.icon,
        selected: node.isLeaf && node.id == selectedId,
        onTap: () => node.isLeaf ? onSelect(node) : onToggle(node),
        trailing: node.isLeaf
            ? null
            : AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: Durations.short3,
                child: const Icon(Icons.chevron_right, size: 18),
              ),
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
