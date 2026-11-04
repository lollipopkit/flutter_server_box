import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// Puts the host key dialog behind [showHostKeyPrompt]. Once, at launch.
void installHostKeyDialog() => HostKeyDialog.show = _showHostKeyDialog;

Future<bool> _showHostKeyDialog(
  HostKeyPromptInfo info,
  BuildContext? context,
) async {
  final ctx = context?.mounted == true ? context : AppNavigator.context;
  if (ctx == null) {
    Loggers.app.warning(
      'Host key prompt skipped: navigator context unavailable.',
    );
    return false;
  }

  final hostLine = info.spi.displayAddr;
  final description = info.isMismatch
      ? l10n.sshHostKeyChangedDesc(info.spi.name)
      : l10n.sshHostKeyNewDesc(info.spi.name);

  final result = await ctx.showRoundDialog<bool>(
    title: libL10n.attention,
    barrierDismiss: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(description),
        const SizedBox(height: 12),
        SelectableText('${libL10n.server}: ${info.spi.name}'),
        SelectableText('${libL10n.addr}: $hostLine'),
        SelectableText('${l10n.sshHostKeyType}: ${info.keyType}'),
        // Verbatim, which is the whole point of it: this is character for
        // character what `ssh-keygen -l` prints on the server, so it can be
        // compared against that without anyone having to strip a label off
        // first. It names its own algorithm, so a `(SHA256)` around it said
        // SHA256 twice.
        SelectableText(info.fingerprint),
        if (info.previousFingerprint != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            l10n.sshHostKeyStoredFingerprint(info.previousFingerprint!),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(onPressed: () => ctx.popDialog(false), child: Text(libL10n.cancel)),
      TextButton(onPressed: () => ctx.popDialog(true), child: Text(libL10n.ok)),
    ],
  );

  return result ?? false;
}
