import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/theme.dart' show ThemeRestoreReport;
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/backup_reader.dart';
import 'package:server_box/data/model/app/bak/backup_source.dart';

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
        context.showErrSheet(e, s, libL10n.backup);
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
  ///
  /// The saved password is tried first, and a wrong one asks for another
  /// without saying so: it is only out of date. A typed one that is wrong asks
  /// whether to try again.
  static Future<void> restoreData(BuildContext context, List<int> data) async {
    // A synced backup, sealed to a sync key this device keeps.
    if (SyncKeyring.sealedToKey(Uint8List.fromList(data))) {
      final (plain, err) = await context.showLoadingSheet(
        fn: () => SyncKeyring.openKept(Uint8List.fromList(data)),
      );
      if (plain == null || err != null || !context.mounted) return;
      data = plain;
    }
    if (!AgeCryptor.isEncrypted(data)) {
      await _open(context, data, null);
      return;
    }

    final saved = await SecureStoreProps.bakPwd.read();
    if (!context.mounted) return;
    if (saved != null && saved.isNotEmpty) {
      if (await _open(context, data, saved) != _Opened.wrongPassword) return;
    }

    while (context.mounted) {
      final password = await _showPasswordDialog(
        context,
        title: libL10n.pwd,
        hint: l10n.backupEncrypted,
      );
      if (password == null || !context.mounted) return;
      if (await _open(context, data, password) != _Opened.wrongPassword) return;
      if (!context.mounted || !await _askRetry(context)) return;
    }
  }

  /// Opens [data] with [password], then confirms and restores it.
  ///
  /// A failure is reported once, by the loading dialog; a wrong password is
  /// an answer instead, left to [restoreData].
  static Future<_Opened> _open(
    BuildContext context,
    List<int> data,
    String? password,
  ) async {
    final (opened, err) = await context.showLoadingSheet(
      // A slow device takes its time over the key derivation.
      timeout: null,
      fn: () async {
        try {
          return (backup: await _decode(data, password), wrongPassword: false);
        } on WrongPasswordException {
          return (backup: null, wrongPassword: true);
        }
      },
    );
    if (err != null || opened == null) return _Opened.failed;
    if (opened.wrongPassword) return _Opened.wrongPassword;
    final backup = opened.backup;
    if (!context.mounted) return _Opened.failed;
    if (backup == null) {
      context.showErrSheet('${libL10n.empty}: ${libL10n.backup}', null, libL10n.restore);
      return _Opened.failed;
    }
    await _confirmAndRestore(context, backup);
    return _Opened.restored;
  }

  /// Asks whether to try another password after a wrong one.
  static Future<bool> _askRetry(BuildContext context) async {
    final retry = await context.showSheet<bool>(
      title: l10n.backupPasswordWrong,
      actions: [
        TextButton(
          onPressed: () => context.popSheet(false),
          child: Text(libL10n.cancel),
        ),
        TextButton(
          onPressed: () => context.popSheet(true),
          child: Text(libL10n.retry),
        ),
      ],
    );
    return retry == true;
  }

  /// Confirm and execute restore operation
  static Future<void> _confirmAndRestore(
    BuildContext context,
    (Mergeable, String) backup,
  ) async {
    if (!context.mounted) return;
    // Its own handle: the page may be gone when the restore ends, and only
    // this is to close — not what was raised over it meanwhile, nor the sheet
    // it may be a page of.
    VoidCallback? close;
    await context.showSheet(
      title: libL10n.restore,
      onShown: (c) => close = c,
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
              ThemeRestoreReport? themes;
              if (mergeable is BackupV2) {
                themes = await mergeable.restoreStores(force: true);
              } else {
                await mergeable.merge(force: true);
              }
              close?.call();
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
              close?.call();
              if (context.mounted) context.showErrSheet(e, s, libL10n.restore);
            }
          },
        ),
      ],
    );
  }

  /// Decrypted in rage's isolate, decoded in a worker: neither on this one.
  static Future<(Mergeable, String)?> _decode(
    List<int> data,
    String? password,
  ) async {
    final plain = await BackupV2.unlock(data, password);
    return compute(BackupReader.fromBytes, plain);
  }

  /// Prompts for the backup password.
  static Future<String?> _showPasswordDialog(
    BuildContext context, {
    String? initial,
    String? title,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await context.showSheet<String>(
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
              onSubmitted: (_) => context.popSheet(controller.text),
            ),
          ],
        ),
      ),
      actions: [
        Btn.cancel(),
        TextButton(
          onPressed: () => context.popSheet(controller.text),
          child: Text(libL10n.ok),
        ),
      ],
    );
    return result;
  }
}

/// What [BackupService._open] came to.
enum _Opened { restored, wrongPassword, failed }
