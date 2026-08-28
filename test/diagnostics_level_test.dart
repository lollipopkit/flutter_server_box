import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';

/// These decide what leaves a user's device by default. The failure mode is
/// silent in both directions: too permissive and an F-Droid build collects
/// without being asked, too strict and nothing is ever reported.
void main() {
  test('the built-in default is the quietest level', () {
    // A build handed no channel is treated as F-Droid's, where collecting by
    // default is exactly what must not happen. The release workflow passes
    // DIAG_DEFAULT=full; nothing else does, including build-fdroid.sh.
    expect(kDefaultDiagnosticsLevel, DiagnosticsLevel.none.name);
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
    expect(none.streamsLogs, isFalse);
    expect(none.tracesPerformance, isFalse);
  });

  test('basic reports failures but is silent in between', () {
    const basic = DiagnosticsLevel.basic;
    expect(basic.uploads, isTrue);
    expect(basic.sendsBreadcrumbs, isTrue, reason: 'context for a failure');
    // The distinction that defines the level: nothing is sent while the app is
    // behaving, so its cost scales with failures rather than with use.
    expect(basic.streamsLogs, isFalse);
    expect(basic.tracesPerformance, isFalse);
  });

  test('full streams while the app runs', () {
    const full = DiagnosticsLevel.full;
    expect(full.uploads, isTrue);
    expect(full.sendsBreadcrumbs, isTrue);
    expect(full.streamsLogs, isTrue);
    expect(full.tracesPerformance, isTrue);
  });
}
