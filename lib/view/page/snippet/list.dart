import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/order.dart';
import 'package:toolbox/view/widget/tag/switcher.dart';

import '../../../data/store/setting.dart';
import '../../../locator.dart';
import '/core/route.dart';
import '/data/provider/snippet.dart';
import 'edit.dart';
import '/view/widget/round_rect_card.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({Key? key}) : super(key: key);

  @override
  _SnippetListPageState createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  late S _s;
  late MediaQueryData _media;

  final _settingStore = locator<SettingStore>();

  String? _tag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
    _media = MediaQuery.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippet',
        child: const Icon(Icons.add),
        onPressed: () => AppRoute(
          const SnippetEditPage(),
          'snippet edit page',
        ).go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<SnippetProvider>(
      builder: (_, provider, __) {
        if (provider.snippets.isEmpty) {
          return Center(
            child: Text(_s.noSavedSnippet),
          );
        }

        final filtered = provider.snippets
            .where((e) => _tag == null || (e.tags?.contains(_tag) ?? false))
            .toList();

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: filtered.length,
          onReorder: (oldIdx, newIdx) => setState(() {
            provider.snippets.moveById(
              filtered[oldIdx],
              filtered[newIdx],
              onMove: (p0) {
                _settingStore.snippetOrder.put(p0.map((e) => e.name).toList());
              },
            );
          }),
          header: TagSwitcher(
            tags: provider.tags,
            onTagChanged: (tag) => setState(() => _tag = tag),
            initTag: _tag,
            all: _s.all,
            width: _media.size.width,
          ),
          itemBuilder: (context, idx) {
            final snippet = filtered[idx];
            return RoundRectCard(
              ListTile(
                contentPadding: const EdgeInsets.only(left: 23, right: 17),
                title: Text(
                  snippet.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: IconButton(
                  onPressed: () => AppRoute(
                    SnippetEditPage(snippet: snippet),
                    'snippet edit page',
                  ).go(context),
                  icon: const Icon(Icons.edit),
                ),
              ),
              key: ValueKey(snippet.name),
            );
          },
        );
      },
    );
  }
}
