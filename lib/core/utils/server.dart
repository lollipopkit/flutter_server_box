import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

/// Must put this func out of any Class.
///
/// Because of this function is called by [compute].
///
/// https://stackoverflow.com/questions/51998995/invalid-arguments-illegal-argument-in-isolate-message-object-is-a-closure
List<SSHKeyPair> loadIndentity(String key) {
  return SSHKeyPair.fromPem(key);
}

/// [args] : [key, pwd]
String decyptPem(List<String> args) {
  /// skip when the key is not encrypted, or will throw exception
  if (!SSHKeyPair.isEncryptedPem(args[0])) return args[0];
  final sshKey = SSHKeyPair.fromPem(args[0], args[1]);
  return sshKey.first.toPem();
}

enum GenSSHClientStatus { socket, key, pwd }

String getPrivateKey(String id) {
  final pki = Stores.key.fetchOne(id);
  if (pki == null) {
    throw SSHErr(type: SSHErrType.noPrivateKey, message: l10n.privateKeyNotFoundFmt(id));
  }
  return pki.key;
}

List<Spi> resolveMergedJumpChain(
  Spi target, {
  List<Spi>? jumpChain,
}) {
  final injectedSpiMap = <String, Spi>{};
  if (jumpChain != null) {
    for (final s in jumpChain) {
      injectedSpiMap[s.id] = s;
      if (s.oldId.isNotEmpty) {
        injectedSpiMap[s.oldId] = s;
      }
    }
  }

  Spi resolveSpi(String id) {
    final injected = injectedSpiMap[id];
    if (injected != null) return injected;
    if (jumpChain != null) {
      throw SSHErr(type: SSHErrType.connect, message: 'Jump server not found in provided chain: $id');
    }
    final fromStore = Stores.server.box.get(id);
    if (fromStore == null) {
      throw SSHErr(type: SSHErrType.connect, message: 'Jump server not found: $id');
    }
    return fromStore;
  }

  return _resolveMergedJumpChainInternal(target, resolveSpi: resolveSpi);
}

List<Spi> _resolveMergedJumpChainInternal(
  Spi target, {
  required Spi Function(String id) resolveSpi,
}) {
  final roots = target.jumpChainIds ?? (target.jumpId == null ? const <String>[] : [target.jumpId!]);
  if (roots.isEmpty) return const <Spi>[];

  final seen = <String>{};
  final stack = <String>{};
  final out = <Spi>[];

  String normId(Spi spi) => spi.id.isNotEmpty ? spi.id : spi.oldId;

  void dfs(String id) {
    final hop = resolveSpi(id);
    final norm = normId(hop);

    if (stack.contains(norm)) {
      throw SSHErr(type: SSHErrType.connect, message: 'Jump loop detected at $norm');
    }
    if (seen.contains(norm)) return;

    stack.add(norm);
    final deps = hop.jumpChainIds ?? (hop.jumpId == null ? const <String>[] : [hop.jumpId!]);
    for (final dep in deps) {
      dfs(dep);
    }
    stack.remove(norm);

    if (seen.add(norm)) {
      out.add(hop);
    }
  }

  for (final r in roots) {
    dfs(r);
  }

  return out;
}

Future<SSHClient> genClient(
  Spi spi, {
  void Function(GenSSHClientStatus)? onStatus,

  /// Only pass this param if using multi-threading and key login
  String? privateKey,

  /// Pre-resolved jump chain (in `spi.jumpId` order: immediate -> farthest).
  ///
  /// This is mainly used when `Stores` is unavailable (e.g. in an isolate).
  List<Spi>? jumpChain,

  /// Private keys for [jumpChain], aligned by index.
  ///
  /// If a jump server uses key auth (`keyId != null`), you must provide the
  /// decrypted key pem here (or `genClient` will try to read from `Stores`).
  List<String?>? jumpPrivateKeys,
  Duration timeout = const Duration(seconds: 5),

  /// Handle keyboard-interactive authentication
  SSHUserInfoRequestHandler? onKeyboardInteractive,
  Map<String, String>? knownHostFingerprints,
  void Function(String storageKey, String fingerprintHex)? onHostKeyAccepted,
  Future<bool> Function(HostKeyPromptInfo info)? onHostKeyPrompt,
}) async {
  return _genClientInternal(
    spi,
    onStatus: onStatus,
    privateKey: privateKey,
    jumpChain: jumpChain,
    jumpPrivateKeys: jumpPrivateKeys,
    timeout: timeout,
    onKeyboardInteractive: onKeyboardInteractive,
    knownHostFingerprints: knownHostFingerprints,
    onHostKeyAccepted: onHostKeyAccepted,
    onHostKeyPrompt: onHostKeyPrompt,
    visited: <String>{},
  );
}

Future<SSHClient> _genClientInternal(
  Spi spi, {
  void Function(GenSSHClientStatus)? onStatus,
  String? privateKey,
  List<Spi>? jumpChain,
  List<String?>? jumpPrivateKeys,
  Duration timeout = const Duration(seconds: 5),
  SSHUserInfoRequestHandler? onKeyboardInteractive,
  Map<String, String>? knownHostFingerprints,
  void Function(String storageKey, String fingerprintHex)? onHostKeyAccepted,
  Future<bool> Function(HostKeyPromptInfo info)? onHostKeyPrompt,
  required Set<String> visited,
  SSHSocket? socketOverride,
  bool followJumpConfig = true,
}) async {
  final identifier = _hostIdentifier(spi);
  if (!visited.add(identifier)) {
    throw SSHErr(type: SSHErrType.connect, message: 'Jump loop detected at ${spi.name} ($identifier)');
  }

  onStatus?.call(GenSSHClientStatus.socket);

  final hostKeyCache = Map<String, String>.from(knownHostFingerprints ?? _loadKnownHostFingerprints());
  final hostKeyPersist = onHostKeyAccepted ?? _persistHostKeyFingerprint;
  final hostKeyPrompt = onHostKeyPrompt ?? _defaultHostKeyPrompt;

  String? alterUser;

  final socket = await () async {
    if (socketOverride != null) return socketOverride;

    if (followJumpConfig) {
      final injectedSpiMap = <String, Spi>{};
      final injectedKeyMap = <String, String?>{};

      if (jumpChain != null) {
        for (var i = 0; i < jumpChain.length; i++) {
          final s = jumpChain[i];
          injectedSpiMap[s.id] = s;
          if (s.oldId.isNotEmpty) injectedSpiMap[s.oldId] = s;
          if (jumpPrivateKeys != null && i < jumpPrivateKeys.length) {
            injectedKeyMap[s.id] = jumpPrivateKeys[i];
            if (s.oldId.isNotEmpty) injectedKeyMap[s.oldId] = jumpPrivateKeys[i];
          }
        }
      }

      Spi resolveSpi(String id) {
        final injected = injectedSpiMap[id];
        if (injected != null) return injected;
        if (jumpChain != null) {
          throw SSHErr(type: SSHErrType.connect, message: 'Jump server not found in provided chain: $id');
        }
        final fromStore = Stores.server.box.get(id);
        if (fromStore == null) {
          throw SSHErr(type: SSHErrType.connect, message: 'Jump server not found: $id');
        }
        return fromStore;
      }

      String? resolveHopPrivateKey(Spi hop) {
        final keyId = hop.keyId;
        if (keyId == null) return null;
        final injected = injectedKeyMap[hop.id] ?? injectedKeyMap[hop.oldId];
        return injected ?? getPrivateKey(keyId);
      }

      final hops = _resolveMergedJumpChainInternal(spi, resolveSpi: resolveSpi);
      if (hops.isNotEmpty) {
        // Build multi-hop forward chain with dedup/merge.
        final createdClients = <SSHClient>[];
        SSHClient? currentClient;

        try {
          final firstHop = hops.first;
          final firstKey = resolveHopPrivateKey(firstHop);
          if (firstHop.keyId != null && firstKey == null) {
            throw SSHErr(type: SSHErrType.noPrivateKey, message: l10n.privateKeyNotFoundFmt(firstHop.keyId ?? ''));
          }

          currentClient = await _genClientInternal(
            firstHop,
            privateKey: firstKey,
            jumpChain: jumpChain,
            jumpPrivateKeys: jumpPrivateKeys,
            timeout: timeout,
            onKeyboardInteractive: onKeyboardInteractive,
            knownHostFingerprints: hostKeyCache,
            onHostKeyAccepted: hostKeyPersist,
            onHostKeyPrompt: hostKeyPrompt,
            visited: visited,
            followJumpConfig: false,
          );
          createdClients.add(currentClient);

          for (var i = 1; i < hops.length; i++) {
            final hop = hops[i];
            final forwarded = await currentClient!.forwardLocal(hop.ip, hop.port);
            final hopKey = resolveHopPrivateKey(hop);
            if (hop.keyId != null && hopKey == null) {
              throw SSHErr(type: SSHErrType.noPrivateKey, message: l10n.privateKeyNotFoundFmt(hop.keyId ?? ''));
            }

            currentClient = await _genClientInternal(
              hop,
              privateKey: hopKey,
              jumpChain: jumpChain,
              jumpPrivateKeys: jumpPrivateKeys,
              timeout: timeout,
              onKeyboardInteractive: onKeyboardInteractive,
              knownHostFingerprints: hostKeyCache,
              onHostKeyAccepted: hostKeyPersist,
              onHostKeyPrompt: hostKeyPrompt,
              visited: visited,
              socketOverride: forwarded,
              followJumpConfig: false,
            );
            createdClients.add(currentClient);
          }

          return await currentClient!.forwardLocal(spi.ip, spi.port);
        } catch (e) {
          // Close all created clients on error to avoid leaks
          for (final client in createdClients) {
            try {
              client.close();
            } catch (_) {
              // Ignore close errors during cleanup
            }
          }
          rethrow;
        }
        // Note: On success, all intermediate clients must remain open
        // because the returned socket tunnels through them.
      }
    }

    // Direct
    try {
      return await SSHSocket.connect(spi.ip, spi.port, timeout: timeout);
    } catch (e) {
      Loggers.app.warning('genClient', e);
      if (spi.alterUrl == null) rethrow;
      try {
        final res = spi.parseAlterUrl();
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

  Future<SSHClient> buildClient(SSHSocket socket) async {
    final keyId = spi.keyId;
    if (keyId == null) {
      onStatus?.call(GenSSHClientStatus.pwd);
      return SSHClient(
        socket,
        username: alterUser ?? spi.user,
        onPasswordRequest: () => spi.pwd,
        onUserInfoRequest: onKeyboardInteractive,
        onVerifyHostKey: hostKeyVerifier.call,
        // printDebug: debugPrint,
        // printTrace: debugPrint,
      );
    }
    privateKey ??= getPrivateKey(keyId);

    onStatus?.call(GenSSHClientStatus.key);
    return SSHClient(
      socket,
      username: spi.user,
      // Must use [compute] here, instead of [Computer.shared.start]
      identities: await compute(loadIndentity, privateKey!),
      onUserInfoRequest: onKeyboardInteractive,
      onVerifyHostKey: hostKeyVerifier.call,
      // printDebug: debugPrint,
      // printTrace: debugPrint,
    );
  }

  return await buildClient(socket);
}

typedef _HostKeyPersistCallback = void Function(String storageKey, String fingerprintHex);

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
        Loggers.app.warning('User rejected new SSH host key for ${spi.name} ($keyType).');
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
    Loggers.app.warning('Updated stored SSH host key for ${spi.name} ($keyType) after user confirmation.');
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

void _persistHostKeyFingerprint(String storageKey, String fingerprintHex) {
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

Future<bool> _defaultHostKeyPrompt(HostKeyPromptInfo info) async {
  final ctx = AppNavigator.context;
  if (ctx == null) {
    Loggers.app.warning('Host key prompt skipped: navigator context unavailable.');
    return false;
  }

  final hostLine = '${info.spi.user}@${info.spi.ip}:${info.spi.port}';
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
        SelectableText('${l10n.server}: ${info.spi.name}'),
        SelectableText('${libL10n.addr}: $hostLine'),
        SelectableText('${l10n.sshHostKeyType}: ${info.keyType}'),
        SelectableText(l10n.sshHostKeyFingerprintMd5Hex(info.fingerprintHex)),
        SelectableText(l10n.sshHostKeyFingerprintMd5Base64(info.fingerprintBase64)),
        if (info.previousFingerprintHex != null) ...[
          const SizedBox(height: 12),
          SelectableText(l10n.sshHostKeyStoredFingerprint(info.previousFingerprintHex!)),
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
  SSHUserInfoRequestHandler? onKeyboardInteractive,
}) async {
  var cache = _loadKnownHostFingerprints();

  final hops = resolveMergedJumpChain(spi);

  // Check each hop's host key, routing through preceding hops
  for (var i = 0; i < hops.length; i++) {
    final hop = hops[i];
    // Preceding hops needed to reach this hop
    final precedingHops = i > 0 ? hops.sublist(0, i) : null;
    final precedingKeys = precedingHops?.map((h) =>
      h.keyId != null ? getPrivateKey(h.keyId!) : null
    ).toList();

    cache = await _ensureKnownHostKeyForSingle(
      hop,
      cache: cache,
      timeout: timeout,
      onKeyboardInteractive: onKeyboardInteractive,
      jumpChain: precedingHops,
      jumpPrivateKeys: precedingKeys,
    );
  }

  // Check the target's host key, routing through all hops
  final allKeys = hops.isNotEmpty
    ? hops.map((h) => h.keyId != null ? getPrivateKey(h.keyId!) : null).toList()
    : null;
  await _ensureKnownHostKeyForSingle(
    spi,
    cache: cache,
    timeout: timeout,
    onKeyboardInteractive: onKeyboardInteractive,
    jumpChain: hops.isNotEmpty ? hops : null,
    jumpPrivateKeys: allKeys,
  );
}

Future<Map<String, String>> _ensureKnownHostKeyForSingle(
  Spi spi, {
  required Map<String, String> cache,
  Duration timeout = const Duration(seconds: 5),
  SSHUserInfoRequestHandler? onKeyboardInteractive,
  List<Spi>? jumpChain,
  List<String?>? jumpPrivateKeys,
}) async {
  if (_hasKnownHostFingerprintForSpi(spi, cache)) {
    return cache;
  }

  final client = await genClient(
    spi,
    timeout: timeout,
    onKeyboardInteractive: onKeyboardInteractive,
    knownHostFingerprints: cache,
    jumpChain: jumpChain,
    jumpPrivateKeys: jumpPrivateKeys,
  );

  try {
    await client.authenticated;
  } finally {
    client.close();
  }

  cache.addAll(_loadKnownHostFingerprints());
  return cache;
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

String _fingerprintToBase64(Uint8List fingerprint) => base64.encode(fingerprint);
