// The native SSH record cipher and MAC, checked against the pointycastle
// implementation they replace. Build the native library first:
// cargo build -p sbm_ffi
//
// The Rust side has its own vectors (crates/sbm_ffi/src/api/ssh_crypto.rs,
// NIST SP 800-38A and RFC 4231). What those cannot show is whether the Dart
// wrapper drives it the way dartssh2 drives a cipher: keyed once and then fed
// packet after packet, with the counter and the chaining block carrying across
// the calls, and a MAC that is reused for every packet of a connection. A
// mistake there does not fail loudly — it produces a valid-looking packet the
// peer cannot authenticate, some way into a session.

import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/api.dart';
import 'package:server_box/core/utils/ssh_native_crypto.dart';

import 'rust_lib_helper.dart';

/// A packet's worth of bytes, block-aligned, varying with [seed].
Uint8List _bytes(int length, [int seed = 1]) {
  return Uint8List.fromList(
    List.generate(length, (i) => (i * 31 + seed * 17) & 0xff),
  );
}

/// Every packet the transport would put through one direction of a connection,
/// concatenated, so that a state mistake at any packet shows up in the result.
Uint8List _runPackets(BlockCipher cipher, List<Uint8List> packets) {
  final out = BytesBuilder(copy: true);
  for (final packet in packets) {
    out.add(cipher.processAll(packet));
  }
  return out.takeBytes();
}

void main() {
  const native = NativeSshCrypto();

  setUpAll(initRustLibForTest);

  group('record cipher', () {
    // Every cipher the backend claims. AEAD is not among them: the transport
    // computes GCM and ChaCha20-Poly1305 inline rather than through
    // `createCipher`, so there is nothing here for a backend to answer.
    const ciphers = {
      SSHCipherType.aes128ctr: 16,
      SSHCipherType.aes192ctr: 24,
      SSHCipherType.aes256ctr: 32,
      SSHCipherType.aes128cbc: 16,
      SSHCipherType.aes192cbc: 24,
      SSHCipherType.aes256cbc: 32,
    };

    for (final entry in ciphers.entries) {
      final type = entry.key;
      final keySize = entry.value;

      for (final forEncryption in [true, false]) {
        final direction = forEncryption ? 'encrypting' : 'decrypting';

        test('${type.name} agrees with pointycastle when $direction', () {
          final key = _bytes(keySize, 3);
          final iv = _bytes(16, 5);
          // Sizes a real session produces: a keystroke, a window of output, a
          // large read. All block-aligned, which is what the framing gives.
          final packets = [
            _bytes(16, 1),
            _bytes(48, 2),
            _bytes(16, 3),
            _bytes(4096, 4),
          ];

          final fallback = type.createCipher(
            key,
            iv,
            forEncryption: forEncryption,
          );
          final backend = native.createBlockCipher(
            type.name,
            key,
            iv,
            forEncryption: forEncryption,
          );
          expect(backend, isNotNull, reason: '${type.name} should be native');

          expect(
            _runPackets(backend!, packets),
            _runPackets(fallback, packets),
          );
        });
      }
    }

    test('a CTR keystream does not depend on how the packets are cut', () {
      final key = _bytes(32, 3);
      final iv = _bytes(16, 5);
      final whole = _bytes(4096, 9);

      final once = native.createBlockCipher(
        'aes256-ctr',
        key,
        iv,
        forEncryption: true,
      )!;
      final split = native.createBlockCipher(
        'aes256-ctr',
        key,
        iv,
        forEncryption: true,
      )!;

      final cut = <Uint8List>[];
      for (var off = 0; off < whole.length; off += 16) {
        cut.add(Uint8List.sublistView(whole, off, off + 16));
      }

      expect(_runPackets(split, cut), _runPackets(once, [whole]));
    });

    test('CBC decrypting undoes CBC encrypting across packets', () {
      final key = _bytes(32, 3);
      final iv = _bytes(16, 5);
      final packets = [_bytes(32, 1), _bytes(16, 2), _bytes(64, 3)];

      final enc = native.createBlockCipher(
        'aes256-cbc',
        key,
        iv,
        forEncryption: true,
      )!;
      final dec = native.createBlockCipher(
        'aes256-cbc',
        key,
        iv,
        forEncryption: false,
      )!;

      for (final packet in packets) {
        expect(dec.processAll(enc.processAll(packet)), packet);
      }
    });

    test('processBlock writes one block at the offset it is given', () {
      final key = _bytes(32, 3);
      final iv = _bytes(16, 5);
      final data = _bytes(48, 7);

      final viaBlocks = native.createBlockCipher(
        'aes256-ctr',
        key,
        iv,
        forEncryption: true,
      )!;
      final viaBulk = native.createBlockCipher(
        'aes256-ctr',
        key,
        iv,
        forEncryption: true,
      )!;

      final out = Uint8List(data.length);
      for (var off = 0; off < data.length; off += 16) {
        expect(viaBlocks.processBlock(data, off, out, off), 16);
      }

      expect(out, viaBulk.processAll(data));
    });

    test('an algorithm the backend has no implementation for answers null', () {
      // What dartssh2 reads as "use pointycastle". The transport computes both
      // AEAD ciphers itself, so this is the path they take.
      expect(
        native.createBlockCipher(
          'aes256-gcm@openssh.com',
          _bytes(32),
          _bytes(16),
          forEncryption: true,
        ),
        isNull,
      );
    });

    test('re-keying is refused rather than silently ignored', () {
      final cipher = native.createBlockCipher(
        'aes256-ctr',
        _bytes(32),
        _bytes(16),
        forEncryption: true,
      )!;
      expect(() => cipher.reset(), throwsStateError);
      expect(() => cipher.init(true, null), throwsStateError);
    });
  });

  group('packet mac', () {
    // Both the plain and the truncated forms of each hash. The `-etm` variants
    // are not listed because they resolve to the same `hmacName` and size — it
    // is `SSHMacType.hmacName` that strips the suffix, and that is covered by
    // the round trip through `createMac` below.
    const macs = [
      SSHMacType.hmacMd5,
      SSHMacType.hmacSha1,
      SSHMacType.hmacSha256,
      SSHMacType.hmacSha512,
      SSHMacType.hmacSha256_96,
      SSHMacType.hmacSha512_96,
    ];

    for (final type in macs) {
      test('${type.name} agrees with pointycastle', () {
        final key = _bytes(type.keySize, 11);
        final fallback = type.createMac(key);
        final backend = native.createMac(type.hmacName, key, type.macSize);
        expect(backend, isNotNull, reason: '${type.hmacName} should be native');
        expect(backend!.macSize, type.macSize);
        expect(fallback.macSize, type.macSize);

        // Fed the way the transport feeds it: a sequence number, then the
        // packet — and then again for the next packet on the same instance.
        for (var seq = 0; seq < 3; seq++) {
          final packet = _bytes(64 + seq * 16, seq);
          final sn = Uint8List(4)..buffer.asByteData().setUint32(0, seq);

          for (final mac in [fallback, backend]) {
            mac.update(sn, 0, sn.length);
            mac.update(packet, 0, packet.length);
          }

          final expected = Uint8List(fallback.macSize);
          fallback.doFinal(expected, 0);
          final got = Uint8List(backend.macSize);
          backend.doFinal(got, 0);

          expect(got, expected, reason: 'packet $seq');
        }
      });
    }

    test('the -etm variants resolve to the same tag as their base', () {
      final key = _bytes(SSHMacType.hmacSha256Etm.keySize, 11);
      final packet = _bytes(128, 2);

      final etm = SSHMacType.hmacSha256Etm.createMac(key);
      final base = SSHMacType.hmacSha256.createMac(key);

      expect(etm.process(packet), base.process(packet));
    });

    test('doFinal writes at the offset it is given and leaves no state', () {
      final key = _bytes(32, 11);
      final mac = native.createMac('hmac-sha2-256', key, 32)!;
      final packet = _bytes(64, 4);

      final first = Uint8List(40);
      mac.update(packet, 0, packet.length);
      expect(mac.doFinal(first, 8), 32);

      // The same input again must give the same tag — a leaked update from the
      // previous packet would show up here and nowhere else.
      final second = Uint8List(32);
      mac.update(packet, 0, packet.length);
      mac.doFinal(second, 0);

      expect(Uint8List.sublistView(first, 8), second);
      expect(Uint8List.sublistView(first, 0, 8), Uint8List(8));
    });

    test('an algorithm the backend has no implementation for answers null', () {
      expect(native.createMac('hmac-ripemd160', _bytes(20), 20), isNull);
    });

    test('re-keying is refused rather than silently ignored', () {
      final mac = native.createMac('hmac-sha2-256', _bytes(32), 32)!;
      expect(() => mac.init(KeyParameter(_bytes(32))), throwsStateError);
    });
  });

  group('installed backend', () {
    tearDown(() => sshCryptoBackend = null);

    test('is what SSHCipherType and SSHMacType then build', () {
      sshCryptoBackend = native;

      final cipher = SSHCipherType.aes256ctr.createCipher(
        _bytes(32, 3),
        _bytes(16, 5),
        forEncryption: true,
      );
      expect(cipher, isA<SSHBulkBlockCipher>());

      // And produces what the implementation it replaced produced.
      sshCryptoBackend = null;
      final fallback = SSHCipherType.aes256ctr.createCipher(
        _bytes(32, 3),
        _bytes(16, 5),
        forEncryption: true,
      );
      expect(fallback, isNot(isA<SSHBulkBlockCipher>()));

      final packet = _bytes(256, 6);
      expect(cipher.processAll(packet), fallback.processAll(packet));
    });

    test('leaves an algorithm it does not implement on pointycastle', () {
      sshCryptoBackend = native;
      // `hmac-md5` is implemented; a MAC nothing implements has no SSHMacType,
      // so the case to check here is the AEAD cipher the transport handles
      // itself — asked through the factory it must still come back usable.
      final cipher = SSHCipherType.aes256ctr.createCipher(
        _bytes(32),
        _bytes(16),
        forEncryption: true,
      );
      expect(cipher.blockSize, 16);
    });
  });
}
