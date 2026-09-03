import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:server_box/core/utils/tag_group.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/widget/pane_settings.dart';

class SnippetListPage extends ConsumerStatefulWidget {
  const SnippetListPage({super.key});

  @override
  ConsumerState<SnippetListPage> createState() => _SnippetListPageState();

  static const route = AppRouteNoArg(
    page: SnippetListPage.new,
    path: '/snippets',
  );
}

/// What the editor pane is on when it is not on a saved snippet.
const _newSnippet = #newSnippet;

class _SnippetListPageState extends ConsumerState<SnippetListPage>
    with AutomaticKeepAliveClientMixin {
  final _tag = ''.vn;

  /// The bar's search: what is typed, and whether the bar is a field at all.
  final _search = InlineSearchController();

  /// The name of the snippet being edited, [_newSnippet] for one being
  /// created, or null for nothing.
  ///
  /// The name rather than the object, because that is a snippet's identity —
  /// `SnippetProvider.update` finds the old one by it — and because the object
  /// is replaced on every edit.
  Object? _editing;

  @override
  void dispose() {
    super.dispose();
    _tag.dispose();
    _search.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final snippets = ref.watch(snippetProvider).snippets;
    final editing = switch (_editing) {
      final String name => snippets.firstWhereOrNull((e) => e.name == name),
      _ => null,
    };
    // A snippet renamed or deleted from under the pane. Cleared next frame
    // rather than now, because this runs during a build.
    if (_editing is String && editing == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _editing is String) setState(() => _editing = null);
      });
    }

    return PaneSettings.listenAll((paneWidth, paneCollapsed) {
      return _tag.listenVal((tag) {
        return AdaptivePanes.detail(
          listWidth: paneWidth,
          onListWidthChanged: PaneSettings.saveWidth,
          collapsed: paneCollapsed,
          onCollapsedChanged: PaneSettings.saveCollapsed,
          collapseTooltip: libL10n.fold,
          expandTooltip: libL10n.open,
          detailId: _editing,
          onCloseDetail: () => setState(() => _editing = null),
          // Never null, so the two columns are what this tab looks like from
          // the moment it opens. A null builder hands the whole width back to
          // the list, which made the first thing anyone saw a grid of cards
          // that rearranged itself into a column as soon as one was tapped —
          // two layouts for one page, the first of which is not the page.
          detailBuilder: (_) => _editing == null
              ? const EmptyPane(icon: Icons.code_outlined)
              : SnippetEditPage(args: SnippetEditPageArgs(snippet: editing)),
          listBuilder: (_, split) => _buildScaffold(snippets, tag, split),
        );
      });
    });
  }

  Widget _buildScaffold(List<Snippet> snippets, String tag, bool split) {
    final snippetState = ref.watch(snippetProvider);

    return ListenBuilder(
      listenable: _search,
      builder: () {
        final needle = _search.needle;
        final filtered = [
          for (final snippet in snippets)
            if (tag == TagSwitcher.kDefaultTag ||
                (snippet.tags?.contains(tag) ?? false))
              // The script and the note as well as the name: a snippet is
              // often remembered by the command in it rather than by whatever
              // it was called when it was saved.
              if (needle.isEmpty ||
                  snippet.name.toLowerCase().contains(needle) ||
                  snippet.script.toLowerCase().contains(needle) ||
                  (snippet.note?.toLowerCase().contains(needle) ?? false))
                snippet,
        ];

        return Scaffold(
          appBar: _SnippetBar(
            tags: snippetState.tags.vn,
            onTagChanged: (tag) => _tag.value = tag,
            initTag: _tag.value,
            search: _search,
            onSearch: _search.start,
            onAdd: () => _edit(null, split),
          ),
          body: _buildSnippetList(filtered, split, searching: needle.isNotEmpty),
        );
      },
    );
  }

  /// Opens [snippet] — or a new one when null — beside the list, or over it
  /// when there is no room for a second column.
  void _edit(Snippet? snippet, bool split) {
    if (split) {
      setState(() => _editing = snippet?.name ?? _newSnippet);
      return;
    }
    SnippetEditPage.route.go(
      context,
      args: snippet == null ? null : SnippetEditPageArgs(snippet: snippet),
    );
  }

  Widget _buildSnippetList(
    List<Snippet> filtered,
    bool split, {
    required bool searching,
  }) {
    // Asked of what the filters left, not of everything: a tag or a query with
    // nothing under it used to draw an empty grid rather than say it was
    // empty.
    if (filtered.isEmpty) {
      return EmptyPane(
        icon: searching ? Icons.search_off : Icons.code_outlined,
        label: searching ? _search.needle : null,
      );
    }

    // The same rail the server, terminal and file pages put beside their pane,
    // because it is the same job: a narrow index read while your attention is
    // on what is open next to it. A card carries a name and two lines of the
    // script, which is worth the width at full width and is a smaller copy of
    // the editor when the editor is right there.
    if (split) {
      // Flattened rather than a list of lists: the rail scrolls as one column,
      // and a heading is a row in it like any other.
      return ListView(
        // Room at the bottom for the add button to float over, the way the
        // server rail leaves it.
        padding: const EdgeInsets.only(top: 4, bottom: 77),
        children: [
          for (final group in groupByTag(filtered, (e) => e.tags)) ...[
            if (group.label case final label?) SideBarSection(label),
            for (final snippet in group.items)
              SideBarTile(
                key: ValueKey(snippet.name),
                title: snippet.name,
                selected: _editing == snippet.name,
                onTap: () => _edit(snippet, true),
              ),
          ],
        ],
      );
    }

    // Flowed rather than a fixed grid: a row is as tall as what it has to say
    // — a snippet with a note is two lines under its name, one without is
    // fewer — and a fixed extent either clipped the long ones or left a gap
    // under every short one.
    return MasonryList.builder(
      // Room at the bottom for the add button to float over.
      padding: MasonryList.kPadding.copyWith(bottom: 77),
      itemCount: filtered.length,
      itemBuilder: (_, index) => _buildSnippetItem(filtered[index]),
    );
  }

  Widget _buildSnippetItem(Snippet snippet) {
    return CardTile(
      icon: Icons.code,
      title: snippet.name,
      subtitle: snippet.note ?? snippet.script,
      onTap: () => _edit(snippet, false),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// One row above the list: what filters it on the left, what acts on the whole
/// of it on the right.
///
/// The shape the server rail has. Search lived in a second row under the bar,
/// which no other pane has one of — and which only existed beside a pane, so on
/// a phone there was no way to search at all.
final class _SnippetBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueNotifier<Set<String>> tags;
  final String initTag;
  final void Function(String) onTagChanged;
  final VoidCallback onSearch;
  final VoidCallback onAdd;

  /// The bar's search — see [InlineSearchBar]. It was a results page, which
  /// put a read-only copy of the list over the list.
  final InlineSearchController search;

  const _SnippetBar({
    required this.tags,
    required this.initTag,
    required this.onTagChanged,
    required this.onSearch,
    required this.onAdd,
    required this.search,
  });

  @override
  Widget build(BuildContext context) {
    // In place of the switcher, as on every other tab that searches.
    return InlineSearchBar(
      controller: search,
      child: Padding(
      padding: const EdgeInsets.only(left: 10, right: 4),
      child: Row(
        children: [
          TagSwitcher(
            tags: tags,
            onTagChanged: onTagChanged,
            initTag: initTag,
            singleLine: true,
          ).expanded(),
          Btn.icon(
            text: libL10n.search,
            icon: const Icon(Icons.search, size: 20),
            onTap: onSearch,
          ),
          // Beside search rather than floating over the list, which is where
          // every other page of this app puts the same action. A button that
          // sits on top of the content also covers the last row of it, and
          // needed two of itself — one size for a pane and another for a full
          // width — for nothing the bar has to think about.
          Btn.icon(
            text: libL10n.add,
            icon: const Icon(Icons.add, size: 20),
            onTap: onAdd,
          ),
        ],
      ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(TagSwitcher.kTagBtnHeight);
}
