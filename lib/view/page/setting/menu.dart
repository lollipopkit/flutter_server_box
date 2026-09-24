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

/// A settings page the search found, and the subject it is under.
final class SettingsHit {
  const SettingsHit({required this.leaf, this.parent});

  final SettingsNode leaf;

  /// Null for a page that is its own subject — Container, About.
  ///
  /// Which is also why the row under a result is the subject's name alone and
  /// not a trail from the root: there is one level above a page here, and a
  /// breadcrumb starting at "Settings" would repeat the window's own title on
  /// every row.
  final SettingsNode? parent;
}

/// The chord that reaches the search field.
///
/// Meta on macOS and Control elsewhere, the same split [desktopShortcuts]
/// makes: on Linux the Super key belongs to the window manager.
final _kSearchShortcut = SingleActivator(
  LogicalKeyboardKey.keyF,
  meta: isMacOS,
  control: !isMacOS,
);

/// Names the menu — the column beside the content, or the list a narrow
/// window starts on. Only ever one of them is in the tree.
const settingsMenuKey = ValueKey('settings_menu');

/// Names the floating tab bar. Several of its labels are also words in the
/// settings behind it, so finding one means saying which of the two is meant.
const settingsTabsKey = ValueKey('settings_tabs');

/// Names the row over the content on a wide window — what the floating bar is
/// there instead of, and named separately for the same reason.
const settingsHeaderKey = ValueKey('settings_header');

/// Names what the search found. The page it is drawn over is still in the
/// tree under it, and half these rows are on that page too — so finding one
/// means saying which of the two is meant.
const settingsResultsKey = ValueKey('settings_results');

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
        leading: ThemedIcon(node.icon, size: 20),
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
/// Flat, and every row goes somewhere. A branch is a door rather than a fold:
/// there is only the one screen here, and the level behind it arrives as the
/// bar of tabs over the page.
final class _SettingsList extends StatelessWidget {
  final List<SettingsNode> nodes;
  final void Function(SettingsNode node) onTap;

  /// The field, above the list it searches.
  final Widget search;

  /// What that field found, in the list's place. Null while nothing is typed.
  final Widget? results;

  const _SettingsList({
    required this.nodes,
    required this.onTap,
    required this.search,
    this.results,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: settingsMenuKey,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 9), child: search),
        if (results case final results?)
          results
        else
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

/// The field over the menu, which is where a search starts from.
///
/// Always there rather than behind a button: what it searches is a tree nine
/// subjects wide, and the whole point is to reach a page without having to
/// know which subject somebody filed it under.
final class _SettingsSearchField extends StatelessWidget {
  const _SettingsSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // One size and one line height for the value and the placeholder both.
    // `InputDecorator` lays the hint out in its own box and lines it up with
    // the input's baseline, so two sizes put the placeholder off the centre
    // of the pill while a typed value sat right — which is only visible on
    // the empty field somebody is about to type into.
    const text = TextStyle(fontSize: 13, height: 1);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: scheme.surfaceContainerLow,
      ),
      child: Row(
        // Explicit, because the three things in here are of three heights: a
        // 17pt glyph, a text field and a 10pt chord.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 17, color: scheme.outline),
          UIs.width7,
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              style: text,
              // No strut, or the line box is the font's own and the field is
              // taller than the text in it — off centre again, by the leading.
              strutStyle: StrutStyle.disabled,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '${libL10n.search} ${libL10n.setting}',
                hintStyle: text.copyWith(color: Colors.grey),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, value, _) {
              if (value.text.isNotEmpty) {
                return InkWell(
                  onTap: onClear,
                  child: Icon(Icons.close, size: 17, color: scheme.outline),
                );
              }
              // The chord, where a field that can be reached by one says so.
              if (!isDesktop) return UIs.placeholder;
              return Text(
                isMacOS ? '⌘F' : 'Ctrl F',
                style: TextStyle(
                  fontSize: 10,
                  height: 1,
                  color: scheme.outline,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One row of the settings menu.
///
/// Not [SideBarTile], which is the rail every *list* column in this app has:
/// those index instances of one thing and keep a column on the leading edge
/// for the mark that says one is running. This indexes subjects, nine of them,
/// and is drawn to the same numbers as the tabs over the content beside it —
/// a 36pt row, a 19pt icon, a 13pt name, and the count the fold used to stand
/// for on the end.
final class _SettingsMenuRow extends StatelessWidget {
  const _SettingsMenuRow({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final SettingsNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurface;
    final radius = BorderRadius.circular(9);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: selected ? scheme.secondaryContainer : null,
            ),
            child: Row(
              children: [
                Icon(
                  node.icon,
                  size: 19,
                  color: selected ? fg : scheme.outline,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      color: fg,
                    ),
                  ),
                ),
                // How many pages the subject holds, which is what the fold
                // used to say before it was opened.
                if (node.children.isNotEmpty)
                  Text(
                    '${node.children.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The settings menu: one row per subject, and nothing folded.
///
/// The rail the terminal, file, server and snippet pages have beside their
/// panes, and now the same shape as theirs. It used to be a tree that opened in
/// place — a subject's row above its own pages, both saying "Application", both
/// selectable, and the count of rows in the column changing under the reader
/// every time one was opened. What is inside a subject is a row of tabs over
/// the content instead, so this column only ever answers one question.
///
/// A row carries how many pages the subject holds, which is what the fold used
/// to say before it was opened.
final class _SettingsMenu extends StatelessWidget {
  final List<SettingsNode> nodes;
  final String? selectedId;
  final void Function(SettingsNode node) onSelect;

  /// The field, above the menu it searches.
  final Widget search;

  const _SettingsMenu({
    required this.nodes,
    required this.selectedId,
    required this.onSelect,
    required this.search,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(9, 9, 9, 4), child: search),
        Expanded(
          child: ListView(
            key: settingsMenuKey,
            padding: const EdgeInsets.fromLTRB(9, 4, 9, 13),
            children: [
              for (final node in nodes)
                _SettingsMenuRow(
                  node: node,
                  // A subject is lit while what is showing is inside it, which
                  // for a subject with one page is the page itself.
                  selected: node.flattened.any((e) => e.id == selectedId),
                  onTap: () => onSelect(node),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
