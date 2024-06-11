import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

import '../../../data/model/server/snippet.dart';
import '/core/route.dart';
import '/data/provider/snippet.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({super.key});

  @override
  State<SnippetListPage> createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  late MediaQueryData _media;

  String? _tag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _media = MediaQuery.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippetAdd',
        child: const Icon(Icons.add),
        onPressed: () => AppRoutes.snippetEdit().go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<SnippetProvider>(
      builder: (_, provider, __) {
        if (provider.snippets.isEmpty) {
          return Center(
            child: Text(l10n.noSavedSnippet),
          );
        }

        final filtered = provider.snippets
            .where((e) => _tag == null || (e.tags?.contains(_tag) ?? false))
            .toList();

        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          itemCount: filtered.length,
          onReorder: (oldIdx, newIdx) => setState(() {
            provider.snippets.moveByItem(
              oldIdx,
              newIdx,
              filtered: filtered,
              onMove: (p0) {
                Stores.setting.snippetOrder.put(p0.map((e) => e.name).toList());
              },
            );
          }),
          header: TagSwitcher(
            tags: provider.tags,
            onTagChanged: (tag) => setState(() => _tag = tag),
            initTag: _tag,
            width: _media.size.width,
          ),
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () =>
                  AppRoutes.snippetEdit(snippet: snippet).go(context),
              icon: const Icon(Icons.edit),
            ),
          ],
        ),
      ),
    );
  }

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
