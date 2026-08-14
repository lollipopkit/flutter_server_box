import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/core/utils/sandbox_import.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/res/url.dart';
import 'package:server_box/view/page/backup.dart';

/// What the App Store build has to say about the DMG one.
///
/// The two macOS builds differ in one entitlement, and that one is the sandbox
/// — which is why a terminal on this machine, and running a snippet on it,
/// exist in only one of them. The App Store build cannot be given those, so it
/// says where they are instead. It does not push: the App Store build still
/// works, still updates for now, and someone who does not want a DMG should be
/// able to say so once and not hear it again.
abstract final class DmgNotice {
  /// Whether this is the build with something to say.
  static bool get applies => isMacOS && LocalShellBackend.isSandboxed;

  /// Stored in [SettingStore.dmgTipBuild]: never mention it again.
  static const _never = -1;

  /// A line for the update dialog, or null when there is nothing to add.
  ///
  /// Once per version at most, and never after the user has dismissed it —
  /// this is a footnote to an update the user asked about, not an errand.
  static Widget? forUpdate(BuildContext context, {required int build}) {
    if (!applies) return null;
    final shown = Stores.setting.dmgTipBuild.fetch();
    if (shown == _never || shown == build) return null;
    return _UpdateNotice(build: build);
  }

  /// The whole of it. Reachable from the settings page for good, so the one
  /// line above never has to carry the explanation itself.
  static Future<void> show(BuildContext context) {
    return context.showRoundDialog(
      title: l10n.macDmgTitle,
      child: SingleChildScrollView(child: SimpleMarkdown(data: l10n.macDmgBody)),
      actions: [
        Btn.text(
          text: libL10n.download,
          onTap: () {
            context.popDialog();
            // Whatever the update check resolved for this machine, which on
            // macOS is the DMG for this architecture; the releases page when
            // no check has run yet.
            (AppUpdate.url ?? '${Urls.thisRepo}/releases/latest').launchUrl();
          },
        ),
        Btn.ok(),
      ],
    );
  }
}

class _UpdateNotice extends StatefulWidget {
  const _UpdateNotice({required this.build});

  final int build;

  @override
  State<_UpdateNotice> createState() => _UpdateNoticeState();
}

class _UpdateNoticeState extends State<_UpdateNotice> {
  var _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.macDmgTip, style: theme.textTheme.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Btn.text(
                  text: libL10n.dontShowAgain,
                  onTap: () {
                    Stores.setting.dmgTipBuild.put(DmgNotice._never);
                    setState(() => _dismissed = true);
                  },
                ),
                Btn.text(
                  text: libL10n.about,
                  onTap: () {
                    // Asked about once per version: the user has now seen it.
                    Stores.setting.dmgTipBuild.put(widget.build);
                    DmgNotice.show(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the DMG build has to say about the data it did or did not find.
///
/// Its first launch copies the sandboxed build's data in — see
/// [SandboxImport]. Silence is right when that worked and the app simply looks
/// like the one the user was already using; it is wrong when it did not, since
/// what they are looking at is an empty app that did not have to be one.
abstract final class SandboxImportNotice {
  /// Call once, after the first frame.
  static Future<void> showIfNeeded(BuildContext context) async {
    final result = SandboxImport.result;
    if (result == null) return;

    if (result == SandboxImportResult.imported) {
      // Named, not omitted. The downloads directory is not copied — it is
      // unbounded and a first launch that copies it looks like one that hung —
      // and a user who is not told where it went has lost files as far as they
      // can tell.
      final left = SandboxImport.leftBehind;
      context.showSnackBar(
        left == null
            ? l10n.macDmgImported
            : l10n.macDmgImportedPartly(left),
      );
      return;
    }

    // Only worth a dialog when the user is left with less than they had.
    if (!result.needsExplaining) return;

    final denied = result == SandboxImportResult.denied;
    await context.showRoundDialog(
      title: l10n.macDmgTitle,
      child: Text(denied ? l10n.macDmgImportDenied : l10n.macDmgImportFailed),
      actions: [
        if (denied)
          Btn.text(
            text: libL10n.setting,
            onTap: () {
              context.popDialog();
              // Full Disk Access. macOS decides whether one app may read
              // another's container, and only the user can change that answer.
              'x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles'
                  .launchUrl();
            },
          )
        else
          Btn.text(
            text: libL10n.restore,
            onTap: () {
              context.popDialog();
              BackupPage.route.go(context);
            },
          ),
        Btn.ok(),
      ],
    );
  }
}
