import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/navigator.dart';
import 'package:toolbox/core/utils/ui.dart';
import 'package:toolbox/data/store/private_key.dart';
import 'package:toolbox/locator.dart';

import '../../../core/route.dart';
import '../../../core/utils/misc.dart';
import '../../../core/utils/platform.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/res/ui.dart';
import 'edit.dart';
import '../../../view/widget/round_rect_card.dart';

class PrivateKeysListPage extends StatefulWidget {
  const PrivateKeysListPage({Key? key}) : super(key: key);

  @override
  _PrivateKeyListState createState() => _PrivateKeyListState();
}

class _PrivateKeyListState extends State<PrivateKeysListPage> {
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  void initState() {
    super.initState();

    autoAddSystemPriavteKey();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_s.privateKey, style: textSize18),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => AppRoute(
          const PrivateKeyEditPage(),
          'private key edit page',
        ).go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<PrivateKeyProvider>(
      builder: (_, key, __) {
        if (key.pkis.isEmpty) {
          return Center(
            child: Text(_s.noSavedPrivateKey),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: key.pkis.length,
          itemBuilder: (context, idx) {
            return RoundRectCard(
              ListTile(
                title: Text(key.pkis[idx].id),
                trailing: TextButton(
                  onPressed: () => AppRoute(
                    PrivateKeyEditPage(pki: key.pkis[idx]),
                    'private key edit page',
                  ).go(context),
                  child: Text(_s.edit),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void autoAddSystemPriavteKey() {
    final store = locator<PrivateKeyStore>();
    // Only trigger on desktop platform and no private key saved
    if (isDesktop && store.box.keys.isEmpty) {
      final home = getHomeDir();
      if (home == null) return;
      final idRsaFile = File(pathJoin(home, '.ssh/id_rsa'));
      if (!idRsaFile.existsSync()) return;
      final sysPk = PrivateKeyInfo(
        id: 'system',
        key: idRsaFile.readAsStringSync(),
      );
      showRoundDialog(
        context: context,
        title: Text(_s.attention),
        child: Text(_s.addSystemPrivateKeyTip),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              AppRoute(
                PrivateKeyEditPage(pki: sysPk),
                'private key edit page',
              ).go(context);
            },
            child: Text(_s.ok),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_s.cancel),
          ),
        ],
      );
    }
  }
}
