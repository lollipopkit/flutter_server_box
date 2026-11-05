import 'dart:async';

import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';
import 'package:server_box/data/store/store_reload.dart';

/// The providers reading stores a restore or a sync just rewrote, told to
/// read them again. One place for both, through the app's own container
/// ([AgentScope.container]) rather than a page's: the reload happens whether
/// or not the home page is mounted.
void installStoreReload() => StoreReload.reload = _reload;

void _reload(Set<ReloadedStore> rewritten) {
  final providers = AgentScope.maybeContainer;
  if (providers == null) return;
  for (final store in rewritten) {
    switch (store) {
      // Not awaited: the reload reconnects every server, which a merge has no
      // reason to wait for.
      case ReloadedStore.servers:
        unawaited(providers.read(serversProvider.notifier).reload());
      case ReloadedStore.snippets:
        providers.read(snippetProvider.notifier).reload();
      case ReloadedStore.keys:
        providers.read(privateKeyProvider.notifier).reload();
      case ReloadedStore.bmcCredentials:
        providers.read(bmcCredentialProvider.notifier).reload();
      case ReloadedStore.containers:
        providers.invalidate(containerProvider);
    }
  }
}
