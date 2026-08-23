import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/error.dart';

/// Asks for a key's passphrase and answers with it, or null if the person
/// declined.
///
/// A parameter so the policy below can be exercised without a screen — see
/// [PrivateKeyUnlock.promptOverrideForTesting].
typedef PassphrasePrompt =
    Future<String?> Function({required String keyName, required bool retry});

/// Opening a private key that is stored encrypted.
///
/// The app stores the key as it was given: one generated here with a
/// passphrase, or imported still encrypted, stays that way in the database.
/// Something has to open it before a connection can use it, and that is here.
///
/// Once per key per run. The opened form is held in memory only — a passphrase
/// that survived a restart would be protecting nothing — and is dropped when
/// the key is edited or deleted.
abstract final class PrivateKeyUnlock {
  /// Opened keys, by the reference that named them.
  static final _opened = <String, String>{};

  /// The ask in progress for a key, so several servers reaching for the same
  /// one at the same moment produce one dialog rather than a stack of them.
  static final _inFlight = <String, Future<String>>{};

  /// How many times a wrong passphrase may be given before the attempt is
  /// abandoned. Not a security limit — the person can start again — it is what
  /// stops a loop with no way out when the dialog cannot be shown.
  static const maxAttempts = 3;

  @visibleForTesting
  static PassphrasePrompt? promptOverrideForTesting;

  /// Whether [pem] cannot be used without a passphrase.
  ///
  /// False for anything unreadable rather than throwing: whether a key is
  /// encrypted is asked in order to decide whether to ask for a passphrase,
  /// and a key that cannot be parsed at all fails later, where the error says
  /// what it is.
  static bool isLocked(String pem) {
    try {
      return SSHKeyPair.isEncryptedPem(pem);
    } catch (_) {
      return false;
    }
  }

  /// [pem] in a form dartssh2 can load, opening it first if it needs opening.
  ///
  /// [cacheKey] names the key — `SshCredential.keyRef`, so a key referred to by
  /// id and the same key referred to by path are not confused for one another.
  /// [keyName] is what to call it when asking.
  static Future<String> open(
    String pem, {
    required String cacheKey,
    required String keyName,
  }) async {
    if (!isLocked(pem)) return pem;

    final already = _opened[cacheKey];
    if (already != null) return already;

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final attempt = _ask(pem, cacheKey: cacheKey, keyName: keyName);
    _inFlight[cacheKey] = attempt;
    try {
      return await attempt;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// The opened form of [pem] if there is one, and [pem] itself when it needs
  /// no opening.
  ///
  /// Null means "locked, and nobody has opened it". For the callers that build
  /// credentials for another isolate from a synchronous context and so cannot
  /// ask — they report that rather than handing over a key that will fail
  /// somewhere with no screen to say so.
  static String? openedOrNull(String pem, {required String cacheKey}) {
    if (!isLocked(pem)) return pem;
    return _opened[cacheKey];
  }

  /// Forgets an opened key, which the next connection will ask for again.
  ///
  /// Called when the key changes or goes away: the passphrase held here is for
  /// the bytes that were there when it was given.
  static void forget(String cacheKey) => _opened.remove(cacheKey);

  static void forgetAll() => _opened.clear();

  @visibleForTesting
  static bool isOpened(String cacheKey) => _opened.containsKey(cacheKey);

  static Future<String> _ask(
    String pem, {
    required String cacheKey,
    required String keyName,
  }) async {
    final prompt = promptOverrideForTesting ?? _showDialog;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final passphrase = await prompt(keyName: keyName, retry: attempt > 0);
      if (passphrase == null) {
        throw SSHErr(
          type: SSHErrType.noPrivateKey,
          message: l10n.sshKeyLockedFmt(keyName),
        );
      }

      try {
        // On another isolate: bcrypt_pbkdf is deliberately slow, which is the
        // point of it, and 16 rounds is long enough to drop frames.
        //
        // `compute`, not `Computer.shared`: that one has to be turned on, and
        // is not in the transfer isolate — which reaches this file through
        // `genClient` — nor under `flutter test`.
        final opened = await compute(decryptPem, [pem, passphrase]);
        _opened[cacheKey] = opened;
        return opened;
      } on SSHKeyDecryptError {
        // Round again, saying so. Any other failure is not about the
        // passphrase and belongs to the caller.
        continue;
      }
    }

    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.sshKeyLockedFmt(keyName),
    );
  }

  static Future<String?> _showDialog({
    required String keyName,
    required bool retry,
  }) async {
    final context = AppNavigator.context;
    if (context == null || !context.mounted) return null;

    final controller = TextEditingController();
    try {
      return await context.showRoundDialog<String>(
        title: libL10n.authRequired,
        childBuilder: (dialogContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dialogContext.l10n.sshKeyUnlockTip(keyName)),
            if (retry) ...[
              const SizedBox(height: 8),
              Text(
                dialogContext.l10n.sshKeyPassphraseWrong,
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Input(
              controller: controller,
              autoFocus: true,
              obscureText: true,
              label: libL10n.pwd,
              icon: Icons.password,
              suggestion: false,
              onSubmitted: (_) =>
                  Navigator.of(dialogContext).pop(controller.text),
            ),
          ],
        ),
        actionsBuilder: (dialogContext) => [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(libL10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(libL10n.ok),
          ),
        ],
      );
    } finally {
      controller.dispose();
    }
  }
}
