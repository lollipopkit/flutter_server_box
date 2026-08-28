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
// Not exported from the barrel.
// ignore_for_file: implementation_imports
import 'package:dartssh2/src/hostkey/hostkey_ecdsa.dart';
import 'package:dartssh2/src/hostkey/hostkey_ed25519.dart';
import 'package:dartssh2/src/kex/kex_x25519.dart';
import 'package:dartssh2/src/utils/bcrypt.dart' as builtin_bcrypt;
import 'package:flutter_test/flutter_test.dart';
import 'package:pinenacl/tweetnacl.dart';
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
  // Every 'agrees with pointycastle' comparison reaches its reference
  // implementation through `SSHCipherType.createCipher`, which reads this
  // global. A group that left it set would have those tests comparing the
  // native implementation with itself, and passing.
  setUp(() => sshCryptoBackend = null);
  tearDown(() => sshCryptoBackend = null);
  _asymmetricTests(native);

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

      // `hmac-md5` and every cipher in `SSHCipherType` are implemented, so the
      // only reachable unimplemented algorithm is one the backend is asked for
      // by name. `SSHMacType` is where that happens.
      expect(native.createMac('hmac-ripemd160', _bytes(20), 20), isNull);
      expect(
        native.createBlockCipher(
          'aes256-gcm@openssh.com',
          _bytes(32),
          _bytes(12),
          forEncryption: true,
        ),
        isNull,
      );

      // And an implemented one still comes back native, so the null above is a
      // refusal of that algorithm rather than of everything.
      expect(
        SSHCipherType.aes256ctr.createCipher(
          _bytes(32),
          _bytes(16),
          forEncryption: true,
        ),
        isA<SSHBulkBlockCipher>(),
      );
    });
  });
}

/// Generated by ssh-keygen. Private keys in a test file are what
/// `false_secrets` exists for.
const _ed25519Pem = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAmeIqTaKVgK3jyqh4LHAn/4XF3L+mFu2FuSIb2WCRxQwAAAIjjp0Dr46dA
6wAAAAtzc2gtZWQyNTUxOQAAACAmeIqTaKVgK3jyqh4LHAn/4XF3L+mFu2FuSIb2WCRxQw
AAAECuXvUxDg2J8RvI6EoCFTBjjLrotdM94vQdVdEEUghqRyZ4ipNopWArePKqHgscCf/h
cXcv6YW7YW5IhvZYJHFDAAAABHRlc3QB
-----END OPENSSH PRIVATE KEY-----''';

const _ed25519EncPem = '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABAg5Riwua
5beS4snWWUidONAAAAGAAAAAEAAAAzAAAAC3NzaC1lZDI1NTE5AAAAIEDCcGtimUlgaIHj
G1FSAGBNXDjxJpZ4d+uUiVxL0N8oAAAAkDONlRPg/9bWYy0tjcW/wn00ojgtXOZUblfZHR
phdwU92jyvjO0h8UnsMsSXjJRGzdq/DdVbNTVoqgYAbCCK3hwrtJIj8c7j5T+l6KzhI7a3
FjyMnkPazhD4KqM6JIhL2ODTcXfue7n0u/gRKVYHjCRQEoxKqUGHs9AHgfp5LtKRkxUsN9
tnsPaek1tyG3JuTQ==
-----END OPENSSH PRIVATE KEY-----''';

/// One ECDSA key per curve, so nistp384 and nistp521 are exercised rather than
/// assumed to work because nistp256 does.
const _ecdsaPems = {
  'nistp256': '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS
1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQQc1TjnppHiTdGaj+xNnQh++l3GSBgB
6B4BlLnkJ10nCLhqi2pNOgRaOLtKNOLNJ5MAamrAVozurBrjnMYUp5mUAAAAoCz+zxAs/s
8QAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBzVOOemkeJN0ZqP
7E2dCH76XcZIGAHoHgGUueQnXScIuGqLak06BFo4u0o04s0nkwBqasBWjO6sGuOcxhSnmZ
QAAAAgP0rwW2WsQ8RYnxy27cil8AleViluaY3v0eI2eO9/aYwAAAAEdGVzdAECAwQ=
-----END OPENSSH PRIVATE KEY-----''',
  'nistp384': '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAiAAAABNlY2RzYS
1zaGEyLW5pc3RwMzg0AAAACG5pc3RwMzg0AAAAYQRGaoYVZIzZ1y6JsatgxxaOAI8h2lqG
/gl7cmw+f+/hURgI1AMX/rEBCcWBBuIzm8ssuH1tedxlKSJWtdE1glWzCaF+9BbFGFRTEm
p6NuXMfSCSY1pFbXpBZz1egWUSFp4AAADQTIdrYUyHa2EAAAATZWNkc2Etc2hhMi1uaXN0
cDM4NAAAAAhuaXN0cDM4NAAAAGEERmqGFWSM2dcuibGrYMcWjgCPIdpahv4Je3JsPn/v4V
EYCNQDF/6xAQnFgQbiM5vLLLh9bXncZSkiVrXRNYJVswmhfvQWxRhUUxJqejblzH0gkmNa
RW16QWc9XoFlEhaeAAAAMQCIYAtyPzGXA5XKGckx3qGtgCVj4lnEg5WaWODamwpMaUBCxj
+OYsSChPCT+Je9LiAAAAAEdGVzdAECAw==
-----END OPENSSH PRIVATE KEY-----''',
  'nistp521': '''
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAArAAAABNlY2RzYS
1zaGEyLW5pc3RwNTIxAAAACG5pc3RwNTIxAAAAhQQB23gkXUanXJbChGTxtTXO4Noaj2N3
uYiAnB+IuSfIW12ow3NqXLoUtYfhFvjYMjAoE8uM2aw+/zwBmC1ExTsHkFIA18JEBY2THT
h0iUAy461UQn+llledNHN9wTbbpvdT9W3OrJwuRWAuy3yHnPDDyylit0/0bd4PNA+V9sUr
V6BK+mgAAAEIUBehllAXoZYAAAATZWNkc2Etc2hhMi1uaXN0cDUyMQAAAAhuaXN0cDUyMQ
AAAIUEAdt4JF1Gp1yWwoRk8bU1zuDaGo9jd7mIgJwfiLknyFtdqMNzaly6FLWH4Rb42DIw
KBPLjNmsPv88AZgtRMU7B5BSANfCRAWNkx04dIlAMuOtVEJ/pZZXnTRzfcE226b3U/Vtzq
ycLkVgLst8h5zww8spYrdP9G3eDzQPlfbFK1egSvpoAAAAQgGyv0+C8/Sq5hb4cHn3yxnQ
PeFOCqJ1FomMr7/kiopQLF50UlxoPfpTnx6zNKVWQlpUitFgb3UjZsxiFo6bD072QgAAAA
R0ZXN0AQIDBAUG
-----END OPENSSH PRIVATE KEY-----''',
};

void _asymmetricTests(NativeSshCrypto native) {
  final message = Uint8List.fromList(List.generate(48, (i) => i * 7 & 0xff));

  group('x25519', () {
    test('both implementations reach the same secret', () {
      final a = native.x25519KeyPair()!;
      final b = native.x25519KeyPair()!;

      // Native against native, then each side re-derived by the built-in.
      final nativeAb = native.x25519SharedSecret(a.$1, b.$2)!;
      final nativeBa = native.x25519SharedSecret(b.$1, a.$2)!;
      expect(nativeAb, nativeBa);

      // `SSHKexX25519` has no public constructor taking a known keypair, so
      // the built-in side is reached through the same pinenacl call its private
      // wrapper makes.
      final builtinAb = TweetNaCl.crypto_scalarmult(Uint8List(32), a.$1, b.$2);
      expect(builtinAb, nativeAb);
    });

    test('a low-order peer point is refused end to end', () async {
      // The refusal moved into `SSHKexX25519` so that it applies whether or not
      // a backend is installed. What is checked here is that installing one
      // does not route around it — the native side refuses, the seam falls
      // back, and the built-in refuses too.
      for (final backend in [null, native]) {
        sshCryptoBackend = backend;
        final kex = await SSHKexX25519.createAsync();
        expect(
          () => kex.computeSecretAsync(Uint8List(32)),
          throwsA(isA<SSHHandshakeError>()),
          reason: 'backend: ${backend == null ? 'none' : 'native'}',
        );
      }
    });
  });

  group('ed25519', () {
    late SSHKeyPair pair;
    late SSHEd25519PublicKey pub;

    setUp(() {
      sshCryptoBackend = null;
      pair = SSHKeyPair.fromPem(_ed25519Pem).first;
      pub = pair.toPublicKey() as SSHEd25519PublicKey;
    });
    tearDown(() => sshCryptoBackend = null);

    test('signs the same bytes as the built-in', () {
      // Ed25519 is deterministic, so this is a byte comparison rather than a
      // cross-verification.
      final builtin = pair.sign(message) as SSHEd25519Signature;
      sshCryptoBackend = native;
      final fromNative = pair.sign(message) as SSHEd25519Signature;
      expect(fromNative.signature, builtin.signature);
    });

    test('each accepts what the other signed', () {
      final builtin = pair.sign(message) as SSHEd25519Signature;
      expect(pub.verify(message, builtin), isTrue);
      expect(native.ed25519Verify(pub.key, message, builtin.signature), isTrue);

      sshCryptoBackend = native;
      final fromNative = pair.sign(message) as SSHEd25519Signature;
      expect(pub.verify(message, fromNative), isTrue);
      sshCryptoBackend = null;
      expect(pub.verify(message, fromNative), isTrue);
    });

    test('every tampering is refused by both', () {
      final good = pair.sign(message) as SSHEd25519Signature;

      for (var bit = 0; bit < 8; bit++) {
        final index = bit * 8 % good.signature.length;
        final bad = Uint8List.fromList(good.signature)..[index] ^= 1 << (bit % 8);
        expect(
          native.ed25519Verify(pub.key, message, bad),
          isFalse,
          reason: 'native accepted a signature with byte $index flipped',
        );
        sshCryptoBackend = null;
        expect(
          () => pub.verify(message, SSHEd25519Signature(bad)),
          throwsA(anything),
          reason: 'the built-in accepted byte $index flipped',
        );
      }

      // A different message under a valid signature, and a valid signature
      // under a different key.
      final otherMessage = Uint8List.fromList(message)..[0] ^= 1;
      expect(
        native.ed25519Verify(pub.key, otherMessage, good.signature),
        isFalse,
      );
      final otherKey = Uint8List.fromList(pub.key)..[0] ^= 1;
      expect(native.ed25519Verify(otherKey, message, good.signature), isFalse);
    });

    test('malformed input is false, and never an exception', () {
      expect(native.ed25519Verify(Uint8List(31), message, Uint8List(64)), isFalse);
      expect(native.ed25519Verify(Uint8List(32), message, Uint8List(63)), isFalse);
      expect(native.ed25519Verify(Uint8List(0), message, Uint8List(0)), isFalse);
    });
  });

  group('ecdsa', () {
    tearDown(() => sshCryptoBackend = null);

    for (final entry in _ecdsaPems.entries) {
      final curve = entry.key;

      // Cross-verification, not byte comparison: pointycastle's ECDSA is
      // randomised and the native one is RFC 6979 deterministic, so the two
      // never produce the same signature for the same input. What has to hold
      // is that each accepts the other's.
      test('$curve — each accepts what the other signed', () {
        sshCryptoBackend = null;
        final pair = SSHKeyPair.fromPem(entry.value).first;
        final pub = pair.toPublicKey() as SSHEcdsaPublicKey;

        final builtin = pair.sign(_ecdsaMessage) as SSHEcdsaSignature;
        expect(pub.verify(_ecdsaMessage, builtin), isTrue);
        expect(
          native.ecdsaVerify(curve, pub.q, _ecdsaMessage, builtin.r, builtin.s),
          isTrue,
          reason: 'native rejected a signature pointycastle made',
        );

        final fromNative = native.ecdsaSign(curve, _ecdsaD(pair), _ecdsaMessage)!;
        expect(
          pub.verify(
            _ecdsaMessage,
            SSHEcdsaSignature('ecdsa-sha2-$curve', fromNative.$1, fromNative.$2),
          ),
          isTrue,
          reason: 'pointycastle rejected a signature native made',
        );
      });

      test('$curve — tampering is refused by both', () {
        sshCryptoBackend = null;
        final pair = SSHKeyPair.fromPem(entry.value).first;
        final pub = pair.toPublicKey() as SSHEcdsaPublicKey;
        final good = pair.sign(_ecdsaMessage) as SSHEcdsaSignature;

        for (final bad in [
          SSHEcdsaSignature('ecdsa-sha2-$curve', good.r + BigInt.one, good.s),
          SSHEcdsaSignature('ecdsa-sha2-$curve', good.r, good.s + BigInt.one),
          SSHEcdsaSignature('ecdsa-sha2-$curve', good.s, good.r),
        ]) {
          expect(pub.verify(_ecdsaMessage, bad), isFalse);
          expect(
            native.ecdsaVerify(curve, pub.q, _ecdsaMessage, bad.r, bad.s),
            isFalse,
          );
        }

        final other = Uint8List.fromList(_ecdsaMessage)..[0] ^= 1;
        expect(pub.verify(other, good), isFalse);
        expect(
          native.ecdsaVerify(curve, pub.q, other, good.r, good.s),
          isFalse,
        );
      });

      test('$curve — signing through the seam verifies unchanged', () {
        // The path a real connection takes: the backend installed, and the
        // result checked by the implementation it replaced.
        final pair = SSHKeyPair.fromPem(entry.value).first;
        final pub = pair.toPublicKey() as SSHEcdsaPublicKey;
        sshCryptoBackend = native;
        final sig = pair.sign(_ecdsaMessage) as SSHEcdsaSignature;
        sshCryptoBackend = null;
        expect(pub.verify(_ecdsaMessage, sig), isTrue);
      });
    }

    test('a curve the backend does not implement falls back', () {
      expect(native.ecdsaSign('nistp192', BigInt.one, _ecdsaMessage), isNull);
      expect(
        native.ecdsaVerify(
          'nistp192',
          Uint8List(0),
          _ecdsaMessage,
          BigInt.one,
          BigInt.one,
        ),
        isNull,
      );
    });
  });

  group('bcrypt_pbkdf', () {
    tearDown(() => sshCryptoBackend = null);

    test('derives what the built-in derives', () {
      final pass = Uint8List.fromList('hunter2'.codeUnits);
      final salt = Uint8List.fromList(List.generate(16, (i) => i * 11 & 0xff));

      final builtin = Uint8List(48);
      builtin_bcrypt.bcrypt_pbkdf(
        pass,
        pass.length,
        salt,
        salt.length,
        builtin,
        builtin.length,
        16,
      );

      expect(native.bcryptPbkdf(pass, salt, 16, 48), builtin);
    });

    test('opens a key the built-in opens', () {
      sshCryptoBackend = native;
      final viaNative = SSHKeyPair.fromPem(_ed25519EncPem, 'hunter2').first;
      sshCryptoBackend = null;
      final viaBuiltin = SSHKeyPair.fromPem(_ed25519EncPem, 'hunter2').first;

      // Not `toPem()`: it writes a random check integer, so two encodings of
      // one key differ. The public half and a signature over a fixed message
      // are what identify the private key that came out.
      expect(viaNative.toPublicKey().encode(), viaBuiltin.toPublicKey().encode());
      expect(
        (viaNative.sign(_ecdsaMessage) as SSHEd25519Signature).signature,
        (viaBuiltin.sign(_ecdsaMessage) as SSHEd25519Signature).signature,
      );
    });

    test('a wrong passphrase still fails with the backend installed', () {
      sshCryptoBackend = native;
      expect(
        () => SSHKeyPair.fromPem(_ed25519EncPem, 'wrong'),
        throwsA(isA<SSHKeyDecryptError>()),
      );
    });
  });
}


final _ecdsaMessage = Uint8List.fromList(List.generate(64, (i) => i * 3 & 0xff));

/// The private scalar out of a parsed ECDSA key pair. The field is public on
/// `OpenSSHEcdsaKeyPair` but that type is not exported, so this reaches it
/// dynamically rather than importing half of `ssh_key_pair.dart`.
BigInt _ecdsaD(SSHKeyPair pair) => (pair as dynamic).d as BigInt;
