import 'package:flutter/material.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/view/widget/cardx.dart';
import 'package:toolbox/view/widget/custom_appbar.dart';
import 'package:toolbox/view/widget/expand_tile.dart';

class SnippetResultPage extends StatelessWidget {
  final Map<String, String?> results;

  const SnippetResultPage({super.key, required this.results});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(l10n.result),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 17),
        itemCount: results.length,
        itemBuilder: (_, index) {
          final key = results.keys.elementAt(index);
          final value = results[key];
          return CardX(
            ExpandTile(
              initiallyExpanded: results.length == 1,
              title: Text(key),
              children: [
                Text(
                  value ?? '',
                  textAlign: TextAlign.start,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
