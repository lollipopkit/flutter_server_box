import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// A manifest as `shellbox-rootfs` actually produces one.
///
/// The contract between two repositories, which is exactly the kind of thing
/// that drifts silently: the app parses strictly, so a field that repository
/// renames becomes a build that installs nothing, and it would be found on a
/// device rather than here. This fixture is the output of `scripts/build.py`
/// run over all three distributions, copied verbatim.
///
/// Regenerate with, from that repository:
///
///     python3 scripts/build.py --out dist --tag <tag> --serial <n>
///
/// and copy `dist/manifest.json` over this file. It fetches and repacks every
/// release, so it takes a few minutes and about 250 MB — which is the point:
/// a fixture written by hand would assert the shape someone believed that
/// script produces.
void main() {
  late RootfsManifest ci;

  setUpAll(() {
    ci = RootfsManifest.parse(
      File('test/fixtures/rootfs_manifest/ci_produced.json').readAsStringSync(),
    );
  });

  test('it parses, and describes what this build can configure', () {
    expect(ci.schema, RootfsManifest.supportedSchema);
    expect(
      ci.distros.keys.toSet(),
      LinuxDistro.values.map((e) => e.id).toSet(),
    );
  });

  test('every release has a repacked artifact preferred over upstream', () {
    // The point of that repository. If `rootfs` were absent the app would fall
    // back to upstream and none of the normalisation would reach a device.
    // Per release rather than per distribution: a series added to the pins and
    // not to the build would be exactly this, and would install an unrepacked
    // tree without saying so.
    for (final distro in ci.distros.values) {
      for (final release in distro.releases) {
        final where = '${distro.id} ${release.version}';
        expect(release.rootfs, isNotNull, reason: where);
        expect(release.source, same(release.rootfs), reason: where);
      }
    }
  });

  test('it publishes more than one release of something', () {
    // Otherwise the schema is carrying a list to hold one item, and every
    // release-aware path below is asserted only against the shape that has no
    // second element.
    expect(
      ci.distros.values.any((e) => e.releases.length > 1),
      isTrue,
      reason: 'no distribution offers a second release',
    );
  });

  test('no two releases of one distribution share a series', () {
    // Two builds of `noble` would be one picker row hiding another, and the
    // app's "is this an update" answer would depend on manifest order.
    for (final distro in ci.distros.values) {
      final branches = distro.releases.map((e) => e.branch).toList();
      expect(branches.toSet(), hasLength(branches.length), reason: distro.id);
    }
  });

  test('each artifact is named for its own release', () {
    // Two releases of one distribution are two files in one release
    // directory. A name carrying only the distribution would have the second
    // overwrite the first, and both entries would point at whichever the
    // build wrote last.
    final names = <String>[];
    for (final distro in ci.distros.values) {
      for (final release in distro.releases) {
        final name = release.rootfs!.url.split('/').last;
        expect(name, contains(release.version), reason: name);
        names.add(name);
      }
    }
    expect(names.toSet(), hasLength(names.length), reason: '$names');
  });

  test('repacking flattens every image layout', () {
    // Rocky publishes an OCI image and nothing else. Flattening it in CI is
    // what lets the app stop carrying an image reader, so a repacked artifact
    // that was still `oci` would mean the build did not do its job.
    for (final distro in ci.distros.values) {
      for (final release in distro.releases) {
        expect(
          release.rootfs!.layout,
          LinuxRootfsLayout.plain,
          reason: '${distro.id} ${release.version}',
        );
      }
    }
    for (final release in ci.distros['rocky']!.releases) {
      expect(release.upstream.layout, LinuxRootfsLayout.oci);
    }
  });

  test('the repacked artifacts do not follow a mirror', () {
    // They are on one host, which is nobody's distribution mirror. The
    // upstream entry is what a person behind a mirror falls back to, and it
    // keeps whatever that distribution allows.
    for (final distro in ci.distros.values) {
      for (final release in distro.releases) {
        expect(
          release.rootfs!.followsMirror,
          isFalse,
          reason: '${distro.id} ${release.version}',
        );
      }
    }
    expect(ci.distros['alpine']!.preferred.upstream.followsMirror, isTrue);
    expect(ci.distros['ubuntu']!.preferred.upstream.followsMirror, isFalse);
  });

  test('repacking Rocky costs less to download, not more', () {
    // Re-compressing a flattened tree beats an OCI wrapper around a gzipped
    // layer. Measured: 80.8 MB upstream against 48.7 MB repacked. If this ever
    // inverts, the repacked artifact is costing users data for no reason.
    for (final release in ci.distros['rocky']!.releases) {
      expect(
        release.rootfs!.sizeBytes,
        lessThan(release.upstream.sizeBytes),
        reason: release.version,
      );
    }
  });

  test('both sources carry a digest and a size', () {
    for (final distro in ci.distros.values) {
      for (final release in distro.releases) {
        for (final source in [release.rootfs!, release.upstream]) {
          expect(source.sha256, hasLength(64));
          expect(source.sizeBytes, greaterThan(0));
          expect(Uri.parse(source.url).isScheme('https'), isTrue);
        }
      }
    }
  });
}
