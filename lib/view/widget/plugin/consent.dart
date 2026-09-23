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
import 'package:server_box/data/model/plugin/l10n.dart';
import 'package:server_box/src/rust/api/plugin.dart' as ffi;

/// The permissions dialog, and the only place consent is given.
///
/// Answers the set the user agreed to, or null if they did not. All or
/// nothing on purpose: a plugin that asks for two things and is granted one
/// is a plugin whose author never tested that combination, and the failure
/// lands on the user as a feature that half works.
Future<Set<String>?> askPluginConsent(
  BuildContext context,
  ffi.PluginManifestInfo manifest, {
  PluginL10n strings = PluginL10n.empty,
}) async {
  final permissions = manifest.permissions;
  final name = strings.resolve(manifest.name);
  final description = strings.resolve(manifest.description);
  final ok = await context.showRoundDialog<bool>(
    title: '$name ${manifest.version}',
    // Scrollable, because how long this is belongs to the plugin. Seven
    // permissions with a line of explanation each is taller than the dialog
    // gets, and an `AlertDialog` whose content does not scroll answers that
    // with a striped bar over the last row — the row nobody then reads, in the
    // one dialog whose whole purpose is being read.
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 7,
        children: [
          if (description.isNotEmpty) Text(description, style: UIs.textGrey),
          Text(
            permissions.isEmpty
                ? l10n.pluginNoPermissions
                : l10n.pluginPermissionsAsk,
          ),
          for (final name in permissions) _PermissionTile(name: name),
        ],
      ),
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
  PluginL10n strings = PluginL10n.empty,
}) async {
  final asks = manifest.permissions.toSet();
  if (asks.difference(granted).isEmpty) return granted;
  return askPluginConsent(context, manifest, strings: strings);
}

/// One permission: what it is, and what granting it means.
///
/// **No chevron.** There was one in front of each of these, and it read as a
/// row that opens — a promise of somewhere to go, in a dialog that has nowhere.
/// What the chevron was standing in for is the second line: a name like
/// "Attention" says nothing about what is being agreed to, and the two heaviest
/// used to be explained in a sentence at the bottom, away from the row it was
/// about.
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final detail = _detail(name);
    // The two that hand over something a person would want to think about get
    // the error colour: one runs commands the user did not type, the other
    // learns the whole fleet exists.
    final heavy = name == 'server.exec' || name == 'server.list';
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('· ${_describe(name)}', style: UIs.text13),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 1),
              child: Text(
                detail,
                style: TextStyle(
                  fontSize: 11,
                  color: heavy
                      ? context.theme.colorScheme.error
                      : context.theme.hintColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What a permission is called.
///
/// Falls back to the name rather than to nothing: a build that meets a
/// permission it has no sentence for should still say which one, since the
/// alternative is asking the user to agree to a blank line.
String _describe(String name) => switch (name) {
  'server.exec' => l10n.permExec,
  'server.stream' => l10n.permStream,
  // Already in the arb, translated everywhere, and the same sentence: three
  // of these are reused rather than duplicated in English only.
  'server.list' => l10n.pluginSeesAllServers,
  'net.http' => l10n.permHttp,
  'ui.dialog' => l10n.permDialog,
  'clipboard' => l10n.permClipboard,
  'storage.sync' => l10n.permSync,
  _ => name,
};

/// What granting it means, in the terms of what could go wrong with it.
///
/// **Every permission has one.** Three of them did not — the rows with nothing
/// under them read as the ones that were still missing something, in a list
/// where the neighbouring rows explain themselves. And the names are the whole
/// story only to somebody who already knows: "read and write the clipboard" is
/// not obviously "can read the password you just pasted", which is what makes
/// it a decision.
///
/// Null for a permission this build has no sentence for, which is a newer
/// plugin's, not one of these.
String? _detail(String name) => switch (name) {
  'server.exec' => l10n.pluginRunsOnServer,
  'server.stream' => l10n.permStreamTip,
  'server.list' => l10n.pluginSeesAllServersTip,
  'net.http' => l10n.permHttpTip,
  'ui.dialog' => l10n.permDialogTip,
  'clipboard' => l10n.permClipboardTip,
  'storage.sync' => l10n.permSyncTip,
  _ => null,
};
