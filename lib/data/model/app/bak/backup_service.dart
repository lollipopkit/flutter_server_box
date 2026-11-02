import 'dart:convert';

import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_source.dart';
import 'package:server_box/data/model/app/bak/utils.dart';

/// Coordinates backup and restore operations with their UI feedback.
class BackupService {
  /// Creates a backup and writes it to [source].
  static Future<void> backup(BuildContext context, BackupSource source) async {
    // The destination's kind, never its address or its credentials. Whether a
    // backup is encrypted is the other half: an unencrypted one going to a
    // third party is the case worth being able to count.
    //
    // Spelled out rather than taken from the object. `runtimeType` is a name a
    // `--obfuscate` build is free to rewrite, and `displayName` is localized —
    // it would file the same destination under as many values as the app has
    // languages.
    final kind = source is ClipboardBackupSource ? 'clipboard' : 'file';
    try {
      final saved = await SecureStoreProps.bakPwd.read();
      final password = saved?.isEmpty == true ? null : saved;

      Diag.crumb(
        SbDiag.backup,
        'save',
        data: {'to': kind, 'encrypted': password == null ? 'no' : 'yes'},
      );

      final path = await BackupV2.backup(null, password);
      await source.saveContent(path);

      if (source is ClipboardBackupSource) {
        Toast.success(libL10n.success);
      }
    } catch (e, s) {
      Diag.crumb(
        SbDiag.backup,
        'save failed',
        level: DiagLevel.warning,
        data: {'to': kind},
      );
      if (context.mounted) {
        context.showErrDialog(e, s, libL10n.backup);
      }
    }
  }

  /// Reads and restores a backup from [source].
  static Future<void> restore(BuildContext context, BackupSource source) async {
    final data = await source.getContent();
    if (data == null) {
      if (source is ClipboardBackupSource) {
        Toast.show(libL10n.empty);
      }
      return;
    }

    if (context.mounted) {
      await restoreData(context, data);
    }
  }

  /// [restoreData] for text: a paste, or the import dialog.
  static Future<void> restoreFromText(BuildContext context, String text) =>
      restoreData(context, utf8.encode(text));

  /// Decodes [data], prompting for a password when it is encrypted.
  static Future<void> restoreData(BuildContext context, List<int> data) async {
    final isEncrypted = AgeCryptor.isEncrypted(data);
    String? password;

    if (!isEncrypted) {
      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => _decode(data, null),
        );
        // [err] has been reported by `showLoadingDialog` already; a dialog
        // here was a second one for the same failure.
        if (err != null) return;
        if (backup == null) {
          if (context.mounted) {
            context.showErrDialog(
              '${libL10n.empty}: ${libL10n.backup}',
              null,
              libL10n.restore,
            );
          }
          return;
        }

        if (!context.mounted) return;
        await _confirmAndRestore(context, backup);
      } catch (e, s) {
        Loggers.app.warning('Import backup failed', e, s);
        if (context.mounted) context.showErrDialog(e, s, libL10n.restore);
      }
      return;
    }

    // Avoid prompting when the saved password can decrypt this backup.
    final savedPassword = await SecureStoreProps.bakPwd.read();
    if (!context.mounted) return;
    if (savedPassword != null && savedPassword.isNotEmpty) {
      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => _decode(data, savedPassword),
        );
        if (err == null && backup != null) {
          if (!context.mounted) return;
          await _confirmAndRestore(context, backup);
          return;
        }
      } catch (e, s) {
        Loggers.app.warning(
          'Failed to restore with saved password, will prompt for manual input',
          e,
          s,
        );
      }
    }

    // Prompt for password with retry logic
    while (true) {
      if (!context.mounted) return;
      password = await _showPasswordDialog(
        context,
        title: libL10n.pwd,
        hint: l10n.backupEncrypted,
      );
      if (!context.mounted) return;
      if (password == null) return; // User cancelled

      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => _decode(data, password),
        );
        if (!context.mounted) return;
        if (err != null) {
          if (err is WrongPasswordException) {
            final retry = await context.showRoundDialog<bool>(
              title: l10n.backupPasswordWrong,
              child: Text(l10n.backupPasswordWrong),
              actions: [
                TextButton(
                  onPressed: () => context.popDialog(false),
                  child: Text(libL10n.cancel),
                ),
                TextButton(
                  onPressed: () => context.popDialog(true),
                  child: Text(libL10n.retry),
                ),
              ],
            );
            if (retry != true) return;
            continue;
          }
          if (context.mounted) {
            context.showErrDialog(err, null, libL10n.restore);
          }
          return;
        }
        if (backup == null) {
          context.showErrDialog(
            '${libL10n.empty}: ${libL10n.backup}',
            null,
            libL10n.restore,
          );
          return;
        }

        await _confirmAndRestore(context, backup);
        return;
      } catch (e) {
        if (!context.mounted) return;
        if (e is WrongPasswordException) {
          final retry = await context.showRoundDialog<bool>(
            title: l10n.backupPasswordWrong,
            child: Text(l10n.backupPasswordWrong),
            actions: [
              TextButton(
                onPressed: () => context.popDialog(false),
                child: Text(libL10n.cancel),
              ),
              TextButton(
                onPressed: () => context.popDialog(true),
                child: Text(libL10n.retry),
              ),
            ],
          );
          if (retry != true) return;
          continue; // Try again
        } else {
          // Other error, show and exit
          if (context.mounted) {
            context.showErrDialog(e, null, libL10n.restore);
          }
          return;
        }
      }
    }
  }

  /// Confirm and execute restore operation
  static Future<void> _confirmAndRestore(
    BuildContext context,
    (dynamic, String) backup,
  ) async {
    if (!context.mounted) return;
    await context.showRoundDialog(
      title: libL10n.restore,
      child: Text(
        libL10n.askContinue(
          '${libL10n.restore} ${libL10n.backup}(${backup.$2})',
        ),
      ),
      actions: [
        Btn.cancel(),
        Btn.ok(
          onTap: () async {
            try {
              final mergeable = backup.$1;
              final themes = mergeable is BackupV2
                  ? await mergeable.mergeReporting(force: true)
                  : null;
              if (mergeable is! BackupV2) await mergeable.merge(force: true);
              if (!context.mounted) return;
              context.popDialog();
              // Said once the restore is done, not as a failure of it: the
              // rest of the backup is in place, and these can be installed
              // again by hand.
              if (themes != null && themes.failed.isNotEmpty) {
                Toast.show(
                  l10n.backupThemesNotRestored,
                  body: themes.failed.join(', '),
                  duration: const Duration(seconds: 8),
                  level: ToastLevel.warn,
                );
              }
            } catch (e, s) {
              if (!context.mounted) return;
              context.popDialog();
              context.showErrDialog(e, s, libL10n.restore);
            }
          },
        ),
      ],
    );
  }

  /// Decrypted in rage's isolate, decoded in a worker: neither on this one.
  static Future<(dynamic, String)?> _decode(
    List<int> data,
    String? password,
  ) async {
    final plain = await BackupV2.unlock(data, password);
    return Computer.shared.start(MergeableUtils.fromBytes, plain);
  }

  /// Prompts for the backup password.
  static Future<String?> _showPasswordDialog(
    BuildContext context, {
    String? initial,
    String? title,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await context.showRoundDialog<String>(
      title: title ?? libL10n.pwd,
      // Disposed by the tree: this future completes on the pop, and the
      // field is still there while the route animates out.
      child: DisposeWith(
        notifiers: [controller],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hint ?? l10n.backupPasswordTip, style: UIs.textGrey),
            UIs.height13,
            Input(
              label: l10n.backupPassword,
              controller: controller,
              obscureText: true,
              onSubmitted: (_) => context.popDialog(controller.text),
            ),
          ],
        ),
      ),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () => context.popDialog(controller.text),
          child: Text(libL10n.ok),
        ),
      ],
    );
    return result;
  }
}
