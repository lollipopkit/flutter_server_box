import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/snippet.dart';

class SnippetResultPage extends StatelessWidget {
  final List<SnippetResult?> args;

  const SnippetResultPage({super.key, required this.args});

  static const route = AppRouteArg(page: SnippetResultPage.new, path: '/snippets/result');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: Text(l10n.result)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 17),
      itemCount: args.length,
      itemBuilder: (_, index) {
        final item = args[index];
        if (item == null) return UIs.placeholder;
        return CardX(
          child: ExpandTile(
            initiallyExpanded: args.length == 1,
            title: Text(item.dest ?? ''),
            subtitle: Text(item.time.toString(), style: UIs.textGrey),
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                scrollDirection: Axis.horizontal,
                child: Text(item.result, textAlign: TextAlign.start),
              ),
            ],
          ),
        );
      },
    );
  }
}
