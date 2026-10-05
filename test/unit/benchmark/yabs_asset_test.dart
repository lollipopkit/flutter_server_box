import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/benchmark/yabs_result.dart';
import 'package:server_box/src/rust/api/bench.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

const _asset = 'assets/yabs.b64';

/// The vendored yabs as the app bundles it, and the results it reads back.
/// The commands that install, run and clear it are `sbm_parser::bench`'s,
/// run against a real shell in `crates/sbm_parser/tests/bench_script.rs`; the
/// asset's digest is asserted by `monitor/tests/benchmark_asset.rs`.
void main() {
  setUpAll(initRustLibForTest);

  group('the vendored asset', () {
    test('carries the version it is recorded as', () async {
      final text = (await ffi.benchDecodeAsset(encoded: await File(_asset).readAsString()))!;
      expect(
        RegExp(r'^YABS_VERSION="(.*)"$', multiLine: true).firstMatch(text)?.group(1),
        ffi.benchUpstreamVersion(),
      );
    });

    test('downloads fio and iperf3 only when -b was requested', () async {
      final text = (await ffi.benchDecodeAsset(encoded: await File(_asset).readAsString()))!;

      // The no-`-b`, no-local-package path must not reach either URL. This is
      // intentionally structural: the asset is the exact shell program sent
      // to a server, and its hash above makes this contract reviewable when
      // the vendored upstream script is refreshed.
      final fioStart = text.indexOf(
        '# create temp directory to store disk write/read test files',
      );
      final fioEnd = text.indexOf(r'if [ -z "$DD_FALLBACK" ]');
      expect(fioStart, isNonNegative);
      expect(fioEnd, greaterThan(fioStart));
      final fio = text.substring(fioStart, fioEnd);
      expect(
        fio,
        contains(r'if [[ -z "$PREFER_BIN" && -n "$LOCAL_FIO" ]]; then'),
      );
      expect(fio, contains(r'elif [[ -n "$PREFER_BIN" ]]; then'));
      expect(
        fio,
        contains('fio is not installed. Running dd test as fallback...'),
      );
      expect(
        fio.indexOf(
          'https://raw.githubusercontent.com/masonr/'
          'yet-another-bench-script/master/bin/fio/',
        ),
        greaterThan(fio.indexOf(r'elif [[ -n "$PREFER_BIN" ]]; then')),
      );

      final iperf = text.substring(
        text.indexOf(r'if [ -z "$SKIP_IPERF" ]; then'),
        text.indexOf('# launch_geekbench'),
      );
      expect(
        iperf,
        contains(r'if [[ -z "$PREFER_BIN" && -n "$LOCAL_IPERF" ]]; then'),
      );
      expect(iperf, contains(r'elif [[ -n "$PREFER_BIN" ]]; then'));
      expect(
        iperf,
        contains('iperf3 is not installed. Skipping network tests...'),
      );
      expect(iperf, contains('IPERF_UNAVAILABLE=True'));
      expect(
        iperf,
        contains(r'[[ -z "$IPERF_DL_FAIL" && -z "$IPERF_UNAVAILABLE" ]]'),
      );
      expect(
        iperf.indexOf(
          'https://raw.githubusercontent.com/masonr/'
          'yet-another-bench-script/master/bin/iperf/',
        ),
        greaterThan(iperf.indexOf(r'elif [[ -n "$PREFER_BIN" ]]; then')),
      );
    });

    // App Store validation walks everything inside `Runner.app` and treats a
    // file it reads as executable code as a nested code object that must be
    // signed on its own. Nothing under `flutter_assets` is. So such an asset
    // costs nothing at build time and fails the *upload*, with `Invalid
    // Signature. Code object is not signed at all.` — an error that names the
    // certificates and not the file's contents. `assets/yabs.sh` shipped that
    // way in v1574, which is why the script is base64 now.
    //
    // Over every declared asset rather than yabs alone: the next one to do
    // this will not be this file.
    test('no bundled asset reads as executable code', () {
      const scriptSuffixes = ['.sh', '.bash', '.zsh', '.py', '.pl', '.rb'];

      final assets = _declaredAssets();
      expect(
        assets,
        contains(_asset),
        reason: 'pubspec.yaml assets: could not be read',
      );

      for (final path in assets) {
        expect(
          scriptSuffixes.any(path.endsWith),
          isFalse,
          reason: '$path has a script suffix and cannot be bundled',
        );

        final bytes = File(path).readAsBytesSync();
        expect(
          bytes.length >= 2 && bytes[0] == 0x23 && bytes[1] == 0x21,
          isFalse,
          reason: '$path starts with a shebang and cannot be bundled',
        );
      }
    });
  });

  group('results parse leniently', () {
    test('a field yabs could not fill is null rather than zero', () {
      // Not a hypothetical: `CPU_CORES` comes from an `lscpu` pipeline that
      // prints nothing when it does not match, and the JSON is assembled by
      // string concatenation, so the value arrives empty.
      final result = YabsResult.fromJson({
        'version': 'v2026-07-24',
        'cpu': {'model': 'x', 'cores': '', 'freq': '3000', 'aes': 'true'},
        'mem': {'ram': '2048', 'ram_units': 'KiB'},
      });

      expect(result.cpu.cores, isNull);
      expect(result.cpu.aes, isTrue);
      expect(result.cpu.virt, isFalse);
      expect(result.mem.ram, 2048);
      expect(result.mem.ramBytes, 2048 * 1024);
      // Absent sections are empty rather than missing.
      expect(result.fio, isEmpty);
      expect(result.ipInfo, isNull);
    });

    test('iperf rates come back as numbers for the chart', () {
      const row = YabsIperf(
        send: '1.20 Gbits/sec',
        recv: '940 Mbits/sec',
        latency: '12.3 ms',
      );
      expect(row.sendBitsPerSec, 1.2e9);
      expect(row.recvBitsPerSec, 940e6);
      expect(row.latencyMs, 12.3);

      // What a location that could not be reached looks like.
      const missing = YabsIperf(send: 'busy', recv: '--', latency: '--');
      expect(missing.sendBitsPerSec, isNull);
      expect(missing.latencyMs, isNull);
    });
  });
}

/// Every file the `assets:` section of pubspec puts in the bundle, with a
/// directory entry expanded the way Flutter expands one — the files directly
/// inside it, not recursively.
///
/// Parsed by indentation rather than with a YAML package: the section is two
/// levels deep in a file this repo controls, and a test that reads pubspec
/// should not decide what the build's own parser accepts.
List<String> _declaredAssets() {
  final assets = <String>[];
  var inSection = false;

  for (final line in File('pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^  assets:\s*$').hasMatch(line)) {
      inSection = true;
      continue;
    }
    if (!inSection) continue;

    final entry = RegExp(r'^    -\s+(\S+)\s*$').firstMatch(line);
    if (entry == null) {
      // Comments and blank lines sit between entries; anything else is the
      // next key, and the section is over.
      if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
      break;
    }

    final path = entry.group(1)!;
    if (path.endsWith('/')) {
      assets.addAll(
        Directory(path).listSync().whereType<File>().map((f) => f.path),
      );
    } else {
      assets.add(path);
    }
  }

  return assets;
}
