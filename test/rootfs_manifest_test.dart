import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// The bundled manifest, and the parser that reads it.
///
/// Two jobs. One is the migration safety net: every value in
/// `assets/rootfs_manifest.json` has to say what [LinuxDistro] says today, so
/// that moving the switches out is a move and not a rewrite. That group is
/// temporary and goes with the switches.
///
/// The other is permanent. This file decides which bytes get downloaded and
/// run, so the parser has to refuse anything it does not fully understand
/// rather than fill in a default — a default here is a silent answer to
/// "which bytes".
void main() {
  late RootfsManifest bundled;

  setUpAll(() {
    // Read from disk rather than through rootBundle: this is a plain unit
    // test, and what is under test is the file that ships, not the asset
    // loader. pubspec.yaml lists it; `assets_present` below is what catches
    // it being dropped from there.
    bundled = RootfsManifest.parse(
      File('assets/rootfs_manifest.json').readAsStringSync(),
    );
  });

  test('the asset is declared, or it ships parsed by nothing', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('assets/rootfs_manifest.json'),
    );
  });

  // TODO(manifest rollout; remove with the LinuxDistro switches): this group
  // exists only to prove the two agree while both exist.
  group('the bundled manifest agrees with the hardcoded values', () {
    test('it describes exactly the distributions this build knows', () {
      expect(
        bundled.distros.keys.toSet(),
        LinuxDistro.values.map((e) => e.id).toSet(),
      );
    });

    for (final distro in LinuxDistro.values) {
      test(distro.id, () {
        final entry = bundled.distros[distro.id];
        expect(entry, isNotNull, reason: '${distro.id} is missing');
        entry!;

        expect(entry.label, distro.label);
        expect(entry.version, distro.version);
        expect(entry.branch, distro.branch);
        expect(entry.packageManager, distro.packageManager);
        expect(entry.defaultMirror, distro.defaultMirror);

        // Nothing is repacked yet, so upstream is what gets downloaded.
        expect(entry.rootfs, isNull);
        expect(entry.source, same(entry.upstream));

        final source = entry.source;
        expect(source.sha256, distro.sha256);
        expect(source.layout, distro.layout);
        expect(source.compression, distro.compression);
        expect(source.followsMirror, distro.rootfsFollowsMirror);
        expect(source.url, distro.rootfsUrl(distro.defaultMirror));
        expect(source.sizeMb, distro.approxDownloadMb);
      });
    }
  });

  group('the parser refuses what it cannot fully read', () {
    /// The bundled file with one thing changed, which is how each case below
    /// differs from a manifest that works.
    String edited(void Function(Map<String, dynamic> root) change) {
      final root =
          json.decode(File('assets/rootfs_manifest.json').readAsStringSync())
              as Map<String, dynamic>;
      change(root);
      return json.encode(root);
    }

    Map<String, dynamic> rocky(Map<String, dynamic> root) =>
        (root['distros'] as Map<String, dynamic>)['rocky']
            as Map<String, dynamic>;

    test('a schema from a later build', () {
      // Read partially, the fields it skipped could be the ones that matter.
      expect(
        () => RootfsManifest.parse(edited((r) => r['schema'] = 2)),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a digest that is not one', () {
      // Caught here rather than at the comparison, where a malformed digest
      // is a check that quietly never matches.
      for (final bad in ['', 'deadbeef', 'Z' * 64, '3FBC6285' * 8]) {
        expect(
          () => RootfsManifest.parse(
            edited((r) => (rocky(r)['upstream'] as Map)['sha256'] = bad),
          ),
          throwsA(isA<RootfsManifestException>()),
          reason: 'accepted $bad',
        );
      }
    });

    test('a layout or compression this build cannot unpack', () {
      expect(
        () => RootfsManifest.parse(
          edited((r) => (rocky(r)['upstream'] as Map)['layout'] = 'squashfs'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
      expect(
        () => RootfsManifest.parse(
          edited((r) => (rocky(r)['upstream'] as Map)['compression'] = 'zstd'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a size that cannot be one', () {
      for (final bad in <Object>[0, -1, '35094845']) {
        expect(
          () => RootfsManifest.parse(
            edited((r) => (rocky(r)['upstream'] as Map)['size_bytes'] = bad),
          ),
          throwsA(isA<RootfsManifestException>()),
          reason: 'accepted $bad',
        );
      }
    });

    test('a mirror with a trailing slash, which callers join onto', () {
      expect(
        () => RootfsManifest.parse(
          edited((r) => rocky(r)['default_mirror'] = 'https://m.test/rocky/'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a mirror that is not http(s)', () {
      expect(
        () => RootfsManifest.parse(
          edited((r) => rocky(r)['default_mirror'] = 'file:///etc'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a missing field, rather than defaulting it', () {
      for (final key in [
        'label',
        'version',
        'branch',
        'package_manager',
        'default_mirror',
        'upstream',
      ]) {
        expect(
          () => RootfsManifest.parse(edited((r) => rocky(r).remove(key))),
          throwsA(isA<RootfsManifestException>()),
          reason: 'defaulted a missing $key',
        );
      }
    });

    test('no distributions at all', () {
      expect(
        () => RootfsManifest.parse(
          edited((r) => r['distros'] = <String, dynamic>{}),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('something that is not JSON', () {
      expect(
        () => RootfsManifest.parse('not a manifest'),
        throwsA(isA<RootfsManifestException>()),
      );
    });
  });

  group('what the manifest promises about itself', () {
    test('the bundled copy carries a serial and a schema this build reads', () {
      expect(bundled.schema, RootfsManifest.supportedSchema);
      expect(bundled.serial, greaterThan(0));
    });

    test('validUntil is after generatedAt', () {
      expect(bundled.validUntil.isAfter(bundled.generatedAt), isTrue);
    });

    test('a size in bytes rounds up to whole megabytes', () {
      // Never down: the dialog is answered before anything is fetched, and
      // understating a download is the direction that costs someone data.
      final rocky = bundled.distros['rocky']!.source;
      expect(rocky.sizeBytes, 84701720);
      expect(rocky.sizeMb, 81);
      expect(bundled.distros['alpine']!.source.sizeMb, 4);
      expect(bundled.distros['ubuntu']!.source.sizeMb, 34);
    });
  });
}
