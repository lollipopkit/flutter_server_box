import 'package:computer/computer.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_source.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/res/store.dart';

/// Service class for handling backup operations
class BackupService {
  /// Perform backup operation with the given source
  static Future<void> backup(BuildContext context, BackupSource source) async {
    final password = await _getBackupPassword(context);
    if (password == null) return;

    try {
      final path = await BackupV2.backup(null, password.isEmpty ? null : password);
      await source.saveContent(path);

      // Show success message for clipboard source
      if (source is ClipboardBackupSource) {
        context.showSnackBar(libL10n.success);
      }
    } catch (e, s) {
      context.showErrDialog(e, s, libL10n.backup);
    }
  }

  /// Perform restore operation with the given source
  static Future<void> restore(BuildContext context, BackupSource source) async {
    final text = await source.getContent();
    if (text == null) {
      // Show empty message for clipboard source
      if (source is ClipboardBackupSource) {
        context.showSnackBar(libL10n.empty);
      }
      return;
    }

    await restoreFromText(context, text);
  }

  /// Handle password dialog for backup operations
  static Future<String?> _getBackupPassword(BuildContext context) async {
    final savedPassword = await Stores.setting.backupasswd.read();
    String? password;

    if (savedPassword != null && savedPassword.isNotEmpty) {
      // Use saved password or ask for custom password
      final useCustom = await context.showRoundDialog<bool>(
        title: l10n.backupPassword,
        child: Text(l10n.backupPasswordTip),
        actions: [
          Btn.cancel(),
          TextButton(onPressed: () => context.pop(false), child: Text(l10n.backupPasswordSet)),
          TextButton(onPressed: () => context.pop(true), child: Text(libL10n.custom)),
        ],
      );

      if (useCustom == null) return null;

      if (useCustom) {
        password = await _showPasswordDialog(context, initial: savedPassword);
      } else {
        password = savedPassword;
      }
    } else {
      // No saved password, ask if user wants to set one
      password = await _showPasswordDialog(context);
    }

    return password;
  }

  /// Handle restore from text with decryption support
  static Future<void> restoreFromText(BuildContext context, String text) async {
    // Check if backup is encrypted
    final isEncrypted = Cryptor.isEncrypted(text);
    String? password;

    if (!isEncrypted) {
      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => Computer.shared.start(MergeableUtils.fromJsonString, text),
        );
        if (err != null || backup == null) return;

        await _confirmAndRestore(context, backup);
      } catch (e, s) {
        Loggers.app.warning('Import backup failed', e, s);
        context.showErrDialog(e, s, libL10n.restore);
      }
      return;
    }

    // Try with saved password first
    final savedPassword = await Stores.setting.backupasswd.read();
    if (savedPassword != null && savedPassword.isNotEmpty) {
      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => Computer.shared.start((args) => MergeableUtils.fromJsonString(args.$1, args.$2), (
            text,
            savedPassword,
          )),
        );
        if (err == null && backup != null) {
          await _confirmAndRestore(context, backup);
          return;
        }
      } catch (e) {
        // Saved password failed, will prompt for manual input
      }
    }

    // Prompt for password with retry logic
    while (true) {
      password = await _showPasswordDialog(context, title: libL10n.pwd, hint: l10n.backupEncrypted);
      if (password == null) return; // User cancelled

      try {
        final (backup, err) = await context.showLoadingDialog(
          fn: () => Computer.shared.start((args) => MergeableUtils.fromJsonString(args.$1, args.$2), (
            text,
            password,
          )),
        );
        if (err != null || backup == null) continue;

        await _confirmAndRestore(context, backup);
        return;
      } catch (e) {
        if (e.toString().contains('incorrect password') || e.toString().contains('Failed to decrypt')) {
          final retry = await context.showRoundDialog<bool>(
            title: l10n.backupPasswordWrong,
            child: Text(l10n.backupPasswordWrong),
            actions: [
              TextButton(onPressed: () => context.pop(false), child: Text(libL10n.cancel)),
              TextButton(onPressed: () => context.pop(true), child: Text(libL10n.retry)),
            ],
          );
          if (retry != true) return;
          continue; // Try again
        } else {
          // Other error, show and exit
          context.showErrDialog(e, null, libL10n.restore);
          return;
        }
      }
    }
  }

  /// Confirm and execute restore operation
  static Future<void> _confirmAndRestore(BuildContext context, (dynamic, String) backup) async {
    await context.showRoundDialog(
      title: libL10n.restore,
      child: Text(libL10n.askContinue('${libL10n.restore} ${libL10n.backup}(${backup.$2})')),
      actions: Btn.ok(
        onTap: () async {
          await backup.$1.merge(force: true);
          context.pop();
        },
      ).toList,
    );
  }

  /// Show password input dialog
  static Future<String?> _showPasswordDialog(
    BuildContext context, {
    String? initial,
    String? title,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await context.showRoundDialog<String>(
      title: title ?? libL10n.pwd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hint ?? l10n.backupPasswordTip, style: UIs.textGrey),
          UIs.height13,
          Input(
            label: l10n.backupPassword,
            controller: controller,
            obscureText: true,
            onSubmitted: (_) => context.pop(controller.text),
          ),
        ],
      ),
      actions: [
        Btn.cancel(),
        TextButton(onPressed: () => context.pop(controller.text), child: Text(libL10n.ok)),
      ],
    );
    controller.dispose();
    return result;
  }
}
