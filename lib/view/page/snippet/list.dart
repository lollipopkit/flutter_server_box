import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/padding.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/view/page/snippet/edit.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({Key? key}) : super(key: key);

  @override
  _SnippetListPageState createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  final _textStyle = TextStyle(color: primaryColor);

  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.snippet, style: textSize18),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () =>
            AppRoute(const SnippetEditPage(), 'snippet edit page').go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<SnippetProvider>(
      builder: (_, key, __) {
        if (key.snippets.isEmpty) {
          return Center(
            child: Text(_s.noSavedSnippet),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: key.snippets.length,
          itemExtent: 57,
          itemBuilder: (context, idx) {
            return RoundRectCard(
              Padding(
                padding: roundRectCardPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      key.snippets[idx].name,
                      textAlign: TextAlign.center,
                    ),
                    TextButton(
                      onPressed: () => AppRoute(
                              SnippetEditPage(snippet: key.snippets[idx]),
                              'snippet edit page')
                          .go(context),
                      child: Text(
                        _s.edit,
                        style: _textStyle,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
