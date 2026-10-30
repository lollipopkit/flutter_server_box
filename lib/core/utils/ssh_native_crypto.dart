import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:pointycastle/api.dart';
import 'package:server_box/src/rust/api/ssh_asym.dart' as asym;
import 'package:server_box/src/rust/api/ssh_crypto.dart' as rust;
import 'package:server_box/src/rust/frb_generated.dart';

/// dartssh2's record cipher and MAC, computed by `sbm_ffi` instead of
/// pointycastle.
///
/// Installed once, at launch, right after `RustLib.init`. It changes nothing
/// about the protocol: the same algorithms are proposed, the same one is
/// negotiated, and an algorithm this does not implement — ChaCha20-Poly1305 —
/// still goes through pointycastle. What changes is that AES and SHA-2 stop
/// being Dart running on the isolate that draws frames, and that AES-GCM stops
/// being 1.9 MiB/s: pointycastle's GHASH is a bit at a time, where Rust's is
/// the CPU's carry-less multiply (lollipopkit/dartssh2#19).
///
/// The file-transfer worker installs it too, with a `RustLib.init` of its own
/// — see [installNativeSshCrypto]: it draws nothing, but a transfer over
/// AES-GCM is where pointycastle's speed is felt.
///
/// Every failure here answers `null`, which dartssh2 reads as "use
/// pointycastle". That is the honest answer for an algorithm this does not
/// implement, and the safe one for a library that would not load: a connection
/// that is slower than it could be beats one that cannot be opened.
final class NativeSshCrypto extends SSHCryptoBackend {
  const NativeSshCrypto();

  /// Names already reported, so a refusal is logged once rather than per
  /// connection. A status poll would otherwise write the same line every cycle.
  static final _reported = <String>{};

  static void _reportOnce(String algorithm, Object e) {
    if (!_reported.add(algorithm)) return;
    Loggers.app.info('No native SSH crypto for $algorithm, using pointycastle: $e');
  }

  @override
  BlockCipher? createBlockCipher(
    String algorithm,
    Uint8List key,
    Uint8List iv, {
    required bool forEncryption,
  }) {
    try {
      return _NativeBlockCipher(
        algorithm,
        rust.SshBlockCipher(
          algorithm: algorithm,
          key: key,
          iv: iv,
          forEncryption: forEncryption,
        ),
      );
    } catch (e) {
      _reportOnce(algorithm, e);
      return null;
    }
  }

  @override
  SSHAeadCipher? createAead(String algorithm, Uint8List key) {
    try {
      return _NativeAead(rust.SshAead(algorithm: algorithm, key: key));
    } catch (e) {
      _reportOnce(algorithm, e);
      return null;
    }
  }

  @override
  Mac? createMac(String algorithm, Uint8List key, int macSize) {
    try {
      return _NativeMac(
        algorithm,
        rust.SshMac(algorithm: algorithm, key: key, macSize: macSize),
      );
    } catch (e) {
      _reportOnce(algorithm, e);
      return null;
    }
  }

  @override
  (Uint8List, Uint8List)? x25519KeyPair() {
    try {
      final pair = asym.x25519Keypair();
      return (pair.privateKey, pair.publicKey);
    } catch (e) {
      _reportOnce('x25519', e);
      return null;
    }
  }

  /// Falls back like the rest, which it could not do until dartssh2 refused a
  /// low-order peer point itself.
  ///
  /// While this was the only place that checked, answering `null` here would
  /// have fallen through to an implementation that did not — so a failure of
  /// any kind had to take the connection down rather than risk completing an
  /// exchange on a secret the peer chose. `SSHKexX25519._secretFrom` now
  /// refuses an all-zero secret on every path, so a library that will not load
  /// is once again just a slower connection.
  @override
  Uint8List? x25519SharedSecret(Uint8List privateKey, Uint8List peerPublicKey) {
    try {
      return asym.x25519SharedSecret(
        privateKey: privateKey,
        peerPublicKey: peerPublicKey,
      );
    } catch (e) {
      _reportOnce('x25519 shared secret', e);
      return null;
    }
  }

  @override
  Uint8List? ed25519Sign(Uint8List privateKey, Uint8List message) {
    try {
      return asym.ed25519Sign(privateKey: privateKey, message: message);
    } catch (e) {
      _reportOnce('ed25519 sign', e);
      return null;
    }
  }

  @override
  bool? ed25519Verify(
    Uint8List publicKey,
    Uint8List message,
    Uint8List signature,
  ) {
    try {
      return asym.ed25519Verify(
        publicKey: publicKey,
        message: message,
        signature: signature,
      );
    } catch (e) {
      // `null`, never `false`: a library that would not load is not a
      // signature that failed, and the caller has to be able to tell.
      _reportOnce('ed25519 verify', e);
      return null;
    }
  }

  @override
  (BigInt, BigInt)? ecdsaSign(String curveId, BigInt d, Uint8List message) {
    final width = _curveWidth(curveId);
    if (width == null) return null;
    try {
      final sig = asym.ecdsaSign(
        curve: curveId,
        privateKey: _fixedWidth(d, width),
        message: message,
      );
      return (_toBigInt(sig.r), _toBigInt(sig.s));
    } catch (e) {
      _reportOnce('ecdsa sign $curveId', e);
      return null;
    }
  }

  @override
  bool? ecdsaVerify(
    String curveId,
    Uint8List q,
    Uint8List message,
    BigInt r,
    BigInt s,
  ) {
    final width = _curveWidth(curveId);
    if (width == null) return null;
    try {
      return asym.ecdsaVerify(
        curve: curveId,
        publicKey: q,
        message: message,
        r: _fixedWidth(r, width),
        s: _fixedWidth(s, width),
      );
    } catch (e) {
      _reportOnce('ecdsa verify $curveId', e);
      return null;
    }
  }

  @override
  Uint8List? bcryptPbkdf(
    Uint8List passphrase,
    Uint8List salt,
    int rounds,
    int outputLength,
  ) {
    try {
      return asym.bcryptPbkdf(
        passphrase: passphrase,
        salt: salt,
        rounds: rounds,
        outputLen: outputLength,
      );
    } catch (e) {
      _reportOnce('bcrypt_pbkdf', e);
      return null;
    }
  }
}

/// Field width in bytes for an SSH curve name, or null for one this does not
/// implement — which the caller passes on as "use pointycastle".
int? _curveWidth(String curveId) => switch (curveId) {
  'nistp256' => 32,
  'nistp384' => 48,
  // 521 bits is 65.125 bytes, and SEC1 rounds up.
  'nistp521' => 66,
  _ => null,
};

/// [v] as exactly [width] big-endian bytes.
///
/// SSH carries `r`, `s` and the private scalar as mpints, so a value with
/// leading zeroes is shorter than the field and one that needed a sign byte is
/// longer. The native side takes the field width, so the conversion happens
/// here rather than being guessed at either end.
///
/// Neither failure names [v]. For `ecdsaSign` it is the private scalar, and the
/// caller puts the error it catches into a log line.
Uint8List _fixedWidth(BigInt v, int width) {
  // Silently wrong without this: the loop below does nothing for a negative
  // value and the overflow check after it does not fire either, so a negative
  // `r` off the wire became a run of zero bytes.
  if (v.isNegative) {
    throw ArgumentError('a negative value has no fixed-width encoding');
  }
  final out = Uint8List(width);
  var x = v;
  for (var i = width - 1; i >= 0 && x > BigInt.zero; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  if (x > BigInt.zero) {
    throw ArgumentError('does not fit in $width bytes');
  }
  return out;
}

/// Big-endian bytes as a non-negative [BigInt].
BigInt _toBigInt(Uint8List bytes) {
  var v = BigInt.zero;
  for (final b in bytes) {
    v = (v << 8) | BigInt.from(b);
  }
  return v;
}

/// One direction of one connection's record cipher.
///
/// [init] and [reset] throw rather than doing nothing. The key and IV are given
/// at construction and the counter or chaining block is a position in a stream
/// that only moves forward, so there is no state to re-establish from here —
/// and a cipher that silently ignored a reset would encrypt the rest of the
/// session under a keystream the peer is not at, which shows up as a corrupt
/// packet with nothing naming the cause. dartssh2 calls neither.
final class _NativeBlockCipher implements SSHBulkBlockCipher {
  _NativeBlockCipher(this.algorithmName, this._cipher)
    : blockSize = _cipher.blockSize();

  @override
  final String algorithmName;

  @override
  final int blockSize;

  final rust.SshBlockCipher _cipher;

  @override
  Uint8List processBulk(Uint8List data) => _cipher.process(data: data);

  /// One block, which is what pointycastle's `BlockCipher.process` is: it
  /// consumes `blockSize` bytes and ignores the rest. Passing the whole input
  /// through would advance the cipher further than the caller asked and give a
  /// different answer from the implementation this replaces.
  @override
  Uint8List process(Uint8List data) =>
      _cipher.process(data: Uint8List.sublistView(data, 0, blockSize));

  @override
  int processBlock(Uint8List inp, int inpOff, Uint8List out, int outOff) {
    final block = Uint8List.sublistView(inp, inpOff, inpOff + blockSize);
    out.setRange(outOff, outOff + blockSize, _cipher.process(data: block));
    return blockSize;
  }

  @override
  void init(bool forEncryption, CipherParameters? params) {
    throw StateError('$algorithmName is keyed when it is created');
  }

  @override
  void reset() {
    throw StateError('$algorithmName cannot rewind its keystream');
  }
}

/// One direction of one connection's packet MAC.
///
/// dartssh2 feeds a packet in several pieces — the sequence number, then the
/// length, then the body — so the pieces are joined here and handed over once.
/// The alternative is a crossing per piece, for a tag over a few dozen bytes.
///
/// [doFinal] leaves this ready for the next packet, which is what pointycastle
/// does and what the transport relies on: it keeps one MAC per direction for
/// the life of the connection.
final class _NativeMac implements Mac {
  _NativeMac(this.algorithmName, this._mac) : macSize = _mac.macSize();

  @override
  final String algorithmName;

  @override
  final int macSize;

  final rust.SshMac _mac;
  final _input = BytesBuilder(copy: true);

  @override
  void init(CipherParameters params) {
    throw StateError('$algorithmName is keyed when it is created');
  }

  @override
  void update(Uint8List inp, int inpOff, int len) {
    _input.add(Uint8List.sublistView(inp, inpOff, inpOff + len));
  }

  @override
  void updateByte(int inp) => _input.addByte(inp);

  @override
  int doFinal(Uint8List out, int outOff) {
    final tag = _mac.compute(data: _input.takeBytes());
    out.setRange(outOff, outOff + macSize, tag);
    return macSize;
  }

  /// [update] then [doFinal], which is what pointycastle's own `process` is —
  /// it appends to whatever is pending rather than starting from nothing.
  @override
  Uint8List process(Uint8List data) {
    _input.add(data);
    return _mac.compute(data: _input.takeBytes());
  }

  @override
  void reset() => _input.clear();
}

/// [rust.SshAead], one call per packet each way.
final class _NativeAead implements SSHAeadCipher {
  _NativeAead(this._aead);

  final rust.SshAead _aead;

  /// Left to throw: a packet that could not be sealed must not be sent.
  @override
  Uint8List seal(Uint8List nonce, Uint8List aad, Uint8List plaintext) =>
      _aead.seal(nonce: nonce, aad: aad, plaintext: plaintext);

  /// A packet that could not be opened is one that does not authenticate,
  /// whatever the reason: dartssh2 ends the connection on that, as it does
  /// for a tag that does not match, rather than on an error it has no name for.
  @override
  Uint8List? open(Uint8List nonce, Uint8List aad, Uint8List sealed) {
    try {
      return _aead.open(nonce: nonce, aad: aad, sealed: sealed);
    } catch (e) {
      NativeSshCrypto._reportOnce('aead open', e);
      return null;
    }
  }
}

/// [NativeSshCrypto] on an isolate other than the main one, which has no
/// `RustLib.init` of its own; once, however many times it is called. A
/// library that will not load leaves pointycastle, as it does on the main
/// isolate, and says so.
Future<void>? _installed;

Future<void> installNativeSshCrypto({ExternalLibrary? library}) =>
    _installed ??= () async {
      try {
        if (!RustLib.instance.initialized) {
          await RustLib.init(externalLibrary: library);
        }
        sshCryptoBackend = const NativeSshCrypto();
      } catch (e, s) {
        Loggers.app.warning('No native SSH crypto on this isolate', e, s);
      }
    }();
