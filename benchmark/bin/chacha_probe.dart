/// Minimal reproduction for `chacha20-poly1305@openssh.com`, kept separate
/// from the throughput run so a hang or a handshake failure is visible on its
/// own with a short timeout and full transport tracing.
///
/// Run: dart run bin/chacha_probe.dart [--trace]
library;

import 'dart:async';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

Future<void> main(List<String> args) async {
  final trace = args.contains('--trace');
  final env = <String, String>{
    ..._readDotEnv('.env'),
    ...Platform.environment,
  };

  final host = env['SBM_BENCH_HOST'];
  final user = env['SBM_BENCH_USER'];
  final key = env['SBM_BENCH_KEY'];
  if (host == null || user == null) {
    print('SBM_BENCH_HOST / _USER not set — run tool/bench_target.sh up first.');
    exit(0);
  }
  final port = int.tryParse(env['SBM_BENCH_PORT'] ?? '') ?? 22;

  for (final cipher in [
    SSHCipherType.chacha20poly1305,
    SSHCipherType.aes256ctr,
  ]) {
    stdout.write('${cipher.name.padRight(32)} ');
    try {
      final out = await _probe(
        host: host,
        port: port,
        user: user,
        keyPath: key,
        cipher: cipher,
        trace: trace,
      ).timeout(const Duration(seconds: 20));
      print('ok — remote said: $out');
    } on TimeoutException {
      print('HUNG (no result in 20s)');
    } catch (e) {
      print('FAILED — $e');
    }
  }
  exit(0);
}

Future<String> _probe({
  required String host,
  required int port,
  required String user,
  required String? keyPath,
  required SSHCipherType cipher,
  required bool trace,
}) async {
  final socket = await SSHSocket.connect(host, port,
      timeout: const Duration(seconds: 10));
  final client = SSHClient(
    socket,
    username: user,
    algorithms: SSHAlgorithms(cipher: [cipher]),
    identities: keyPath == null
        ? null
        : SSHKeyPair.fromPem(File(keyPath).readAsStringSync()),
    onVerifyHostKey: (type, fingerprint) => true,
    printDebug: trace ? (m) => print('  [debug] $m') : null,
  );
  try {
    await client.authenticated;
    // A payload big enough to span many packets, so a body-alignment or
    // counter bug shows up as corruption rather than passing on a short one.
    final result = await client.run('dd if=/dev/zero bs=1k count=256 2>/dev/null | wc -c');
    return String.fromCharCodes(result).trim();
  } finally {
    client.close();
  }
}

Map<String, String> _readDotEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return const {};
  final out = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final idx = trimmed.indexOf('=');
    if (idx <= 0) continue;
    out[trimmed.substring(0, idx).trim()] = trimmed.substring(idx + 1).trim();
  }
  return out;
}
