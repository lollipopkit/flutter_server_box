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
  }) : builder = page,
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

/// Names the menu — the column beside the content, or the list a narrow
/// window starts on. Only ever one of them is in the tree.
const settingsMenuKey = ValueKey('settings_menu');

/// Names the native tab bar. Several of its labels are also words in the
/// settings behind it, so finding one means saying which of the two is meant.
const settingsTabsKey = ValueKey('settings_tabs');

/// One row of the narrow list.
///
/// A card with a tile in it, which is what every row of the settings it leads
/// to is — on a whole screen, getting there and being there read the same way.
/// The wide menu is a strip beside the content and keeps its rail.
final class _SettingsRow extends StatelessWidget {
  final SettingsNode node;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsRow({required this.node, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return CardX(
      child: ListTile(
        leading: Icon(node.icon, size: 20),
        title: Text(
          node.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

/// One level's leaves, with the native tab bar above them.
///
/// `TabBar` and `TabBarView` share a `TabController`, so tapping or swiping a
/// setting uses the same Material tab behavior and keeps the selected setting
/// in sync with the settings navigator.
final class _SettingsPages extends StatefulWidget {
  final List<SettingsNode> leaves;
  final bool showTabBar;
  final String selectedId;
  final void Function(SettingsNode node) onChanged;

  const _SettingsPages({
    super.key,
    required this.leaves,
    required this.showTabBar,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  State<_SettingsPages> createState() => _SettingsPagesState();
}

class _SettingsPagesState extends State<_SettingsPages>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  late int _lastNotifiedIndex;

  @override
  void initState() {
    super.initState();
    final initial = _indexOf(widget.selectedId);
    _lastNotifiedIndex = initial;
    _controller = TabController(
      length: widget.leaves.length,
      initialIndex: initial,
      vsync: this,
    )..addListener(_onControllerChanged);
  }

  int _indexOf(String id) {
    final index = widget.leaves.indexWhere((e) => e.id == id);
    return index < 0 ? 0 : index;
  }

  @override
  void didUpdateWidget(_SettingsPages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId == oldWidget.selectedId) return;
    final target = _indexOf(widget.selectedId);
    if (_controller.index != target) {
      _lastNotifiedIndex = target;
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_controller.indexIsChanging) return;
    final index = _controller.index;
    if (index == _lastNotifiedIndex || index >= widget.leaves.length) return;
    _lastNotifiedIndex = index;
    widget.onChanged(widget.leaves[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.showTabBar)
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              key: settingsTabsKey,
              controller: _controller,
              isScrollable: true,
              tabs: [
                for (final node in widget.leaves)
                  Tab(icon: Icon(node.icon, size: 20), text: node.title),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [for (final leaf in widget.leaves) leaf.builder!()],
          ),
        ),
      ],
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
      // The rail this column has always been, at every level. A strip 232 wide
      // has room for one kind of row, and cards among rails read as two menus
      // rather than as one with something open in it.
      child: SideBarTile(
        title: node.title,
        icon: node.icon,
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
