import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
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
String? resolvePrivateKey(SshCredential ssh) {
  final keyId = ssh.keyId;
  if (keyId != null) return getPrivateKey(keyId);
  final keyPath = ssh.keyPath;
  if (keyPath == null) return null;

  // Only ever reachable on desktop — `~/.ssh/config` import is the only writer
  // of `keyPath` — and not on one particular desktop build: the App Store one
  // is sandboxed and `~/.ssh` is outside its container, so this would fail
  // there with a file error that says nothing about why.
  if (Pfs.isMacSandboxed) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileSandboxed(keyPath),
    );
  }

  final expanded = SSHConfig.expandHome(keyPath);
  try {
    final file = File(expanded);
    // Guard against unbounded key files on the main isolate.
    try {
      final size = file.statSync().size;
      if (size > _keyFileMaxSize) {
        throw SSHErr(
          type: SSHErrType.noPrivateKey,
          message: l10n.fileTooLarge(
            expanded,
            size.bytes2Str,
            _keyFileMaxSize.bytes2Str,
          ),
        );
      }
    } catch (e) {
      // A failed stat is non-fatal — let the read attempt decide. The size
      // check above is not: rethrowing is what stops an oversized file going
      // on to be read into memory anyway.
      if (e is SSHErr) rethrow;
    }
    return file.readAsStringSync();
  } catch (e) {
    if (e is SSHErr) rethrow;
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileUnreadable(expanded, '$e'),
    );
  }
}

/// Async variant of [resolvePrivateKey] for callers that can await.
Future<String?> resolvePrivateKeyAsync(SshCredential ssh) async {
  final keyId = ssh.keyId;
  if (keyId != null) return getPrivateKey(keyId);
  final keyPath = ssh.keyPath;
  if (keyPath == null) return null;
  if (Pfs.isMacSandboxed) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileSandboxed(keyPath),
    );
  }
  final expanded = SSHConfig.expandHome(keyPath);
  try {
    final file = File(expanded);
    final stat = await file.stat();
    if (stat.size > _keyFileMaxSize) {
      throw SSHErr(
        type: SSHErrType.noPrivateKey,
        message: l10n.fileTooLarge(
          expanded,
          stat.size.bytes2Str,
          _keyFileMaxSize.bytes2Str,
        ),
      );
    }
    return await file.readAsString();
  } catch (e) {
    if (e is SSHErr) rethrow;
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyFileUnreadable(expanded, '$e'),
    );
  }
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

          return await jumpClient.forwardLocal(ssh.ip, ssh.port);
        } catch (e, stack) {
          jumpClient?.close();
          if (!_isJumpFailoverError(e)) {
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
  }();

  // Everything past here can throw with the socket already open, and the
  // caller is given a key error and no handle — so nobody can close it. A
  // status poll retries, so one unreadable key used to mean one leaked socket
  // per attempt, or on the ProxyCommand path one leaked `/bin/sh` per attempt.
  //
  // `destroy`, not `close`: there is nothing buffered worth flushing, and on
  // the ProxyCommand path this is what kills the process.
  try {
    return await _authenticatedClient(
      socket: socket,
      spi: spi,
      ssh: ssh,
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
  } catch (_) {
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
  required String? alterUser,
  required String? privateKey,
  required Map<String, String>? privateKeysByKeyId,
  required void Function(GenSSHClientStatus)? onStatus,
  required SSHKeyboardInteractiveHandler? onKeyboardInteractive,
  required HostKeyVerifier hostKeyVerifier,
}) async {
  final keyRef = ssh.keyRef;
  if (keyRef == null) {
    onStatus?.call(GenSSHClientStatus.pwd);
    return SSHClient(
      socket,
      username: alterUser ?? ssh.user,
      onPasswordRequest: () => ssh.pwd,
      onUserInfoRequest: onKeyboardInteractive == null
          ? null
          : (request) => onKeyboardInteractive(spi, request),
      onVerifyHostKey: hostKeyVerifier.call,
    );
  }
  // `keyRef` being non-null means one of the two key fields is set, so this
  // either yields a key or throws saying why it could not. The null branch is
  // unreachable and says so rather than handing `compute` a null.
  privateKey ??= privateKeysByKeyId?[keyRef] ?? resolvePrivateKey(ssh);
  if (privateKey == null) {
    throw SSHErr(
      type: SSHErrType.noPrivateKey,
      message: l10n.privateKeyNotFoundFmt(ssh.keyId ?? ssh.keyPath ?? keyRef),
    );
  }

  onStatus?.call(GenSSHClientStatus.key);
  // A key stored encrypted is opened here, once per key per run. Nothing
  // happens for a key that is not — including one already opened before it was
  // handed to another isolate, which is why the transfer path can reach this
  // line with no screen to ask on.
  privateKey = await PrivateKeyUnlock.open(
    privateKey,
    cacheKey: keyRef,
    keyName: privateKeyDisplayName(keyRef),
  );
  return SSHClient(
    socket,
    // The same fallback user the password branch above uses. Key auth read
    // `ssh.user` regardless, so a server reached through its `alterUrl` — which
    // is where `alterUser` comes from — authenticated as the primary host's
    // user and failed with a permission error naming neither.
    username: alterUser ?? ssh.user,
    // Must use [compute] here, instead of [Computer.shared.start]
    identities: await compute(loadIdentity, privateKey),
    onPasswordRequest: ssh.pwd?.isNotEmpty == true ? () => ssh.pwd : null,
    onUserInfoRequest: onKeyboardInteractive == null
        ? null
        : (request) => onKeyboardInteractive(spi, request),
    onVerifyHostKey: hostKeyVerifier.call,
  );
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

bool _isJumpFailoverError(Object error) {
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
      (errStr.contains('session') && errStr.contains('failed') && !errStr.contains('auth'));
}

@visibleForTesting
bool isJumpFailoverErrorForTest(Object error) => _isJumpFailoverError(error);

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

Future<void> _hostKeyPersistence = Future.value();

Future<void> persistHostKeyFingerprint(
  String storageKey,
  String fingerprint,
) {
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
void forgetHostKeyFingerprints(String serverId) {
  try {
    final prop = Stores.setting.sshKnownHostFingerprints;
    final known = Map<String, String>.from(prop.get());
    final updated = withoutHostKeysFor(known, serverId);
    if (updated.length == known.length) return;
    prop.put(updated);
  } catch (e, stack) {
    Loggers.app.warning('Forget SSH host key fingerprints failed', e, stack);
  }
}

/// [known] without the entries belonging to [serverId].
///
/// Split out and pure because the separator carries the whole of the
/// correctness here: keys are `<id>::<keyType>`, a host may have offered
/// several types, and matching on the id alone would take every other server
/// whose id happens to start with the same characters.
@visibleForTesting
Map<String, String> withoutHostKeysFor(
  Map<String, String> known,
  String serverId,
) {
  if (serverId.isEmpty) return known;
  final prefix = '$serverId::';
  return {
    for (final entry in known.entries)
      if (!entry.key.startsWith(prefix)) entry.key: entry.value,
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
  final question = '${info.keyType} ${info.fingerprint}';

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
  final running = show();
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

/// Drops any prompt a test left in flight, so the next one does not wait on it.
@visibleForTesting
void resetHostKeyPromptsForTesting() => _pendingHostKeyPrompts.clear();

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

bool _hasKnownHostFingerprintForSpi(Spi spi, Map<String, String> cache) {
  final prefix = '${_hostIdentifier(spi)}::';
  return cache.keys.any((key) => key.startsWith(prefix));
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
final _colonHexFingerprint = RegExp(
  r'^(?:[0-9a-fA-F]{2}:)*[0-9a-fA-F]{2}$',
);

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
/// separator is the whole of the correctness. A key type may itself contain no
/// `::`, but an id could — so the split is on the **first** one, and everything
/// after it is the type.
///
/// Entries whose key has no separator at all are kept under their whole string
/// as the id and an empty type: they are unreadable rather than absent, and a
/// list that silently dropped them would leave something trusted and invisible.
Map<String, List<KnownHostKey>> groupHostKeysByServer(
  Map<String, String> known,
) {
  final grouped = <String, List<KnownHostKey>>{};
  for (final entry in known.entries) {
    final at = entry.key.indexOf('::');
    final serverId = at < 0 ? entry.key : entry.key.substring(0, at);
    final keyType = at < 0 ? '' : entry.key.substring(at + 2);
    grouped.putIfAbsent(serverId, () => []).add(
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
void forgetHostKey(String storageKey) {
  try {
    final prop = Stores.setting.sshKnownHostFingerprints;
    final known = Map<String, String>.from(prop.get());
    if (known.remove(storageKey) == null) return;
    prop.put(known);
  } catch (e, stack) {
    Loggers.app.warning('Forget SSH host key failed', e, stack);
  }
}
