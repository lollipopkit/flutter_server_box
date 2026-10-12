import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
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
  /// image layout's mapping from a digest to a file — and the hex is the
  /// blob's own checksum, which the reader holds it to.
  String hexOf(List<int> bytes) => sha256.convert(bytes).toString();
  String digestOf(List<int> bytes) => 'sha256:${hexOf(bytes)}';

  ArchiveFile blob(List<int> bytes) =>
      ArchiveFile.bytes('blobs/sha256/${hexOf(bytes)}', bytes);

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
            'digest': digestOf(layer.bytes),
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
              'digest': digestOf(manifestBytes),
              'size': manifestBytes.length,
            },
          ],
        });

    final image = Archive()
      ..add(ArchiveFile.string('oci-layout', '{"imageLayoutVersion":"1.0.0"}'))
      ..add(ArchiveFile.string('index.json', index))
      ..add(blob(manifestBytes));
    for (final layer in layers) {
      if (omitBlobs.contains(layer.name)) continue;
      image.add(blob(layer.bytes));
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
      expect(layers.map((e) => e.file.content.single), [1, 2, 3]);
    });

    test('selects the Linux arm64 manifest from a platform index', () {
      List<int> manifest(List<int> layer) => utf8.encode(
        json.encode({
          'schemaVersion': 2,
          'layers': [
            {
              'mediaType': 'application/vnd.oci.image.layer.v1.tar',
              'digest': digestOf(layer),
              'size': layer.length,
            },
          ],
        }),
      );
      final amd64 = manifest(const [1]);
      final arm64 = manifest(const [2]);
      final image = Archive()
        ..add(
          ArchiveFile.string(
            'index.json',
            json.encode({
              'schemaVersion': 2,
              'manifests': [
                {
                  'digest': digestOf(amd64),
                  'size': amd64.length,
                  'platform': {'os': 'linux', 'architecture': 'amd64'},
                },
                {
                  'digest': digestOf(arm64),
                  'size': arm64.length,
                  'platform': {'os': 'linux', 'architecture': 'arm64'},
                },
              ],
            }),
          ),
        )
        ..add(blob(amd64))
        ..add(blob(arm64))
        ..add(blob(const [1]))
        ..add(blob(const [2]));

      expect(ociLayers(image).single.file.content, [2]);
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
      final notAnImage = Archive()
        ..add(ArchiveFile.string('etc/hostname', 'x'));
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

    test('says so when the manifest names no layers at all', () {
      // Read as an empty list this was a rootfs that unpacked to nothing and
      // reported success — a system installed with no files in it, found at
      // the first command rather than here.
      final image = imageWith(layers: const []);

      expect(() => ociLayers(image), throwsStateError);
    });

    test('says so when the manifest is an index rather than an image', () {
      // What a multi-architecture image looks like: the blob the index points
      // at names further manifests, one per platform, and has no `layers`.
      // Following it as if it were an image is how a build ends up unpacking
      // nothing.
      final index = utf8.encode(json.encode({
        'schemaVersion': 2,
        'manifests': [
          {
            'mediaType': 'application/vnd.oci.image.manifest.v1+json',
            'digest': digestOf(const [9]),
            'size': 1,
            'platform': {'architecture': 'arm64', 'os': 'linux'},
          },
        ],
      }));
      final image = Archive()
        ..add(
          ArchiveFile.string(
            'index.json',
            json.encode({
              'schemaVersion': 2,
              'manifests': [
                {
                  'mediaType': 'application/vnd.oci.image.index.v1+json',
                  'digest': digestOf(index),
                  'size': index.length,
                },
              ],
            }),
          ),
        )
        ..add(blob(index));

      expect(() => ociLayers(image), throwsStateError);
    });
  });

  group('a blob', () {
    test('that is not what its descriptor says is refused', () {
      final image = imageWith(
        layers: [
          (
            name: 'l',
            bytes: const [1],
            mediaType: 'application/vnd.oci.image.layer.v1.tar',
          ),
        ],
      );
      // The path its descriptor names, holding something else.
      image.add(ArchiveFile.bytes('blobs/sha256/${hexOf(const [1])}', [2]));

      expect(() => ociLayerTar(ociLayers(image).single), throwsStateError);
    });

    test('whose descriptor gives no size is refused', () {
      final manifest = utf8.encode(json.encode({'schemaVersion': 2}));
      final image = Archive()
        ..add(
          ArchiveFile.string(
            'index.json',
            json.encode({
              'schemaVersion': 2,
              'manifests': [
                {'digest': digestOf(manifest)},
              ],
            }),
          ),
        )
        ..add(blob(manifest));

      expect(() => ociLayers(image), throwsStateError);
    });

    test('named by a digest this cannot check is refused', () {
      final image = imageWith(layers: const [])
        ..add(
          ArchiveFile.string(
            'index.json',
            json.encode({
              'schemaVersion': 2,
              'manifests': [
                {'digest': 'md5:0123456789abcdef'},
              ],
            }),
          ),
        );

      expect(() => ociLayers(image), throwsStateError);
    });
  });

  group("a layer's media type", () {
    Archive of(String mediaType) => imageWith(
      layers: [
        (name: 'l', bytes: const [1], mediaType: mediaType),
      ],
    );

    test("Docker's own spelling of a gzipped layer is one", () {
      // `…tar.gzip`, which is what Docker wrote before the OCI media types
      // existed. It ends in neither `+gzip` nor `+zstd`, so a check written
      // around those two read it as an uncompressed tar and handed gzip bytes
      // to the tar decoder.
      expect(
        ociLayers(
          of('application/vnd.docker.image.rootfs.diff.tar.gzip'),
        ).single.compression,
        LinuxRootfsCompression.gzip,
      );
    });

    test('an unrecognised one is refused, not assumed to be a plain tar', () {
      // The one wrong way to be wrong here. Whatever those bytes are, they are
      // not what the decoder is about to be told they are.
      for (final type in const [
        'application/vnd.oci.image.layer.v1.tar+zstd',
        'application/vnd.docker.image.rootfs.diff.tar.zstd',
        'application/octet-stream',
        '',
      ]) {
        expect(() => ociLayers(of(type)), throwsStateError, reason: type);
      }
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

    test('a marker cannot target its directory or parent', () {
      for (final name in const ['.wh.', '.wh..', '.wh...']) {
        expect(() => ociWhiteout(name), throwsStateError, reason: name);
      }
    });
  });
}
