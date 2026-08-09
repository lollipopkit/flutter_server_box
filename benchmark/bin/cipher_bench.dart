/// Layer 1 of the SSH throughput investigation: raw symmetric-crypto cost,
/// no network involved.
///
/// Every case mirrors how `SSHTransport` actually drives the cipher, because
/// the way it is driven turns out to matter more than which cipher it is:
///
///   - Non-AEAD (`aes*-ctr`, `aes*-cbc`) go through `BlockCipherX.processAll`
///     in `packages/dartssh2/lib/src/utils/cipher_ext.dart`, which loops
///     `processBlock` once per **16-byte block** — 2048 virtual calls for one
///     32 KiB packet. The `bulk` variant below is the same cipher driven via
///     `CTRStreamCipher.processBytes` instead, so the difference between the
///     two is purely per-block dispatch overhead.
///   - CTR state is continuous across packets in SSH, so it is initialised
///     once. AEAD modes re-key per packet (new nonce), so they are
///     re-initialised per chunk — that init cost is part of their real price.
///   - Non-AEAD packets additionally pay an HMAC over the whole packet, which
///     is why `ctr + hmac` is measured as its own case.
///
/// Run: dart run bin/cipher_bench.dart [--mib=64] [--packet=32768]
library;

import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:pointycastle/export.dart';

/// Matches `_maximumPacketSize` in `packages/dartssh2/lib/src/ssh_client.dart`.
const _defaultPacketSize = 32768;

/// Cap per case so a pathologically slow path does not stall the whole run.
const _maxDuration = Duration(seconds: 5);

void main(List<String> args) {
  final targetMib = _intArg(args, '--mib') ?? 64;
  final packetSize = _intArg(args, '--packet') ?? _defaultPacketSize;
  final targetBytes = targetMib * 1024 * 1024;

  stdout('SSH symmetric-crypto throughput (pointycastle, pure Dart)');
  stdout('packet=$packetSize B  target=$targetMib MiB  cap=${_maxDuration.inSeconds}s');
  stdout('');

  final results = <_Result>[
    _benchCtrProcessAll(targetBytes, packetSize),
    _benchCtrBulk(targetBytes, packetSize),
    _benchHmacSha256(targetBytes, packetSize),
    _benchCtrPlusHmac(targetBytes, packetSize),
    _benchAesGcm(targetBytes, packetSize),
    _benchChaCha20Poly1305(targetBytes, packetSize),
  ];

  _report(results);
}

// ---------------------------------------------------------------------------
// Cases
// ---------------------------------------------------------------------------

/// The path dartssh2 uses today for `aes256-ctr`.
_Result _benchCtrProcessAll(int targetBytes, int packetSize) {
  final cipher = SSHCipherType.aes256ctr.createCipher(
    _bytes(32),
    _bytes(SSHCipherType.aes256ctr.ivSize),
    forEncryption: true,
  );
  final input = _bytes(packetSize);
  final output = Uint8List(packetSize);
  final blockSize = cipher.blockSize;

  return _run('aes256-ctr (processAll, per-block — current)', targetBytes,
      packetSize, () {
    for (var offset = 0; offset < packetSize; offset += blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }
  });
}

/// Same cipher, driven in bulk. The delta against the case above is the cost
/// of per-block dispatch alone.
_Result _benchCtrBulk(int targetBytes, int packetSize) {
  final cipher = CTRStreamCipher(AESEngine())
    ..init(true, ParametersWithIV(KeyParameter(_bytes(32)), _bytes(16)));
  final input = _bytes(packetSize);
  final output = Uint8List(packetSize);

  return _run('aes256-ctr (processBytes, bulk)', targetBytes, packetSize, () {
    cipher.processBytes(input, 0, packetSize, output, 0);
  });
}

/// Non-AEAD packets pay this on top of the cipher.
_Result _benchHmacSha256(int targetBytes, int packetSize) {
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(_bytes(32)));
  final input = _bytes(packetSize);
  final out = Uint8List(mac.macSize);
  final seq = Uint8List(4);

  return _run('hmac-sha2-256 (mac only)', targetBytes, packetSize, () {
    mac.update(seq, 0, 4);
    mac.update(input, 0, packetSize);
    mac.doFinal(out, 0);
  });
}

/// What a full `aes256-ctr` + `hmac-sha2-256` packet actually costs.
_Result _benchCtrPlusHmac(int targetBytes, int packetSize) {
  final cipher = SSHCipherType.aes256ctr.createCipher(
    _bytes(32),
    _bytes(SSHCipherType.aes256ctr.ivSize),
    forEncryption: true,
  );
  final mac = HMac(SHA256Digest(), 64)..init(KeyParameter(_bytes(32)));
  final input = _bytes(packetSize);
  final output = Uint8List(packetSize);
  final macOut = Uint8List(mac.macSize);
  final seq = Uint8List(4);
  final blockSize = cipher.blockSize;

  return _run('aes256-ctr + hmac-sha2-256 (full packet)', targetBytes,
      packetSize, () {
    for (var offset = 0; offset < packetSize; offset += blockSize) {
      cipher.processBlock(input, offset, output, offset);
    }
    mac.update(seq, 0, 4);
    mac.update(output, 0, packetSize);
    mac.doFinal(macOut, 0);
  });
}

/// AEAD: re-initialised per packet, as SSH requires a fresh nonce each time.
_Result _benchAesGcm(int targetBytes, int packetSize) {
  final key = KeyParameter(_bytes(32));
  final nonce = _bytes(12);
  final input = _bytes(packetSize);
  final cipher = GCMBlockCipher(AESEngine());

  return _run('aes256-gcm@openssh.com', targetBytes, packetSize, () {
    cipher.init(true, AEADParameters(key, 128, nonce, Uint8List(0)));
    cipher.process(input);
  });
}

/// Mirrors `_encryptChaChaOpenSSH` in `ssh_transport.dart`: a ChaCha20 pass
/// over the payload plus a Poly1305 tag, re-keyed per packet.
_Result _benchChaCha20Poly1305(int targetBytes, int packetSize) {
  final key = KeyParameter(_bytes(32));
  final nonce = _bytes(12);
  final input = _bytes(packetSize);
  final output = Uint8List(packetSize);
  final engine = ChaCha7539Engine();
  final poly = Poly1305();
  final polyKey = KeyParameter(_bytes(32));
  final tag = Uint8List(16);

  return _run('chacha20-poly1305@openssh.com', targetBytes, packetSize, () {
    engine.init(true, ParametersWithIV(key, nonce));
    engine.processBytes(input, 0, packetSize, output, 0);
    poly.init(polyKey);
    poly.update(output, 0, packetSize);
    poly.doFinal(tag, 0);
  });
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

class _Result {
  _Result(this.name, this.bytes, this.elapsed);

  final String name;
  final int bytes;
  final Duration elapsed;

  double get mibPerSecond =>
      bytes / 1024 / 1024 / (elapsed.inMicroseconds / 1000000);
}

_Result _run(String name, int targetBytes, int packetSize, void Function() op) {
  // Warm up the JIT before measuring.
  for (var i = 0; i < 8; i++) {
    op();
  }

  var processed = 0;
  final sw = Stopwatch()..start();
  while (processed < targetBytes && sw.elapsed < _maxDuration) {
    op();
    processed += packetSize;
  }
  sw.stop();

  final result = _Result(name, processed, sw.elapsed);
  stdout('  ${name.padRight(42)} ${result.mibPerSecond.toStringAsFixed(1).padLeft(8)} MiB/s'
      '   (${(processed / 1024 / 1024).toStringAsFixed(0)} MiB in ${sw.elapsed.inMilliseconds} ms)');
  return result;
}

void _report(List<_Result> results) {
  stdout('');
  final perBlock = results[0];
  final bulk = results[1];
  final ratio = bulk.mibPerSecond / perBlock.mibPerSecond;
  stdout('processAll (per-block) vs processBytes (bulk): '
      '${ratio.toStringAsFixed(2)}x');
  stdout(ratio > 1.15
      ? '  → that gap is per-block dispatch overhead in cipher_ext.dart, '
          'recoverable without changing library.'
      : '  → no meaningful difference, so per-block dispatch is not a cost '
          'here despite how cipher_ext.dart reads.');

  final fastest =
      results.reduce((a, b) => a.mibPerSecond > b.mibPerSecond ? a : b);
  final slowest =
      results.reduce((a, b) => a.mibPerSecond < b.mibPerSecond ? a : b);
  stdout('');
  stdout('Fastest: ${fastest.name} '
      '(${fastest.mibPerSecond.toStringAsFixed(1)} MiB/s)');
  stdout('Slowest: ${slowest.name} '
      '(${slowest.mibPerSecond.toStringAsFixed(1)} MiB/s)');
  stdout('A cipher far below the others caps the whole connection whenever it '
      'is negotiated — cross-check with layers 2/3 in bin/ssh_bench.dart.');
}

Uint8List _bytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (i) => (i * 31 + 7) & 0xff));

int? _intArg(List<String> args, String name) {
  for (final arg in args) {
    if (arg.startsWith('$name=')) {
      return int.tryParse(arg.substring(name.length + 1));
    }
  }
  return null;
}

void stdout(String line) => print(line);
