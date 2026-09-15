import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/oci_image.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// What a layer's whiteout markers delete, and what they leave alone.
///
/// The rule that is easy to get wrong is the opaque one. `.wh..wh..opq` says
/// "what the layers *below* put in this directory is gone" — not "this
/// directory is empty". A layer that masks a directory and then fills it is
/// the ordinary case, and emptying it is a rootfs missing whatever that layer
/// was for.
///
/// It stayed invisible because every image the app installs today has one
/// layer, which is the condition under which a layering bug cannot show. So
/// the image here is built rather than fetched: two layers, which is the
/// smallest thing that has a "below".
void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('sbm-whiteout-');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A gzipped tar of [entries], which is what a layer blob is.
  List<int> layer(Map<String, String> entries) {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.add(ArchiveFile.string(entry.key, entry.value));
    }
    return GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));
  }

  /// An OCI image of [layers], written to a file, as a download would arrive.
  Future<File> imageOf(List<List<int>> layers) async {
    String nameOf(int i) => 'layer$i';
    final manifest = utf8.encode(
      json.encode({
        'schemaVersion': 2,
        'mediaType': 'application/vnd.oci.image.manifest.v1+json',
        'layers': [
          for (var i = 0; i < layers.length; i++)
            {
              'mediaType': 'application/vnd.oci.image.layer.v1.tar+gzip',
              'digest': 'sha256:${nameOf(i)}',
              'size': layers[i].length,
            },
        ],
      }),
    );
    final image = Archive()
      ..add(ArchiveFile.string('oci-layout', '{"imageLayoutVersion":"1.0.0"}'))
      ..add(
        ArchiveFile.string(
          'index.json',
          json.encode({
            'schemaVersion': 2,
            'manifests': [
              {
                'mediaType': 'application/vnd.oci.image.manifest.v1+json',
                'digest': 'sha256:manifest',
              },
            ],
          }),
        ),
      )
      ..add(ArchiveFile.bytes('blobs/sha256/manifest', manifest));
    for (var i = 0; i < layers.length; i++) {
      image.add(ArchiveFile.bytes('blobs/sha256/${nameOf(i)}', layers[i]));
    }

    final file = File('${dir.path}/image.tar.gz');
    await file.writeAsBytes(
      GZipEncoder().encodeBytes(TarEncoder().encodeBytes(image)),
    );
    return file;
  }

  const source = RootfsSource(
    url: 'https://example.test/image.tar.gz',
    sha256: '0000000000000000000000000000000000000000000000000000000000000000',
    sizeBytes: 1,
    layout: LinuxRootfsLayout.oci,
    compression: LinuxRootfsCompression.gzip,
    followsMirror: false,
  );

  Future<Directory> unpack(List<List<int>> layers) async {
    final into = Directory('${dir.path}/root')..createSync(recursive: true);
    await IosRootfs.extract(await imageOf(layers), into, source: source);
    return into;
  }

  test('an opaque marker deletes what the layers below it put there', () {
    // The half that did work. Without it the marker means nothing at all.
    return unpack([
      layer({'etc/old': 'from below', 'etc/keep-me-not': 'also from below'}),
      layer({'etc/.wh..wh..opq': '', 'etc/new': 'from above'}),
    ]).then((into) async {
      expect(File('${into.path}/etc/old').existsSync(), isFalse);
      expect(File('${into.path}/etc/keep-me-not').existsSync(), isFalse);
    });
  });

  test('and spares what the layer carrying it writes', () async {
    // The failure. Everything in the directory was deleted, including the
    // entries this layer was adding, so a layer that masked `/etc` and then
    // filled it left `/etc` empty — and only entries the archive happened to
    // list after the marker survived, which is an ordering no image promises.
    final into = await unpack([
      layer({'etc/old': 'from below'}),
      layer({
        // Deliberately before the marker in the archive, since that is the
        // order under which the bug bit.
        'etc/before': 'from above',
        'etc/.wh..wh..opq': '',
        'etc/after': 'from above',
      }),
    ]);

    expect(File('${into.path}/etc/before').readAsStringSync(), 'from above');
    expect(File('${into.path}/etc/after').readAsStringSync(), 'from above');
    expect(File('${into.path}/etc/old').existsSync(), isFalse);
    // And the marker is not left behind as a file.
    expect(File('${into.path}/etc/.wh..wh..opq').existsSync(), isFalse);
  });

  test('a named marker deletes only its own sibling', () async {
    final into = await unpack([
      layer({'etc/gone': 'x', 'etc/stays': 'y'}),
      layer({'etc/.wh.gone': ''}),
    ]);

    expect(File('${into.path}/etc/gone').existsSync(), isFalse);
    expect(File('${into.path}/etc/stays').readAsStringSync(), 'y');
  });

  test('a later layer may put back what an opaque marker removed', () async {
    final into = await unpack([
      layer({'etc/x': 'first'}),
      layer({'etc/.wh..wh..opq': ''}),
      layer({'etc/x': 'third'}),
    ]);

    expect(File('${into.path}/etc/x').readAsStringSync(), 'third');
  });

  group('a layer path', () {
    test('is compared without the ./ and the trailing /', () {
      // Two spellings of one path that would otherwise not compare equal, and
      // both are ordinary in a tar: `./etc/passwd` for files, `./etc/` for the
      // directory holding them.
      expect(ociPath('./etc/passwd'), 'etc/passwd');
      expect(ociPath('etc/'), 'etc');
      expect(ociPath('./etc/'), 'etc');
      expect(ociPath('etc/passwd'), 'etc/passwd');
    });

    test('the set of them drops what normalises to nothing', () {
      // `./` is the archive naming its own root, which is not a path anything
      // is compared against.
      expect(ociLayerPaths(['./', './etc/', './etc/passwd']), {
        'etc',
        'etc/passwd',
      });
    });
  });
}
