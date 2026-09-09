/// The permissions dialog, and the only place consent is given.
///
/// Shared by every way a plugin arrives — a `.sbp`, a development directory,
/// a repository — because they are the same question. Which is also the rule
/// an update follows: it asks again, since the permissions may have moved and
/// PLUGINS.md 6.2 says an added one must not be usable before the user has
/// seen it.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

/// The permissions dialog, and the only place consent is given.
///
/// Answers the set the user agreed to, or null if they did not. All or
/// nothing on purpose: a plugin that asks for two things and is granted one
/// is a plugin whose author never tested that combination, and the failure
/// lands on the user as a feature that half works.
Future<Set<String>?> askPluginConsent(
  BuildContext context,
  ffi.PluginManifestInfo manifest,
) async {
  final permissions = manifest.permissions;
  final ok = await context.showRoundDialog<bool>(
    title: '${manifest.name} ${manifest.version}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 7,
      children: [
        if (manifest.description.isNotEmpty)
          Text(manifest.description, style: UIs.textGrey),
        Text(
          permissions.isEmpty
              ? l10n.pluginNoPermissions
              : l10n.pluginPermissionsAsk,
        ),
        for (final name in permissions)
          Row(
            spacing: 5,
            children: [
              const Icon(Icons.chevron_right, size: 15),
              Flexible(child: Text(_describe(name), style: UIs.text13)),
            ],
          ),
        // A status plugin runs a command it chose on every server it is
        // shown for. `server.exec` is what says so in the list above, but
        // the list is names and this is what they mean.
        // The two that are worth a sentence rather than a name: one runs
        // arbitrary commands, the other learns the whole fleet exists.
        if (permissions.contains('server.list'))
          Text(
            l10n.pluginSeesAllServersTip,
            style: TextStyle(
              fontSize: 11,
              color: context.theme.colorScheme.error,
            ),
          ),
        if (permissions.contains('server.exec'))
          Text(
            l10n.pluginRunsOnServer,
            style: TextStyle(
              fontSize: 11,
              color: context.theme.colorScheme.error,
            ),
          ),
      ],
    ),
    actions: Btnx.cancelOk,
  );
  if (ok != true) return null;
  return permissions.toSet();
}

/// The same question for an update, asked only when there is something new in
/// it.
///
/// An update goes through the install path in every other respect — the same
/// download, the same digest rule — and PLUGINS.md 6.2 is why it asks at all:
/// a permission the new version adds must not be usable before the user has
/// seen it. **When it adds none, there is nothing to show.** Asking anyway
/// teaches tapping through a dialog whose whole value is being read, and an
/// "update all" over five plugins would be five of them.
///
/// What is installed then is [granted] rather than the manifest's own list, so
/// a permission refused last time stays refused: `PluginInstaller.install`
/// intersects the two, and handing it the manifest would be granting by
/// omission.
Future<Set<String>?> askPluginUpgradeConsent(
  BuildContext context,
  ffi.PluginManifestInfo manifest, {
  required Set<String> granted,
}) async {
  final asks = manifest.permissions.toSet();
  if (asks.difference(granted).isEmpty) return granted;
  return askPluginConsent(context, manifest);
}

/// What a permission means, in the app's own words where it has them.
///
/// Falls back to the name rather than to nothing: a build that meets a
/// permission it has no sentence for should still say which one, since the
/// alternative is asking the user to agree to a blank line.
String _describe(String name) => switch (name) {
  'server.exec' => libL10n.cmd,
  'server.list' => l10n.pluginSeesAllServers,
  'net.http' => libL10n.network,
  'ui.dialog' => libL10n.attention,
  'clipboard' => libL10n.copy,
  _ => name,
};

