import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// The bundled manifest, and the parser that reads it.
///
/// This file decides which bytes get downloaded and
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

  test('it describes exactly the distributions this build can configure', () {
    // Not a restatement of the manifest: installing means writing the package
    // manager's configuration, and that format is code in LinuxDistro. A
    // manifest naming something this build has never heard of would describe
    // a system it could download and unpack and then leave with no working
    // repositories, so the two lists have to agree.
    //
    // The per-field comparison that used to live here went with the switches
    // it was guarding; comparing the manifest to values read from the manifest
    // proves nothing.
    expect(
      bundled.distros.keys.toSet(),
      LinuxDistro.values.map((e) => e.id).toSet(),
    );
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
