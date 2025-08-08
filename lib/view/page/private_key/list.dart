import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/private_key/edit.dart';

class PrivateKeysListPage extends StatefulWidget {
  const PrivateKeysListPage({super.key});

  @override
  State<PrivateKeysListPage> createState() => _PrivateKeyListState();

  static const route = AppRouteNoArg(page: PrivateKeysListPage.new, path: '/private_key');
}

class _PrivateKeyListState extends State<PrivateKeysListPage> with AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => PrivateKeyEditPage.route.go(context),
      ),
    );
  }

  Widget _buildBody() {
    return PrivateKeyProvider.pkis.listenVal((pkis) {
      if (pkis.isEmpty) {
        return Center(child: Text(libL10n.empty));
      }

      final children = pkis.map(_buildKeyItem).toList();
      return AutoMultiList(children: children);
    });
  }

  Widget _buildKeyItem(PrivateKeyInfo item) {
    return ListTile(
      title: Text(item.id),
      subtitle: Text(item.type ?? l10n.unknown, style: UIs.textGrey),
      onTap: () => PrivateKeyEditPage.route.go(context, args: PrivateKeyEditPageArgs(pki: item)),
      trailing: const Icon(Icons.edit),
    ).cardx;
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    _autoAddSystemPriavteKey();
  }
}

extension on _PrivateKeyListState {
  void _autoAddSystemPriavteKey() async {
    // Only trigger on desktop platform and no private key saved
    if (isDesktop && Stores.snippet.box.keys.isEmpty) {
      final home = Pfs.homeDir;
      if (home == null) return;
      final idRsaFile = File(home.joinPath('.ssh/id_rsa'));
      if (!idRsaFile.existsSync()) return;
      final sysPk = PrivateKeyInfo(id: 'system', key: await idRsaFile.readAsString());
      context.showRoundDialog(
        title: libL10n.attention,
        child: Text(l10n.addSystemPrivateKeyTip),
        actions: Btn.ok(
          onTap: () {
            context.pop();
            PrivateKeyEditPage.route.go(context, args: PrivateKeyEditPageArgs(pki: sysPk));
          },
        ).toList,
      );
    }
  }
}
