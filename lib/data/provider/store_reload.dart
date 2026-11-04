import 'dart:async';

import 'package:server_box/data/provider/ai/agent_scope.dart';
import 'package:server_box/data/provider/bmc_credential.dart';
import 'package:server_box/data/provider/container.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/snippet.dart';

/// The providers reading stores a restore or a sync just rewrote, told to
/// read them again. One place for both, through the app's own container
/// ([AgentScope.container]) rather than a page's: the reload happens whether
/// or not the home page is mounted.
abstract final class StoreReload {
  static void after({
    bool servers = false,
    bool snippets = false,
    bool keys = false,
    bool bmcCredentials = false,
    bool containers = false,
  }) {
    final providers = AgentScope.maybeContainer;
    if (providers == null) return;
    // Not awaited: the reload reconnects every server, which a merge has no
    // reason to wait for.
    if (servers) unawaited(providers.read(serversProvider.notifier).reload());
    if (snippets) providers.read(snippetProvider.notifier).reload();
    if (keys) providers.read(privateKeyProvider.notifier).reload();
    if (bmcCredentials) providers.read(bmcCredentialProvider.notifier).reload();
    if (containers) providers.invalidate(containerProvider);
  }
}
