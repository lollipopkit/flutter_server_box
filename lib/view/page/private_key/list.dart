import 'dart:io';
import 'dart:async';
import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:provider/provider.dart';
import 'package:toolbox/core/extension/context/common.dart';
import 'package:toolbox/core/extension/context/dialog.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:toolbox/core/utils/platform/path.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../core/route.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/provider/private_key.dart';
import '../../../data/res/ui.dart';
import '../../widget/custom_appbar.dart';
import '../../../view/widget/round_rect_card.dart';

class PrivateKeysListPage extends StatefulWidget {
  const PrivateKeysListPage({Key? key}) : super(key: key);

  @override
  _PrivateKeyListState createState() => _PrivateKeyListState();
}

class _PrivateKeyListState extends State<PrivateKeysListPage>
    with AfterLayoutMixin {
  late S _s;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _s = S.of(context)!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(_s.privateKey, style: UIs.textSize18),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => AppRoute.keyEdit().go(context),
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
            final item = key.pkis[idx];
            return RoundRectCard(
              ListTile(
                leading: Text(
                  '#$idx',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: Text(item.id),
                subtitle: Text(item.type ?? _s.unknown, style: UIs.textGrey),
                onTap: () => AppRoute.keyEdit(pki: item).go(context),
                trailing: const Icon(Icons.edit),
              ),
            );
          },
        );
      },
    );
  }

  void autoAddSystemPriavteKey() {
    // Only trigger on desktop platform and no private key saved
    if (isDesktop && Stores.snippet.box.keys.isEmpty) {
      final home = getHomeDir();
      if (home == null) return;
      final idRsaFile = File(joinPath(home, '.ssh/id_rsa'));
      if (!idRsaFile.existsSync()) return;
      final sysPk = PrivateKeyInfo(
        id: 'system',
        key: idRsaFile.readAsStringSync(),
      );
      context.showRoundDialog(
        title: Text(_s.attention),
        child: Text(_s.addSystemPrivateKeyTip),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              AppRoute.keyEdit(pki: sysPk).go(context);
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

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    autoAddSystemPriavteKey();
  }
}
