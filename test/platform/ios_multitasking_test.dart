import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What iPadOS reads before it will let this app share the screen.
///
/// Slide Over and Split View are not something the app switches on: iPadOS
/// offers them to any app whose bundle meets three conditions — no
/// `UIRequiresFullScreen`, all four orientations on iPad, and a launch
/// storyboard. Lose one and the app silently stops being draggable into a
/// small window. Nothing goes red, and the three build configurations are
/// separate files, so a key added to one and forgotten in the others is a
/// debug build that multitasks and a shipped one that does not.
///
/// Beside `macos_entitlements_test.dart`, which guards the same class of
/// mistake on the other Apple platform.
void main() {
  const plists = [
    'ios/Runner/Info-Debug.plist',
    'ios/Runner/Info-Profile.plist',
    'ios/Runner/Info-Release.plist',
  ];
  const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';

  String read(String path) {
    final file = File(path);
    expect(file.existsSync(), true, reason: '$path is gone');
    return file.readAsStringSync();
  }

  bool hasKey(String path, String key) =>
      RegExp('<key>${RegExp.escape(key)}</key>').hasMatch(read(path));

  /// The `<string>`s of the `<array>` filed under [key].
  List<String> arrayOf(String path, String key) {
    final block = RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(read(path));
    expect(block, isNotNull, reason: '$key is not in $path');
    return RegExp(r'<string>([^<]+)</string>')
        .allMatches(block!.group(1)!)
        .map((e) => e.group(1)!.trim())
        .toList();
  }

  test('no build asks iPadOS for the whole screen', () {
    // The key does not have to be false, it has to be absent: present at all
    // is a claim this app makes about itself, and the only reason to make it
    // is to opt out of multitasking.
    for (final plist in plists) {
      expect(
        hasKey(plist, 'UIRequiresFullScreen'),
        false,
        reason: '$plist opts out of Slide Over and Split View',
      );
    }
    expect(read(pbxproj).contains('UIRequiresFullScreen'), false);
  });

  test('every build supports all four orientations on iPad', () {
    // iPadOS can put the app in either half of a split in either rotation, so
    // it will not offer multitasking to an app that cannot take all four.
    const required = {
      'UIInterfaceOrientationPortrait',
      'UIInterfaceOrientationPortraitUpsideDown',
      'UIInterfaceOrientationLandscapeLeft',
      'UIInterfaceOrientationLandscapeRight',
    };
    for (final plist in plists) {
      expect(
        arrayOf(plist, 'UISupportedInterfaceOrientations~ipad').toSet(),
        required,
        reason: '$plist does not take every iPad orientation',
      );
    }
  });

  test('every build launches from a storyboard', () {
    // The third condition, and the one that says the app lays itself out from
    // the window it is given rather than from the device it is on.
    for (final plist in plists) {
      expect(
        hasKey(plist, 'UILaunchStoryboardName'),
        true,
        reason: '$plist has no launch storyboard',
      );
    }
  });

  test('the app is built for iPad', () {
    expect(read(pbxproj).contains('TARGETED_DEVICE_FAMILY = "1,2"'), true);
  });
}
