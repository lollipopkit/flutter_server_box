import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/oci_image.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

/// Reading an OCI image layout, which is how Rocky ships its rootfs and the
/// only shape the app installs that is not simply a tarball.
///
/// Built here rather than fetched: what is under test is the walk from
/// `index.json` to a manifest to layer blobs, and a real image exercises the
/// same walk while taking 85MB and a network to do it. The one thing a real
/// image would add — that a genuine Rocky layout matches these expectations —
/// is pinned by the digest in [LinuxDistro.sha256] instead.
void main() {
  /// `sha256:<hex>` addresses `blobs/sha256/<hex>`, which is the whole of an
  /// image layout's mapping from a digest to a file. The hex here is a name,
  /// not a checksum — nothing in the reader verifies it, and pretending
  /// otherwise in the fixture would suggest it does.
  String digestOf(String name) => 'sha256:$name';

  ArchiveFile blob(String name, List<int> bytes) =>
      ArchiveFile.bytes('blobs/sha256/$name', bytes);

  Archive imageWith({
    required List<({String name, List<int> bytes, String mediaType})> layers,
    String? indexJson,
    Set<String> omitBlobs = const {},
  }) {
    final manifest = {
      'schemaVersion': 2,
      'mediaType': 'application/vnd.oci.image.manifest.v1+json',
      'layers': [
        for (final layer in layers)
          {
            'mediaType': layer.mediaType,
            'digest': digestOf(layer.name),
            'size': layer.bytes.length,
          },
      ],
    };
    final manifestBytes = utf8.encode(json.encode(manifest));
    final index =
        indexJson ??
        json.encode({
          'schemaVersion': 2,
          'manifests': [
            {
              'mediaType': 'application/vnd.oci.image.manifest.v1+json',
              'digest': digestOf('manifest'),
            },
          ],
        });

    final image = Archive()
      ..add(ArchiveFile.string('oci-layout', '{"imageLayoutVersion":"1.0.0"}'))
      ..add(ArchiveFile.string('index.json', index))
      ..add(blob('manifest', manifestBytes));
    for (final layer in layers) {
      if (omitBlobs.contains(layer.name)) continue;
      image.add(blob(layer.name, layer.bytes));
    }
    return image;
  }

  group('ociLayers', () {
    test('returns the layers in the order the manifest lists them', () {
      // Order is the whole contract and today's Rocky image has one layer,
      // which is exactly the condition under which getting it wrong stays
      // invisible. Three, deliberately not in alphabetical or digest order.
      final image = imageWith(
        layers: [
          (
            name: 'ccc',
            bytes: const [1],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
          (
            name: 'aaa',
            bytes: const [2],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
          (
            name: 'bbb',
            bytes: const [3],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
        ],
      );

      final layers = ociLayers(image);
      expect(layers.map((e) => e.bytes.single), [1, 2, 3]);
    });

    test('reads compression from the declared media type', () {
      final image = imageWith(
        layers: [
          (
            name: 'plain',
            bytes: const [1],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
          (
            name: 'gz',
            bytes: const [2],
            mediaType: 'application/vnd.oci.image.layer.v1.tar+gzip',
          ),
        ],
      );

      final layers = ociLayers(image);
      expect(layers[0].compression, isNull);
      expect(layers[1].compression, LinuxRootfsCompression.gzip);
    });

    test('refuses zstd layers rather than feeding them to a gzip decoder', () {
      final image = imageWith(
        layers: [
          (
            name: 'zstd',
            bytes: const [1],
            mediaType: 'application/vnd.oci.image.layer.v1.tar+zstd',
          ),
        ],
      );

      expect(() => ociLayers(image), throwsStateError);
    });

    test('a gzip layer round-trips through ociLayerTar', () {
      final payload = utf8.encode('a layer, of a sort');
      final image = imageWith(
        layers: [
          (
            name: 'gz',
            bytes: GZipEncoder().encodeBytes(payload),
            mediaType: 'application/vnd.oci.image.layer.v1.tar+gzip',
          ),
        ],
      );

      expect(ociLayerTar(ociLayers(image).single), payload);
    });

    test('a plain layer is handed back untouched', () {
      final payload = utf8.encode('already a tar');
      final image = imageWith(
        layers: [
          (
            name: 'plain',
            bytes: payload,
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
        ],
      );

      expect(ociLayerTar(ociLayers(image).single), payload);
    });

    test('says so when the download is not an image layout', () {
      // What a plain rootfs tarball would look like if a distribution's layout
      // were ever set to `oci` by mistake: real files, no index.json.
      final notAnImage = Archive()..add(ArchiveFile.string('etc/hostname', 'x'));
      expect(() => ociLayers(notAnImage), throwsStateError);
    });

    test('says so when the index names no manifest', () {
      final image = imageWith(
        layers: const [],
        indexJson: json.encode({'schemaVersion': 2, 'manifests': []}),
      );
      expect(() => ociLayers(image), throwsStateError);
    });

    test('says so when a blob the manifest names is missing', () {
      // The manifest still lists it; the blob simply is not in the archive,
      // which is what a truncated or partly-written download looks like.
      final image = imageWith(
        layers: [
          (
            name: 'gone',
            bytes: const [1],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
        ],
        omitBlobs: const {'gone'},
      );

      expect(() => ociLayers(image), throwsStateError);
    });
  });

  group('ociWhiteout', () {
    test('an ordinary name is not a marker', () {
      expect(ociWhiteout('bin'), isNull);
      // Near misses, because the check is a prefix and these are not it.
      expect(ociWhiteout('wh.bin'), isNull);
      expect(ociWhiteout('.whatever'), isNull);
    });

    test('.wh.<name> deletes that sibling', () {
      final mark = ociWhiteout('.wh.bin');
      expect(mark?.opaque, false);
      expect(mark?.deletes, 'bin');
    });

    test('the opaque marker is not read as deleting a file called wh..opq', () {
      // It starts with `.wh.` too, so the order of these two checks is what
      // keeps the directory-wide case from being read as a single deletion.
      final mark = ociWhiteout('.wh..wh..opq');
      expect(mark?.opaque, true);
      expect(mark?.deletes, isNull);
    });
  });
}
