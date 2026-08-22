/// Reading an OCI image layout, which is how one distribution ships its rootfs.
///
/// Shared by both platforms rather than owned by either, for the reason
/// `linux_seed.dart` gives: they download the same file, check it against the
/// same digest, and drifted the last time a step was written twice. What they
/// do with the layers afterwards *is* different — iOS unpacks in Dart because
/// it cannot start a process, Android hands each layer to the system `tar` so
/// that symlinks survive — and that difference stays on their side of this.
///
/// Rocky publishes no plain rootfs tarball, only this. An image layout is
/// `index.json` naming a manifest, the manifest naming layers, and the layers
/// being the filesystem.
library;

import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

/// One layer's bytes and how they are packed. A null [compression] is a plain
/// tar, which the specification allows and no image seen so far uses.
typedef OciLayer = ({List<int> bytes, LinuxRootfsCompression? compression});

/// Undoes [how]. The download's outer wrapper and a layer's inner one are the
/// same question asked twice, so they share an answer.
List<int> decompressRootfs(List<int> bytes, LinuxRootfsCompression how) =>
    switch (how) {
      LinuxRootfsCompression.gzip => GZipDecoder().decodeBytes(bytes),
      LinuxRootfsCompression.xz => XZDecoder().decodeBytes(bytes),
    };

/// A layer's tar, decompressed.
List<int> ociLayerTar(OciLayer layer) => layer.compression == null
    ? layer.bytes
    : decompressRootfs(layer.bytes, layer.compression!);

/// The layers of [image], in the order they must be applied.
///
/// Order matters even though today's Rocky base image has exactly one layer —
/// which is precisely the condition under which getting it wrong stays
/// invisible until some future image has two.
List<OciLayer> ociLayers(Archive image) {
  List<int> blob(String digest) {
    // `sha256:abcd…` lives at `blobs/sha256/abcd…`, which is the whole of the
    // mapping an image layout defines between a digest and a file.
    final parts = digest.split(':');
    if (parts.length != 2) {
      throw StateError('The image names a malformed digest: $digest');
    }
    final bytes = image.findFile('blobs/${parts[0]}/${parts[1]}')?.readBytes();
    if (bytes == null) {
      throw StateError('The image is missing the blob $digest');
    }
    return bytes;
  }

  final indexBytes = image.findFile('index.json')?.readBytes();
  if (indexBytes == null) {
    throw StateError('The download is not an OCI image: it has no index.json');
  }
  final index = json.decode(utf8.decode(indexBytes)) as Map<String, dynamic>;
  final manifests = index['manifests'] as List<dynamic>?;
  if (manifests == null || manifests.isEmpty) {
    throw StateError('The image index names no manifest');
  }
  final manifest =
      json.decode(
            utf8.decode(blob((manifests.first as Map)['digest'] as String)),
          )
          as Map<String, dynamic>;

  return [
    for (final layer in (manifest['layers'] as List<dynamic>? ?? const []))
      (
        bytes: blob((layer as Map)['digest'] as String),
        compression: _layerCompression(layer['mediaType'] as String?),
      ),
  ];
}

/// Which compression a layer's media type declares, or null for a plain tar.
///
/// By the declared type rather than by sniffing magic bytes: the image says
/// what it packed, and a layer this build cannot unpack has to fail loudly
/// rather than be fed to the wrong decoder.
LinuxRootfsCompression? _layerCompression(String? mediaType) {
  final type = mediaType ?? '';
  if (type.endsWith('+gzip')) return LinuxRootfsCompression.gzip;
  if (type.endsWith('+zstd')) {
    throw StateError('This image has zstd layers, which are not supported.');
  }
  return null;
}

/// Whether [name] is a whiteout marker, and what it deletes.
///
/// A layer removes a path by carrying a marker in its place rather than by
/// saying so out of band: `.wh.<name>` deletes that sibling, and
/// `.wh..wh..opq` says everything already in this directory is gone. Neither
/// is a file to write; both are instructions.
({bool opaque, String? deletes})? ociWhiteout(String name) {
  if (name == '.wh..wh..opq') return (opaque: true, deletes: null);
  if (name.startsWith('.wh.')) {
    return (opaque: false, deletes: name.substring(4));
  }
  return null;
}
