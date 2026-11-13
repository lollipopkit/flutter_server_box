import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/core/ssh/key_unlock.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';

/// What each of [keys] decoded to, in order: its key pairs, or why it failed.
///
/// Top-level for isolate execution, and reporting the failure
/// as a string for a related one: this runs in an isolate, whatever
/// `SSHKeyPair.fromPem` throws is not required to be sendable across one, and
/// the only thing the caller does with it is put it in a message.
///
/// Per key rather than one merged list so that [identitiesOf] can cache each
/// one on its own — a key that failed included, since retrying it once per
/// connection would spawn an isolate per attempt to reach the same answer.
List<(List<SSHKeyPair>, String?)> loadIdentitiesEach(List<String> keys) {
  final results = <(List<SSHKeyPair>, String?)>[];
  for (final key in keys) {
    try {
      results.add((SSHKeyPair.fromPem(key), null));
    } catch (e) {
      results.add((const <SSHKeyPair>[], '$e'));
    }
  }
  return results;
}

/// Key pairs parsed this run, by the PEM they were parsed from.
///
/// `SSHKeyPair.fromPem` is milliseconds of RSA or Ed25519 decoding and
/// [compute] spawns an isolate to run it, so ten servers sharing one key
/// parsed that key ten times in ten isolates — during launch, where
/// `ServersNotifier` connects several at once and the isolate spawns land on
/// the frames the user is looking at.
///
/// Keyed by the PEM and not by the id or path it came from, so replacing a
/// key's contents parses the new one instead of handing back the old one's
/// pairs. Growth is bounded by the distinct key material this run has seen.
///
/// Sharing an [SSHKeyPair] between connections is safe: every `sign` builds its
/// own signer out of the key's fields and writes nothing back, so a parsed pair
/// is read-only.
///
/// Nor does this hold a secret the process was not holding already —
/// [PrivateKeyUnlock] caches the decrypted PEM for the run, and this is that
/// same PEM decoded.
final _identityCache = <String, (List<SSHKeyPair>, String?)>{};

/// Parses already running, by the PEM they are parsing.
///
/// Without this the cache pays off only on a reconnect. Ten servers sharing one
/// key reach [identitiesOf] in the same turn, before any `compute` has
/// returned, so every one of them finds the cache empty and starts its own
/// isolate — which is the launch this exists to fix.
/// `PrivateKeyUnlock` joins its in-flight unlocks the same way.
///
/// Each future carries **what it parsed**, rather than only signalling that it
/// finished. A joiner that had to read the answer back out of [_identityCache]
/// would be reading a map that anything on this isolate can empty while it is
/// suspended — [forgetParsedIdentities] is called straight out of a button
/// handler — and would find its own entry gone.
final _identityParses = <String, Future<Map<String, _Parsed>>>{};

/// What one PEM decoded to: its key pairs, or why it failed.
typedef _Parsed = (List<SSHKeyPair>, String?);

/// Drops what has been parsed, for a key that is no longer what it was.
///
/// Two reasons, and the second is the one that is easy to miss. A key edited or
/// deleted leaves its decrypted PEM in [_identityCache] as a map *key*, so
/// "holds no secret the process was not already holding" stops being true the
/// moment `PrivateKeyUnlock.forget` runs. And a PEM that failed to parse is
/// cached as a failure, so a key repaired outside the app would keep reporting
/// unreadable until the next launch.
///
/// Clears everything rather than one entry: the cache is keyed by PEM content
/// and the caller has an id, so there is nothing to match on — and rebuilding
/// it costs one parse per key still in use.
void forgetParsedIdentities() {
  _identityCache.clear();
  _identityParses.clear();
}

/// The key pairs [keys] decode to, parsing only the ones not already parsed.
///
/// Keeps [loadIdentitiesEach]'s tolerance: a PEM that will not parse is
/// skipped, and the failure is only raised when *nothing* parsed — a server
/// listing several keys authenticates with whichever of them is usable.
Future<List<SSHKeyPair>> identitiesOf(List<String> keys) async {
  // Answered out of `parsed`, which is this call's own, rather than by reading
  // [_identityCache] back at the end. The cache is an optimisation that any
  // turn can empty; what this was asked about is the bytes it was handed, and
  // a key deleted while the parse ran does not make those bytes something else.
  final parsed = <String, _Parsed>{};
  final joining = <Future<Map<String, _Parsed>>>{};
  final missing = <String>[];

  for (final key in keys.toSet()) {
    switch ((_identityCache[key], _identityParses[key])) {
      case (final cached?, _):
        parsed[key] = cached;
      case (_, final running?):
        joining.add(running);
      default:
        missing.add(key);
    }
  }

  if (missing.isNotEmpty) {
    final parse = compute(loadIdentitiesEach, missing).then((results) {
      final done = <String, _Parsed>{};
      for (var i = 0; i < missing.length; i++) {
        done[missing[i]] = results[i];
        _identityCache[missing[i]] = results[i];
      }
      return done;
    });
    // Recorded before the first `await`, so the servers connecting in the same
    // turn join this rather than each starting their own.
    for (final key in missing) {
      _identityParses[key] = parse;
    }
    joining.add(parse);
    try {
      await parse;
    } finally {
      for (final key in missing) {
        if (identical(_identityParses[key], parse)) {
          unawaited(_identityParses.remove(key));
        }
      }
    }
  }

  for (final parse in joining) {
    parsed.addAll(await parse);
  }

  final identities = <SSHKeyPair>[];
  String? lastError;
  for (final key in keys) {
    final entry = parsed[key];
    // Every key was cached, joined or parsed above, so this holds. Stated
    // rather than asserted with `!`, which fails as a bare null check with
    // nothing saying what went wrong. The key is not named: `key` is the PEM
    // itself, and the caller puts what it catches into a message.
    if (entry == null) {
      throw StateError('identitiesOf: a requested key was never parsed');
    }
    identities.addAll(entry.$1);
    if (entry.$2 != null) lastError = entry.$2;
  }
  if (identities.isEmpty && lastError != null) {
    throw PrivateKeyParseException(lastError);
  }
  return identities;
}

/// A PEM that would not parse, carrying the message the parse failed with.
///
/// The parse happens in an isolate and what it threw is not required to survive
/// the trip, so what comes back is the text — see [loadIdentitiesEach]. Its
/// [toString] is that text unadorned, which is what the callers interpolate.
class PrivateKeyParseException implements Exception {
  const PrivateKeyParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What to call a key when asking the person about it.
///
/// [keyRef] is an id for a key the store holds and a path for one the user's
/// own `~/.ssh` holds, so the lookup missing is not a failure — the path is
/// already the name. Guarded because this is also reached from the transfer
/// isolate, which has no stores; there the reference is the best that can be
/// said.
String privateKeyDisplayName(String keyRef) {
  try {
    return Stores.key.fetchOne(keyRef)?.name ?? keyRef;
  } catch (_) {
    return keyRef;
  }
}

String getPrivateKey(String id) {
  final pki = Stores.key.fetchOne(id);
  if (pki == null) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyNotFoundFmt(id),
    );
  }
  return pki.key;
}

/// Cap on a key file read off disk by path. Deliberately far above any real
/// key — an RSA-4096 PEM is a few KB — because this reads a file the user
/// already points OpenSSH at, and the point is only to keep a mistaken path
/// from pulling an arbitrary file into memory on the main isolate.
/// `Miscs.privateKeyMaxSize` is the tighter limit on what gets pasted into the
/// store, which is a different question.
const _keyFileMaxSize = 1024 * 1024;

/// The key file's text, or a refusal if it did not stop inside the cap.
///
/// One bounded read off one open handle, rather than a stat followed by an
/// unbounded read: between those two the path can be replaced — a symlink
/// repointed, a file appended to — and the size that was checked is then not
/// the size that is read. Asking for one byte past the cap is what tells the
/// two cases apart without ever holding more than that.
String _decodeCapped(String path, List<int> bytes) {
  if (bytes.length > _keyFileMaxSize) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.fileTooLarge(
        path,
        '>${_keyFileMaxSize.bytes2Str}',
        _keyFileMaxSize.bytes2Str,
      ),
    );
  }
  return utf8.decode(bytes);
}

Map<String, String> resolvePrivateKeys(
  SshCredential ssh, {
  String? originalHost,
}) {
  final keyId = ssh.keyId;
  if (keyId != null) {
    return {SshCredential.keyRefForId(keyId): getPrivateKey(keyId)};
  }
  final keyPaths = ssh.resolvedIdentityFiles;
  if (keyPaths.isEmpty) return const {};

  final keys = <String, String>{};
  Object? lastError;
  for (final keyPath in keyPaths) {
    final expanded = SSHConfig.expandIdentityFile(
      keyPath,
      hostname: ssh.ip,
      remoteUser: ssh.user,
      originalHost: originalHost,
      port: ssh.port,
    );
    try {
      final handle = File(expanded).openSync();
      try {
        keys['path:$keyPath'] = _decodeCapped(
          expanded,
          handle.readSync(_keyFileMaxSize + 1),
        );
      } finally {
        handle.closeSync();
      }
    } catch (e) {
      final error = e is SSHErr
          ? e
          : SSHErr(
              type: SSHErrType.noPrivateKey,
              message: l10n.privateKeyFileUnreadable(expanded, '$e'),
            );
      if (keyPaths.length == 1) {
        throw error;
      }
      lastError = error;
      Loggers.app.warning('Skipping unreadable IdentityFile $expanded', e);
    }
  }
  if (keys.isEmpty && lastError != null) throw lastError;
  return keys;
}

Future<Map<String, String>> resolvePrivateKeysAsync(
  SshCredential ssh, {
  String? originalHost,
}) async {
  final keyId = ssh.keyId;
  if (keyId != null) {
    return {SshCredential.keyRefForId(keyId): getPrivateKey(keyId)};
  }
  final keyPaths = ssh.resolvedIdentityFiles;
  if (keyPaths.isEmpty) return const {};

  final keys = <String, String>{};
  Object? lastError;
  for (final keyPath in keyPaths) {
    final expanded = SSHConfig.expandIdentityFile(
      keyPath,
      hostname: ssh.ip,
      remoteUser: ssh.user,
      originalHost: originalHost,
      port: ssh.port,
    );
    try {
      final handle = await File(expanded).open();
      try {
        keys['path:$keyPath'] = _decodeCapped(
          expanded,
          await handle.read(_keyFileMaxSize + 1),
        );
      } finally {
        await handle.close();
      }
    } catch (e) {
      final error = e is SSHErr
          ? e
          : SSHErr(
              type: SSHErrType.noPrivateKey,
              message: l10n.privateKeyFileUnreadable(expanded, '$e'),
            );
      if (keyPaths.length == 1) {
        throw error;
      }
      lastError = error;
      Loggers.app.warning('Skipping unreadable IdentityFile $expanded', e);
    }
  }
  if (keys.isEmpty && lastError != null) throw lastError;
  return keys;
}
