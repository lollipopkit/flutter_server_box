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
  final List<SettingsNode> children;
  final Widget Function()? builder;

  const SettingsNode.leaf({
    required this.id,
    required this.title,
    required Widget Function() page,
  })  : builder = page,
        children = const [];

  const SettingsNode.branch({
    required this.id,
    required this.title,
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
