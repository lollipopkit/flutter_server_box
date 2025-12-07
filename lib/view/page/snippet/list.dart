import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/view/page/snippet/edit.dart';

class SnippetListPage extends ConsumerStatefulWidget {
  const SnippetListPage({super.key});

  @override
  ConsumerState<SnippetListPage> createState() => _SnippetListPageState();

  static const route = AppRouteNoArg(page: SnippetListPage.new, path: '/snippets');
}

class _SnippetListPageState extends ConsumerState<SnippetListPage> with AutomaticKeepAliveClientMixin {
  final _tag = ''.vn;
  final _splitViewCtrl = SplitViewController();

  static const _desiredItemHeight = 77.0;

  @override
  void dispose() {
    super.dispose();
    _tag.dispose();
    _splitViewCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody();
  }

  Widget _buildBody() {
    // final isMobile = ResponsiveBreakpoints.of(context).isMobile;
    final snippetState = ref.watch(snippetProvider);
    final snippets = snippetState.snippets;
    
    return _tag.listenVal((tag) {
      final child = _buildScaffold(snippets, tag);
      // if (isMobile) {
      return child;
      // }

        // return SplitView(
        //   controller: _splitViewCtrl,
        //   leftWeight: 1,
        //   rightWeight: 1.3,
        //   initialRight: Center(child: Text(libL10n.empty)),
        //   leftBuilder: (_, __) => child,
        // );
    });
  }

  Widget _buildScaffold(List<Snippet> snippets, String tag) {
    final snippetState = ref.watch(snippetProvider);
    return Scaffold(
      appBar: TagSwitcher(
        tags: snippetState.tags.vn,
        onTagChanged: (tag) => _tag.value = tag,
        initTag: _tag.value,
        singleLine: true,
      ),
      body: _buildSnippetList(snippets, tag),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippetAdd',
        child: const Icon(Icons.add),
        onPressed: () {
          // if (ResponsiveBreakpoints.of(context).isMobile) {
          SnippetEditPage.route.go(context);
          // } else {
          //   _splitViewCtrl.replace(const SnippetEditPage());
          // }
        },
      ),
    );
  }

  Widget _buildSnippetList(List<Snippet> snippets, String tag) {
    if (snippets.isEmpty) return Center(child: Text(libL10n.empty));

    final filtered = tag == TagSwitcher.kDefaultTag
        ? snippets
        : snippets.where((e) => e.tags?.contains(tag) ?? false).toList();

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: UIs.columnWidth,
        mainAxisExtent: _desiredItemHeight,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final snippet = filtered[index];
        return _buildSnippetItem(snippet);
      },
    );
  }

  Widget _buildSnippetItem(Snippet snippet) {
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 23, right: 17),
      title: Text(snippet.name, overflow: TextOverflow.ellipsis, maxLines: 1),
      subtitle: Text(
        snippet.note ?? snippet.script,
        overflow: TextOverflow.ellipsis,
        maxLines: 3,
        style: UIs.textGrey,
      ),
      trailing: const Icon(Icons.keyboard_arrow_right),
      onTap: () {
        // final isMobile = ResponsiveBreakpoints.of(context).isMobile;
        // if (isMobile) {
        SnippetEditPage.route.go(context, args: SnippetEditPageArgs(snippet: snippet));
        // } else {
        //   _splitViewCtrl.replace(SnippetEditPage(
        //     args: SnippetEditPageArgs(snippet: snippet),
        //   ));
        // }
      },
    ).cardx;
  }

  @override
  bool get wantKeepAlive => true;
}
