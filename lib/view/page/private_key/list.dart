import 'dart:io';
import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';

class PrivateKeysListPage extends StatefulWidget {
  const PrivateKeysListPage({super.key});

  @override
  State<PrivateKeysListPage> createState() => _PrivateKeyListState();
}

class _PrivateKeyListState extends State<PrivateKeysListPage>
    with AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => AppRoutes.keyEdit().go(context),
      ),
    );
  }

  Widget _buildBody() {
    return PrivateKeyProvider.pkis.listenVal(
      (pkis) {
        if (pkis.isEmpty) {
          return Center(child: Text(libL10n.empty));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: pkis.length,
          itemBuilder: (context, idx) {
            final item = pkis[idx];
            return CardX(
              child: ListTile(
                leading: Text(
                  '#$idx',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                title: Text(item.id),
                subtitle: Text(item.type ?? l10n.unknown, style: UIs.textGrey),
                onTap: () => AppRoutes.keyEdit(pki: item).go(context),
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
      final home = Pfs.homeDir;
      if (home == null) return;
      final idRsaFile = File(home.joinPath('.ssh/id_rsa'));
      if (!idRsaFile.existsSync()) return;
      final sysPk = PrivateKeyInfo(
        id: 'system',
        key: idRsaFile.readAsStringSync(),
      );
      context.showRoundDialog(
        title: libL10n.attention,
        child: Text(l10n.addSystemPrivateKeyTip),
        actions: Btn.ok(onTap: () {
          context.pop();
          AppRoutes.keyEdit(pki: sysPk).go(context);
        }).toList,
      );
    }
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) {
    autoAddSystemPriavteKey();
  }
}
