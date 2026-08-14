import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/view/page/snippet/edit.dart';
import 'package:server_box/view/page/ssh/snippet_run.dart';

class SnippetListPage extends ConsumerStatefulWidget {
  const SnippetListPage({super.key});

  @override
  ConsumerState<SnippetListPage> createState() => _SnippetListPageState();

  static const route = AppRouteNoArg(
    page: SnippetListPage.new,
    path: '/snippets',
  );
}

class _SnippetListPageState extends ConsumerState<SnippetListPage>
    with AutomaticKeepAliveClientMixin {
  final _tag = ''.vn;

  static const _desiredItemHeight = 85.0;

  @override
  void dispose() {
    super.dispose();
    _tag.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildBody();
  }

  Widget _buildBody() {
    final snippetState = ref.watch(snippetProvider);
    final snippets = snippetState.snippets;

    return _tag.listenVal((tag) {
      return _buildScaffold(snippets, tag);
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
          SnippetEditPage.route.go(context);
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
    return InkWell(
      onTap: () {
        SnippetEditPage.route.go(
          context,
          args: SnippetEditPageArgs(snippet: snippet),
        );
      },
      child: SizedBox(
        height: _desiredItemHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: 23, right: 45),
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
            // Running is what a snippet is *for*, so it gets a target of its
            // own rather than living behind the editor: tapping the card still
            // opens the editor, which is what the chevron behind this promises.
            Positioned(
              top: 0,
              right: 9,
              bottom: 0,
              child: Center(
                child: IconButton(
                  tooltip: libL10n.run,
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () => _run(snippet),
                ),
              ),
            ),
          ],
        ),
      ),
    ).cardx;
  }

  /// Picks a server, then runs the snippet on it.
  ///
  /// The picker is here rather than a step inside the terminal because the
  /// question — which machine — is the only thing this page does not already
  /// know, and answering it should not require going to the server list and
  /// finding the snippet again from there.
  Future<void> _run(Snippet snippet) async {
    final servers = ref.read(serversProvider);
    final spis = [for (final id in servers.serverOrder) ?servers.servers[id]];
    if (spis.isEmpty) {
      context.showSnackBar(libL10n.empty);
      return;
    }

    final chosen = await context.showPickSingleDialog<Spi>(
      title: libL10n.server,
      items: spis,
      display: (spi) => spi.name,
    );
    if (chosen == null || !mounted) return;

    final fmted = snippet.fmtWithSpi(chosen);
    final sure = await context.showRoundDialog<bool>(
      title: libL10n.attention,
      child: SingleChildScrollView(
        child: SimpleMarkdown(data: '```shell\n$fmted\n```'),
      ),
      actions: [
        CountDownBtn(
          onTap: () => context.popDialog(true),
          text: libL10n.run,
          afterColor: Colors.red,
        ),
      ],
    );
    if (sure != true || !mounted) return;

    // The same dialog the server page runs a snippet in. One action, one
    // behaviour: it runs here, and moves to the terminal tab only if the user
    // wants to stay with it — where every other shell in the app lives, and so
    // where it can be returned to after this page is left.
    final session = await showSnippetRun(
      context,
      ref,
      spi: chosen,
      snippet: snippet,
    );
    if (session == null) return;
    // Nowhere left to send it. Hanging up beats leaving a shell running with
    // nothing that can ever show it again.
    if (!mounted) {
      session.close();
      return;
    }
    ref.read(terminalRequestsProvider.notifier).add(chosen, session: session);
    ref.read(homeTabRequestProvider.notifier).go(AppTab.ssh);
  }

  @override
  bool get wantKeepAlive => true;
}
