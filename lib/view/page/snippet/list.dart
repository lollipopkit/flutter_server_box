import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'snippet',
        child: const Icon(Icons.add),
        onPressed: () =>
            AppRoute(const SnippetEditPage(), 'snippet edit page',).go(context),
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

        return ListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: provider.snippets.length,
          itemBuilder: (context, idx) {
            return RoundRectCard(
              ListTile(
                contentPadding: const EdgeInsets.only(left: 23, right: 17),
                title: Text(
                  provider.snippets[idx].name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                trailing: IconButton(
                  onPressed: () => AppRoute(
                          SnippetEditPage(snippet: provider.snippets[idx]),
                          'snippet edit page')
                      .go(context),
                  icon: const Icon(Icons.edit),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
