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
///
/// The gap is carried by the bar's own padding rather than by where it is
/// placed, so that its shadow falls inside the scroll view that clips it. The
/// two shadows are written to stay within this much — see where they are built.
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
/// are on, floating over the foot of the content.
///
/// Only the level: the way back out is the title bar's own button, which is
/// where every other page in the app puts it. A second one here was the same
/// move twice on one screen.
final class _SettingsTabs extends StatelessWidget {
  /// The level being shown, which is the root or one branch's children.
  final List<SettingsNode> nodes;

  final String? selectedId;
  final void Function(SettingsNode node) onTap;

  const _SettingsTabs({
    super.key,
    required this.nodes,
    required this.selectedId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(_kTabsHeight / 2);

    final row = SizedBox(
      height: _kTabsHeight,
      child: Row(
        // As wide as what is on it. A level of two tabs is a short bar.
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 4),
          for (final node in nodes)
            _TabButton(
              icon: node.icon,
              label: node.title,
              // A branch counts as on while what is showing is inside it.
              selected: node.flattened.any((e) => e.id == selectedId),
              onTap: () => onTap(node),
            ),
          const SizedBox(width: 4),
        ],
      ),
    );

    // Translucent and blurring what goes behind it, because the content runs
    // the full height of the page and passes under here rather than stopping
    // above it. Opaque, the bar sat in a band of bare background and read as a
    // second bottom bar instead of as something over the page.
    //
    // The shadow is outside the clip: inside, the rounded rect that keeps the
    // blur in would cut it off.
    //
    // An elevation and not a single `BoxShadow`: one soft shadow at 16% is
    // visible over the content on a full page and invisible over the bare
    // background of a short one, which is where it was first noticed. What
    // Flutter draws for an elevation carries far enough to read either way.
    final bar = Material(
      color: Colors.transparent,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.34),
      borderRadius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            key: settingsTabsKey,
            color: scheme.surfaceContainerHigh.withValues(alpha: 0.72),
            // Around the row rather than inside it, so the bar itself is what
            // springs between one level's width and the next. Inside, the
            // overshoot would be a gap opening at the end of a bar that had
            // already stopped growing.
            child: AnimatedSize(
              duration: Durations.medium2,
              curve: _kTabsCurve,
              alignment: Alignment.centerLeft,
              child: row,
            ),
          ),
        ),
      ),
    );

    // Centred while it fits and scrolled when it does not: the first level has
    // more tabs than a phone is wide, and the levels under it have three.
    //
    // The vertical padding is the room the shadow needs. A scroll view clips to
    // its viewport, and this one's viewport is as tall as the bar exactly — so
    // the shadow was cut off above and below while the sides, which have the
    // width of the page to spread into, kept theirs. Padding grows the viewport
    // instead of turning the clip off, which the horizontal axis still needs:
    // a level too wide for the phone has to scroll out of sight, not spill.
    //
    // It is padding here rather than an offset on the `Positioned` that places
    // this, so the bar sits where it always did — see [_kTabsMargin].
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(_kTabsMargin),
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

  const _TabButton({
    required this.icon,
    this.label,
    this.selected = false,
    this.onTap,
  });

  /// The pill behind the icon, at the measurements `NavigationBar` uses.
  ///
  /// It sizes the icon's background and nothing else. The label below is left
  /// to its own width, so a tab is as wide as its name — the pill only sets
  /// how narrow a short one can get.
  static const _indicator = Size(56, 30);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Wider than it was. The label used to sit in a fixed box and centre
        // itself in it, which left a gap either side whatever it said; now it
        // reaches the edges of its tab, and two of them need keeping apart.
        padding: const EdgeInsets.symmetric(horizontal: 8),
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
              // Unconstrained: a tab is as wide as its own name. Held to the
              // pill's width these ellipsed — they are section names, not the
              // one or two words a bottom bar carries, and several languages
              // spell them longer still. The bar already scrolls sideways when
              // a level does not fit across the window, so the room is there
              // to be taken.
              Text(
                label!,
                maxLines: 1,
                textAlign: TextAlign.center,
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
  }
}

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
