import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:pointycastle/api.dart';
import 'package:server_box/src/rust/api/ssh_asym.dart' as asym;
import 'package:server_box/src/rust/api/ssh_crypto.dart' as rust;

/// dartssh2's record cipher and MAC, computed by `sbm_ffi` instead of
/// pointycastle.
///
/// Installed once, at launch, right after `RustLib.init`. It changes nothing
/// about the protocol: the same algorithms are proposed, the same one is
/// negotiated, and an algorithm this does not implement — AES-GCM and
/// ChaCha20-Poly1305, which the transport computes inline rather than through
/// these factories — still goes through pointycastle. What changes is that
/// AES and SHA-2 stop being Dart running on the isolate that draws frames.
///
/// Only the main isolate installs it. The file-transfer worker is an isolate of
/// its own and would need its own `RustLib.init`, but it is also not the
/// isolate anyone is looking at, so pointycastle there costs nothing worth the
/// wiring.
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

  /// Unlike the rest, a failure here is **not** swallowed.
  ///
  /// The one thing this refuses is a low-order peer point, which is not "the
  /// library could not do it" but a peer forcing a secret both sides would
  /// share with it. Answering `null` would fall back to the built-in, which
  /// does not check, and complete the exchange anyway.
  @override
  Uint8List? x25519SharedSecret(Uint8List privateKey, Uint8List peerPublicKey) {
    return asym.x25519SharedSecret(
      privateKey: privateKey,
      peerPublicKey: peerPublicKey,
    );
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
Uint8List _fixedWidth(BigInt v, int width) {
  final out = Uint8List(width);
  var x = v;
  for (var i = width - 1; i >= 0 && x > BigInt.zero; i--) {
    out[i] = (x & BigInt.from(0xff)).toInt();
    x = x >> 8;
  }
  if (x > BigInt.zero) {
    throw ArgumentError.value(v, 'v', 'does not fit in $width bytes');
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

  @override
  Uint8List process(Uint8List data) => _cipher.process(data: data);

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
