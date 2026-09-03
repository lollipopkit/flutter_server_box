import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/proxy_command_socket.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/core/utils/ssh_config.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';

/// Must put this func out of any Class.
///
/// Because of this function is called by [compute].
///
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIdentity(String key) {
  return SSHKeyPair.fromPem(key);
}

/// What each of [keys] decoded to, in order: its key pairs, or why it failed.
///
/// Top-level for the same reason [loadIdentity] is, and reporting the failure
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
        if (identical(_identityParses[key], parse)) _identityParses.remove(key);
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

/// Decrypts an encrypted PEM private key.
///
/// Must also be a top-level function because it is called via [Computer]
/// (isolate) — see comment on [loadIdentity].
///
/// [args] : [key, pwd]
String decryptPem(List<String> args) {
  /// skip when the key is not encrypted, or will throw exception
  if (!SSHKeyPair.isEncryptedPem(args[0])) return args[0];
  final sshKey = SSHKeyPair.fromPem(args[0], args[1]);
  return sshKey.first.toPem();
}

enum GenSSHClientStatus { socket, key, pwd }

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

/// The PEM [ssh] authenticates with, or null when it has no key at all.
///
/// Two sources that are not interchangeable, which is the whole point of them
/// being two fields: a key the user imported lives in `Stores.key` and is named
/// by [SshCredential.keyId], while a key `~/.ssh/config` pointed at stays on
/// disk and is named by [SshCredential.keyPath]. Reading the file here rather
/// than copying it into the store at import time is what leaves the user's own
/// key management intact.
///
/// Runs where there are stores, a filesystem the user granted, and a UI to
/// report a failure to. `SshTransferCreds` calls it on the main isolate and
/// hands the result across, because the transfer isolate has none of those.
String? resolvePrivateKey(SshCredential ssh, {String? originalHost}) {
  final keys = resolvePrivateKeys(ssh, originalHost: originalHost);
  return keys.isEmpty ? null : keys.values.first;
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

  // Only ever reachable on desktop — `~/.ssh/config` import is the only writer
  // of `keyPath` — and not on one particular desktop build: the App Store one
  // is sandboxed and `~/.ssh` is outside its container, so this would fail
  // there with a file error that says nothing about why.
  if (Pfs.isMacSandboxed) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileSandboxed(keyPaths.first),
    );
  }

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

/// Async variant of [resolvePrivateKey] for callers that can await.
Future<String?> resolvePrivateKeyAsync(
  SshCredential ssh, {
  String? originalHost,
}) async {
  final keys = await resolvePrivateKeysAsync(ssh, originalHost: originalHost);
  return keys.isEmpty ? null : keys.values.first;
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
  if (Pfs.isMacSandboxed) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileSandboxed(keyPaths.first),
    );
  }

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

Future<SSHClient> genClient(
  Spi spi, {
  void Function(GenSSHClientStatus)? onStatus,

  /// Only pass this param if using multi-threading and key login
  String? privateKey,

  /// Only pass this param if using multi-threading and key login
  String? jumpPrivateKey,

  /// Prefer this map in isolate mode, fallback to [Stores.key] otherwise.
  Map<String, String>? privateKeysByKeyId,

  /// Prefer this map in isolate mode, fallback to [Stores.server] otherwise.
  Map<String, Spi>? jumpSpisById,
  Duration timeout = const Duration(seconds: 5),

  /// [Spi] of the jump server
  ///
  /// Must pass this param if using multi-threading and key login
  Spi? jumpSpi,

  /// Handle keyboard-interactive authentication
  SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  Map<String, String>? knownHostFingerprints,
  HostKeyPersistCallback? onHostKeyAccepted,
  Future<bool> Function(HostKeyPromptInfo info)? onHostKeyPrompt,
  Set<String>? visitedServerIds,
}) async {
  // Bound once, up front: everything below needs SSH, and a server reached
  // only over monitor's HTTP API has no credential to connect with
  final ssh = spi.ssh;
  if (ssh == null) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'No SSH credential configured for ${spi.name}',
    );
  }

  final chainVisitedServerIds = visitedServerIds ?? <String>{};
  final currentServerId = _hostIdentifier(spi);
  if (!chainVisitedServerIds.add(currentServerId)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'Invalid jump chain: cycle detected at ${spi.name} ($currentServerId)',
    );
  }
  // Also detect address-level cycles for cloned servers.
  final addrKey = 'addr:${ssh.ip}:${ssh.port}';
  if (!chainVisitedServerIds.add(addrKey)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'Invalid jump chain: address cycle at ${ssh.ip}:${ssh.port}',
    );
  }

  // Where the byte stream comes from is the axis that decides which half of
  // this function runs, and a failure looks the same from the outside whichever
  // it was. Recorded before the socket is opened, since a connection that never
  // returns leaves no later crumb.
  //
  // Guarded, because the two `Redact` calls are two hash passes and a regex,
  // and this runs per connection and again per jump hop. On the transfer
  // isolate — which installs no sink, statics being per isolate — that would
  // all be computed for a crumb nothing receives.
  final via = switch (ssh) {
    _ when spi.resolvedJumpIds.isNotEmpty => 'jump',
    _ when ssh.proxyCommand != null => 'proxy',
    _ => 'direct',
  };
  if (Diag.enabled) {
    Diag.crumb(SbDiag.server, 'ssh connect', data: {
      'server': Redact.id(spi.id),
      'host': Redact.host(ssh.ip),
      'via': via,
    });
  }

  /// The other end of the crumb above, which on its own says only that a
  /// connection was attempted.
  ///
  /// [at] is which half failed, and the halves fail for unrelated reasons: a
  /// socket that never opens is the network, the jump chain or the
  /// `ProxyCommand`, while everything after it is a key, a password or a host
  /// key that no longer matches. Together with `via` this says which of the
  /// three routes is unreliable and where — a question nothing else here can
  /// answer, since a caller is handed one error and cannot tell the phases
  /// apart either.
  void connectFailed(String at, Object e) {
    if (!Diag.enabled) return;
    Diag.crumb(
      SbDiag.server,
      'ssh connect failed',
      level: DiagLevel.warning,
      data: {'via': via, 'at': at, 'error': Redact.error(e)},
    );
  }

  onStatus?.call(GenSSHClientStatus.socket);

  final hostKeyCache = Map<String, String>.from(
    knownHostFingerprints ?? _loadKnownHostFingerprints(),
  );
  final hostKeyPersist = onHostKeyAccepted ?? persistHostKeyFingerprint;
  final hostKeyPrompt = onHostKeyPrompt ?? showHostKeyPrompt;

  String? alterUser;

  final socket = await () async {
    // Proxy
    final jumpSpis = _resolveJumpCandidates(
      spi: spi,
      preloadedJumpSpi: jumpSpi,
      jumpSpisById: jumpSpisById,
    );
    final jumpIds = spi.resolvedJumpIds;
    if (jumpIds.isNotEmpty && jumpSpis.isEmpty) {
      final message = l10n.jumpServersNotFoundFmt(spi.name, jumpIds.join(', '));
      Loggers.app.warning(message);
      throw SSHErr(type: SSHErrType.connect, message: message);
    }
    if (jumpSpis.isNotEmpty) {
      Object? lastNetworkError;
      StackTrace? lastNetworkStack;

      for (final jumpSpi_ in jumpSpis) {
        SSHClient? jumpClient;
        try {
          String? nextJumpPrivateKey;
          final jumpSpiKeyRef = jumpSpi_.ssh?.keyRef;
          if (jumpSpi != null &&
              jumpSpi.id == jumpSpi_.id &&
              jumpPrivateKey != null) {
            // Isolate mode may preload first-hop key and pass it via [jumpPrivateKey].
            nextJumpPrivateKey = jumpPrivateKey;
          } else if (jumpSpiKeyRef != null) {
            nextJumpPrivateKey = privateKeysByKeyId?[jumpSpiKeyRef];
          }

          jumpClient = await genClient(
            jumpSpi_,
            privateKey: nextJumpPrivateKey,
            privateKeysByKeyId: privateKeysByKeyId,
            jumpSpisById: jumpSpisById,
            timeout: timeout,
            onKeyboardInteractive: onKeyboardInteractive,
            knownHostFingerprints: hostKeyCache,
            onHostKeyAccepted: hostKeyPersist,
            onHostKeyPrompt: hostKeyPrompt,
            visitedServerIds: {...chainVisitedServerIds},
          );

          final forwarded = await jumpClient
              .forwardLocal(ssh.ip, ssh.port)
              .timeout(
                timeout,
                onTimeout: () => throw TimeoutException(
                  'forwardLocal timed out after ${timeout.inSeconds}s',
                ),
              );
          return _JumpSocket(forwarded, jumpClient);
        } catch (e, stack) {
          try {
            jumpClient?.close();
          } catch (_) {}
          if (!isJumpFailoverError(e)) {
            rethrow;
          }
          lastNetworkError = e;
          lastNetworkStack = stack;
          Loggers.app.warning(
            'Jump server ${jumpSpi_.name} failed, trying next candidate',
            e,
            stack,
          );
        }
      }

      Error.throwWithStackTrace(
        lastNetworkError ??
            SSHErr(
              type: SSHErrType.connect,
              message: l10n.noJumpServerAvailable,
            ),
        lastNetworkStack ?? StackTrace.current,
      );
    }

    final proxyCommand = ssh.proxyCommand;
    if (proxyCommand != null && proxyCommand.trim().isNotEmpty) {
      return await ProxyCommandSocket.connect(
        command: proxyCommand,
        host: ssh.ip,
        port: ssh.port,
        user: ssh.user,
        originalHost: spi.name,
        jump: ssh.resolvedJumpIds.join(','),
        timeout: timeout,
      );
    }

    // Direct
    try {
      return await SSHSocket.connect(ssh.ip, ssh.port, timeout: timeout);
    } catch (e) {
      Loggers.app.warning('genClient', e);
      if (ssh.alterUrl == null) rethrow;
      try {
        final res = ssh.parseAlterUrl();
        alterUser = res.$2;
        return await SSHSocket.connect(res.$1, res.$3, timeout: timeout);
      } catch (e) {
        Loggers.app.warning('genClient alterUrl', e);
        rethrow;
      }
    }
  }().onError((Object e, s) {
    // Attached rather than wrapping the closure in a `try`, so the body above
    // keeps its indentation and stays reviewable against its own history.
    connectFailed('socket', e);
    Error.throwWithStackTrace(e, s);
  });

  // Everything past here can throw with the socket already open, and the
  // caller is given a key error and no handle — so nobody can close it. A
  // status poll retries, so one unreadable key used to mean one leaked socket
  // per attempt, or on the ProxyCommand path one leaked `/bin/sh` per attempt.
  //
  // `destroy`, not `close`: there is nothing buffered worth flushing, and on
  // the ProxyCommand path this is what kills the process.
  try {
    final client = await _authenticatedClient(
      socket: socket,
      spi: spi,
      ssh: ssh,
      timeout: timeout,
      alterUser: alterUser,
      privateKey: privateKey,
      privateKeysByKeyId: privateKeysByKeyId,
      onStatus: onStatus,
      onKeyboardInteractive: onKeyboardInteractive,
      hostKeyVerifier: HostKeyVerifier(
        spi: spi,
        cache: hostKeyCache,
        persistCallback: hostKeyPersist,
        prompt: hostKeyPrompt,
      ),
    );
    if (Diag.enabled) {
      Diag.crumb(SbDiag.server, 'ssh connect ok', data: {'via': via});
    }
    return client;
  } catch (e) {
    connectFailed('auth', e);
    socket.destroy();
    rethrow;
  }
}

/// The client itself, once there is a socket to build it on.
///
/// Split out so that [genClient] has one place to undo the socket from: every
/// throw in here happens after it is open.
Future<SSHClient> _authenticatedClient({
  required SSHSocket socket,
  required Spi spi,
  required SshCredential ssh,
  required Duration timeout,
  required String? alterUser,
  required String? privateKey,
  required Map<String, String>? privateKeysByKeyId,
  required void Function(GenSSHClientStatus)? onStatus,
  required SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  required HostKeyVerifier hostKeyVerifier,
}) async {
  SSHClient passwordClient() {
    onStatus?.call(GenSSHClientStatus.pwd);
    return SSHClient(
      socket,
      username: alterUser ?? ssh.user,
      onPasswordRequest: () => ssh.pwd,
      onUserInfoRequest: onKeyboardInteractive == null
          ? null
          : (request) => onKeyboardInteractive(spi, request),
      onVerifyHostKey: hostKeyVerifier.call,
      handshakeTimeout: timeout,
      authTimeout: timeout,
    );
  }

  final keyRefs = ssh.keyRefs;
  if (keyRefs.isEmpty) {
    return passwordClient();
  }
  final keyMaterial = <String, String>{};
  if (privateKey != null) keyMaterial[keyRefs.first] = privateKey;
  if (privateKeysByKeyId != null) {
    for (final ref in keyRefs) {
      final pem = privateKeysByKeyId[ref];
      if (pem != null) keyMaterial[ref] = pem;
    }
  } else if (privateKey == null || keyRefs.length > 1) {
    try {
      for (final entry in (await resolvePrivateKeysAsync(
        ssh,
        originalHost: spi.name,
      )).entries) {
        keyMaterial.putIfAbsent(entry.key, () => entry.value);
      }
    } catch (e, s) {
      if (ssh.pwd?.isNotEmpty != true) rethrow;
      Loggers.app.warning(
        'SSH key unavailable for ${spi.name}; falling back to password',
        e,
        s,
      );
      return passwordClient();
    }
  }
  if (keyMaterial.isEmpty) {
    if (ssh.pwd?.isNotEmpty == true) return passwordClient();
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyNotFoundFmt(
        ssh.keyId ?? ssh.keyPath ?? keyRefs.first,
      ),
    );
  }

  onStatus?.call(GenSSHClientStatus.key);
  // A key stored encrypted is opened here, once per key per run. Nothing
  // happens for a key that is not — including one already opened before it was
  // handed to another isolate, which is why the transfer path can reach this
  // line with no screen to ask on.
  final openedKeys = <String>[];
  for (final entry in keyMaterial.entries) {
    openedKeys.add(
      await PrivateKeyUnlock.open(
        entry.value,
        cacheKey: entry.key,
        keyName: privateKeyDisplayName(entry.key),
      ),
    );
  }
  final List<SSHKeyPair> identities;
  try {
    // Must use [compute] here, instead of [Computer.shared.start].
    // Which [identitiesOf] does, for whatever it has not parsed yet.
    identities = await identitiesOf(openedKeys);
  } catch (e) {
    // A PEM that will not parse is a key problem and the caller has a category
    // for those. Left raw it arrived as whatever the parser threw — naming
    // neither the key nor the server, and matching none of the handling every
    // other key failure gets.
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileUnreadable(
        privateKeyDisplayName(keyRefs.first),
        '$e',
      ),
    );
  }
  return SSHClient(
    socket,
    // The same fallback user the password branch above uses. Key auth read
    // `ssh.user` regardless, so a server reached through its `alterUrl` — which
    // is where `alterUser` comes from — authenticated as the primary host's
    // user and failed with a permission error naming neither.
    username: alterUser ?? ssh.user,
    identities: identities,
    onPasswordRequest: ssh.pwd?.isNotEmpty == true ? () => ssh.pwd : null,
    onUserInfoRequest: onKeyboardInteractive == null
        ? null
        : (request) => onKeyboardInteractive(spi, request),
    onVerifyHostKey: hostKeyVerifier.call,
    handshakeTimeout: timeout,
    authTimeout: timeout,
  );
}

/// A forwarded channel that owns the jump connection carrying it.
///
/// `forwardLocal` hands back a channel and nothing else, so the authenticated
/// jump client it came from had no owner: on success nobody held it — closing
/// the target closed the channel and left the jump session, its socket and its
/// process running until the far end timed them out — and on a target failure
/// the socket was destroyed with the jump client still open. Every connection
/// through a jump host leaked one, and a status poll that keeps failing on the
/// target's host key leaked one per attempt.
///
/// Everything is the channel's; the only addition is that closing this closes
/// the client behind it, which is the ownership the return type could not
/// express.
class _JumpSocket implements SSHSocket {
  _JumpSocket(this._inner, this._jumpClient);

  final SSHSocket _inner;
  final SSHClient _jumpClient;

  @override
  Stream<Uint8List> get stream => _inner.stream;

  @override
  StreamSink<List<int>> get sink => _inner.sink;

  @override
  Future<void> get done => _inner.done;

  @override
  Future<void> close() async {
    try {
      await _inner.close();
    } finally {
      _jumpClient.close();
    }
  }

  @override
  void destroy() {
    try {
      _inner.destroy();
    } finally {
      _jumpClient.close();
    }
  }

  @override
  Future<void> flush() => _inner.flush();
}

typedef HostKeyPersistCallback =
    FutureOr<void> Function(String storageKey, String fingerprint);

List<Spi> _resolveJumpCandidates({
  required Spi spi,
  required Spi? preloadedJumpSpi,
  required Map<String, Spi>? jumpSpisById,
}) {
  final candidates = <Spi>[];
  for (final jumpId in spi.resolvedJumpIds) {
    final candidate = preloadedJumpSpi?.id == jumpId
        ? preloadedJumpSpi
        : jumpSpisById?[jumpId] ?? Stores.server.fetchOneRaw(jumpId);
    if (candidate == null || candidates.any((e) => e.id == candidate.id)) {
      continue;
    }
    candidates.add(candidate);
  }
  return candidates;
}

bool isJumpFailoverError(Object error) {
  final errStr = error.toString().toLowerCase();
  // Exclude auth failures that also contain "too many" (e.g. "too many authentication failures").
  if (errStr.contains('auth') ||
      errStr.contains('permission denied') ||
      errStr.contains('access denied')) {
    return false;
  }
  return errStr.contains('timed out') ||
      errStr.contains('timeout') ||
      errStr.contains('connection refused') ||
      errStr.contains('connection reset') ||
      errStr.contains('connection closed') ||
      errStr.contains('no route to host') ||
      errStr.contains('network unreachable') ||
      errStr.contains('network is unreachable') ||
      errStr.contains('socketexception') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('forwardlocal') ||
      errStr.contains('proxycommand exited') ||
      errStr.contains('proxycommand timed out') ||
      errStr.contains('channel open failed') ||
      errStr.contains('maxsessions') ||
      (errStr.contains('too many') && errStr.contains('session')) ||
      (errStr.contains('session') &&
          errStr.contains('failed') &&
          !errStr.contains('auth'));
}

class HostKeyPromptInfo {
  HostKeyPromptInfo({
    required this.spi,
    required this.keyType,
    required this.fingerprint,
    required this.isMismatch,
    this.previousFingerprint,
  });

  final Spi spi;
  final String keyType;

  /// OpenSSH-style fingerprint, normally `SHA256:<base64-without-padding>`.
  final String fingerprint;
  final bool isMismatch;
  final String? previousFingerprint;
}

/// What `onVerifyHostKey` decides, and what it writes down when it decides it.
///
/// Public because this is the whole of "the user vetted this host": the store
/// is written here and nowhere else, and the one answer that must never be
/// recorded is "no". Everything above it needs a socket and a server that has
/// changed its key — so left inside [genClient] the refusal path could only be
/// reached by hand, and never was.
class HostKeyVerifier {
  HostKeyVerifier({
    required this.spi,
    required Map<String, String> cache,
    required this.prompt,
    this.persistCallback,
  }) : _cache = cache;

  final Spi spi;
  final Map<String, String> _cache;
  final HostKeyPersistCallback? persistCallback;
  final Future<bool> Function(HostKeyPromptInfo info) prompt;

  Future<bool> call(String keyType, Uint8List fingerprintBytes) async {
    final storageKey = _hostKeyStorageKey(spi, keyType);
    final fingerprint = fingerprintToOpenSsh(fingerprintBytes);
    final stored = _cache[storageKey];
    final existing = stored == null ? null : normalizeStoredFingerprint(stored);
    if (stored != null && existing != stored) {
      _cache[storageKey] = existing!;
      await persistCallback?.call(storageKey, existing);
    }

    if (existing == null) {
      final accepted = await prompt(
        HostKeyPromptInfo(
          spi: spi,
          keyType: keyType,
          fingerprint: fingerprint,
          isMismatch: false,
        ),
      );
      if (!accepted) {
        Loggers.app.warning(
          'User rejected new SSH host key for ${spi.name} ($keyType).',
        );
        return false;
      }
      _cache[storageKey] = fingerprint;
      await persistCallback?.call(storageKey, fingerprint);
      Loggers.app.info('Trusted SSH host key for ${spi.name} ($keyType).');
      return true;
    }

    if (existing == fingerprint) {
      return true;
    }

    final accepted = await prompt(
      HostKeyPromptInfo(
        spi: spi,
        keyType: keyType,
        fingerprint: fingerprint,
        isMismatch: true,
        previousFingerprint: existing,
      ),
    );
    if (!accepted) {
      Loggers.app.warning(
        'SSH host key mismatch for ${spi.name}',
        'expected $existing but received $fingerprint ($keyType)',
      );
      return false;
    }

    _cache[storageKey] = fingerprint;
    await persistCallback?.call(storageKey, fingerprint);
    Loggers.app.warning(
      'Updated stored SSH host key for ${spi.name} ($keyType) after user confirmation.',
    );
    return true;
  }
}

Map<String, String> _loadKnownHostFingerprints() {
  try {
    final prop = Stores.setting.sshKnownHostFingerprints;
    return Map<String, String>.from(prop.get());
  } catch (e, stack) {
    Loggers.app.warning('Load SSH host key fingerprints failed', e, stack);
    return <String, String>{};
  }
}

/// One queue for every change to the remembered fingerprints.
///
/// Read-modify-write over a whole map, from callers that do not know about
/// each other: an acceptance arriving from a transfer isolate, a forget from
/// the settings page, a server being deleted. Interleaving two of those loses
/// one of them, and when the pair is an acceptance and a forget, the one lost
/// can be the forget — the queued write reads the map as it was before the
/// pruning and puts the fingerprint the user just revoked straight back.
Future<void> _hostKeyPersistence = Future.value();

Future<void> _enqueueHostKeyWrite(String what, void Function() body) {
  _hostKeyPersistence = _hostKeyPersistence.then((_) async {
    try {
      body();
    } catch (e, stack) {
      Loggers.app.warning('$what failed', e, stack);
    }
  });
  return _hostKeyPersistence;
}

Future<void> persistHostKeyFingerprint(String storageKey, String fingerprint) {
  _hostKeyPersistence = _hostKeyPersistence.then((_) async {
    try {
      final prop = Stores.setting.sshKnownHostFingerprints;
      final updated = Map<String, String>.from(prop.get());
      if (updated[storageKey] == fingerprint) return;
      updated[storageKey] = fingerprint;
      await prop.set(updated);
      Loggers.app.info('Stored SSH host key fingerprint for $storageKey');
    } catch (e, stack) {
      Loggers.app.warning('Persist SSH host key fingerprint failed', e, stack);
    }
  });
  return _hostKeyPersistence;
}

/// Forgets every host key filed under one server id.
///
/// For an ad-hoc connection that was never kept: it accepted a key under an id
/// nothing will ever look up again, and one entry per trial connection is a
/// setting that only grows.
/// Queued behind any acceptance still waiting to be written — see
/// [_hostKeyPersistence]. Awaiting the returned future is optional; joining the
/// queue is not.
Future<void> forgetHostKeyFingerprints(String serverId) =>
    _enqueueHostKeyWrite('Forget SSH host key fingerprints', () {
      final prop = Stores.setting.sshKnownHostFingerprints;
      final known = Map<String, String>.from(prop.get());
      final updated = withoutHostKeysFor(known, serverId);
      if (updated.length == known.length) return;
      prop.put(updated);
    });

/// A stored key read back as the server id and the key type it was built from.
///
/// The separator carries the whole of the correctness here, and which one to
/// split on follows from what each half can contain. A key type is an SSH
/// algorithm name — `ssh-ed25519`, `rsa-sha2-512` — and never holds a `::`,
/// while an id can: one restored from a backup is whatever that file said.
/// So the id is everything before the **last** separator.
///
/// It was the first one, which reads a key belonging to `a::b` as server `a`
/// with the type `b::ssh-rsa`: listed under a server that is not its own, and
/// forgetting the real `a` took it along with `a`'s.
///
/// A key with no separator at all is its whole self as the id and an empty
/// type — unreadable rather than absent, and a list that dropped it would
/// leave something trusted and invisible.
@visibleForTesting
(String serverId, String keyType) splitHostKeyStorageKey(String storageKey) {
  final at = storageKey.lastIndexOf('::');
  if (at < 0) return (storageKey, '');
  return (storageKey.substring(0, at), storageKey.substring(at + 2));
}

/// [known] without the entries belonging to [serverId].
///
/// Compared as a whole id rather than as a prefix, for the reason
/// [splitHostKeyStorageKey] gives: `startsWith('$serverId::')` also matched
/// every server whose id merely *begins* with this one followed by `::`, so
/// forgetting `a` reached into `a::b`.
@visibleForTesting
Map<String, String> withoutHostKeysFor(
  Map<String, String> known,
  String serverId,
) {
  if (serverId.isEmpty) return known;
  return {
    for (final entry in known.entries)
      if (splitHostKeyStorageKey(entry.key).$1 != serverId)
        entry.key: entry.value,
  };
}

/// The host key question a server is being asked right now.
///
/// Keyed by server because that is what the user sees: one dialog, naming one
/// server. Several parts of the app hold their own connection to the same
/// server — status polling, a terminal, an SFTP browser, each with its own
/// `onVerifyHostKey` — and a connection that failed is retried, so without
/// this every attempt raises a dialog of its own and they stack up.
final _pendingHostKeyPrompts = <String, _PendingHostKeyPrompt>{};

class _PendingHostKeyPrompt {
  _PendingHostKeyPrompt(this.question) {
    // Nobody may ever join this one, and a completer that carries an error
    // with no listener reports it to the zone as unhandled.
    answer.future.then<void>((_) {}, onError: (Object _) {});
  }

  /// Which key type, and which fingerprint. Two attempts that agree on this
  /// are asking the same thing; anything else is a different decision and gets
  /// a dialog of its own, once this one is gone.
  final String question;

  final answer = Completer<bool>();
}

/// Shows at most one host key dialog per server at a time.
///
/// An attempt whose question matches the one on screen joins it and takes its
/// answer. An attempt with a different question for the same server waits for
/// the screen to clear before asking, rather than covering it.
///
/// [show] is what actually puts the dialog up, passed in so a test can drive
/// this without a navigator.
@visibleForTesting
Future<bool> promptHostKeyExclusively(
  HostKeyPromptInfo info,
  Future<bool> Function() show,
) async {
  final server = _hostIdentifier(info.spi);
  // Joined on a byte neither half can contain, so no key type and fingerprint
  // can spell the same question as another pair — the ambiguity
  // [splitHostKeyStorageKey] records `::` walking into. Written as an escape:
  // it was a literal control byte, which made `rg` and `grep` read this whole
  // file as binary and skip it.
  final question = '${info.keyType}\x00${info.fingerprint}';

  while (true) {
    final pending = _pendingHostKeyPrompts[server];
    if (pending == null) break;
    if (pending.question == question) return pending.answer.future;
    // Whatever that dialog answers, and whether it fails, belongs to the
    // attempt that raised it. This one only needs the screen back.
    await pending.answer.future.then<void>((_) {}, onError: (Object _) {});
  }

  final entry = _PendingHostKeyPrompt(question);
  _pendingHostKeyPrompts[server] = entry;
  Future<bool> running;
  try {
    running = show();
  } catch (e, s) {
    entry.answer.completeError(e, s);
    if (identical(_pendingHostKeyPrompts[server], entry)) {
      _pendingHostKeyPrompts.remove(server);
    }
    rethrow;
  }
  entry.answer.complete(running);
  try {
    return await running;
  } finally {
    // Identity, not presence: a caller that gave up before this returned could
    // have left a later question in its place.
    if (identical(_pendingHostKeyPrompts[server], entry)) {
      _pendingHostKeyPrompts.remove(server);
    }
  }
}

Future<bool> showHostKeyPrompt(
  HostKeyPromptInfo info, {
  BuildContext? context,
}) => promptHostKeyExclusively(info, () => _showHostKeyDialog(info, context));

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
      TextButton(onPressed: () => ctx.pop(false), child: Text(libL10n.cancel)),
      TextButton(onPressed: () => ctx.pop(true), child: Text(libL10n.ok)),
    ],
  );

  return result ?? false;
}

Future<void> ensureKnownHostKey(
  Spi spi, {
  Duration timeout = const Duration(seconds: 5),
  SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  Map<String, Spi>? jumpSpisById,
  Set<String>? visitedServerIds,
}) async {
  // Bound once, up front: everything below needs SSH, and a server reached
  // only over monitor's HTTP API has no credential to connect with
  final ssh = spi.ssh;
  if (ssh == null) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'No SSH credential configured for ${spi.name}',
    );
  }

  final chainVisitedServerIds = visitedServerIds ?? <String>{};
  final currentServerId = _hostIdentifier(spi);
  if (!chainVisitedServerIds.add(currentServerId)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message:
          'Invalid jump chain: cycle detected at ${spi.name} ($currentServerId)',
    );
  }
  final addrKey2 = 'addr:${ssh.ip}:${ssh.port}';
  if (!chainVisitedServerIds.add(addrKey2)) {
    throw SSHErr(
      type: SSHErrType.connect,
      message: 'Invalid jump chain: address cycle at ${ssh.ip}:${ssh.port}',
    );
  }

  final cache = _loadKnownHostFingerprints();

  for (final jumpSpi in _resolveJumpCandidates(
    spi: spi,
    preloadedJumpSpi: null,
    jumpSpisById: jumpSpisById,
  )) {
    if (!_hasKnownHostFingerprintForSpi(jumpSpi, cache)) {
      await ensureKnownHostKey(
        jumpSpi,
        timeout: timeout,
        onKeyboardInteractive: onKeyboardInteractive,
        jumpSpisById: jumpSpisById,
        visitedServerIds: {...chainVisitedServerIds},
      );
      cache.addAll(_loadKnownHostFingerprints());
    }
  }

  if (_hasKnownHostFingerprintForSpi(spi, cache)) {
    return;
  }

  final client = await genClient(
    spi,
    timeout: timeout,
    onKeyboardInteractive: onKeyboardInteractive,
    knownHostFingerprints: cache,
  );

  try {
    await client.authenticated;
  } finally {
    client.close();
  }
}

/// Whether anything is remembered for [spi] at all.
///
/// Compared as a whole id, not as a prefix, for the reason
/// [splitHostKeyStorageKey] gives: `startsWith('$id::')` also answered yes for
/// server `a` on a key belonging to the distinct server `a::b`.
///
/// Any key type counts. Which one a connection ends up negotiating is not
/// knowable without making it, so a server that offered `ssh-rsa` when this
/// was remembered and negotiates `ssh-ed25519` now still reaches the prompt on
/// the connection itself — the same prompt a first connection raises, in a
/// flow that had hoped to have settled it here.
bool _hasKnownHostFingerprintForSpi(Spi spi, Map<String, String> cache) {
  final id = _hostIdentifier(spi);
  return cache.keys.any((key) => splitHostKeyStorageKey(key).$1 == id);
}

String _hostKeyStorageKey(Spi spi, String keyType) {
  final base = _hostIdentifier(spi);
  return '$base::$keyType';
}

String _hostIdentifier(Spi spi) => spi.id.isNotEmpty ? spi.id : spi.oldId;

String _fingerprintToHex(Uint8List fingerprint) {
  final buffer = StringBuffer();
  for (var i = 0; i < fingerprint.length; i++) {
    if (i > 0) buffer.write(':');
    buffer.write(fingerprint[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

final _openSshSha256 = RegExp(r'^SHA256:[A-Za-z0-9+/]{43}$');
final _colonHexFingerprint = RegExp(r'^(?:[0-9a-fA-F]{2}:)*[0-9a-fA-F]{2}$');

@visibleForTesting
String fingerprintToOpenSsh(Uint8List fingerprint) {
  try {
    final encoded = utf8.decode(fingerprint);
    if (_openSshSha256.hasMatch(encoded)) return encoded;
  } on FormatException {
    // Older dartssh2 versions passed digest bytes instead of the formatted
    // OpenSSH fingerprint.
  }

  if (fingerprint.length == 32) {
    final encoded = base64.encode(fingerprint).replaceAll('=', '');
    return 'SHA256:$encoded';
  }
  return 'MD5:${_fingerprintToHex(fingerprint)}';
}

@visibleForTesting
String normalizeStoredFingerprint(String fingerprint) {
  if (_openSshSha256.hasMatch(fingerprint) || fingerprint.startsWith('MD5:')) {
    return fingerprint;
  }
  if (!_colonHexFingerprint.hasMatch(fingerprint)) return fingerprint;

  final bytes = Uint8List.fromList(
    fingerprint.split(':').map((part) => int.parse(part, radix: 16)).toList(),
  );
  try {
    final decoded = utf8.decode(bytes);
    if (_openSshSha256.hasMatch(decoded)) return decoded;
  } on FormatException {
    // A legacy raw digest is handled by length below.
  }
  if (bytes.length == 32) {
    final encoded = base64.encode(bytes).replaceAll('=', '');
    return 'SHA256:$encoded';
  }
  if (bytes.length == 16) return 'MD5:${_fingerprintToHex(bytes)}';
  return fingerprint;
}

/// One remembered host key: which server it was filed under, which algorithm
/// the host offered, and the fingerprint that was accepted.
class KnownHostKey {
  const KnownHostKey({
    required this.storageKey,
    required this.serverId,
    required this.keyType,
    required this.fingerprint,
  });

  /// The map key it is stored under, so removing one takes exactly one.
  final String storageKey;

  final String serverId;

  /// `ssh-ed25519`, `ssh-rsa`, and so on — what the host offered.
  final String keyType;

  final String fingerprint;
}

/// [known] read out as entries, grouped by the server they belong to.
///
/// Pure, and split out for the same reason [withoutHostKeysFor] is: the
/// separator is the whole of the correctness, and [splitHostKeyStorageKey] is
/// where that decision lives so the two sides cannot disagree about it.
Map<String, List<KnownHostKey>> groupHostKeysByServer(
  Map<String, String> known,
) {
  final grouped = <String, List<KnownHostKey>>{};
  for (final entry in known.entries) {
    final (serverId, keyType) = splitHostKeyStorageKey(entry.key);
    grouped
        .putIfAbsent(serverId, () => [])
        .add(
          KnownHostKey(
            storageKey: entry.key,
            serverId: serverId,
            keyType: keyType,
            fingerprint: entry.value,
          ),
        );
  }
  for (final list in grouped.values) {
    list.sort((a, b) => a.keyType.compareTo(b.keyType));
  }
  return grouped;
}

/// Forgets exactly one remembered key, by the map key it is stored under.
///
/// Beside [forgetHostKeyFingerprints], which takes every type a server
/// offered. A host that rotated one algorithm and kept another is the case
/// this exists for.
Future<void> forgetHostKey(String storageKey) =>
    _enqueueHostKeyWrite('Forget SSH host key', () {
      final prop = Stores.setting.sshKnownHostFingerprints;
      final known = Map<String, String>.from(prop.get());
      if (known.remove(storageKey) == null) return;
      prop.put(known);
    });
