import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';
import 'package:server_box/data/model/app/rootfs_manifest_trust.dart';

/// Verifying a fetched manifest.
///
/// The fixture is a real signature, produced by the key that signs
/// `shellbox-rootfs` — the private half of which is in the maintainer's login
/// keychain, not here. Regenerate it with:
///
///     security find-generic-password -s shellbox-rootfs-signing \
///       -a manifest -w | base64 -d > priv.pem
///     openssl pkeyutl -sign -inkey priv.pem -rawin \
///       -in test/fixtures/rootfs_manifest/signed.json \
///       -out test/fixtures/rootfs_manifest/signed.json.sig
///
/// A mocked signature would prove that the code calls a verifier. What has to
/// be proved is that it calls it correctly, against the key that is actually
/// compiled in — so the fixture is signed rather than fabricated, and every
/// negative case starts from bytes that genuinely do verify.
void main() {
  final dir = Directory('test/fixtures/rootfs_manifest');
  late Uint8List source;
  late Uint8List signature;

  /// Before `valid_until` in the fixture, and after `generated_at`.
  final now = DateTime.utc(2026, 9, 1);

  setUpAll(() {
    source = File('${dir.path}/signed.json').readAsBytesSync();
    signature = File('${dir.path}/signed.json.sig').readAsBytesSync();
  });

  test('a signed manifest verifies and parses', () {
    final manifest = RootfsManifestTrust.verify(
      source,
      signature,
      previousSerial: null,
      now: now,
    );
    expect(manifest.schema, RootfsManifest.supportedSchema);
    expect(manifest.distros.keys, containsAll(['alpine', 'ubuntu', 'rocky']));
  });

  test('one flipped byte in the payload is refused', () {
    // Not a rewritten manifest — a single bit of the bytes that were signed.
    // Anything less than this passing would mean the payload was not what got
    // checked.
    final tampered = Uint8List.fromList(source);
    tampered[tampered.length ~/ 2] ^= 0x01;
    expect(
      () => RootfsManifestTrust.verify(
        tampered,
        signature,
        previousSerial: null,
        now: now,
      ),
      throwsA(isA<RootfsManifestException>()),
    );
  });

  test('a plausible edit with the original signature is refused', () {
    // What an attacker who could rewrite the file but not the key would do:
    // keep it valid JSON, point a download somewhere else.
    final edited = Uint8List.fromList(
      utf8.encode(
        utf8
            .decode(source)
            .replaceFirst('dl-cdn.alpinelinux.org', 'mirror.attacker.test'),
      ),
    );
    expect(
      () => RootfsManifestTrust.verify(
        edited,
        signature,
        previousSerial: null,
        now: now,
      ),
      throwsA(isA<RootfsManifestException>()),
    );
  });

  test('one flipped byte in the signature is refused', () {
    final tampered = Uint8List.fromList(signature);
    tampered[0] ^= 0x01;
    expect(
      () => RootfsManifestTrust.verify(
        source,
        tampered,
        previousSerial: null,
        now: now,
      ),
      throwsA(isA<RootfsManifestException>()),
    );
  });

  test('a signature of the wrong length is refused, not thrown over', () {
    for (final length in [0, 32, 63, 65, 128]) {
      expect(
        () => RootfsManifestTrust.verify(
          source,
          Uint8List(length),
          previousSerial: null,
          now: now,
        ),
        throwsA(isA<RootfsManifestException>()),
        reason: 'accepted or mis-threw on $length bytes',
      );
    }
  });

  group('replay', () {
    test('a serial below what was already accepted is refused', () {
      // A signature stays valid as long as the key does, so verifying is not
      // the same as being current. Without this, an old signed copy would pin
      // a device to a rootfs whose problems are known.
      final serial = RootfsManifestTrust.verify(
        source,
        signature,
        previousSerial: null,
        now: now,
      ).serial;

      expect(
        () => RootfsManifestTrust.verify(
          source,
          signature,
          previousSerial: serial + 1,
          now: now,
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('the same serial is still accepted', () {
      // Re-fetching what is already held is ordinary, not an attack.
      final serial = RootfsManifestTrust.verify(
        source,
        signature,
        previousSerial: null,
        now: now,
      ).serial;

      expect(
        RootfsManifestTrust.verify(
          source,
          signature,
          previousSerial: serial,
          now: now,
        ).serial,
        serial,
      );
    });

    test('an expired manifest is refused', () {
      final validUntil = RootfsManifestTrust.verify(
        source,
        signature,
        previousSerial: null,
        now: now,
      ).validUntil;

      expect(
        () => RootfsManifestTrust.verify(
          source,
          signature,
          previousSerial: null,
          now: validUntil.add(const Duration(seconds: 1)),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });
  });

  test('the compiled-in key is a raw Ed25519 public key', () {
    expect(base64Decode(RootfsManifestTrust.publicKey), hasLength(32));
  });
}
