/// What the share payload has to be for the scanner to have a chance.
///
/// The two constants here are a pair taken out of the QR capacity table, and
/// nothing at their definition can check them — a wrong number produces a
/// symbol that is simply larger than intended, which no round trip notices and
/// the camera reports as "it does not scan". So they are held against the real
/// encoder, and the compression they assume is held against a real payload.
@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// An ed25519 private key is 399 bytes of key material in base64, which is the
/// case this format is sized for. Random, and a different one per call, so the
/// numbers below are not flattered by two keys deflating against each other.
String _ed25519(int seed) {
  final random = Random(seed);
  final body = base64.encode(List.generate(399, (_) => random.nextInt(256)));
  final lines = <String>[
    for (var i = 0; i < body.length; i += 70)
      body.substring(i, min(i + 70, body.length)),
  ];
  return '-----BEGIN OPENSSH PRIVATE KEY-----\n'
      '${lines.join('\n')}\n'
      '-----END OPENSSH PRIVATE KEY-----';
}

Spi _spi() => Spi(
  id: 'b3f1c2d4-5a6b-7c8d-9e0f-1a2b3c4d5e6f',
  name: 'hetzner-fsn1-web-01',
  ssh: const SshCredential(
    ip: 'web-01.fsn1.example.com',
    port: 22,
    user: 'deploy',
    pwd: 'correct-horse-battery-staple',
    keyId: 'k1',
  ),
  tags: const ['prod', 'web', 'eu'],
);

ServerShare _share({int keys = 0}) => ServerShare(
  version: ServerShare.formatVer,
  spi: _spi(),
  keys: [
    for (var i = 0; i < keys; i++)
      PrivateKeyInfo(id: 'k$i', name: 'key$i', key: _ed25519(i)),
  ],
);

/// The guard's own sentence, not just its type: every other way these inputs
/// fail also raises [ServerShareUnreadableException].
final _tooLarge = throwsA(
  isA<ServerShareUnreadableException>().having(
    (e) => '$e',
    'message',
    contains('too large'),
  ),
);

int _modulesOf(int chars) =>
    17 +
    4 *
        QrCode.fromData(
          data: 'a' * chars,
          errorCorrectLevel: QrErrorCorrectLevel.L,
        ).typeNumber;

void main() {
  group('the cap is the symbol size, not the format', () {
    test('a payload at the cap is exactly the intended symbol', () {
      expect(
        _modulesOf(ServerShareCodec.qrCapacity),
        ServerShareCodec.qrMaxModules,
      );
    });

    test('one more byte is a larger symbol', () {
      expect(
        _modulesOf(ServerShareCodec.qrCapacity + 1),
        greaterThan(ServerShareCodec.qrMaxModules),
      );
    });

    test('the level the dialog asks for is the level the cap assumes', () {
      // At M the same payload needs more versions, so a cap derived from L and
      // a dialog drawing at M would silently exceed [qrMaxModules].
      final atM =
          17 +
          4 *
              QrCode.fromData(
                data: 'a' * ServerShareCodec.qrCapacity,
                errorCorrectLevel: QrErrorCorrectLevel.M,
              ).typeNumber;
      expect(atM, greaterThan(ServerShareCodec.qrMaxModules));
    });
  });

  group('what fits', () {
    test('a server alone, and a server with the key it uses', () {
      expect(ServerShareCodec.fitsInQr(_share()), isTrue);
      expect(ServerShareCodec.fitsInQr(_share(keys: 1)), isTrue);
    });

    test('a payload carrying two keys is sent as a file', () {
      // Deliberate. Before compression this fit, at 177 modules across, and a
      // code that size cannot be read off a screen at any distance the lens
      // will focus at.
      expect(ServerShareCodec.fitsInQr(_share(keys: 2)), isFalse);
    });

    test('the measurement is what encoding actually produces', () {
      // Both carriers, because the envelope is four bytes shorter at
      // `Cryptor`'s default cost and only the QR carrier asks for more.
      for (final carrier in ShareCarrier.values) {
        final share = _share(keys: 1);
        final encoded = ServerShareCodec.encode(share, '123456', carrier);
        expect(
          encoded.length,
          ServerShareCodec.encodedLengthOf(share, carrier: carrier),
          reason: '$carrier',
        );
      }
    });

    test('compression takes versions off the symbol', () {
      final share = _share(keys: 1);
      final raw = utf8.encode(json.encode(share.toJson())).length;
      // What the same payload encoded to before [_pack] existed.
      final uncompressed = ((raw + 76 + 2) ~/ 3) * 4;
      expect(
        _modulesOf(ServerShareCodec.encodedLengthOf(share)),
        lessThan(_modulesOf(uncompressed)),
      );
    });
  });

  group('round trips', () {
    test('what this build writes, this build reads', () {
      final share = _share(keys: 1);
      final encoded = ServerShareCodec.encode(share, 'pw', ShareCarrier.file);
      final back = ServerShareCodec.decode(encoded, password: 'pw');
      expect(back.spi.name, share.spi.name);
      expect(back.keys.single.key, share.keys.single.key);
    });

    test('a payload written before compression still reads', () {
      // What `encode` produced between the format landing and the marker: the
      // plaintext is the JSON itself, so the first byte is `{`.
      final share = _share(keys: 1);
      final legacy = Cryptor.encrypt(
        json.encode(share.toJson()),
        'pw',
        iterations: 1000,
      );
      final back = ServerShareCodec.decode(legacy, password: 'pw');
      expect(back.keys.single.key, share.keys.single.key);
    });

    test('a decompression bomb is refused rather than allocated', () {
      // Compression is also where the size of the input stopped bounding the
      // size of the allocation. 8 MiB of one byte deflates to a couple of
      // kilobytes, and the envelope authenticates: whoever hands over a share
      // hands over the password with it, so this passes every check before
      // the one that has to catch it.
      final bomb = ZLibCodec(
        raw: true,
        level: ZLibOption.maxLevel,
      ).encode(List.filled(8 << 20, 0x41));
      final payload = Cryptor.encryptBytes(
        [0x01, ...bomb],
        'pw',
        iterations: 1000,
      );
      expect(payload.length, lessThan(64 * 1024));
      expect(
        () => ServerShareCodec.decode(payload, password: 'pw'),
        _tooLarge,
      );
    });

    test('an oversized payload is refused before anything is derived', () {
      // Asserted on the message: without the cap this still throws, from
      // `json.decode` further down, and a test that only checked the type
      // would pass with the cap removed.
      expect(
        () => ServerShareCodec.decode('x' * ((1 << 20) + 1), password: 'pw'),
        _tooLarge,
      );
    });

    test('a wrong password still says so rather than blaming the format', () {
      final encoded = ServerShareCodec.encode(
        _share(),
        'pw',
        ShareCarrier.file,
      );
      expect(
        () => ServerShareCodec.decode(encoded, password: 'nope'),
        throwsA(isNot(isA<ServerShareUnreadableException>())),
      );
    });
  });
}
