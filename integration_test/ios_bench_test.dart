import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/ish_exec.dart';

/// What the Linux guest costs on the hardware people actually have.
///
/// The fork publishes 7–12x figures for the ARM64 JIT over the x86 interpreter,
/// measured on a Mac. Those are not the numbers a phone gives, and a phone is
/// where this ships — so the suite runs here, in the app, on the device.
///
/// The script and the prebuilt binary are the fork's own and are passed in
/// rather than vendored, so there is one copy of each:
///
///     scripts/ios-bench-defines.sh > /tmp/bench.json
///     flutter drive --driver=integration_test/driver.dart \
///       --target=integration_test/ios_bench_test.dart \
///       -d <device> --profile --publish-port \
///       --dart-define-from-file=/tmp/bench.json
///
/// Skipped when the defines are absent, so running the whole suite without
/// them is not a failure.
///
/// Nothing here asserts a duration. Timings depend on the device, its thermal
/// state and what else is running, and a benchmark that fails the build on a
/// warm phone would be turned off within a week. It asserts that the suite ran
/// and reports what it measured; the numbers go in `ISHBENCH|` lines.
/// Both arrive base64: a define is passed to the frontend server as a literal
/// `-DNAME=value`, so a value with a newline in it is taken for another source
/// file to compile.
const _shellbenchB64 = String.fromEnvironment('SHELLBENCH_B64');
const _cbench = String.fromEnvironment('CBENCH_ARM64_B64');

/// Every section the script runs unconditionally — System 7, Compute 9, Text 6,
/// File-IO 4, Crypto 2, Process 3. Python, Go, Node and C are each behind a
/// `command -v`, so a bare Alpine reports none of them and that is not a fault.
const _unconditionalRows = 31;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => IosRootfs.prepare());

  testWidgets('the guest runs the fork\'s benchmark', (_) async {
    if (!IshExec.isSupported) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    if (_shellbenchB64.isEmpty) {
      markTestSkipped('no benchmark passed in — see scripts/ios-bench-defines.sh');
      return;
    }
    final shellbench = utf8.decode(base64.decode(_shellbenchB64));
    await IosRootfs.install(distro: LinuxDistro.alpine);
    const exec = IshExec();

    // The C section runs a prebuilt musl aarch64 binary, which is exactly what
    // the guest is. Written through the host path the way the host runner
    // writes it, rather than piped in: 74 KB through a pty's line discipline is
    // not the same bytes coming out.
    if (_cbench.isNotEmpty) {
      final host = await exec.hostPathOf('/tmp/cbench_prebuilt', forWrite: true);
      expect(host, isNotNull, reason: '/tmp is not a path the guest exposes');
      await File(host!).writeAsBytes(base64.decode(_cbench), flush: true);
      // Dart cannot set the execute bit and iOS has no process to ask, but the
      // guest can: `realfs` puts the host's mode on the file either way.
      final marked = await exec.run('chmod +x /tmp/cbench_prebuilt');
      expect(marked.exitCode, 0, reason: marked.stderr);
    }

    // What the script will time itself with, before it does. It prefers
    // `date +%s%N` and falls back to /proc/uptime, and neither is something a
    // guest necessarily has: a clock that does not advance reports every
    // measurement as zero rather than failing, which is the one result that
    // looks like data and is not.
    final clock = await exec.run(
      r'echo "sN=$(date +%s%N)"; echo "N=$(date +%N)"; '
      r'echo "up1=$(cat /proc/uptime)"; sleep 1; '
      r'echo "up2=$(cat /proc/uptime)"; echo "sN2=$(date +%s%N)"',
    );
    debugPrint('ISHCLOCK ${clock.stdout.trim().replaceAll("\n", " ")}');

    // Written to the guest and run from there, the way the fork's host runner
    // does it, so what is measured is the script as the fork ships it. `run`
    // would take it directly now — it writes anything past 4 KB to a file
    // itself, since the session's command line is one 4096-byte block — but a
    // benchmark should not also be measuring that.
    final script = await exec.hostPathOf('/tmp/shellbench.sh', forWrite: true);
    expect(script, isNotNull, reason: '/tmp is not a path the guest exposes');
    await File(script!).writeAsString(shellbench, flush: true);

    final result = await exec.run('sh /tmp/shellbench.sh');
    expect(result.exitCode, 0, reason: result.stderr);

    // "category|name|milliseconds" per line, and nothing else on stdout.
    final rows = <({String category, String name, int ms})>[];
    for (final line in const LineSplitter().convert(result.stdout)) {
      final parts = line.trim().split('|');
      if (parts.length != 3) continue;
      final ms = int.tryParse(parts[2]);
      if (ms == null) continue;
      rows.add((category: parts[0], name: parts[1], ms: ms));
    }

    for (final row in rows) {
      debugPrint('ISHBENCH|${row.category}|${row.name}|${row.ms}');
    }
    final categories = rows.map((r) => r.category).toSet();
    debugPrint('ISHBENCH_DONE rows=${rows.length} categories=${categories.join(",")}');

    // Also to a file, because the printed copy needs a harness attached to be
    // read and the harness is the part that does not work here: the VM service
    // socket is reset moments after launch, every time, since the host's tunnel
    // to this device became `wired`. A profile build launched from the home
    // screen runs the suite anyway, and this is how its answer gets off the
    // device:
    //
    //     xcrun devicectl device copy from -d <device> \
    //       --domain-type appDataContainer \
    //       --domain-identifier com.lollipopkit.toolbox \
    //       --source Documents/ish_bench.txt --destination /tmp/
    final report = StringBuffer()
      ..writeln('clock ${clock.stdout.trim().replaceAll("\n", " ")}')
      ..writeln('rows ${rows.length}');
    for (final row in rows) {
      report.writeln('${row.category}|${row.name}|${row.ms}');
    }
    final documents = await getApplicationDocumentsDirectory();
    await File(
      '${documents.path}/ish_bench.txt',
    ).writeAsString(report.toString(), flush: true);

    expect(
      rows.length,
      greaterThanOrEqualTo(_unconditionalRows),
      reason: 'the suite did not finish: only ${rows.length} results',
    );
    // A negative duration means the clock the script picked runs backwards,
    // which would make every number here meaningless rather than merely slow.
    expect(rows.every((r) => r.ms >= 0), isTrue, reason: 'a timing went backwards');

    // The shell sections time themselves against a guest clock. If that clock
    // does not advance every one of them reads zero, which is the failure that
    // looks most like a result — 31 rows, all present, all meaningless. The C
    // section is excluded: it carries its own clock inside the binary and would
    // hide the very thing this checks.
    final shell = rows.where((r) => r.category != 'C');
    expect(
      shell.any((r) => r.ms > 0),
      isTrue,
      reason: 'every shell timing read zero — the guest clock does not advance',
    );
  }, skip: !Platform.isIOS, timeout: const Timeout(Duration(minutes: 20)));
}
