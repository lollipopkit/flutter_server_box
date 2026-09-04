import 'dart:convert';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:server_box/core/utils/server_dedup.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

/// How a share payload is carried to the other device.
///
/// The carrier decides the KDF cost and whether the payload expires, because
/// the two carriers fail in different ways. A QR is on a screen for a minute
/// and is protected by a code spoken out loud, so its password is short and
/// the cost has to make up for it; a file is saved deliberately and protected
/// by a passphrase the user chose, so it gets the same cost every backup does.
enum ShareCarrier {
  /// Six digits is twenty bits. Nothing makes that a strong password — the
  /// cost and the deadline together are what make guessing it not worth
  /// starting, and both are stated in the dialog rather than implied.
  ///
  /// 600k is the OWASP figure for PBKDF2-HMAC-SHA256 and is roughly 0.6s on a
  /// phone, paid once per share and once per scan.
  qr(iterations: 600000, ttl: Duration(minutes: 10)),

  /// What a backup gets, against a passphrase the user chose. No deadline: a
  /// file is saved to be opened later, and expiring it would only mean the
  /// user's own copy stopped working.
  file(iterations: Cryptor.defaultIterations, ttl: null);

  const ShareCarrier({required this.iterations, required this.ttl});

  final int iterations;
  final Duration? ttl;
}

/// Raised when a payload decoded but its deadline has passed.
class ServerShareExpiredException implements Exception {
  const ServerShareExpiredException();

  @override
  String toString() => 'ServerShareExpiredException';
}

/// Raised when the text is neither an encrypted payload nor a bare server.
class ServerShareUnreadableException implements Exception {
  const ServerShareUnreadableException(this.cause);

  final Object cause;

  @override
  String toString() => 'ServerShareUnreadableException: $cause';
}

/// Packs a server into a string, and reads one back.
abstract final class ServerShareCodec {
  /// How many digits [generateCode] produces.
  ///
  /// Read by the dialog so the field's length and the code's cannot drift.
  static const codeDigits = 6;

  /// A one-time code for the [ShareCarrier.qr] flavour, from a CSPRNG.
  ///
  /// `Random.secure()` rather than `Random()`: the sender's code is the only
  /// thing between a photographed QR and the plaintext, and a predictable one
  /// would leave nothing at all.
  static String generateCode() {
    final random = Random.secure();
    return List.generate(codeDigits, (_) => random.nextInt(10)).join();
  }

  static String encode(
    ServerShare share,
    String password,
    ShareCarrier carrier,
  ) {
    return Cryptor.encrypt(
      json.encode(share.toJson()),
      password,
      iterations: carrier.iterations,
    );
  }

  /// [encode] on another isolate.
  ///
  /// 600k rounds of PBKDF2 is most of a second, which on the isolate drawing
  /// frames is the share button appearing not to work. `compute`, not
  /// `Computer.shared`, for the reason `ssh_key_unlock` gives: the shared one
  /// has to be turned on and is not under `flutter test`.
  static Future<String> encodeAsync(
    ServerShare share,
    String password,
    ShareCarrier carrier,
  ) => compute(_encrypt, (
    json.encode(share.toJson()),
    password,
    carrier.iterations,
  ));

  static String _encrypt((String, String, int) args) =>
      Cryptor.encrypt(args.$1, args.$2, iterations: args.$3);

  /// The most bytes a version-40 QR holds in byte mode at error correction
  /// level M, which is the level `QrView` fixes.
  static const qrCapacity = 2331;

  /// How long [encode] will make this payload, without paying the KDF to find
  /// out.
  ///
  /// Exact, not an estimate: AES-GCM ciphertext is the plaintext's length plus
  /// a 16-byte tag, and everything else in the envelope is fixed width. Used
  /// to decide whether to offer a QR at all — an RSA key does not fit in one,
  /// and finding that out from `QrCode.fromData` throwing is finding it out
  /// too late.
  static int encodedLengthOf(ServerShare share) {
    final plain = utf8.encode(json.encode(share.toJson())).length;
    // magic(12) + iterations(4) + salt(32) + nonce(12) + tag(16)
    const envelope = 76;
    return ((plain + envelope + 2) ~/ 3) * 4;
  }

  static bool fitsInQr(ServerShare share) =>
      encodedLengthOf(share) <= qrCapacity;

  static String _decrypt((String, String) args) =>
      Cryptor.decrypt(args.$1, args.$2);

  /// Whether [text] has to be decrypted before it can be read.
  ///
  /// False for a QR written by a build that predates this format, which is a
  /// bare `Spi` in clear text. Asked before prompting, so a user scanning an
  /// old code is not asked for a code that was never generated.
  static bool needsPassword(String text) => Cryptor.isEncrypted(text.trim());

  /// Reads [text] into a payload, or throws saying why it could not.
  ///
  /// Accepts three shapes, in this order:
  /// - an encrypted [ServerShare], which is what this build writes;
  /// - a bare `ServerShare` JSON, which nothing writes and which exists so a
  ///   payload can be inspected in a test without a password;
  /// - a bare `Spi` JSON, which is every QR code shared before this format.
  ///
  /// The last one is why this cannot simply parse and throw: dropping it would
  /// mean a code printed and stuck on a rack stopped working on upgrade.
  static ServerShare decode(String text, {String? password}) {
    final trimmed = text.trim();

    String plain;
    if (Cryptor.isEncrypted(trimmed)) {
      if (password == null || password.isEmpty) {
        throw const ServerShareUnreadableException('password required');
      }
      // Whatever `decrypt` throws — a wrong password and a corrupt payload are
      // the same `Exception` — is the caller's to show. Not wrapped, so the
      // message the user reads is the one that says which.
      plain = Cryptor.decrypt(trimmed, password);
    } else {
      plain = trimmed;
    }
    return _fromPlain(plain);
  }

  /// [decode] with the key derivation on another isolate. See [encodeAsync].
  static Future<ServerShare> decodeAsync(
    String text, {
    String? password,
  }) async {
    final trimmed = text.trim();
    if (!Cryptor.isEncrypted(trimmed)) return _fromPlain(trimmed);
    if (password == null || password.isEmpty) {
      throw const ServerShareUnreadableException('password required');
    }
    return _fromPlain(await compute(_decrypt, (trimmed, password)));
  }

  static ServerShare _fromPlain(String plain) {
    final Object? decoded;
    try {
      decoded = json.decode(plain);
    } catch (e) {
      throw ServerShareUnreadableException(e);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const ServerShareUnreadableException('not an object');
    }

    // `version` is what tells the two shapes apart. A bare `Spi` has no such
    // field, and it is checked before `Spi` is attempted so a payload from a
    // newer build is refused rather than half-read as a server.
    if (decoded.containsKey('version')) {
      final share = ServerShare.fromJson(decoded);
      share.validate();
      if (share.isExpired()) throw const ServerShareExpiredException();
      return share;
    }

    try {
      return ServerShare(
        version: ServerShare.formatVer,
        spi: Spi.fromJson(decoded),
      );
    } catch (e) {
      throw ServerShareUnreadableException(e);
    }
  }
}

/// What installing a payload did.
final class ServerShareResult {
  const ServerShareResult({required this.spi, required this.addedKeys});

  /// The server as it was actually written, with its id, name and key
  /// reference resolved against what was already here.
  final Spi spi;

  /// Keys this added. Empty when the payload carried one the device already
  /// had, which is what re-importing the same share does.
  final List<PrivateKeyInfo> addedKeys;
}

/// Writes a decoded payload into the local stores.
///
/// Additive, always. Nothing here can remove or overwrite a record the user
/// already had — which is the one hard difference from a backup restore, where
/// an absent key means a deletion.
abstract final class ServerShareInstaller {
  /// The server this payload describes, if this device already has it.
  ///
  /// Deliberately not `Spi.isSameAs`: that compares SSH credentials and
  /// nothing else, so it answers *true* for any two servers that both have
  /// none — two unrelated monitor-only servers read as the same machine.
  ///
  /// TODO: fold this back into `Spi.isSameAs` once that grows an identity
  /// covering both transports, and delete this.
  static Spi? findExisting(Spi incoming) {
    for (final existing in Stores.server.fetch()) {
      if (existing.id == incoming.id) return existing;

      final a = incoming.ssh, b = existing.ssh;
      if (a != null && b != null) {
        if (a.ip == b.ip && a.port == b.port && a.user == b.user) {
          return existing;
        }
      }

      final ma = incoming.monitorHttp, mb = existing.monitorHttp;
      if (ma != null && mb != null && ma.addr == mb.addr) return existing;
    }
    return null;
  }

  /// Writes [share] and answers what it did.
  ///
  /// One unit: a payload whose server is rejected must not leave its key
  /// behind, which is a credential the user never agreed to hold.
  static ServerShareResult install(ServerShare share) =>
      SqliteStore.transact(() => _install(share));

  static ServerShareResult _install(ServerShare share) {
    final added = <PrivateKeyInfo>[];
    final keyIds = <String, String>{};
    for (final key in share.keys) {
      final (id, isNew) = _installKey(key);
      keyIds[key.id] = id;
      if (isNew) added.add(key.copyWith(id: id));
    }

    var spi = share.spi;
    final keyId = spi.ssh?.keyId;
    if (keyId != null) {
      // A payload whose `keys` does not carry the id its server names is one
      // the sender could not complete. Dropped rather than kept, for the same
      // reason `ServerShare._portable` drops it: a dangling reference looks
      // like key auth and behaves like nothing.
      spi = spi.copyWith(ssh: spi.ssh?.copyWith(keyId: keyIds[keyId]));
    }

    final existing = Stores.server.fetch();
    if (spi.id.isEmpty || existing.any((e) => e.id == spi.id)) {
      spi = spi.copyWith(id: ShortId.generate());
    }
    // `existingServers` passed rather than left to default, which reads
    // `ServerStore.instance` — a different object from `Stores.server` with a
    // cache of its own, so the default answers from whatever that instance
    // last read. Two installs in a row saw an empty list the second time.
    spi = ServerDeduplication.resolveNameConflicts(
      [spi],
      existingServers: existing,
    ).first;

    // Before the write, and here rather than left to `ServerNotifier.addServer`
    // — a payload is a file someone else made, so "carries a way in at all" is
    // not something this side may assume. The transaction takes the key with
    // it when this throws.
    spi.validateOrThrow();

    Stores.server.put(spi);
    return ServerShareResult(spi: spi, addedKeys: added);
  }

  /// Returns the id to point the server at, and whether a row was written.
  ///
  /// Key material decides identity here, not the name and not the id. A name
  /// match would be wrong in the direction that costs the most: `Stores.key`
  /// has a UNIQUE name and `EntityStore.reconcile` resolves a collision by
  /// *taking the existing row's id* — which through `put` would overwrite the
  /// receiver's own key with the sender's. That is right for restoring a
  /// backup of one's own device and wrong for a payload from someone else's.
  static (String id, bool isNew) _installKey(PrivateKeyInfo incoming) {
    final existing = Stores.key.fetch();

    final same = existing.firstWhereOrNull(
      (e) => e.key.trim() == incoming.key.trim(),
    );
    if (same != null) return (same.id, false);

    final names = existing.map((e) => e.name).toSet();
    var name = incoming.name;
    for (var n = 2; names.contains(name); n++) {
      name = '${incoming.name} ($n)';
    }

    final id = existing.any((e) => e.id == incoming.id)
        ? ShortId.generate()
        : incoming.id;
    Stores.key.put(incoming.copyWith(id: id, name: name));
    return (id, true);
  }
}
