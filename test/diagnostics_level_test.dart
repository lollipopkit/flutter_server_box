import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';

/// These decide what leaves a user's device by default. The failure mode is
/// silent in both directions: too permissive and an F-Droid build collects
/// without being asked, too strict and nothing is ever reported.
void main() {
  test('the default is decided by platform, not by build flags', () {
    // Android must start at `none`: it is the only platform F-Droid
    // distributes, and their policy requires opt-in *and* disabled by default.
    // Everywhere else starts at `basic`.
    //
    // Runtime rather than compile-time, and that is the load-bearing part:
    // F-Droid rebuilds this source and compares byte for byte against the
    // published APK, so a flag that differed between the two would fail the
    // verification. The tests run on the host, hence the branch here.
    expect(
      defaultDiagnosticsLevel,
      Platform.isAndroid ? DiagnosticsLevel.none : DiagnosticsLevel.basic,
    );
    // Whatever the platform, the default never traces.
    expect(defaultDiagnosticsLevel.tracesPerformance, isFalse);
  });

  test('an unreadable stored value sends nothing', () {
    // Not the build default: a value that cannot be read is not a record of
    // what the user agreed to.
    expect(DiagnosticsLevel.fromName(null), DiagnosticsLevel.none);
    expect(DiagnosticsLevel.fromName(''), DiagnosticsLevel.none);
    expect(DiagnosticsLevel.fromName('nonsense'), DiagnosticsLevel.none);
    expect(DiagnosticsLevel.fromName('None'), DiagnosticsLevel.none);
  });

  test('every level round-trips through its name', () {
    // Stored by name, so a rename is a data migration rather than a typo.
    for (final level in DiagnosticsLevel.values) {
      expect(DiagnosticsLevel.fromName(level.name), level);
    }
  });

  test('none uploads nothing at all', () {
    const none = DiagnosticsLevel.none;
    expect(none.uploads, isFalse);
    expect(none.sendsBreadcrumbs, isFalse);
    expect(none.tracesPerformance, isFalse);
  });

  test('basic reports failures but is silent in between', () {
    const basic = DiagnosticsLevel.basic;
    expect(basic.uploads, isTrue);
    expect(basic.sendsBreadcrumbs, isTrue, reason: 'context for a failure');
    // The distinction that defines the level: nothing is sent while the app is
    // behaving, so its cost scales with failures rather than with use.
    expect(basic.tracesPerformance, isFalse);
  });

  test('full adds timings, and nothing else', () {
    const full = DiagnosticsLevel.full;
    expect(full.uploads, isTrue);
    expect(full.sendsBreadcrumbs, isTrue);
    // The whole of what `full` is: `basic` plus traced operations. It used to
    // stream the app's log lines too, which is the one thing no level does now
    // -- a log line is written for a developer reading the file on the device,
    // not to be published, and `SentrySink.log` drops it at every level.
    expect(full.tracesPerformance, isTrue);
  });
}
