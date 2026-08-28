import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:pointycastle/api.dart';
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
final class NativeSshCrypto implements SSHCryptoBackend {
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
