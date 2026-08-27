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

  /// Keys whose prompt was refused, or answered wrongly until it gave up.
  ///
  /// Without this, a refusal is forgotten the moment it happens and the next
  /// reconnect asks again — and the status poller reconnects on a timer, so
  /// declining once means a dialog per poll per server sharing the key.
  /// Cleared by [forget], which is what editing the key does.
  static final _declined = <String>{};

  /// Bumped by [forget]. An ask already on screen when the key is replaced
  /// answers for bytes that are no longer stored, and dropping it from
  /// [_inFlight] only stops *new* callers joining it — the one already running
  /// still returns, and would otherwise put the old key in the cache for every
  /// connection after it.
  static final _generation = <String, int>{};

  /// How many times a wrong passphrase may be given before the attempt is
  /// abandoned. Not a security limit — the person can start again — it is what
  /// stops a loop with no way out when the dialog cannot be shown.
  static const maxAttempts = 3;

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
    PassphrasePrompt? prompt,
  }) async {
    if (!isLocked(pem)) return pem;

    final already = _opened[cacheKey];
    if (already != null) return already;

    // Asked and refused already. Reported the same way, without putting the
    // same dialog up again.
    if (_declined.contains(cacheKey)) throw _locked(keyName);

    final inFlight = _inFlight[cacheKey];
    if (inFlight != null) return inFlight;

    final attempt = _ask(
      pem,
      cacheKey: cacheKey,
      keyName: keyName,
      prompt: prompt ?? _showDialog,
    );
    _inFlight[cacheKey] = attempt;
    try {
      return await attempt;
    } finally {
      _inFlight.remove(cacheKey);
    }
  }

  /// Forgets an opened key, which the next connection will ask for again.
  ///
  /// Called when the key changes or goes away: the passphrase held here is for
  /// the bytes that were there when it was given.
  static void forget(String cacheKey) {
    _opened.remove(cacheKey);
    _declined.remove(cacheKey);
    // The ask still running was for the bytes that have just been replaced, so
    // its answer must not land in the cache afterwards.
    _inFlight.remove(cacheKey);
    _generation[cacheKey] = (_generation[cacheKey] ?? 0) + 1;
  }

  static void forgetAll() {
    // Bumped, not cleared: clearing would reset every generation to zero and
    // let an ask that is still running match again — which is the whole thing
    // this counter exists to stop. A restore replaces every key at once, so
    // every one of them has a dialog that may be up.
    for (final key in {
      ..._opened.keys,
      ..._inFlight.keys,
      ..._generation.keys,
    }) {
      _generation[key] = (_generation[key] ?? 0) + 1;
    }
    _opened.clear();
    _declined.clear();
    _inFlight.clear();
  }

  /// Records a key already known to be open, so the next connection does not
  /// ask for a passphrase that was just typed.
  ///
  /// The import page verifies the passphrase it was given; throwing that away
  /// and asking again seconds later is the same question twice.
  static void remember(String cacheKey, String openedPem) {
    _declined.remove(cacheKey);
    _opened[cacheKey] = openedPem;
  }

  static SSHErr _locked(String keyName) => SSHErr(
    type: SSHErrType.noPrivateKey,
    message: l10n.sshKeyLockedFmt(keyName),
  );

  static Future<String> _ask(
    String pem, {
    required String cacheKey,
    required String keyName,
    required PassphrasePrompt prompt,
  }) async {
    final generation = _generation[cacheKey] ?? 0;
    var guesses = 0;
    var rounds = 0;
    // Two counters: an empty field is not a guess — `open` is only reached for
    // a key that needs a passphrase, so the empty string cannot be the right
    // one and spending an attempt and a full bcrypt round on it would be
    // punishing a slip. The outer bound is what stops a dialog that keeps
    // answering empty from looping for ever.
    while (guesses < maxAttempts && rounds < maxAttempts * 3) {
      rounds++;
      final passphrase = await prompt(keyName: keyName, retry: guesses > 0);
      if (passphrase == null) {
        _declined.add(cacheKey);
        throw _locked(keyName);
      }
      if (passphrase.isEmpty) continue;
      guesses++;

      try {
        // On another isolate: bcrypt_pbkdf is deliberately slow, which is the
        // point of it, and 16 rounds is long enough to drop frames.
        //
        // `compute`, not `Computer.shared`: that one has to be turned on, and
        // is not in the transfer isolate — which reaches this file through
        // `genClient` — nor under `flutter test`.
        final opened = await compute(decryptPem, [pem, passphrase]);
        // Cached only if the key is still the one this was asked about. The
        // caller gets it either way — it passed those bytes in — but a later
        // connection reads whatever is stored now, and must not be handed the
        // key that was replaced while this dialog was up.
        if ((_generation[cacheKey] ?? 0) == generation) {
          _opened[cacheKey] = opened;
        }
        return opened;
      } on SSHKeyDecryptError {
        // Round again, saying so. Any other failure is not about the
        // passphrase and belongs to the caller.
        continue;
      }
    }

    _declined.add(cacheKey);
    throw _locked(keyName);
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
