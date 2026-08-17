import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/proxy_command_socket.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
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
  void Function(String storageKey, String fingerprintHex)? onHostKeyAccepted,
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
          final jumpSpiKeyId = jumpSpi_.ssh?.keyId;
          if (jumpSpi != null &&
              jumpSpi.id == jumpSpi_.id &&
              jumpPrivateKey != null) {
            // Isolate mode may preload first-hop key and pass it via [jumpPrivateKey].
            nextJumpPrivateKey = jumpPrivateKey;
          } else if (jumpSpiKeyId != null) {
            nextJumpPrivateKey = privateKeysByKeyId?[jumpSpiKeyId];
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

  final hostKeyVerifier = _HostKeyVerifier(
    spi: spi,
    cache: hostKeyCache,
    persistCallback: hostKeyPersist,
    prompt: hostKeyPrompt,
  );

  final keyId = ssh.keyId;
  if (keyId == null) {
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
  privateKey ??= privateKeysByKeyId?[keyId] ?? getPrivateKey(keyId);

  onStatus?.call(GenSSHClientStatus.key);
  return SSHClient(
    socket,
    username: ssh.user,
    // Must use [compute] here, instead of [Computer.shared.start]
    identities: await compute(loadIdentity, privateKey),
    onPasswordRequest: ssh.pwd?.isNotEmpty == true ? () => ssh.pwd : null,
    onUserInfoRequest: onKeyboardInteractive == null
        ? null
        : (request) => onKeyboardInteractive(spi, request),
    onVerifyHostKey: hostKeyVerifier.call,
  );
}

typedef _HostKeyPersistCallback =
    void Function(String storageKey, String fingerprintHex);

List<Spi> _resolveJumpCandidates({
  required Spi spi,
  required Spi? preloadedJumpSpi,
  required Map<String, Spi>? jumpSpisById,
}) {
  final candidates = <Spi>[];
  for (final jumpId in spi.resolvedJumpIds) {
    final candidate = preloadedJumpSpi?.id == jumpId
        ? preloadedJumpSpi
        : jumpSpisById?[jumpId] ?? Stores.server.box.get(jumpId);
    if (candidate == null || candidates.any((e) => e.id == candidate.id)) {
      continue;
    }
    candidates.add(candidate);
  }
  return candidates;
}

bool _isJumpFailoverError(Object error) {
  final errStr = error.toString().toLowerCase();
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
      errStr.contains('proxycommand timed out');
}

@visibleForTesting
bool isJumpFailoverErrorForTest(Object error) => _isJumpFailoverError(error);

class HostKeyPromptInfo {
  HostKeyPromptInfo({
    required this.spi,
    required this.keyType,
    required this.fingerprintHex,
    required this.fingerprintBase64,
    required this.isMismatch,
    this.previousFingerprintHex,
  });

  final Spi spi;
  final String keyType;
  final String fingerprintHex;
  final String fingerprintBase64;
  final bool isMismatch;
  final String? previousFingerprintHex;
}

class _HostKeyVerifier {
  _HostKeyVerifier({
    required this.spi,
    required Map<String, String> cache,
    required this.prompt,
    this.persistCallback,
  }) : _cache = cache;

  final Spi spi;
  final Map<String, String> _cache;
  final _HostKeyPersistCallback? persistCallback;
  final Future<bool> Function(HostKeyPromptInfo info) prompt;

  Future<bool> call(String keyType, Uint8List fingerprintBytes) async {
    final storageKey = _hostKeyStorageKey(spi, keyType);
    final fingerprintHex = _fingerprintToHex(fingerprintBytes);
    final fingerprintBase64 = _fingerprintToBase64(fingerprintBytes);
    final existing = _cache[storageKey];

    if (existing == null) {
      final accepted = await prompt(
        HostKeyPromptInfo(
          spi: spi,
          keyType: keyType,
          fingerprintHex: fingerprintHex,
          fingerprintBase64: fingerprintBase64,
          isMismatch: false,
        ),
      );
      if (!accepted) {
        Loggers.app.warning(
          'User rejected new SSH host key for ${spi.name} ($keyType).',
        );
        return false;
      }
      _cache[storageKey] = fingerprintHex;
      persistCallback?.call(storageKey, fingerprintHex);
      Loggers.app.info('Trusted SSH host key for ${spi.name} ($keyType).');
      return true;
    }

    if (existing == fingerprintHex) {
      return true;
    }

    final accepted = await prompt(
      HostKeyPromptInfo(
        spi: spi,
        keyType: keyType,
        fingerprintHex: fingerprintHex,
        fingerprintBase64: fingerprintBase64,
        isMismatch: true,
        previousFingerprintHex: existing,
      ),
    );
    if (!accepted) {
      Loggers.app.warning(
        'SSH host key mismatch for ${spi.name}',
        'expected $existing but received $fingerprintHex ($keyType)',
      );
      return false;
    }

    _cache[storageKey] = fingerprintHex;
    persistCallback?.call(storageKey, fingerprintHex);
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

void persistHostKeyFingerprint(String storageKey, String fingerprintHex) {
  try {
    final prop = Stores.setting.sshKnownHostFingerprints;
    final updated = Map<String, String>.from(prop.get());
    if (updated[storageKey] == fingerprintHex) {
      return;
    }
    updated[storageKey] = fingerprintHex;
    prop.put(updated);
    Loggers.app.info('Stored SSH host key fingerprint for $storageKey');
  } catch (e, stack) {
    Loggers.app.warning('Persist SSH host key fingerprint failed', e, stack);
  }
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
  final question = '${info.keyType} ${info.fingerprintHex}';

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
        SelectableText(l10n.sshHostKeyFingerprintMd5Hex(info.fingerprintHex)),
        SelectableText(
          l10n.sshHostKeyFingerprintMd5Base64(info.fingerprintBase64),
        ),
        if (info.previousFingerprintHex != null) ...[
          const SizedBox(height: 12),
          SelectableText(
            l10n.sshHostKeyStoredFingerprint(info.previousFingerprintHex!),
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

String _fingerprintToBase64(Uint8List fingerprint) =>
    base64.encode(fingerprint);

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
