import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/proxy_command_executor.dart';
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

Future<SSHClient> genClient(
  Spi spi, {
  void Function(GenSSHClientStatus)? onStatus,

  /// Only pass this param if using multi-threading and key login
  String? privateKey,

  /// Only pass this param if using multi-threading and key login
  String? jumpPrivateKey,
  Duration timeout = const Duration(seconds: 5),

  /// [Spi] of the jump server
  ///
  /// Must pass this param if using multi-threading and key login
  Spi? jumpSpi,

  /// Handle keyboard-interactive authentication
  SSHUserInfoRequestHandler? onKeyboardInteractive,
  Map<String, String>? knownHostFingerprints,
  void Function(String storageKey, String fingerprintHex)? onHostKeyAccepted,
  Future<bool> Function(HostKeyPromptInfo info)? onHostKeyPrompt,
}) async {
  onStatus?.call(GenSSHClientStatus.socket);

  final hostKeyCache = Map<String, String>.from(knownHostFingerprints ?? _loadKnownHostFingerprints());
  final hostKeyPersist = onHostKeyAccepted ?? _persistHostKeyFingerprint;
  final hostKeyPrompt = onHostKeyPrompt ?? _defaultHostKeyPrompt;

  String? alterUser;

  // Check for Jump Server first - this needs special handling
    final jumpSpi_ = () {
      // Multi-thread or key login
      if (jumpSpi != null) return jumpSpi;
      // Main thread
      if (spi.jumpId != null) return Stores.server.box.get(spi.jumpId);
    }();
    if (jumpSpi_ != null) {
      // For jump server, we establish connection through the jump client
      final jumpClient = await genClient(
        jumpSpi_,
        privateKey: jumpPrivateKey,
        timeout: timeout,
        knownHostFingerprints: hostKeyCache,
        onHostKeyAccepted: hostKeyPersist,
        onHostKeyPrompt: onHostKeyPrompt,
      );

      final forwardChannel = await jumpClient.forwardLocal(spi.ip, spi.port);

      final hostKeyVerifier = _HostKeyVerifier(
        spi: spi,
        cache: hostKeyCache,
        persistCallback: hostKeyPersist,
        prompt: hostKeyPrompt,
      );

      final keyId = spi.keyId;
      if (keyId == null) {
        onStatus?.call(GenSSHClientStatus.pwd);
        return SSHClient(
          forwardChannel,
          username: spi.user,
          onPasswordRequest: () => spi.pwd,
          onUserInfoRequest: onKeyboardInteractive,
          onVerifyHostKey: hostKeyVerifier.call,
        );
      }

      privateKey ??= getPrivateKey(keyId);
      onStatus?.call(GenSSHClientStatus.key);
      return SSHClient(
        forwardChannel,
        username: spi.user,
        identities: await compute(loadIndentity, privateKey),
        onUserInfoRequest: onKeyboardInteractive,
        onVerifyHostKey: hostKeyVerifier.call,
      );
    }

    // For ProxyCommand and direct connections, get SSHSocket
    SSHSocket? socket;
    try {
      final proxyCommand = spi.proxyCommand;
      // ProxyCommand support - Check for ProxyCommand configuration first
      if (proxyCommand != null && !Platform.isIOS) {
        try {
          Loggers.app.info('Connecting via ProxyCommand: ${proxyCommand.command}');
          socket = await ProxyCommandExecutor.executeProxyCommand(
            proxyCommand,
            hostname: spi.ip,
            port: spi.port,
            user: spi.user,
          );
        } catch (e) {
          Loggers.app.warning('ProxyCommand failed', e);
          if (!proxyCommand.retryOnFailure) {
            rethrow;
          }
          // If retry is enabled, fall through to direct connection
          Loggers.app.info('ProxyCommand failed, falling back to direct connection');
        }
      } else if (proxyCommand != null && Platform.isIOS) {
        Loggers.app.info('ProxyCommand configuration is ignored on iOS');
      }

      // Direct connection (or fallback)
      socket ??= await () async {
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
    } catch (e) {
      Loggers.app.warning('Failed to establish connection', e);
      rethrow;
    }

  final hostKeyVerifier = _HostKeyVerifier(
    spi: spi,
    cache: hostKeyCache,
    persistCallback: hostKeyPersist,
    prompt: hostKeyPrompt,
  );

  final keyId = spi.keyId;
  if (keyId == null) {
    onStatus?.call(GenSSHClientStatus.pwd);
    return SSHClient(
      socket,
      username: alterUser ?? spi.user,
      onPasswordRequest: () => spi.pwd,
      onUserInfoRequest: onKeyboardInteractive,
      onVerifyHostKey: hostKeyVerifier.call,
    );
  }
  privateKey ??= getPrivateKey(keyId);

  onStatus?.call(GenSSHClientStatus.key);
  return SSHClient(
    socket,
    username: spi.user,
    identities: await compute(loadIndentity, privateKey),
    onUserInfoRequest: onKeyboardInteractive,
    onVerifyHostKey: hostKeyVerifier.call,
  );
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
  final cache = _loadKnownHostFingerprints();
  if (_hasKnownHostFingerprintForSpi(spi, cache)) {
    return;
  }

  final jumpSpi = spi.jumpId != null ? Stores.server.box.get(spi.jumpId) : null;
  if (jumpSpi != null && !_hasKnownHostFingerprintForSpi(jumpSpi, cache)) {
    await ensureKnownHostKey(
      jumpSpi,
      timeout: timeout,
      onKeyboardInteractive: onKeyboardInteractive,
    );
    cache.addAll(_loadKnownHostFingerprints());
    if (_hasKnownHostFingerprintForSpi(spi, cache)) return;
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

String _fingerprintToBase64(Uint8List fingerprint) => base64.encode(fingerprint);
