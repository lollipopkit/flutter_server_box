import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/oci_image.dart';
import 'package:server_box/core/utils/rootfs_tar_utils.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// Unpacks a rootfs archive in Dart, on iOS and on Android alike.
///
/// iOS has no `tar` to run — it will not start a process. Android has one,
/// and it was what unpacked there until it turned out to be the wrong tool:
/// as the app's uid it cannot `link()` in the app's own directory, so every
/// hard link in Ubuntu and Rocky failed (#1697), and it creates a `0555`
/// directory before writing into it, so Rocky's read-only directories failed
/// too. This walks the entries itself and answers both the way iOS always
/// had: a hard link that cannot be made is a relative symlink, and a
/// directory is owner-writable while it is filled.
abstract final class RootfsUnpack {
  /// The most any one decompression may write — see [_CappedOutput].
  static const maxRootfsExpanded = 4 << 30; // 4 GB

  /// Puts the downloaded rootfs on disk, whichever shape it came in.
  ///
  /// [LinuxDistro.compression] and [LinuxDistro.layout] are two axes because
  /// they are two decisions: what decompresses the download, and whether what
  /// falls out is the filesystem or an image describing one.
  static Future<void> extract(
    File archiveFile,
    Directory into, {
    required RootfsSource source,
    void Function(double? progress)? onProgress,
  }) async {
    final stat = await archiveFile.stat();
    const maxArchiveSize = 1024 * 1024 * 1024; // 1 GB
    if (stat.size > maxArchiveSize) {
      throw StateError('Rootfs archive too large (${stat.size} bytes)');
    }
    // Beside the tree being written, so on the same filesystem and in the
    // app's own directory, and gone however this ends.
    final work = await into.parent.createTemp('.unpack-');
    try {
      final outerDecoder = TarDecoder();
      final outerInput = InputFileStream(
        await _decompressed(archiveFile.path, source.compression, work),
      );
      try {
        // Over a file, an entry's contents are a view into it, read when the
        // entry is written out: neither the download nor what it unpacks to
        // is ever held in memory whole.
        final outer = outerDecoder.decodeStream(outerInput);
        switch (source.layout) {
          case LinuxRootfsLayout.plain:
            await _unpackTar(outer, outerDecoder, into, onProgress: onProgress);
          case LinuxRootfsLayout.oci:
            // In order, and each over the last: a later layer's copy of a path
            // replaces an earlier one's, and its whiteouts delete what earlier
            // layers put there.
            var n = 0;
            for (final layer in ociLayers(outer)) {
              final blob = '${work.path}/layer${n++}';
              await _copyOut(layer, blob);
              final how = layer.compression;
              final decoder = TarDecoder();
              final input = InputFileStream(
                how == null ? blob : await _decompressed(blob, how, work),
              );
              try {
                await _unpackTar(
                  decoder.decodeStream(input),
                  decoder,
                  into,
                  applyWhiteouts: true,
                  onProgress: onProgress,
                );
              } finally {
                await input.close();
              }
            }
        }
      } finally {
        await outerInput.close();
      }
    } finally {
      await work.delete(recursive: true);
    }
  }

  /// [from], decompressed into a file in [work], on another isolate: a
  /// rootfs is hundreds of megabytes of inflating, and on the UI isolate that
  /// is the app frozen for as long as it takes.
  static Future<String> _decompressed(
    String from,
    LinuxRootfsCompression how,
    Directory work,
  ) async {
    final to = '${work.path}/${from.split('/').last}.tar';
    await Isolate.run(() {
      final input = InputFileStream(from);
      final output = _CappedOutput(to);
      try {
        final ok = switch (how) {
          LinuxRootfsCompression.gzip => GZipDecoder().decodeStream(
            input,
            output,
          ),
          LinuxRootfsCompression.xz => XZDecoder().decodeStream(
            input,
            output,
            throwOnError: true,
          ),
        };
        if (!ok) throw StateError('The rootfs archive is truncated');
      } finally {
        input.closeSync();
        output.closeSync();
      }
    });
    return to;
  }

  /// [layer] written to [path] a megabyte at a time, and held to its
  /// descriptor on the way.
  static Future<void> _copyOut(OciLayer layer, String path) async {
    final digest = _DigestSink();
    final hashing = sha256.startChunkedConversion(digest);
    final length = await _writeOut(layer.file, path, also: hashing.add);
    hashing.close();
    checkOciBlob(layer, digest.value!, length);
  }

  /// [file]'s contents written to [path] a megabyte at a time, each chunk
  /// also handed to [also]; how many bytes there were.
  ///
  /// Never the whole of it at once: a member of a rootfs can be far larger
  /// than any memory budget, and an image's layer is most of the image.
  static Future<int> _writeOut(
    ArchiveFile file,
    String path, {
    void Function(List<int> chunk)? also,
  }) async {
    final content = file.getContent();
    final output = OutputFileStream(path);
    var length = 0;
    try {
      while (content != null && !content.isEOS) {
        final chunk = content.readBytes(1 << 20).toUint8List();
        output.writeBytes(chunk);
        also?.call(chunk);
        length += chunk.length;
      }
    } finally {
      await output.close();
    }
    return length;
  }

  /// Which entries were hard links, by name, with what they point at.
  ///
  /// The tar reader hands a hard link and a symbolic link to the caller in the
  /// same shape — it sets `symbolicLink` from the header's link name for both,
  /// because both carry one — so the only way to tell them apart is the type
  /// flag, which lives on the decoder's own entries rather than on the archive
  /// it builds.
  ///
  /// Getting this wrong is not a broken file, it is a link pointing nowhere. A
  /// hard link's target is a path from the root of the archive; read as a
  /// symbolic link it resolves relative to the link's own directory instead.
  /// Ubuntu 26.04 ships uutils coreutils as one binary with 115 hard links to
  /// it, so `/usr/bin/ls` became a symlink to a symlink to nothing and the
  /// shell answered `ls: not found` in a system that had `ls`.
  static Map<String, String> _hardLinks(TarDecoder decoder) {
    final links = <String, String>{};
    for (final file in decoder.files) {
      final name = _tarPath(file.filename);
      final target = file.nameOfLinkedFile;
      // The last entry of a name is the one that stands, as tar has it and as
      // the archive keeps it: a link that a later regular file replaced is no
      // link, and nothing may still resolve through it.
      if (file.typeFlag != TarFile.hardLink || target == null || target.isEmpty) {
        links.remove(name);
        continue;
      }
      links[name] = _tarPath(target);
    }
    return links;
  }

  /// `0700`. What a directory needs whatever the archive says, since the guest
  /// runs as one unprivileged host uid and nothing in it is root.
  static const _ownerRwx = 0x1c0;

  // Tar helpers now share rootfs_tar_utils.dart (single source; was duplicated
  // between Android and iOS installers).
  static String _tarPath(String name) => tarPath(name);

  static List<String>? _safeTarParts(String name) => safeTarParts(name);

  static bool _isTarRoot(String name) => isTarRoot(name);

  static bool _isSafeTarEntry(String name) => isSafeTarEntry(name);

  static bool _hasTarLinkAncestor(List<String> parts, Set<String> links) =>
      hasLinkAncestor(parts, links);

  /// Resolves an archive member one component at a time without ever asking
  /// the host filesystem to traverse a symlinked parent.
  static Future<String> _safeTarTarget(Directory into, String name) async {
    final parts = _safeTarParts(name);
    if (parts == null) throw StateError('Unsafe tar entry: $name');
    var parent = into.path;
    for (final segment in parts.take(parts.length - 1)) {
      parent = parent.joinPath(segment);
      switch (await FileSystemEntity.type(parent, followLinks: false)) {
        case FileSystemEntityType.notFound:
          await Directory(parent).create();
          break;
        case FileSystemEntityType.directory:
          break;
        case FileSystemEntityType.link:
          throw StateError('Tar entry has a symlinked parent: $name');
        default:
          throw StateError('Tar entry has a non-directory parent: $name');
      }
    }
    return parent.joinPath(parts.last);
  }

  static Future<void> _removeTarTarget(String path) async {
    switch (await FileSystemEntity.type(path, followLinks: false)) {
      case FileSystemEntityType.notFound:
        return;
      case FileSystemEntityType.directory:
        await Directory(path).delete(recursive: true);
        return;
      case FileSystemEntityType.link:
        await Link(path).delete();
        return;
      default:
        await File(path).delete();
        return;
    }
  }

  static Future<void> _unpackTar(
    Archive archive,
    TarDecoder decoder,
    Directory into, {
    bool applyWhiteouts = false,
    void Function(double? progress)? onProgress,
  }) async {
    final hardLinks = _hardLinks(decoder);
    final symbolicLinks = <String>{};
    for (final entry in archive) {
      if (!entry.isSymbolicLink) continue;
      final parts = _safeTarParts(entry.name);
      if (parts != null && parts.isNotEmpty) symbolicLinks.add(parts.join('/'));
    }
    // What this layer writes, which is what an opaque marker spares. Built up
    // front because the archive is not obliged to put the marker before the
    // entries it applies to, so "has it been written yet" is not the same
    // question as "does this layer write it".
    final written = applyWhiteouts
        ? ociLayerPaths(archive.map((e) => e.name))
        : const <String>{};
    // Applied after everything is written, because an archive may name a link
    // before the file it points at. Ours is sorted and does not, but upstream's
    // ordering is upstream's business.
    final pendingHardLinks = <String, String>{};
    final pendingSymlinks = <String, String>{};
    var done = 0;
    for (final entry in archive) {
      done++;
      if (done % 200 == 0) {
        onProgress?.call(0.9 + (done / archive.length) * 0.1);
      }
      // The archive's own root, which is already there — it is what everything
      // else is being written into.
      if (_isTarRoot(entry.name)) continue;
      if (!_isSafeTarEntry(entry.name)) {
        throw StateError('${libL10n.invalid}: ${libL10n.path} (${entry.name})');
      }
      final entryParts = _safeTarParts(entry.name)!;
      if (_hasTarLinkAncestor(entryParts, symbolicLinks)) {
        throw StateError('${libL10n.invalid}: ${libL10n.path} (${entry.name})');
      }
      final path = await _safeTarTarget(into, entry.name);

      if (applyWhiteouts) {
        final mark = ociWhiteout(entry.name.split('/').last);
        if (mark != null) {
          final parent = Directory(File(path).parent.path);
          final directory = ociParent(entry.name);
          if (mark.opaque) {
            if (await parent.exists()) {
              await for (final child in parent.list(followLinks: false)) {
                // Only what the layers below put here. A sibling this layer
                // writes stays: the marker hides what is underneath it, and
                // deleting the layer's own contents would empty a directory
                // the layer exists to fill.
                final name = child.path.split(Platform.pathSeparator).last;
                final sibling = directory.isEmpty ? name : '$directory/$name';
                if (written.contains(sibling)) continue;
                await child.delete(recursive: true);
              }
            }
          } else {
            final target = parent.path.joinPath(mark.deletes!);
            await _removeTarTarget(target);
          }
          continue;
        }
      }

      // Links as links, never followed. Under `realfs` a guest symlink is
      // resolved inside the guest, so `/bin/sh -> /bin/busybox` means the
      // guest's busybox; written as a copy of whatever the host has at that
      // path it is the wrong file, and skipped it is no file — which is how an
      // earlier attempt booted with no `/bin/sh` to run.
      // Hard links first: the reader marks them symbolic, so asking whether
      // this is a symlink would answer yes for both.
      final hardTarget = hardLinks[_tarPath(entry.name)];
      if (hardTarget != null) {
        if (!_isSafeTarEntry(hardTarget)) {
          throw StateError('${libL10n.invalid}: ${libL10n.path} ($hardTarget)');
        }
        if (_hasTarLinkAncestor(_safeTarParts(hardTarget)!, symbolicLinks)) {
          throw StateError('${libL10n.invalid}: ${libL10n.path} ($hardTarget)');
        }
        pendingHardLinks[_tarPath(entry.name)] = hardTarget;
        continue;
      }

      if (entry.isSymbolicLink) {
        pendingSymlinks[_tarPath(entry.name)] = entry.symbolicLink!;
        continue;
      }
      if (entry.isDirectory) {
        final type = await FileSystemEntity.type(path, followLinks: false);
        if (type != FileSystemEntityType.directory &&
            type != FileSystemEntityType.notFound) {
          await _removeTarTarget(path);
        }
        await Directory(path).create();
        // The tarball's mode, with owner rwx forced on. `realfs` hands the
        // host's mode straight to the guest, and the host process is this app
        // rather than root — so uid 0 in the guest buys nothing, and Rocky's
        // 17 directories at 0555 (`/usr/bin` and `/usr/lib` among them) are
        // ones a package manager cannot create its temp files in. That is the
        // difference between an image that can install packages here and one
        // that cannot.
        //
        // Only that difference, though. Dropping the mode entirely also drops
        // the bits that say something a single-uid guest still reads: `/tmp`
        // is 1777 and becomes 0755, and every `--verify` a package manager
        // offers then reports the directories as altered — which is the same
        // complaint stripping locales would have caused, and the reason
        // `shellbox-rootfs` does not strip them.
        chmodGuestFile(path, (entry.mode & 0xfff) | _ownerRwx);
        continue;
      }
      if (!entry.isFile) {
        // Device nodes, which a tarball carries and no unprivileged process
        // can create. `/dev` is built at boot instead — see the C side.
        continue;
      }
      if (await FileSystemEntity.type(path, followLinks: false) !=
          FileSystemEntityType.notFound) {
        await _removeTarTarget(path);
      }
      await _writeOut(entry, path);
      // The mode the tarball recorded. It matters more here than under
      // `fakefs`: `realfs` reports the host's mode to the guest, so a busybox
      // written 0644 by Dart is a busybox the guest cannot execute.
      //
      // Through libc rather than `chmod(1)`: iOS refuses to start a process,
      // which is the same refusal that put an interpreter on this platform.
      chmodGuestFile(path, entry.mode & 0xfff);
    }

    /// What [name] is a hard link to in the end: a link may name another link,
    /// in either order, and only the end of the chain is something the
    /// archive wrote. Each step was checked when it was recorded.
    String origin(String name) {
      var at = name;
      final seen = {at};
      for (var next = pendingHardLinks[at];
          next != null;
          next = pendingHardLinks[at]) {
        if (!seen.add(next)) {
          throw StateError('${libL10n.invalid}: ${libL10n.file} ($name)');
        }
        at = next;
      }
      return at;
    }

    for (final entry in pendingHardLinks.entries) {
      final path = await _safeTarTarget(into, entry.key);
      final source = origin(entry.key);
      final pendingSymlink = pendingSymlinks[source];
      if (pendingSymlink != null) {
        await _removeTarTarget(path);
        await Link(path).create(pendingSymlink);
        continue;
      }
      final target = await _safeTarTarget(into, source);
      if (await FileSystemEntity.type(target, followLinks: false) !=
          FileSystemEntityType.file) {
        throw StateError('${libL10n.invalid}: ${libL10n.file} ($source)');
      }
      await _removeTarTarget(path);
      if (linkGuestFile(target, path)) continue;
      // A symlink is the fallback, not the intent: same file, one more
      // indirection, and it costs nothing where a copy would cost a gigabyte.
      // Relative to the link's own directory, which is what a symlink means
      // and what reading the hard link as one got wrong in the first place.
      final rel = _relativeTo(File(path).parent.path, target);
      final link = Link(path);
      await link.create(rel);
    }

    // Last, so a link in this layer cannot become the parent through which a
    // later regular file or hard-link fallback is written.
    for (final entry in pendingSymlinks.entries) {
      final path = await _safeTarTarget(into, entry.key);
      await _removeTarTarget(path);
      await Link(path).create(entry.value);
    }
  }

  /// [target] as a path from [from], both absolute.
  static String _relativeTo(String from, String target) {
    final fromParts = from.split(Platform.pathSeparator)
      ..removeWhere((e) => e.isEmpty);
    final toParts = target.split(Platform.pathSeparator)
      ..removeWhere((e) => e.isEmpty);
    var shared = 0;
    while (shared < fromParts.length &&
        shared < toParts.length &&
        fromParts[shared] == toParts[shared]) {
      shared++;
    }
    return [
      ...List.filled(fromParts.length - shared, '..'),
      ...toParts.sublist(shared),
    ].join('/');
  }
}

/// A decompressed file that stops at [maxRootfsExpanded].
///
/// Every byte of a download inflates to disk before a single entry is read,
/// and a small enough input can inflate to whatever the device has free —
/// the app's other data and everyone else's with it. The systems offered
/// today unpack to a few hundred megabytes; this is several times that, and
/// a bound.
final class _CappedOutput extends OutputFileStream {
  _CappedOutput(String path)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));

  void _admit(int bytes) {
    if (length + bytes > RootfsUnpack.maxRootfsExpanded) {
      throw StateError(
        'The rootfs unpacks to more than '
        '${RootfsUnpack.maxRootfsExpanded >> 30} GB',
      );
    }
  }

  @override
  void writeByte(int value) {
    _admit(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _admit(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }
}

/// Where a chunked SHA-256 leaves its answer.
final class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
