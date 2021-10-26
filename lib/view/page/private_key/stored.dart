import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/route.dart';
import 'package:toolbox/data/provider/private_key.dart';
import 'package:toolbox/data/res/color.dart';
import 'package:toolbox/view/page/private_key/edit.dart';
import 'package:toolbox/view/widget/round_rect_card.dart';

class StoredPrivateKeysPage extends StatefulWidget {
  const StoredPrivateKeysPage({Key? key}) : super(key: key);

  @override
  _PrivateKeyListState createState() => _PrivateKeyListState();
}

class _PrivateKeyListState extends State<StoredPrivateKeysPage> {
  final _textStyle = TextStyle(color: primaryColor);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Private Keys'),
      ),
      body: Consumer<PrivateKeyProvider>(
        builder: (_, key, __) {
          return key.infos.isNotEmpty
              ? ListView.builder(
                  padding: const EdgeInsets.all(13),
                  itemCount: key.infos.length,
                  itemExtent: 57,
                  itemBuilder: (context, idx) {
                    return RoundRectCard(Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          key.infos[idx].id,
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                            onPressed: () => AppRoute(
                                    PrivateKeyEditPage(info: key.infos[idx]),
                                    'private key edit page')
                                .go(context),
                            child: Text(
                              'Edit',
                              style: _textStyle,
                            ))
                      ],
                    ));
                  })
              : const Center(child: Text('No saved private keys.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () =>
            AppRoute(const PrivateKeyEditPage(), 'private key edit page')
                .go(context),
      ),
    );
  }
}
