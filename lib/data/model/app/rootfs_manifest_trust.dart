/// Deciding whether a fetched manifest may be believed.
///
/// A manifest names the bytes this app downloads and then runs, so whoever
/// can choose the manifest chooses what runs on the device. Compiling a digest
/// into the binary is what used to prevent that; moving the digests out has to
/// put something equally hard in their place, and this is it.
///
/// Three parties, and each decides exactly one thing:
///
/// - the app decides **which key** — [publicKey], compiled in;
/// - `shellbox-rootfs` decides **which bytes**, by signing the manifest;
/// - a mirror still decides only **where the bytes come from**.
///
/// The bundled asset is not signed and does not need to be. It arrives inside
/// the binary, so anyone who could alter it could equally alter [publicKey],
/// and a signature would be checked against a key the same attacker chose.
library;

import 'dart:convert';

import 'package:pinenacl/ed25519.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

abstract final class RootfsManifestTrust {
  /// The key `shellbox-rootfs` signs with, raw Ed25519, base64.
  ///
  /// Its private half is not in this repository and never was: it lives in
  /// that repository's Actions secret, and on the maintainer's machine in the
  /// login keychain under `shellbox-rootfs-signing`. Rotating it means
  /// shipping a build — which is the point, since a key a server could
  /// replace would protect nothing.
  static const publicKey = 'wsNkktBO13RsNJm9P38/QPXExoFYluty9zKlZpWSYkk=';

  /// Ed25519, so this is fixed. Checked before the library is asked, which
  /// answers a malformed signature with [RootfsManifestException] rather than
  /// whatever pinenacl throws for a bad length.
  static const signatureBytes = 64;

  /// Reads [source] only if [signature] signs those exact bytes.
  ///
  /// The bytes as downloaded, not a re-encoding of the parsed result: signing
  /// a canonical form would mean the app and the signer had to agree on what
  /// canonical means, and every such agreement is somewhere a difference can
  /// hide. Verify first, parse second.
  ///
  /// [previousSerial] is the highest serial this device has already accepted.
  /// A signature stays valid for as long as the key does, so a manifest that
  /// verifies is not therefore current — without this check, replaying an
  /// older signed copy would pin a device to a rootfs whose problems are
  /// known. Pass null on a device that has never accepted one.
  ///
  /// [now] is taken rather than read so that a caller can be tested; it is
  /// compared against `valid_until`, which is what stops a manifest being
  /// replayed forever after the repository stops publishing.
  static RootfsManifest verify(
    Uint8List source,
    Uint8List signature, {
    required int? previousSerial,
    required DateTime now,
  }) {
    if (signature.length != signatureBytes) {
      throw RootfsManifestException(
        'the signature is ${signature.length} bytes, not $signatureBytes',
      );
    }

    final key = VerifyKey(Uint8List.fromList(base64Decode(publicKey)));
    final bool ok;
    try {
      ok = key.verify(signature: Signature(signature), message: source);
    } catch (e) {
      // A library that throws on a malformed input must not read as a pass.
      throw RootfsManifestException('the signature could not be checked: $e');
    }
    if (!ok) {
      throw const RootfsManifestException('the signature does not match');
    }

    // Decoded as UTF-8, which is what the file is. `String.fromCharCodes`
    // reads each byte as a code point, so anything outside ASCII becomes a
    // different string — and the bytes that were signed are not the bytes that
    // get parsed. Every manifest published so far happens to be ASCII, which
    // is what kept it invisible; a distribution label with an accent in it is
    // all it would take.
    final String text;
    try {
      text = utf8.decode(source);
    } on FormatException catch (e) {
      throw RootfsManifestException('it is not UTF-8: ${e.message}');
    }
    final manifest = RootfsManifest.parse(text);

    if (previousSerial != null && manifest.serial < previousSerial) {
      throw RootfsManifestException(
        'serial ${manifest.serial} is older than the accepted $previousSerial',
      );
    }
    if (!manifest.validUntil.isAfter(now.toUtc())) {
      throw RootfsManifestException(
        'it expired at ${manifest.validUntil.toIso8601String()}',
      );
    }
    return manifest;
  }
}
