import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/provider/snippet.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({super.key});

  @override
  State<SnippetListPage> createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage>
    with AutomaticKeepAliveClientMixin {
  final _tag = ''.vn;

  @override
  void dispose() {
    super.dispose();
    _tag.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: TagSwitcher(
        tags: SnippetProvider.tags,
        onTagChanged: (tag) => _tag.value = tag,
        initTag: _tag.value,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippetAdd',
        child: const Icon(Icons.add),
        onPressed: () => AppRoutes.snippetEdit().go(context),
      ),
    );
  }

  Widget _buildBody() {
    return SnippetProvider.snippets.listenVal(
      (snippets) {
        if (snippets.isEmpty) return Center(child: Text(libL10n.empty));
        return _tag.listenVal((tag) => _buildSnippetList(snippets, tag));
      },
    );
  }

  Widget _buildSnippetList(List<Snippet> snippets, String tag) {
    final filtered = tag == TagSwitcher.kDefaultTag
        ? snippets
        : snippets.where((e) => e.tags?.contains(tag) ?? false).toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      itemCount: filtered.length,
      onReorder: (oldIdx, newIdx) {
        snippets.moveByItem(
          oldIdx,
          newIdx,
          filtered: filtered,
          onMove: (p0) {
            Stores.setting.snippetOrder.put(p0.map((e) => e.name).toList());
          },
        );
        SnippetProvider.snippets.notify();
      },
      footer: UIs.height77,
      buildDefaultDragHandles: false,
      itemBuilder: (context, idx) {
        final snippet = filtered.elementAt(idx);
        return ReorderableDelayedDragStartListener(
          key: ValueKey(idx),
          index: idx,
          child: _buildSnippetItem(snippet),
        );
      },
    );
  }

  Widget _buildSnippetItem(Snippet snippet) {
    return CardX(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 23, right: 17),
        title: Text(
          snippet.name,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          snippet.note ?? snippet.script,
          overflow: TextOverflow.ellipsis,
          maxLines: 3,
          style: UIs.textGrey,
        ),
        trailing: const Icon(Icons.keyboard_arrow_right),
        onTap: () => AppRoutes.snippetEdit(snippet: snippet).go(context),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  // Future<void> _runSnippet(Snippet snippet) async {
  //   final servers = await context.showPickDialog<Server>(
  //     items: Pros.server.servers.toList(),
  //     name: (e) => e.spi.name,
  //   );
  //   if (servers == null) {
  //     return;
  //   }
  //   final ids = servers.map((e) => e.spi.id).toList();
  //   final results = await Pros.server.runSnippetsMulti(ids, snippet);
  //   if (results.isNotEmpty) {
  //     AppRoutes.snippetResult(results: results).go(context);
  //   }
  // }
}
