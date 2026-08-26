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

    /// Rocky's first release, which is where the per-release fields are.
    Map<String, dynamic> release(Map<String, dynamic> root) =>
        (rocky(root)['releases'] as List).first as Map<String, dynamic>;

    Map<String, dynamic> upstream(Map<String, dynamic> root) =>
        release(root)['upstream'] as Map<String, dynamic>;

    test('a schema from a later build', () {
      // Read partially, the fields it skipped could be the ones that matter.
      expect(
        () => RootfsManifest.parse(edited((r) => r['schema'] = 3)),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('the schema this build replaced, which reads nothing like it', () {
      // Schema 1 held one release per distribution, inline. Read as 2 it has
      // no `releases` at all, and the fields it does have sit a level up from
      // where they are now — so a device that cached one before updating gets
      // a refusal rather than a distribution with no releases in it.
      expect(
        () => RootfsManifest.parse(edited((r) => r['schema'] = 1)),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a digest that is not one', () {
      // Caught here rather than at the comparison, where a malformed digest
      // is a check that quietly never matches.
      for (final bad in ['', 'deadbeef', 'Z' * 64, '3FBC6285' * 8]) {
        expect(
          () => RootfsManifest.parse(
            edited((r) => upstream(r)['sha256'] = bad),
          ),
          throwsA(isA<RootfsManifestException>()),
          reason: 'accepted $bad',
        );
      }
    });

    test('a layout or compression this build cannot unpack', () {
      expect(
        () => RootfsManifest.parse(
          edited((r) => upstream(r)['layout'] = 'squashfs'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
      expect(
        () => RootfsManifest.parse(
          edited((r) => upstream(r)['compression'] = 'zstd'),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('a size that cannot be one', () {
      for (final bad in <Object>[0, -1, '35094845']) {
        expect(
          () => RootfsManifest.parse(
            edited((r) => upstream(r)['size_bytes'] = bad),
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

    test('a timestamp that names no timezone', () {
      // `DateTime.parse` reads one without a `Z` or an offset as *local*, so
      // `valid_until` would mean a different instant in every timezone — and
      // it is what decides whether a fetched manifest has expired. A rollback
      // window that opens by flying west is not one.
      for (final key in ['generated_at', 'valid_until']) {
        expect(
          () => RootfsManifest.parse(
            edited((r) => r[key] = '2027-02-18T00:00:00'),
          ),
          throwsA(isA<RootfsManifestException>()),
          reason: key,
        );
      }
      // An explicit offset is an instant, so it is accepted.
      expect(
        RootfsManifest.parse(
          edited((r) => r['valid_until'] = '2027-02-18T08:00:00+08:00'),
        ).validUntil,
        DateTime.utc(2027, 2, 18),
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
        'package_manager',
        'default_mirror',
        'releases',
      ]) {
        expect(
          () => RootfsManifest.parse(edited((r) => rocky(r).remove(key))),
          throwsA(isA<RootfsManifestException>()),
          reason: 'defaulted a missing $key',
        );
      }
      for (final key in ['version', 'branch', 'upstream']) {
        expect(
          () => RootfsManifest.parse(edited((r) => release(r).remove(key))),
          throwsA(isA<RootfsManifestException>()),
          reason: 'defaulted a missing $key',
        );
      }
    });

    test('a distribution with no releases in it', () {
      // Nothing to install and nothing to compare an installed system
      // against. `preferred` would have no first element to answer with, so
      // this has to be refused here rather than thrown from a getter later.
      expect(
        () => RootfsManifest.parse(
          edited((r) => rocky(r)['releases'] = <dynamic>[]),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
    });

    test('two releases of one series', () {
      // Which of them a system is running would then be undecidable, and
      // `newestIn` would answer with whichever came last in the file.
      expect(
        () => RootfsManifest.parse(
          edited((r) {
            final list = rocky(r)['releases'] as List;
            final copy = json.decode(json.encode(list.first));
            (copy as Map<String, dynamic>)['version'] = '9.9';
            list.add(copy);
          }),
        ),
        throwsA(isA<RootfsManifestException>()),
      );
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
      //
      // The property, over every source in the file, rather than three
      // numbers copied out of it — those go stale the next time a pin moves,
      // and a test that has to be edited to keep passing is one nobody reads
      // the failure of. One fixed pair below covers the boundary itself.
      for (final distro in bundled.distros.values) {
        for (final release in distro.releases) {
          for (final source in [release.source, release.upstream]) {
            final where = '${distro.id} ${release.version}';
            expect(
              source.sizeMb * 1048576,
              greaterThanOrEqualTo(source.sizeBytes),
              reason: '$where is understated',
            );
            expect(
              (source.sizeMb - 1) * 1048576,
              lessThan(source.sizeBytes),
              reason: '$where is rounded up further than it needs',
            );
          }
        }
      }
    });

    test('and a byte over a megabyte is two', () {
      // The boundary itself, stated rather than derived, since the property
      // above holds for any rounding that never goes down.
      const of = RootfsSource(
        url: 'https://m.test/x',
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
        sizeBytes: 1048577,
        layout: LinuxRootfsLayout.plain,
        compression: LinuxRootfsCompression.gzip,
        followsMirror: false,
      );

      expect(of.sizeMb, 2);
    });

    test('a mirror is swapped on a path boundary, not on a prefix', () {
      // `…/pub/rocky` is a prefix of `…/pub/rockyfoo/x`. Swapped there, the
      // result is a URL made of two hosts' paths — the one case where
      // honouring a mirror fetches something nobody named.
      const source = RootfsSource(
        url: 'https://dl.test/pub/rockyfoo/9/x.tar.xz',
        sha256:
            '0000000000000000000000000000000000000000000000000000000000000000',
        sizeBytes: 1,
        layout: LinuxRootfsLayout.plain,
        compression: LinuxRootfsCompression.gzip,
        followsMirror: true,
      );

      expect(
        source.urlOn('https://m.test/rocky', 'https://dl.test/pub/rocky'),
        source.url,
      );
      // And the ordinary case still is swapped.
      expect(
        source.urlOn('https://m.test/x', 'https://dl.test/pub/rockyfoo'),
        'https://m.test/x/9/x.tar.xz',
      );
    });
  });

  group('ordering two release versions', () {
    test('is by number, segment by segment', () {
      expect(compareRootfsVersions('24.04.4', '24.04.3'), greaterThan(0));
      expect(compareRootfsVersions('24.04.3', '24.04.4'), lessThan(0));
      expect(compareRootfsVersions('24.04.3', '24.04.3'), 0);
      // Not by text, which would put 10 before 9.
      expect(compareRootfsVersions('3.10', '3.9'), greaterThan(0));
      // A missing segment is a zero, so a release precedes its own point
      // releases rather than sorting after them.
      expect(compareRootfsVersions('24.04.1', '24.04'), greaterThan(0));
      expect(compareRootfsVersions('24.04', '24.04.0'), 0);
    });

    test('and an update is only ever offered upwards', () {
      // What this is for. `isOutdated` asked whether the two versions were
      // *different*, and a manifest can describe an older release than what is
      // installed — a fetched one that fails verification falls back to the
      // copy compiled into the build. Installing over a profile destroys the
      // tree, so "different" meant a downgrade that took everything with it.
      expect(compareRootfsVersions('24.04.3', '24.04.4'), lessThan(0));
      expect(compareRootfsVersions('24.04.4', '24.04.4'), 0);
    });

    test('a scheme it cannot read gets no answer at all', () {
      // Null, not a comparison of the text. Ordering these by their first
      // letters is a guess, and what the caller does with a positive answer is
      // replace the tree and destroy everything in it — so half the guesses
      // would be the downgrade this function exists to prevent.
      expect(compareRootfsVersions('edge', 'v3'), isNull);
      expect(compareRootfsVersions('v3', 'edge'), isNull);
      expect(compareRootfsVersions('24.04.3', '24.04.edge'), isNull);

      // Which makes it outdated in neither direction: `isOutdated` asks for an
      // ordering and a greater one, and null is neither.
      bool outdated(String manifest, String installed) {
        final order = compareRootfsVersions(manifest, installed);
        return order != null && order > 0;
      }

      expect(outdated('edge', 'v3'), isFalse);
      expect(outdated('v3', 'edge'), isFalse);
    });

    test('but two profiles on the same unreadable scheme are the same', () {
      // Identical text needs no ordering to be equal, so this is not a guess
      // and does not have to be refused.
      expect(compareRootfsVersions('edge', 'edge'), 0);
      expect(compareRootfsVersions('v3.20', 'v3.20'), 0);
    });
  });
}
