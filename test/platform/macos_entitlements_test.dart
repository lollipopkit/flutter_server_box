import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every macOS build is unsandboxed: the App Store build, the one product
/// that had to be sandboxed, is no longer made.
///
/// The entitlement is read at runtime — a local terminal (`LocalShellBackend`)
/// and where the data lives (`Paths`) — so a mistake here is not a build error
/// but a shipped app that quietly lost a feature and its data. The DMG once
/// shipped sandboxed for two months with nothing going red.
void main() {
  const debugProfile = 'macos/Runner/DebugProfile.entitlements';
  const release = 'macos/Runner/Release.entitlements';
  const pbxproj = 'macos/Runner.xcodeproj/project.pbxproj';
  const dmgScript = 'scripts/release/release-macos-dmg.sh';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), true, reason: '$path is gone');
    return file.readAsStringSync();
  }

  /// The value of `com.apple.security.app-sandbox`, or null if unstated —
  /// which for a macOS app means unsandboxed, but never on purpose.
  bool? sandboxOf(String path) {
    final match = RegExp(
      r'<key>com\.apple\.security\.app-sandbox</key>\s*<(true|false)\s*/>',
    ).firstMatch(read(path));
    return switch (match?.group(1)) {
      'true' => true,
      'false' => false,
      _ => null,
    };
  }

  Set<String> keysOf(String path) => RegExp(r'<key>([^<]+)</key>')
      .allMatches(read(path))
      .map((e) => e.group(1)!)
      .toSet();

  test('no build is sandboxed', () {
    expect(sandboxOf(release), false);
    expect(sandboxOf(debugProfile), false);
  });

  test('what is developed against has what ships', () {
    // Anything Release has that Debug lacks is a capability no `flutter run`
    // exercises — iCloud, for one.
    expect(keysOf(debugProfile).containsAll(keysOf(release)), true);
  });

  test('one set of release entitlements, the one the project names', () {
    expect(read(pbxproj).contains('Runner/Release.entitlements'), true);
    expect(File('macos/Runner/ReleaseDmg.entitlements').existsSync(), false);
    expect(read(dmgScript).contains('CODE_SIGN_ENTITLEMENTS'), false);
    expect(read(dmgScript).contains('ReleaseDmg'), false);
  });
}
