import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/ssh/algorithms.dart';
import 'package:server_box/data/model/server/host_cert_authority.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/store/stores.dart';

typedef HostKeyPersistCallback =
    FutureOr<void> Function(String storageKey, String fingerprint);

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

  /// The key types already trusted for this host, which the algorithm list
  /// prefers — see [SshAlgorithms.of].
  Set<String> get pinnedKeyTypes {
    final prefix = hostKeyStorageKey(spi, '');
    return {
      for (final key in _cache.keys)
        if (key.startsWith(prefix)) key.substring(prefix.length),
    };
  }

  Future<bool> call(String keyType, Uint8List fingerprintBytes) async {
    final storageKey = hostKeyStorageKey(spi, keyType);
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

/// The trusted host certificate authorities, or none when they cannot be read.
List<HostCertAuthority> loadHostCertAuthorities() {
  try {
    return Stores.setting.sshHostCertAuthorities.get();
  } catch (e, stack) {
    Loggers.app.warning('Load SSH host certificate authorities failed', e, stack);
    return const [];
  }
}

/// The remembered host key fingerprints, or none when they cannot be read.
Map<String, String> loadKnownHostFingerprints() {
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
  final server = hostKeyServerId(info.spi);
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
bool hasKnownHostFingerprint(Spi spi, Map<String, String> cache) {
  final id = hostKeyServerId(spi);
  return cache.keys.any((key) => splitHostKeyStorageKey(key).$1 == id);
}

String hostKeyStorageKey(Spi spi, String keyType) {
  final base = hostKeyServerId(spi);
  return '$base::$keyType';
}

String hostKeyServerId(Spi spi) => spi.id.isNotEmpty ? spi.id : spi.oldId;

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

/// How a host key question reaches the user: the dialog the app installs at
/// launch (`installHostKeyDialog`). Until then every question is refused, as
/// it is with no screen to ask on.
abstract final class HostKeyDialog {
  static Future<bool> Function(HostKeyPromptInfo info, BuildContext? context) show =
      (_, _) async => false;
}

/// Asks about [info] once per server at a time — see [promptHostKeyExclusively].
Future<bool> showHostKeyPrompt(
  HostKeyPromptInfo info, {
  BuildContext? context,
}) => promptHostKeyExclusively(info, () => HostKeyDialog.show(info, context));

