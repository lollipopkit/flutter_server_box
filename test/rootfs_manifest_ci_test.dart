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
/// and copy `dist/manifest.json` over this file.
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

  test('every distribution has a repacked artifact preferred over upstream', () {
    // The point of that repository. If `rootfs` were absent the app would fall
    // back to upstream and none of the normalisation would reach a device.
    for (final distro in ci.distros.values) {
      expect(distro.rootfs, isNotNull, reason: distro.id);
      expect(distro.source, same(distro.rootfs), reason: distro.id);
    }
  });

  test('repacking flattens every image layout', () {
    // Rocky publishes an OCI image and nothing else. Flattening it in CI is
    // what lets the app stop carrying an image reader, so a repacked artifact
    // that was still `oci` would mean the build did not do its job.
    for (final distro in ci.distros.values) {
      expect(distro.rootfs!.layout, LinuxRootfsLayout.plain, reason: distro.id);
    }
    expect(ci.distros['rocky']!.upstream.layout, LinuxRootfsLayout.oci);
  });

  test('the repacked artifacts do not follow a mirror', () {
    // They are on one host, which is nobody's distribution mirror. The
    // upstream entry is what a person behind a mirror falls back to, and it
    // keeps whatever that distribution allows.
    for (final distro in ci.distros.values) {
      expect(distro.rootfs!.followsMirror, isFalse, reason: distro.id);
    }
    expect(ci.distros['alpine']!.upstream.followsMirror, isTrue);
    expect(ci.distros['ubuntu']!.upstream.followsMirror, isFalse);
  });

  test('repacking Rocky costs less to download, not more', () {
    // Re-compressing a flattened tree beats an OCI wrapper around a gzipped
    // layer. Measured: 80.8 MB upstream against 48.7 MB repacked. If this ever
    // inverts, the repacked artifact is costing users data for no reason.
    final rocky = ci.distros['rocky']!;
    expect(rocky.rootfs!.sizeBytes, lessThan(rocky.upstream.sizeBytes));
  });

  test('both sources carry a digest and a size', () {
    for (final distro in ci.distros.values) {
      for (final source in [distro.rootfs!, distro.upstream]) {
        expect(source.sha256, hasLength(64));
        expect(source.sizeBytes, greaterThan(0));
        expect(Uri.parse(source.url).isScheme('https'), isTrue);
      }
    }
  });
}
