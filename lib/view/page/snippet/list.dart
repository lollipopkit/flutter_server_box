import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// The name of the snippet being edited, [_newSnippet] for one being
  /// created, or null for nothing.
  ///
  /// The name rather than the object, because that is a snippet's identity —
  /// `SnippetProvider.update` finds the old one by it — and because the object
  /// is replaced on every edit.
  Object? _editing;

  static const _desiredItemHeight = 85.0;

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
          // Null until something is opened, so the list gets the whole width
          // to browse in rather than a column reserved for nothing.
          detailBuilder: _editing == null
              ? null
              : (_) => SnippetEditPage(
                  args: SnippetEditPageArgs(snippet: editing),
                ),
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippetAdd',
        child: const Icon(Icons.add),
        onPressed: () => _edit(null, split),
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

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        // One column beside an editor, however wide the window is: the list is
        // an index there, not the browsing grid it is at full width.
        maxCrossAxisExtent: split ? double.infinity : UIs.columnWidth,
        mainAxisExtent: _desiredItemHeight,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final snippet = filtered[index];
        return _buildSnippetItem(snippet, split);
      },
    );
  }

  Widget _buildSnippetItem(Snippet snippet, bool split) {
    return InkWell(
      onTap: () => _edit(snippet, split),
      child: SizedBox(
        height: _desiredItemHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      snippet.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      snippet.note ?? snippet.script,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: UIs.textGrey,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).cardx;
  }

  @override
  bool get wantKeepAlive => true;
}
