import 'dart:io';
import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';

import '../../../core/route.dart';
import '../../../data/model/server/private_key_info.dart';
import '../../../data/provider/private_key.dart';

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
      appBar: CustomAppBar(
        title: Text(l10n.privateKey, style: UIs.text18),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => AppRoutes.keyEdit().go(context),
      ),
    );
  }

  Widget _buildBody() {
    return Consumer<PrivateKeyProvider>(
      builder: (_, key, __) {
        if (key.pkis.isEmpty) {
          return Center(
            child: Text(l10n.noSavedPrivateKey),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(13),
          itemCount: key.pkis.length,
          itemBuilder: (context, idx) {
            final item = key.pkis[idx];
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
        title: l10n.attention,
        child: Text(l10n.addSystemPrivateKeyTip),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              AppRoutes.keyEdit(pki: sysPk).go(context);
            },
            child: Text(l10n.ok),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
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
