import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/view/page/bmc_credential/edit.dart';

/// The BMC accounts, and how many servers each one opens.
///
/// Its own page because the account outlives the server it was first typed
/// into: a rack shares one, so rotating a password is one edit here rather
/// than twenty in the server editor.
class BmcCredentialsListPage extends ConsumerWidget {
  const BmcCredentialsListPage({super.key});

  static const route = AppRouteNoArg(
    page: BmcCredentialsListPage.new,
    path: '/bmc_credential',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creds = ref.watch(bmcCredentialProvider).creds;

    return Scaffold(
      body: SafeArea(
        child: creds.isEmpty
            ? Center(child: Text(libL10n.empty))
            : PageColumns(
                children: [
                  for (final cred in creds) _buildItem(context, ref, cred),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => BmcCredentialEditPage.route.go(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildItem(BuildContext context, WidgetRef ref, BmcCredential cred) {
    final shared = ref.read(bmcCredentialProvider.notifier).serversUsing(
      cred.id,
    );
    return ListTile(
      title: Text(cred.name),
      subtitle: Text(
        shared > 0 ? '${cred.user} - ${l10n.bmcAccountShared(shared)}'
            : cred.user,
        style: UIs.textGrey,
      ),
      trailing: const Icon(Icons.edit),
      onTap: () => BmcCredentialEditPage.route.go(
        context,
        args: BmcCredentialEditPageArgs(cred: cred),
      ),
    ).cardx;
  }
}
