import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/widget/empty_pane.dart';
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

    return PaneSettings.listen((paneWidth) {
      return _tag.listenVal((tag) {
        return AdaptivePanes(
          primaryWidth: paneWidth,
          onPrimaryWidthChanged: PaneSettings.saveWidth,
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
          primaryBuilder: (_, split) => _buildScaffold(snippets, tag, split),
        );
      });
    });
  }

  Widget _buildScaffold(List<Snippet> snippets, String tag, bool split) {
    final snippetState = ref.watch(snippetProvider);
    return Scaffold(
      appBar: TagSwitcher(
        tags: snippetState.tags.vn,
        onTagChanged: (tag) => _tag.value = tag,
        initTag: _tag.value,
        singleLine: true,
      ),
      body: _buildSnippetList(snippets, tag, split),
      // Small in a column, like the server rail's: a full-size button in a
      // rail this narrow covers the row under it.
      floatingActionButton: split
          ? FloatingActionButton.small(
              heroTag: 'snippetAdd',
              tooltip: libL10n.add,
              onPressed: () => _edit(null, true),
              child: const Icon(Icons.add),
            )
          : FloatingActionButton(
              heroTag: 'snippetAdd',
              tooltip: libL10n.add,
              onPressed: () => _edit(null, false),
              child: const Icon(Icons.add),
            ),
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

  Widget _buildSnippetList(List<Snippet> snippets, String tag, bool split) {
    if (snippets.isEmpty) return Center(child: Text(libL10n.empty));

    final filtered = tag == TagSwitcher.kDefaultTag
        ? snippets
        : snippets.where((e) => e.tags?.contains(tag) ?? false).toList();

    // The same rail the server, terminal and file pages put beside their pane,
    // because it is the same job: a narrow index read while your attention is
    // on what is open next to it. A card carries a name and two lines of the
    // script, which is worth the width at full width and is a smaller copy of
    // the editor when the editor is right there.
    if (split) {
      return ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 77),
        itemCount: filtered.length,
        itemBuilder: (_, index) {
          final snippet = filtered[index];
          return SideBarTile(
            title: snippet.name,
            selected: _editing == snippet.name,
            onTap: () => _edit(snippet, true),
          );
        },
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
