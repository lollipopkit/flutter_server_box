/// That every distribution claiming a glyph has one, and no more.
///
/// The mapping is by enum name, so a renamed case or a moved file is a glyph
/// that silently stops loading — `SvgPicture.asset` on a missing asset draws
/// nothing rather than throwing, so every affected row would just lose its
/// icon with no error anywhere.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/dist.dart';

/// Read off disk, since a test binary has no asset bundle and the point is
/// what is in the directory rather than what the manifest says about it.
Set<String> _shipped() {
  final dir = Directory('assets/distro');
  return {
    for (final f in dir.listSync())
      if (f.path.endsWith('.svg')) f.uri.pathSegments.last,
  };
}

void main() {
  test('every glyph a distribution names is actually there', () {
    final shipped = _shipped();
    for (final dist in Dist.values) {
      final path = dist.iconPath;
      if (path == null) continue;
      expect(
        shipped,
        contains('${dist.name}.svg'),
        reason: '$path is named by Dist.${dist.name} and has to exist',
      );
    }
  });

  test('and every file there is named by a distribution', () {
    // The other direction: a file nothing points at is dead weight in the
    // bundle, and usually a rename that only got done on one side.
    final named = {
      for (final dist in Dist.values)
        if (dist.iconPath != null) '${dist.name}.svg',
    };
    expect(_shipped(), named);
  });

  test('the two without one say so rather than pointing at nothing', () {
    // font-logos has no glyph for either. They are not to be filled in from
    // those projects' own artwork — see assets/distro/README.md.
    expect(Dist.armbian.iconPath, isNull);
    expect(Dist.coreelec.iconPath, isNull);
  });

  test('a path is under the directory the pubspec ships', () {
    // `assets/distro/` is registered as a directory, so a glyph placed
    // anywhere else resolves at analysis time and fails at runtime.
    for (final dist in Dist.values) {
      final path = dist.iconPath;
      if (path == null) continue;
      expect(path, startsWith('assets/distro/'));
    }
  });

  group('reading a distribution out of os-release', () {
    test('matches the names the glyphs are filed under', () {
      expect('Ubuntu 24.04.1 LTS'.dist, Dist.ubuntu);
      expect('Debian GNU/Linux 12 (bookworm)'.dist, Dist.debian);
      expect('Rocky Linux 9.4'.dist, Dist.rocky);
      expect('openSUSE Tumbleweed'.dist, Dist.opensuse);
    });

    test('and iStoreOS is still OpenWrt, which has a glyph', () {
      // The one entry in `_wrts`: a name that never contains "wrt".
      expect('iStoreOS 22.03'.dist, Dist.wrt);
      expect(Dist.wrt.iconPath, isNotNull);
    });

    test('something unrecognised is null, which draws the fallback', () {
      expect('Some Unknown Linux'.dist, isNull);
    });
  });
}
