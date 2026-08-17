/// Layers 2 and 3 of the SSH throughput investigation, against a real host.
///
/// Layer 1 (`bin/cipher_bench.dart`) measures crypto in isolation. This one
/// separates the two things stacked on top of it:
///
///   - **Layer 2 — SSH transport.** `dd if=/dev/zero` on the remote, read via
///     an exec channel. Exercises packet framing, cipher, MAC and channel
///     windowing, with no SFTP involved.
///   - **Layer 3 — SFTP.** Same bytes moved through the SFTP protocol, using
///     the exact chunk size and in-flight limit the app uses
///     (`lib/data/model/sftp/worker.dart`).
///
/// Each is compared against the system `ssh`/`scp` doing the same work over
/// the same cipher, which is the "native SSH" reference point.
///
/// Reading the result:
///   L1 fast, L2 slow            → transport layer (framing, allocation, window)
///   L1 and L2 fast, L3 slow     → SFTP protocol layer (chunking, pipelining)
///   all three slow              → crypto
///
/// Configuration — environment, or a `.env` beside this file or at the repo
/// root. Skipped entirely when unset. Credentials are never printed.
///   SBM_BENCH_HOST      host or IP
///   SBM_BENCH_PORT      default 22
///   SBM_BENCH_USER      login user
///   SBM_BENCH_KEY       path to a private key (PEM), optional
///   SBM_BENCH_PASSWORD  password, optional (used if no key)
///   SBM_BENCH_SSH_DEST  destination for the system-ssh baseline,
///                       default "$USER@$HOST"
///   SBM_BENCH_MIB       payload size, default 64
///
/// Run: dart run bin/ssh_bench.dart
library;

// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

/// Mirrors `_sftpChunkSize` in `lib/data/model/sftp/worker.dart`.
const _appSftpChunkSize = 32 * 1024;

/// Mirrors `_sftpUploadMaxBytesOnTheWire` (chunk * 64) in the same file.
const _appUploadMaxPendingWrites = 64;

/// The ciphers worth comparing: the app's negotiated default, the AEAD
/// alternative, and the one layer 1 flagged as pathologically slow.
const _ciphers = <SSHCipherType>[
  SSHCipherType.aes256ctr,
  SSHCipherType.chacha20poly1305,
  SSHCipherType.aes256gcm,
];

late final _Config _cfg;

Future<void> main(List<String> args) async {
  final cfg = _Config.load();
  if (cfg == null) {
    print('SBM_BENCH_HOST / _USER not set — skipping.');
    print('See the doc comment at the top of this file for configuration.');
    exit(0);
  }
  _cfg = cfg;

  print('SSH throughput vs system ssh/scp');
  print('host=${cfg.host}:${cfg.port}  payload=${cfg.mib} MiB  '
      'auth=${cfg.keyPath != null ? 'key' : 'password'}');
  print('');

  final remotePath = '/tmp/sbm_bench_${cfg.mib}mib.bin';
  final rows = <_Row>[];

  try {
    print('Layer 2 — SSH transport (exec + dd, no SFTP)');
    rows.add(await _safe('L2 dartssh2 exec', null, () => _benchExec(null)));
    for (final cipher in _ciphers) {
      rows.add(await _safe(
          'L2 dartssh2 exec', cipher, () => _benchExec(cipher)));
    }
    for (final cipher in _ciphers) {
      rows.add(await _safe(
          'L2 system ssh', cipher, () => _baselineExec(cipher)));
    }

    print('');
    print('Layer 3 — SFTP (chunk=$_appSftpChunkSize B, '
        'maxPending=$_appUploadMaxPendingWrites — same as the app)');
    await _createRemoteFile(remotePath);
    rows.add(await _safe('L3 dartssh2 SFTP get', null,
        () => _benchSftpDownload(null, remotePath)));
    for (final cipher in _ciphers) {
      rows.add(await _safe('L3 dartssh2 SFTP get', cipher,
          () => _benchSftpDownload(cipher, remotePath)));
    }
    rows.add(await _safe('L3 dartssh2 SFTP put', SSHCipherType.aes256ctr,
        () => _benchSftpUpload(SSHCipherType.aes256ctr)));
    rows.add(await _safe('L3 system scp', SSHCipherType.aes256ctr,
        () => _baselineScpDownload(remotePath)));
  } finally {
    await _cleanup(remotePath);
  }

  _summary(rows);
}

// ---------------------------------------------------------------------------
// Layer 2 — exec channel
// ---------------------------------------------------------------------------

/// [cipher] null runs the case that matters most: no forced cipher, so the
/// app's real `SSHAlgorithms` defaults negotiate against whatever the server
/// offers. On a server that still allows CTR this lands on `aes256-ctr`; on an
/// AEAD-only server it has to fall back to something else.
Future<_Row> _benchExec(SSHCipherType? cipher) async {
  final client = await _connect(cipher);
  try {
    final sw = Stopwatch()..start();
    final session = await client.execute(_ddCommand());
    var bytes = 0;
    await for (final chunk in session.stdout) {
      bytes += chunk.length;
    }
    await session.done;
    sw.stop();
    return _row('L2 dartssh2 exec', _label(cipher), bytes, sw.elapsed);
  } finally {
    client.close();
  }
}

Future<_Row> _baselineExec(SSHCipherType cipher) async {
  final sw = Stopwatch()..start();
  final result = await Process.run('sh', [
    '-c',
    '${_systemSshCommand(cipher)} ${_shellQuote(_ddCommand())} | wc -c',
  ]);
  sw.stop();
  if (result.exitCode != 0) {
    return _row('L2 system ssh', cipher.name, 0, sw.elapsed,
        note: 'failed: ${_firstLine(result.stderr)}');
  }
  final bytes = int.tryParse((result.stdout as String).trim()) ?? 0;
  return _row('L2 system ssh', cipher.name, bytes, sw.elapsed);
}

// ---------------------------------------------------------------------------
// Layer 3 — SFTP
// ---------------------------------------------------------------------------

Future<_Row> _benchSftpDownload(SSHCipherType? cipher, String remotePath) async {
  final client = await _connect(cipher);
  try {
    final sftp = await client.sftp();
    final sw = Stopwatch()..start();
    final file = await sftp.open(remotePath);
    var bytes = 0;
    await for (final chunk in file.read(chunkSize: _appSftpChunkSize)) {
      bytes += chunk.length;
    }
    await file.close();
    sw.stop();
    return _row('L3 dartssh2 SFTP get', _label(cipher), bytes, sw.elapsed);
  } finally {
    client.close();
  }
}

Future<_Row> _benchSftpUpload(SSHCipherType cipher) async {
  final uploadPath = '/tmp/sbm_bench_upload.bin';
  final payload = Uint8List(_cfg.mib * 1024 * 1024);
  final client = await _connect(cipher);
  try {
    final sftp = await client.sftp();
    final sw = Stopwatch()..start();
    final file = await sftp.open(
      uploadPath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.truncate |
          SftpFileOpenMode.write,
    );
    await file.writeBytes(
      payload,
      chunkSize: _appSftpChunkSize,
      maxPendingWrites: _appUploadMaxPendingWrites,
    );
    await file.close();
    sw.stop();
    return _row('L3 dartssh2 SFTP put', cipher.name, payload.length, sw.elapsed);
  } finally {
    client.close();
  }
}

Future<_Row> _baselineScpDownload(String remotePath) async {
  final tmp = await Directory.systemTemp.createTemp('sbm_bench');
  final local = '${tmp.path}/dl.bin';
  try {
    final sw = Stopwatch()..start();
    final result = await Process.run('scp', [
      '-P', '${_cfg.port}',
      if (_cfg.keyPath != null) ...['-i', _cfg.keyPath!],
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'UserKnownHostsFile=/dev/null',
      '-c', SSHCipherType.aes256ctr.name,
      '${_cfg.sshDest}:$remotePath',
      local,
    ]);
    sw.stop();
    if (result.exitCode != 0) {
      return _row('L3 system scp', SSHCipherType.aes256ctr.name, 0, sw.elapsed,
          note: 'failed: ${_firstLine(result.stderr)}');
    }
    final bytes = await File(local).length();
    return _row('L3 system scp', SSHCipherType.aes256ctr.name, bytes,
        sw.elapsed);
  } finally {
    await tmp.delete(recursive: true);
  }
}

// ---------------------------------------------------------------------------
// Remote helpers
// ---------------------------------------------------------------------------

String _ddCommand() =>
    'dd if=/dev/zero bs=1M count=${_cfg.mib} 2>/dev/null';

Future<void> _createRemoteFile(String path) async {
  final client = await _connect(null);
  try {
    await client.run('${_ddCommand()} > $path');
  } finally {
    client.close();
  }
}

Future<void> _cleanup(String remotePath) async {
  try {
    final client = await _connect(null);
    try {
      await client.run('rm -f $remotePath /tmp/sbm_bench_upload.bin');
    } finally {
      client.close();
    }
  } catch (_) {
    // Best effort; the files live in /tmp.
  }
}

/// [cipher] null means "use the app's default preference list and let the
/// server pick", which is what the app itself does.
Future<SSHClient> _connect(SSHCipherType? cipher) async {
  final socket = await SSHSocket.connect(
    _cfg.host,
    _cfg.port,
    timeout: const Duration(seconds: 10),
  );
  final key = _cfg.keyPath;
  return SSHClient(
    socket,
    username: _cfg.user,
    algorithms:
        cipher == null ? const SSHAlgorithms() : SSHAlgorithms(cipher: [cipher]),
    identities: key == null
        ? null
        : SSHKeyPair.fromPem(File(key).readAsStringSync()),
    onPasswordRequest: key == null ? () => _cfg.password : null,
    // A benchmark against a host the operator just named; the app's own
    // verification path is covered by its tests, not by this.
    onVerifyHostKey: (type, fingerprint) => true,
  );
}

String _systemSshCommand(SSHCipherType cipher) {
  final parts = [
    'ssh',
    '-p', '${_cfg.port}',
    if (_cfg.keyPath != null) ...['-i', _cfg.keyPath!],
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'UserKnownHostsFile=/dev/null',
    '-o', 'LogLevel=ERROR',
    '-c', cipher.name,
    _cfg.sshDest,
  ];
  return parts.map(_shellQuote).join(' ');
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

class _Row {
  _Row(this.layer, this.cipher, this.bytes, this.elapsed, this.note);

  final String layer;
  final String cipher;
  final int bytes;
  final Duration elapsed;
  final String? note;

  double get mibPerSecond => bytes == 0
      ? 0
      : bytes / 1024 / 1024 / (elapsed.inMicroseconds / 1000000);
}

/// A cipher that fails to connect at all is itself a result worth recording,
/// so one broken combination does not abort the whole run. A short pause
/// between cases keeps sshd's connection rate limiting out of the numbers.
Future<_Row> _safe(
  String layer,
  SSHCipherType? cipher,
  Future<_Row> Function() body,
) async {
  await Future<void>.delayed(const Duration(milliseconds: 300));
  try {
    return await body();
  } catch (e) {
    return _row(layer, _label(cipher), 0, Duration.zero,
        note: 'failed: ${_firstLine(e)}');
  }
}

String _label(SSHCipherType? cipher) => cipher?.name ?? '(app defaults)';

_Row _row(String layer, String cipher, int bytes, Duration elapsed,
    {String? note}) {
  final row = _Row(layer, cipher, bytes, elapsed, note);
  final rate = note ?? '${row.mibPerSecond.toStringAsFixed(1)} MiB/s';
  print('  ${layer.padRight(22)} ${cipher.padRight(30)} ${rate.padLeft(12)}');
  return row;
}

void _summary(List<_Row> rows) {
  print('');
  print('Summary');
  final ok = rows.where((r) => r.note == null && r.bytes > 0).toList();
  if (ok.isEmpty) {
    print('  No successful measurements.');
    return;
  }

  _ratio(ok, 'L2 dartssh2 exec', 'L2 system ssh', 'transport');
  _ratio(ok, 'L3 dartssh2 SFTP get', 'L3 system scp', 'SFTP');

  final l2 = _best(ok, 'L2 dartssh2 exec');
  final l3 = _best(ok, 'L3 dartssh2 SFTP get');
  if (l2 != null && l3 != null && l2.mibPerSecond > 0) {
    final sftpVsExec = l3.mibPerSecond / l2.mibPerSecond;
    print('  dartssh2 SFTP vs its own exec channel: '
        '${sftpVsExec.toStringAsFixed(2)}x');
    print(sftpVsExec < 0.7
        ? '    → SFTP loses a lot on top of the transport; the cost is in the '
            'SFTP layer.'
        : '    → SFTP tracks the transport, so the SFTP layer is not where '
            'the cost is.');
  }
}

void _ratio(List<_Row> rows, String a, String b, String label) {
  final ra = _best(rows, a);
  final rb = _best(rows, b);
  if (ra == null || rb == null || ra.mibPerSecond == 0) return;
  print('  $label — dartssh2 ${ra.mibPerSecond.toStringAsFixed(1)} MiB/s vs '
      'native ${rb.mibPerSecond.toStringAsFixed(1)} MiB/s '
      '(${(rb.mibPerSecond / ra.mibPerSecond).toStringAsFixed(1)}x slower)');
}

_Row? _best(List<_Row> rows, String layer) {
  final matching = rows.where((r) => r.layer == layer);
  if (matching.isEmpty) return null;
  return matching.reduce((a, b) => a.mibPerSecond > b.mibPerSecond ? a : b);
}

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

class _Config {
  _Config({
    required this.host,
    required this.port,
    required this.user,
    required this.keyPath,
    required this.password,
    required this.sshDest,
    required this.mib,
  });

  final String host;
  final int port;
  final String user;
  final String? keyPath;
  final String? password;
  final String sshDest;
  final int mib;

  static _Config? load() {
    final env = <String, String>{
      ..._readDotEnv('../.env'),
      ..._readDotEnv('.env'),
      ...Platform.environment,
    };

    final host = env['SBM_BENCH_HOST'];
    final user = env['SBM_BENCH_USER'];
    if (host == null || host.isEmpty || user == null || user.isEmpty) {
      return null;
    }

    return _Config(
      host: host,
      port: int.tryParse(env['SBM_BENCH_PORT'] ?? '') ?? 22,
      user: user,
      keyPath: _nonEmpty(env['SBM_BENCH_KEY']),
      password: _nonEmpty(env['SBM_BENCH_PASSWORD']),
      sshDest: _nonEmpty(env['SBM_BENCH_SSH_DEST']) ?? '$user@$host',
      mib: int.tryParse(env['SBM_BENCH_MIB'] ?? '') ?? 64,
    );
  }

  static Map<String, String> _readDotEnv(String path) {
    final file = File(path);
    if (!file.existsSync()) return const {};
    final out = <String, String>{};
    for (final line in file.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final idx = trimmed.indexOf('=');
      if (idx <= 0) continue;
      var value = trimmed.substring(idx + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      out[trimmed.substring(0, idx).trim()] = value;
    }
    return out;
  }
}

String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;

String _shellQuote(String s) => "'${s.replaceAll("'", r"'\''")}'";

String _firstLine(Object? s) {
  final text = (s ?? '').toString().trim();
  if (text.isEmpty) return 'unknown error';
  final line = text.split('\n').first;
  return line.length > 80 ? '${line.substring(0, 80)}…' : line;
}
