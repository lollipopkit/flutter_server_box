import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two macOS products differ in one entitlement and nothing else.
///
/// The App Store requires the sandbox; the DMG is signed without it, which is
/// the only reason it can host a terminal on this machine
/// (`LocalShellBackend.isSupported`) and the reason its data lives somewhere
/// else (`Paths`, `SandboxImport`). Both of those read the entitlement at
/// runtime, so a mistake here is not a build error — it is a shipped product
/// that quietly lost a feature, or an App Store submission that is rejected.
///
/// That is not hypothetical: the DMG shipped sandboxed from v1.0.1450 until
/// `ReleaseDmg.entitlements` was added, and nothing went red for two months.
void main() {
  const debugProfile = 'macos/Runner/DebugProfile.entitlements';
  const release = 'macos/Runner/Release.entitlements';
  const releaseDmg = 'macos/Runner/ReleaseDmg.entitlements';
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

  test('the App Store build is sandboxed and the DMG one is not', () {
    expect(sandboxOf(release), true);
    expect(sandboxOf(releaseDmg), false);
  });

  test('the two products differ in the sandbox and nothing else', () {
    // Anything added to one and forgotten in the other is a capability the
    // other build silently does without — iCloud, for one, which both need.
    expect(keysOf(releaseDmg), keysOf(release));
  });

  test('the project wires the App Store entitlements', () {
    final project = read(pbxproj);
    expect(project.contains('Runner/Release.entitlements'), true);

    // The DMG's entitlements are applied by the release script alone. Wiring
    // them into a build configuration is how an unsandboxed binary would end
    // up submitted to the App Store.
    expect(project.contains('ReleaseDmg'), false);
  });

  test('the release script is what swaps them', () {
    expect(
      read(dmgScript).contains(
        'CODE_SIGN_ENTITLEMENTS = Runner/ReleaseDmg.entitlements',
      ),
      true,
    );
  });

  test('what you develop against is what ships as the DMG', () {
    // Debug and Profile share this file. Sandboxed, it would mean no local
    // terminal while working on one, `SandboxImport` skipping itself, and the
    // app's data sitting somewhere no release build looks — three code paths
    // that only the unsandboxed product ever takes, none of them reachable
    // from `flutter run`.
    expect(sandboxOf(debugProfile), false);
    expect(sandboxOf(debugProfile), sandboxOf(releaseDmg));
  });
}
