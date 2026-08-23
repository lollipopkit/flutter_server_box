import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/view/page/private_key/edit.dart';
import 'package:server_box/view/page/private_key/generate.dart';

class PrivateKeysListPage extends ConsumerStatefulWidget {
  const PrivateKeysListPage({super.key});

  @override
  ConsumerState<PrivateKeysListPage> createState() => _PrivateKeyListState();

  static const route = AppRouteNoArg(
    page: PrivateKeysListPage.new,
    path: '/private_key',
  );
}

class _PrivateKeyListState extends ConsumerState<PrivateKeysListPage>
    with AfterLayoutMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
      floatingActionButton: FloatingActionButton(
        onPressed: _onTapAdd,
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Two ways to end up with a key here, asked before either page opens.
  ///
  /// The dialog answers with what to do and closes itself; this navigates. A
  /// button that pushed the page from inside the dialog would be reaching for
  /// the root navigator the dialog is on, not the one holding this page.
  Future<void> _onTapAdd() async {
    final generate = await context.showRoundDialog<bool>(
      title: libL10n.add,
      childBuilder: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(l10n.sshKeyGenerate),
            onTap: () => dialogContext.popDialog(true),
          ),
          ListTile(
            leading: const Icon(Icons.file_open),
            title: Text(libL10n.import),
            onTap: () => dialogContext.popDialog(false),
          ),
        ],
      ),
      actions: const [],
    );
    if (generate == null || !mounted) return;
    if (generate) {
      PrivateKeyGeneratePage.route.go(context);
    } else {
      PrivateKeyEditPage.route.go(context);
    }
  }

  Widget _buildBody() {
    final privateKeyState = ref.watch(privateKeyProvider);
    final pkis = privateKeyState.keys;

    if (pkis.isEmpty) {
      return Center(child: Text(libL10n.empty));
    }

    final children = pkis.map(_buildKeyItem).toList();
    return PageColumns(children: children);
  }

  Widget _buildKeyItem(PrivateKeyInfo item) {
    // Read per build rather than stored: the fingerprint is a function of the
    // key, and a copy of it in the record would be one more thing that can
    // disagree with what is actually there. It is a hash of a few hundred
    // bytes, over a list of a handful of keys.
    final digest = describeSshKey(item.key);
    // The stored comment wins, and the key's own is the fallback — which is
    // what a key imported or generated before anyone edited its label has.
    // That one is absent for an encrypted key, since it sits inside the part
    // that gets encrypted while the public key does not. `type` is left for a
    // key that reads as neither.
    final lines = [
      ?digest.fingerprint,
      ?(item.comment ?? digest.comment),
      if (digest.isEmpty) item.type ?? libL10n.unknown,
    ];
    return ListTile(
      title: Text(item.name),
      subtitle: Text(
        lines.join('\n'),
        style: UIs.textGrey,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: lines.length > 1,
      onTap: () => PrivateKeyEditPage.route.go(
        context,
        args: PrivateKeyEditPageArgs(pki: item),
      ),
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
    if (isDesktop && Stores.key.keys().isEmpty) {
      final home = Pfs.homeDir;
      if (home == null) return;
      final idRsaFile = File(home.joinPath('.ssh/id_rsa'));
      if (!idRsaFile.existsSync()) return;
      final sysPk = PrivateKeyInfo(
        id: ShortId.generate(),
        name: 'system',
        key: await idRsaFile.readAsString(),
      );
      context.showRoundDialog(
        title: libL10n.attention,
        child: Text(l10n.addSystemPrivateKeyTip),
        actions: Btn.ok(
          onTap: () {
            context.popDialog();
            PrivateKeyEditPage.route.go(
              context,
              args: PrivateKeyEditPageArgs(pki: sysPk),
            );
          },
        ).toList,
      );
    }
  }
}
