import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/core/utils.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/provider/server.dart';
import 'package:toolbox/data/provider/snippet.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/data/res/font_style.dart';
import 'package:toolbox/data/res/padding.dart';
import 'package:toolbox/generated/l10n.dart';
import 'package:toolbox/locator.dart';
import 'package:toolbox/view/page/snippet/edit.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class SnippetListPage extends StatefulWidget {
  const SnippetListPage({Key? key, this.spi}) : super(key: key);
  final ServerPrivateInfo? spi;

  @override
  _SnippetListPageState createState() => _SnippetListPageState();
}

class _SnippetListPageState extends State<SnippetListPage> {
  late ServerPrivateInfo _selectedIndex;

  final _textStyle = TextStyle(color: primaryColor);

  late S s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    s = S.of(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.snippet, style: textSize18),
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
        return key.snippets.isNotEmpty
            ? ListView.builder(
                padding: const EdgeInsets.all(13),
                itemCount: key.snippets.length,
                itemExtent: 57,
                itemBuilder: (context, idx) {
                  return RoundRectCard(Padding(
                    padding: roundRectCardPadding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          key.snippets[idx].name,
                          textAlign: TextAlign.center,
                        ),
                        Row(children: [
                          TextButton(
                              onPressed: () => AppRoute(
                                      SnippetEditPage(
                                          snippet: key.snippets[idx]),
                                      'snippet edit page')
                                  .go(context),
                              child: Text(
                                s.edit,
                                style: _textStyle,
                              )),
                          TextButton(
                              onPressed: () {
                                final snippet = key.snippets[idx];
                                if (widget.spi == null) {
                                  _showRunDialog(snippet);
                                  return;
                                }
                                run(context, snippet);
                              },
                              child: Text(
                                s.run,
                                style: _textStyle,
                              ))
                        ])
                      ],
                    ),
                  ));
                })
            : Center(child: Text(s.noSavedSnippet));
      },
    );
  }

  void _showRunDialog(Snippet snippet) {
    showRoundDialog(context, s.chooseDestination,
        Consumer<ServerProvider>(builder: (_, provider, __) {
      if (provider.servers.isEmpty) {
        return Text(s.noServerAvailable);
      }
      _selectedIndex = provider.servers.first.info;
      return SizedBox(
          height: 111,
          child: Stack(children: [
            Positioned(
              top: 36,
              bottom: 36,
              left: 0,
              right: 0,
              child: Container(
                height: 37,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                  color: Colors.black12,
                ),
              ),
            ),
            ListWheelScrollView.useDelegate(
              itemExtent: 37,
              diameterRatio: 1.2,
              controller: FixedExtentScrollController(initialItem: 0),
              onSelectedItemChanged: (idx) =>
                  _selectedIndex = provider.servers[idx].info,
              physics: const FixedExtentScrollPhysics(),
              childDelegate: ListWheelChildBuilderDelegate(
                  builder: (context, index) => Center(
                        child: Text(
                          provider.servers[index].info.name,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  childCount: provider.servers.length),
            )
          ]));
    }), [
      TextButton(
          onPressed: () async => run(context, snippet), child: Text(s.run)),
      TextButton(
          onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
    ]);
  }

  Future<void> run(BuildContext context, Snippet snippet) async {
    final result = await locator<ServerProvider>()
        .runSnippet(widget.spi ?? _selectedIndex, snippet);
    if (result != null) {
      showRoundDialog(context, s.result,
          Text(result, style: const TextStyle(fontSize: 13)), [
        TextButton(
            onPressed: () => Navigator.of(context).pop(), child: Text(s.close))
      ]);
    }
  }
}
