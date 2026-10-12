import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/diagnostics_level.dart';

/// These decide what leaves a user's device by default. The failure mode is
/// silent in both directions: too permissive and an F-Droid build collects
/// without being asked, too strict and nothing is ever reported.
void main() {
  test('nothing is uploaded until the user picks a level that uploads', () {
    // The same on every platform: uploading is turned on, never found on. No
    // build flag either — F-Droid compares its rebuild of the Android build
    // byte for byte against the published APK.
    expect(defaultDiagnosticsLevel, DiagnosticsLevel.none);
    expect(defaultDiagnosticsLevel.uploads, isFalse);
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
  });

  test('basic reports failures but is silent in between', () {
    const basic = DiagnosticsLevel.basic;
    expect(basic.uploads, isTrue);
    expect(basic.sendsBreadcrumbs, isTrue, reason: 'context for a failure');
  });

  // TODO: remove with `DiagnosticsUpload.retireFullLevel`.
  test('the removed full level reads as basic', () {
    // It sent everything `basic` does, so that much was agreed to; reading it
    // as `none` would stop crash reports nobody asked to stop.
    expect(DiagnosticsLevel.fromName('full'), DiagnosticsLevel.basic);
    expect(DiagnosticsLevel.values.map((l) => l.name), isNot(contains('full')));
  });
}
