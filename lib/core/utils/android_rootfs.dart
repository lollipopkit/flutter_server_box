import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/utils/guest_path.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/oci_image.dart';
import 'package:server_box/core/utils/rootfs_lifecycle.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

final class _TarValidationEntry {
  const _TarValidationEntry(this.name, this.type, this.linkTarget);

  final String name;
  final String type;
  final String? linkTarget;
}

/// Incrementally keeps only tar headers and extended path metadata while a
/// gzip stream is decoded. File payloads are skipped, so validation does not
/// need a second uncompressed archive on disk or in memory.
final class _TarValidationParser {
  static const _blockSize = 512;
  static const _maxMetadataSize = 1024 * 1024;

  final entries = <_TarValidationEntry>[];
  final _header = Uint8List(_blockSize);
  final _globalPax = <String, String>{};
  int _headerLength = 0;
  int _payloadRemaining = 0;
  int _paddingRemaining = 0;
  BytesBuilder? _metadata;
  String? _metadataType;
  String? _longName;
  String? _longLink;
  Map<String, String>? _localPax;
  bool _ended = false;

  void add(List<int> bytes) {
    var offset = 0;
    while (offset < bytes.length && !_ended) {
      if (_headerLength < _blockSize) {
        final needed = _blockSize - _headerLength;
        final available = bytes.length - offset;
        final count = needed < available ? needed : available;
        _header.setRange(_headerLength, _headerLength + count, bytes, offset);
        _headerLength += count;
        offset += count;
        if (_headerLength == _blockSize) _beginEntry();
        continue;
      }

      if (_payloadRemaining > 0) {
        final available = bytes.length - offset;
        final count = _payloadRemaining < available
            ? _payloadRemaining
            : available;
        _metadata?.add(bytes.sublist(offset, offset + count));
        _payloadRemaining -= count;
        offset += count;
        continue;
      }

      if (_paddingRemaining > 0) {
        final available = bytes.length - offset;
        final count = _paddingRemaining < available
            ? _paddingRemaining
            : available;
        _paddingRemaining -= count;
        offset += count;
        continue;
      }

      _finishEntry();
    }
  }

  void finish() {
    if (_ended) return;
    if (_headerLength == 0) return;
    if (_headerLength != _blockSize ||
        _payloadRemaining != 0 ||
        _paddingRemaining != 0) {
      throw const FormatException('Truncated tar archive');
    }
    _finishEntry();
  }

  void _beginEntry() {
    if (_header.every((byte) => byte == 0)) {
      _ended = true;
      return;
    }

    final size = _parseNumber(_header, 124, 12);
    final type = String.fromCharCode(_header[156]);
    final name = _headerName(_header);
    final linkTarget = _parseString(_header, 157, 100);
    final metadata =
        type == 'g' ||
        type == 'G' ||
        type == 'x' ||
        type == 'X' ||
        type == 'L' ||
        type == 'K' ||
        name == '././@LongLink';
    if (metadata && size > _maxMetadataSize) {
      throw const FormatException('Tar path metadata is too large');
    }

    _payloadRemaining = size;
    _paddingRemaining = size % _blockSize == 0
        ? 0
        : _blockSize - (size % _blockSize);
    if (metadata) {
      _metadata = BytesBuilder(copy: false);
      _metadataType = type;
      return;
    }

    final pax = <String, String>{..._globalPax, ...?_localPax};
    entries.add(
      _TarValidationEntry(
        pax['path'] ?? _longName ?? name,
        type,
        pax['linkpath'] ?? _longLink ?? linkTarget.selfNotEmptyOrNull,
      ),
    );
    _localPax = null;
    _longName = null;
    _longLink = null;
  }

  void _finishEntry() {
    final metadata = _metadata;
    if (metadata != null) {
      final data = metadata.takeBytes();
      switch (_metadataType) {
        case 'g' || 'G':
          _globalPax.addAll(_parsePax(data));
        case 'x' || 'X':
          _localPax = _parsePax(data);
        case 'K':
          _longLink = _decodeMetadata(data);
        default:
          _longName = _decodeMetadata(data);
      }
    }
    _metadata = null;
    _metadataType = null;
    _payloadRemaining = 0;
    _paddingRemaining = 0;
    _headerLength = 0;
  }

  static String _headerName(Uint8List header) {
    final name = _parseString(header, 0, 100);
    final prefix = _parseString(header, 345, 155);
    return prefix.isEmpty ? name : '$prefix/$name';
  }

  static String _parseString(Uint8List bytes, int offset, int length) {
    var end = offset;
    final limit = offset + length;
    while (end < limit && bytes[end] != 0) {
      end++;
    }
    return utf8.decode(bytes.sublist(offset, end), allowMalformed: true);
  }

  static int _parseNumber(Uint8List bytes, int offset, int length) {
    final first = bytes[offset];
    if (first & 0x80 != 0) {
      if (first & 0x40 != 0) {
        throw const FormatException('Negative tar size');
      }
      var value = first & 0x3f;
      for (var i = offset + 1; i < offset + length; i++) {
        value = (value << 8) | bytes[i];
      }
      return value;
    }
    final raw = ascii
        .decode(bytes.sublist(offset, offset + length), allowInvalid: true)
        .replaceAll('\u0000', '')
        .trim();
    if (raw.isEmpty) return 0;
    final value = int.tryParse(raw, radix: 8);
    if (value == null || value < 0) {
      throw const FormatException('Invalid tar size');
    }
    return value;
  }

  static String _decodeMetadata(Uint8List bytes) {
    var end = bytes.length;
    while (end > 0 && (bytes[end - 1] == 0 || bytes[end - 1] == 10)) {
      end--;
    }
    return utf8.decode(bytes.sublist(0, end), allowMalformed: true);
  }

  static Map<String, String> _parsePax(Uint8List bytes) {
    final values = <String, String>{};
    var offset = 0;
    while (offset < bytes.length) {
      final space = bytes.indexOf(32, offset);
      if (space < 0) throw const FormatException('Invalid pax record');
      final length = int.tryParse(ascii.decode(bytes.sublist(offset, space)));
      if (length == null || length <= space - offset + 1) {
        throw const FormatException('Invalid pax record length');
      }
      final end = offset + length;
      if (end > bytes.length) {
        throw const FormatException('Truncated pax record');
      }
      final recordEnd = bytes[end - 1] == 10 ? end - 1 : end;
      final record = utf8.decode(
        bytes.sublist(space + 1, recordEnd),
        allowMalformed: true,
      );
      final equals = record.indexOf('=');
      if (equals > 0) {
        values[record.substring(0, equals)] = record.substring(equals + 1);
      }
      offset = end;
    }
    return values;
  }
}

/// A Linux userland on Android, and what it takes to get one.
///
/// Android's own shell is toybox: no package manager, and a good deal less
/// than any of the servers this app talks to. An Alpine rootfs is a real one —
/// and it cannot simply be unpacked and run, because an app targeting API 29
/// or later may not `execve` a file in its own data directory.
///
/// proot is what gets around that, and not by asking for permission: it never
/// uses `execve` on a guest binary. It carries a loader that maps the guest ELF
/// and hands control to the guest's own interpreter, so nothing on the host has
/// to be able to run a musl binary — Android's linker cannot, which is
/// measured in `integration_test/android_exec_test.dart`.
///
/// proot itself is shipped in the native library directory, the one place an
/// app may execute from. It is built by `scripts/build-proot-android.sh`, is
/// not in this repository, and is absent from any build that did not run it —
/// hence [isAvailable] rather than an assumption. It is built for arm64 alone,
/// as is the rootfs, so [isAvailable] is also how a 32-bit or x86 device says
/// no: there is no `libproot.so` in its own ABI's directory to find.
abstract final class AndroidRootfs {
  static final _lifecycle = RootfsLifecycle();
  static final _activeProfiles = <String, int>{};

  static int openSessions(String profileId) => _activeProfiles[profileId] ?? 0;

  /// What this build would install, pinned and checked by [LinuxDistro]. The
  /// tarball is executable code fetched over the network and then run; the
  /// digest is the only thing that makes that different from running whatever
  /// the connection handed back.
  ///
  /// Alpine's branch is 3.22 rather than the newest, and that is not for want
  /// of updating: 3.23 and later ship apk-tools 3, whose network fetches fail
  /// under proot on Android with `Permission denied` on every repository —
  /// measured on API 36, where the same rootfs installs happily from a local
  /// file repository and busybox `wget` fetches the same URLs over both HTTP
  /// and HTTPS. Cause not established. 3.22 is the last branch with apk-tools
  /// 2.14, which works; `integration_test/rootfs_shell_test.dart` installs a
  /// package over the network and is what would notice this changing.
  static String get version => linuxDistro().version;

  /// The directory the rootfs trees live in, one subdirectory each.
  ///
  /// Internal storage. `Paths.doc` is external on Android and mounted
  /// `noexec`, so a rootfs there could never run even under proot.
  static String? _container;
  static String? _proot;
  static String? _loader;

  /// Where the selected rootfs lives, or null before [prepare].
  static String? get root => rootOf(selected?.id);

  /// Where one profile's tree is.
  static String? rootOf(String? id) =>
      id == null ? null : _container?.joinPath(id);

  /// Whether this build carries proot at all.
  static bool get isAvailable => _proot != null && _loader != null;

  /// Whether there is anything to enter at all.
  static Future<bool> get isInstalled async {
    await scan();
    return _profiles.isNotEmpty;
  }

  /// Reads the container: one profile per subdirectory that holds a rootfs.
  ///
  /// The directory listing is the list, for the reason iOS's is — a profile
  /// deleted from disk cannot linger in it.
  static Future<void> scan() => _lifecycle.run(_scan);

  static Future<void> _scan() async {
    final container = _container;
    if (container == null) {
      _profiles.clear();
      return;
    }
    // Built beside the list rather than in it. [profiles] and [selected] are
    // synchronous because what reads them is a widget being built, and every
    // frame drawn between the clear and the last await used to see nothing
    // installed — no chips, no rail rows, and `open` refusing for want of an
    // id. Renaming one was enough to hit it.
    final found = <LinuxProfile>[];
    final dir = Directory(container);
    if (!await dir.exists()) {
      _profiles.clear();
      return;
    }
    final entries = await dir.list(followLinks: false).toList();
    entries.sort((a, b) => a.path.compareTo(b.path));
    for (final entry in entries) {
      if (entry is! Directory) continue;
      final id = entry.path.split(Platform.pathSeparator).last;
      if (id.startsWith('.')) continue;
      final marker = File(entry.path.joinPath(LinuxProfile.marker));
      // The marker rather than [looksUnpacked]: here it is written last and its
      // presence is what says the extraction finished.
      if (!await marker.exists()) continue;
      found.add(LinuxProfile.decode(id, await marker.readAsString()));
    }
    _profiles
      ..clear()
      ..addAll(found);
  }

  /// The last answer [isInstalled] gave, without asking the filesystem again.
  ///
  /// A synchronous question, because the callers that decide whether to *offer*
  /// the rootfs — building the Agent's instructions, listing what a target can
  /// do — are on paths that cannot await one, and a file check per prompt would
  /// be answering the same question a hundred times. Kept true by the two
  /// things that change it, [install] and [remove].
  static bool get isReady => isAvailable && _profiles.isNotEmpty;

  /// Every rootfs unpacked in the container.
  static List<LinuxProfile> get profiles => List.unmodifiable(_profiles);
  static final _profiles = <LinuxProfile>[];

  /// The one the settings point at, or the first there is.
  static LinuxProfile? get selected {
    if (_profiles.isEmpty) return null;
    final id = linuxProfileId();
    return _profiles.firstWhereOrNull((e) => e.id == id) ?? _profiles.first;
  }

  /// Locates proot and the rootfs. Call once, before anything asks.
  static Future<void> prepare() async {
    if (!isAndroid) return;
    _container = (await getApplicationSupportDirectory()).path.joinPath(
      'linux',
    );

    // Whether proot is here decides whether a system can be *run*, which is
    // what `isAvailable` answers. It does not decide whether one is installed,
    // so scanning and seeding happen either way: returning early left
    // `_profiles` empty and every installed system invisible — reported as
    // "nothing installed" rather than "nothing to run it with".
    final libDir = await MethodChans.nativeLibDir();
    if (libDir != null) {
      final proot = libDir.joinPath('libproot.so');
      final loader = libDir.joinPath('libproot-loader.so');
      // Both, or neither is any use: without the loader proot falls back to a
      // plain `execve` and is refused by the very rule it exists to avoid.
      if (await File(proot).exists() && await File(loader).exists()) {
        _proot = proot;
        _loader = loader;
      }
    }
    await _lifecycle.run(() async {
      await _scan();
      for (final profile in _profiles) {
        final root = rootOf(profile.id);
        if (root == null) continue;
        // Repairs a rootfs unpacked before either existed, and carries a fix to
        // the script itself into one already installed. Writes the resolver only
        // when absent, so one pointed at its owner's own keeps it.
        await seedResolvConf(root, nameservers: linuxNameservers());
        await seedChsh(root);
      }
    });
  }

  /// Downloads and unpacks the rootfs.
  ///
  /// [onProgress] is fed a fraction, or null while the size is unknown.
  /// [replace] unpacks over whatever is there, for the version pin having
  /// moved. Everything installed into the old one goes with it.
  static Future<LinuxProfile> install({
    required LinuxDistro distro,
    RootfsRelease? release,
    LinuxProfile? into,
    String? label,
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) => _lifecycle.run(
    () => _install(
      distro: distro,
      release: release,
      into: into,
      label: label,
      onProgress: onProgress,
      cancel: cancel,
    ),
  );

  static Future<LinuxProfile> _install({
    required LinuxDistro distro,
    RootfsRelease? release,
    LinuxProfile? into,
    String? label,
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final container = _container;
    if (container == null) {
      throw StateError('AndroidRootfs.prepare was not called');
    }
    await _scan();

    if (into != null &&
        _profiles.firstWhereOrNull((e) => e.id == into.id) != into) {
      throw StateError('The Linux system is no longer installed');
    }

    final id =
        into?.id ?? LinuxProfile.nextId(distro, _profiles.map((e) => e.id));
    if ((_activeProfiles[id] ?? 0) > 0) {
      throw StateError('The Linux system is still in use');
    }
    final root = container.joinPath(id);
    final stagingRoot = container.joinPath(
      '.$id.install-${ShortId.generate()}',
    );
    final mirror = linuxMirror(distro);
    // Read once, for the reason the mirror is.
    final chosen = release ?? distro.preferred;

    final dir = Directory(stagingRoot);
    // Build the replacement beside the live tree. A cancelled download,
    // digest mismatch, or extraction failure must leave the last good system
    // untouched.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final archive = stagingRoot.joinPath('rootfs.tar.gz');
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
      final downloadCancel = cancel ?? CancelToken();
      final sizeLimit = chosen.source.sizeBytes;
      try {
        await dio.download(
          chosen.source.urlOn(mirror, distro.defaultMirror),
          archive,
          cancelToken: downloadCancel,
          onReceiveProgress: (got, total) {
            if (got > sizeLimit && !downloadCancel.isCancelled) {
              downloadCancel.cancel(
                StateError('Rootfs archive exceeded $sizeLimit bytes'),
              );
              return;
            }
            onProgress?.call(total > 0 ? got / total : null);
          },
        );
      } on DioException catch (e) {
        final reason = e.error;
        if (e.type == DioExceptionType.cancel && reason is StateError) {
          throw reason;
        }
        rethrow;
      }

      final digest = await _sha256Of(File(archive));
      if (digest != chosen.source.sha256) {
        throw StateError(
          'The rootfs did not match its digest and was discarded. '
          'Expected ${chosen.source.sha256}, got $digest.',
        );
      }

      await _unpack(archive, stagingRoot, source: chosen.source);

      await seedResolvConf(stagingRoot, nameservers: linuxNameservers());
      await seedRepositories(
        stagingRoot,
        distro: distro,
        release: chosen,
        mirror: mirror,
      );
      await seedChsh(stagingRoot, force: true);
      final profile = LinuxProfile(
        id: id,
        distro: distro,
        version: chosen.version,
        branch: chosen.branch,
        label: label ?? into?.label ?? distro.label,
      );
      await (await rootfsFileForWrite(
        stagingRoot,
        '/${LinuxProfile.marker}',
      )).writeAsString(profile.encode());
      await _commitInstall(stagingRoot, root, replacing: into != null);
      await _scan();
      return profile;
    } catch (_) {
      // Nothing half-installed is left to be mistaken for a working one.
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    } finally {
      final leftover = File(archive);
      if (await leftover.exists()) await leftover.delete();
    }
  }

  static Future<void> _commitInstall(
    String stagingRoot,
    String root, {
    required bool replacing,
  }) async {
    final rootType = await FileSystemEntity.type(root, followLinks: false);
    if (replacing && rootType != FileSystemEntityType.directory) {
      throw StateError('The Linux system changed while it was being replaced');
    }
    if (!replacing && rootType != FileSystemEntityType.notFound) {
      throw StateError('The Linux system destination already exists');
    }

    final previous = '$root.previous-${ShortId.generate()}';
    var movedPrevious = false;
    if (rootType == FileSystemEntityType.directory) {
      await Directory(root).rename(previous);
      movedPrevious = true;
    }
    try {
      await Directory(stagingRoot).rename(root);
    } catch (_) {
      if (movedPrevious) await Directory(previous).rename(root);
      rethrow;
    }
    if (movedPrevious) {
      try {
        await Directory(previous).delete(recursive: true);
      } catch (e, s) {
        Loggers.app.warning('Could not remove previous Linux system', e, s);
      }
    }
  }

  /// Puts the downloaded rootfs on disk, whichever shape it came in.
  ///
  /// The writing is done by the system's own tar, not a Dart one. It is a
  /// system binary so it may execute, it is far faster on a few thousand
  /// files, and — the part that matters — it restores the symlinks that make
  /// `/bin/sh` a name for busybox. A rootfs whose links became copies is a
  /// rootfs of one program pretending to be two hundred.
  ///
  /// It is only ever handed a plain or gzipped tar, though. Anything else is
  /// decompressed here first, so nothing depends on which compressors a given
  /// device's toybox happens to have been built with — `-J` in particular is
  /// not something to discover the absence of on a user's phone.
  static Future<void> _unpack(
    String archivePath,
    String root, {
    required RootfsSource source,
  }) async {
    switch (source.layout) {
      case LinuxRootfsLayout.plain:
        if (source.compression == LinuxRootfsCompression.gzip) {
          await _validatedTar(archivePath, root, gzip: true);
        } else {
          await _withTemp(
            '$archivePath.tar',
            decompressRootfs(
              await File(archivePath).readAsBytes(),
              source.compression,
            ),
            (path) => _validatedTar(path, root, gzip: false),
          );
        }
      case LinuxRootfsLayout.oci:
        final image = TarDecoder().decodeBytes(
          decompressRootfs(
            await File(archivePath).readAsBytes(),
            source.compression,
          ),
        );
        var n = 0;
        for (final layer in ociLayers(image)) {
          await _withTemp('$archivePath.layer${n++}', ociLayerTar(layer), (
            path,
          ) async {
            // What this layer writes, asked of the archive rather than of the
            // tree: after extraction the two are indistinguishable, and the
            // difference is exactly what an opaque marker turns on.
            final written = ociLayerPaths(await _tarList(path));
            await _validatedTar(path, root, gzip: false);
            // Between layers, not at the end: a marker in this layer deletes
            // what the one below it wrote, and the layer above may put the
            // same path back.
            await _applyWhiteouts(root, written);
          });
        }
    }
    await _makeDirsWritable(root);
  }

  /// Writes [bytes] to [path], runs [use], and removes it either way.
  static Future<void> _withTemp(
    String path,
    List<int> bytes,
    Future<void> Function(String path) use,
  ) async {
    final file = File(path);
    await file.writeAsBytes(bytes);
    try {
      await use(path);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  /// The names in [archivePath], as the archive spells them.
  ///
  /// Asked of the same tar that unpacks it, so the two cannot disagree about
  /// what is in there. Cheaper than it looks — this reads headers and skips
  /// the data — and it replaces a recursive walk of the whole extracted tree.
  static Future<List<String>> _tarList(String archivePath) async {
    final res = await Process.run('/system/bin/tar', ['tf', archivePath]);
    if (res.exitCode != 0) {
      throw StateError('Could not read the rootfs layer: ${res.stderr}');
    }
    return LineSplitter.split(
      res.stdout as String,
    ).where((e) => e.isNotEmpty).toList();
  }

  static Future<void> _validatedTar(
    String archivePath,
    String root, {
    required bool gzip,
  }) async {
    if (gzip) {
      await _validateGzipTar(archivePath, root);
    } else {
      await _validateTar(archivePath, root);
    }
    await _tar(archivePath, root, gzip: gzip);
  }

  @visibleForTesting
  static Future<void> validateTarForTest(File archive, Directory root) =>
      _validateTar(archive.path, root.path);

  @visibleForTesting
  static Future<void> validateGzipTarForTest(File archive, Directory root) =>
      _validateGzipTar(archive.path, root.path);

  static Future<void> _validateGzipTar(String archivePath, String root) async {
    final parser = _TarValidationParser();
    await for (final chunk in File(
      archivePath,
    ).openRead().transform(GZipCodec().decoder)) {
      parser.add(chunk);
    }
    parser.finish();
    await _validateEntries(parser.entries, root);
  }

  /// The components [name] names inside the root, or null where it escapes.
  ///
  /// Empty is neither: it is the archive's own root, and the two have to be
  /// told apart. `tar czf` writes a `./` member first and almost every rootfs
  /// tarball therefore starts with one — read as an escape, that refused the
  /// whole archive on its first entry.
  static List<String>? _safeTarParts(String name) {
    var value = name;
    while (value.startsWith('./')) {
      value = value.substring(2);
    }
    if (value.startsWith('/')) return null;
    final parts = <String>[];
    for (final segment in value.split('/')) {
      if (segment.isEmpty || segment == '.') continue;
      if (segment == '..') {
        if (parts.isEmpty) return null;
        parts.removeLast();
      } else {
        parts.add(segment);
      }
    }
    return parts;
  }

  static bool _hasLinkAncestor(List<String> parts, Set<String> links) {
    for (var i = 1; i < parts.length; i++) {
      if (links.contains(parts.take(i).join('/'))) return true;
    }
    return false;
  }

  static Future<bool> _hasExistingLinkAncestor(
    String root,
    List<String> parts,
  ) async {
    var parent = root;
    for (final segment in parts.take(parts.length - 1)) {
      parent = parent.joinPath(segment);
      final type = await FileSystemEntity.type(parent, followLinks: false);
      if (type == FileSystemEntityType.link) return true;
      if (type == FileSystemEntityType.notFound) return false;
      if (type != FileSystemEntityType.directory) return true;
    }
    return false;
  }

  static Future<void> _validateTar(String archivePath, String root) async {
    final input = InputFileStream(archivePath);
    final decoder = TarDecoder();
    try {
      decoder.decodeStream(input, storeData: false);
      await _validateEntries(
        decoder.files
            .map(
              (entry) => _TarValidationEntry(
                entry.filename,
                entry.typeFlag,
                entry.nameOfLinkedFile,
              ),
            )
            .toList(),
        root,
      );
    } finally {
      input.closeSync();
    }
  }

  static Future<void> _validateEntries(
    List<_TarValidationEntry> entries,
    String root,
  ) async {
    final links = <String>{};
    for (final entry in entries) {
      if (entry.type != TarFile.symbolicLink) continue;
      final parts = _safeTarParts(entry.name);
      // Empty names the root, which is not something a symlink may be.
      if (parts == null || parts.isEmpty) {
        throw StateError('Unsafe tar entry: ${entry.name}');
      }
      links.add(parts.join('/'));
    }

    for (final entry in entries) {
      final parts = _safeTarParts(entry.name);
      if (parts == null) throw StateError('Unsafe tar entry: ${entry.name}');
      // The archive's own root: already there, and no ancestor to check.
      if (parts.isEmpty) continue;
      if (_hasLinkAncestor(parts, links) ||
          await _hasExistingLinkAncestor(root, parts)) {
        throw StateError('Unsafe tar entry: ${entry.name}');
      }
      if (entry.type != TarFile.hardLink) continue;
      final target = entry.linkTarget;
      final targetParts = target == null ? null : _safeTarParts(target);
      // Empty names the root, which is not something a hard link may point at.
      if (targetParts == null ||
          targetParts.isEmpty ||
          links.contains(targetParts.join('/')) ||
          _hasLinkAncestor(targetParts, links) ||
          await _hasExistingLinkAncestor(root, targetParts)) {
        throw StateError('Unsafe hardlink target: $target');
      }
    }
  }

  static Future<void> _tar(
    String archivePath,
    String root, {
    required bool gzip,
  }) async {
    final res = await Process.run('/system/bin/tar', [
      gzip ? 'xzf' : 'xf',
      archivePath,
      '-C',
      root,
    ]);
    if (res.exitCode != 0) {
      throw StateError('Could not unpack the rootfs: ${res.stderr}');
    }
  }

  /// Acts on the whiteout markers tar has just written out as ordinary files.
  ///
  /// It writes them as files because that is what they are in the archive;
  /// only a reader of the image knows one means "delete this". iOS acts on
  /// them while unpacking, which it can because it walks the entries itself —
  /// this is the same rule reached from the other side, sharing
  /// [ociWhiteout] so the two cannot disagree about what a marker is.
  ///
  /// [written] is what this layer's archive contains, which is both where the
  /// markers are found and what an opaque one spares.
  static Future<void> _applyWhiteouts(String root, Set<String> written) async {
    for (final relative in written) {
      final mark = ociWhiteout(relative.split('/').last);
      if (mark == null) continue;
      final path = root.joinPath(relative);
      final parent = File(path).parent;
      if (mark.opaque) {
        if (!await parent.exists()) continue;
        final directory = ociParent(relative);
        await for (final child in parent.list(followLinks: false)) {
          if (child.path == path) continue;
          // Only what the layers below put here. A sibling this layer writes
          // stays — the marker hides what is underneath it, and deleting the
          // layer's own contents would empty a directory the layer exists to
          // fill.
          final name = child.path.split(Platform.pathSeparator).last;
          final sibling = directory.isEmpty ? name : '$directory/$name';
          if (written.contains(sibling)) continue;
          await child.delete(recursive: true);
        }
      } else {
        final target = parent.path.joinPath(mark.deletes!);
        await _removeWithoutFollowing(target);
      }
      final marker = File(path);
      if (await marker.exists()) await marker.delete();
    }
  }

  static Future<void> _removeWithoutFollowing(String path) async {
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

  /// Gives every directory back its owner-write bit.
  ///
  /// Rocky ships 17 of them at 0555, `/usr/bin` and `/usr/lib` among them.
  /// proot presents the guest as root but the kernel still checks the app's
  /// real uid, so a package manager cannot create its temp files there and
  /// every install fails partway through unpacking — `rpm` reports it as
  /// `cpio: open failed`, which reads as a broken download.
  ///
  /// Not needed on iOS, which creates directories itself and never applies the
  /// recorded mode; here tar does apply it, so this undoes that much.
  static Future<void> _makeDirsWritable(String root) async {
    const ownerWrite = 0x80; // S_IWUSR
    await for (final entry in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (entry is! Directory) continue;
      final mode = (await entry.stat()).mode;
      if (mode & ownerWrite != 0) continue;
      chmodGuestFile(entry.path, (mode & 0xfff) | ownerWrite);
    }
  }

  /// Rewrites the resolver and repository files of a rootfs already on disk.
  ///
  /// Both are seeded at install and never again, so a mirror or a resolver
  /// changed afterwards would otherwise only take effect on the next install —
  /// which means downloading the release again and losing everything `apk` put
  /// in the old one.
  ///
  /// Written for the distribution *on disk*, not the one the setting names:
  /// with a switch pending, the repositories file apt or apk is about to read
  /// still belongs to the tree that is there.
  static Future<void> applyNetSettings() => _lifecycle.run(_applyNetSettings);

  static Future<void> _applyNetSettings() async {
    final snapshot = List<LinuxProfile>.from(_profiles);
    for (final profile in snapshot) {
      // Skip profiles that were removed concurrently.
      if (!_profiles.any((e) => e.id == profile.id)) continue;
      final root = rootOf(profile.id);
      if (root == null) continue;
      if (!await Directory(root).exists()) continue;
      await seedResolvConf(
        root,
        nameservers: linuxNameservers(),
        overwrite: true,
      );
      // Between the two seeds a concurrent deletion can remove the tree;
      // re-check before recreating repository paths that would resurrect it.
      if (!_profiles.any((e) => e.id == profile.id)) continue;
      if (!await Directory(root).exists()) continue;
      // Preserve the installed release series rather than the current
      // preferred one, so a profile installed on noble is not silently
      // rewritten to resolute after a manifest update.
      final release = profile.branch.isEmpty
          ? null
          : profile.distro.info.releases.firstWhereOrNull(
              (r) => r.branch == profile.branch,
            );
      // An installed branch disappearing from a refreshed manifest does not
      // make the current preferred branch compatible with that filesystem.
      if (profile.branch.isNotEmpty && release == null) continue;
      await seedRepositories(
        root,
        distro: profile.distro,
        release: release,
        mirror: linuxMirror(profile.distro),
      );
    }
  }

  static Future<void> rename(LinuxProfile profile, String label) =>
      _lifecycle.run(() async {
        if (!_profiles.any((e) => e.id == profile.id)) return;
        final root = rootOf(profile.id);
        if (root == null) return;
        await File(
          root.joinPath(LinuxProfile.marker),
        ).writeAsString(profile.copyWith(label: label).encode());
        await _scan();
      });

  /// Removes one rootfs and everything in it. The others stay.
  static Future<void> removeProfile(String id, {LinuxProfile? expected}) =>
      _lifecycle.run(() => _removeProfile(id, expected: expected));

  static Future<void> _removeProfile(
    String id, {
    LinuxProfile? expected,
  }) async {
    // A known id, before a recursive delete is built from it. `rootOf` only
    // joins a path, so anything the caller passes becomes one.
    final current = _profiles.firstWhereOrNull((e) => e.id == id);
    if (current == null) return;
    if (expected != null && current != expected) {
      throw StateError('The Linux system changed before it could be deleted');
    }
    if ((_activeProfiles[id] ?? 0) > 0) {
      throw StateError('The Linux system is still in use');
    }
    final root = rootOf(id);
    if (root == null) return;
    if (await FileSystemEntity.type(root, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw StateError('The Linux system directory is no longer available');
    }
    // Remove from the cached list before the filesystem delete so a
    // concurrent applyNetSettings that is mid-iteration skips this profile
    // and does not recreate its repository file after the tree was removed.
    _profiles.removeWhere((e) => e.id == id);
    final dir = Directory(root);
    if (await dir.exists()) await dir.delete(recursive: true);
    await _scan();
  }

  /// The command that enters the rootfs, or null when it cannot be entered.
  ///
  /// [command] is what to run inside; null opens a shell.
  static Future<
    ({String executable, List<String> arguments, void Function() release})?
  >
  enter({String? command, String? profileId}) => _lifecycle.run(() async {
    final id = profileId ?? selected?.id;
    // A named profile has to be one that exists. `rootOf` only joins a path,
    // so an unknown id reads as a rootfs and starts proot on a directory that
    // is not there.
    if (id == null || !_profiles.any((e) => e.id == id)) return null;
    final root = rootOf(id);
    final proot = _proot;
    if (root == null || proot == null || !isAvailable) return null;
    if (await FileSystemEntity.type(root, followLinks: false) !=
        FileSystemEntityType.directory) {
      return null;
    }
    _activeProfiles[id] = (_activeProfiles[id] ?? 0) + 1;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      final remaining = (_activeProfiles[id] ?? 1) - 1;
      if (remaining <= 0) {
        _activeProfiles.remove(id);
      } else {
        _activeProfiles[id] = remaining;
      }
    }

    return (
      executable: proot,
      arguments: [
        '-r', root,
        // Android's own kernel filesystems, which the guest's tools read.
        '-b', '/dev',
        '-b', '/proc',
        '-b', '/sys',
        // A writable home that survives the guest, and somewhere for tmp.
        '-w', '/root',
        // Every guest process believing it is root is what makes `apk` work
        // without any of it being true on the host.
        '--kill-on-exit',
        '-0',
        // Android refuses `link()` inside an app's own data directory, and
        // `-0` does not help: it makes the guest believe it is root, while
        // the uid the kernel checks is still the app's. A package whose tar
        // carries hard links then fails on exactly those entries and on
        // nothing else — `apk add go` reports `Permission denied` for
        // `usr/bin/gcc-{ar,nm,ranlib}` and `usr/bin/ld.gold`, which are the
        // hard-linked members of gcc and binutils-gold, and leaves a gcc that
        // is missing its drivers.
        //
        // This is why the build uses termux/proot rather than upstream: the
        // extension is theirs. It resolves a hard link to a symlink, which
        // those tools are indifferent to — each dispatches on `argv[0]`.
        '--link2symlink',
        // The setting is for interactive terminals only. A one-shot command
        // stays POSIX: the app and the Agent write `sh` and parse what comes
        // back, and `fish` would fail at that in ways that read as the host
        // being broken. See `linuxShell`.
        if (command == null)
          linuxShell(root)
        else ...[
          '/bin/sh',
          '-lc',
          command,
        ],
      ],
      release: release,
    );
  });

  /// The host path a guest path names, or null when it names nothing inside.
  ///
  /// See [resolveWithinRoot], which iOS's guest shares: what has to be refused
  /// is the same on both, and only the root differs.
  static Future<String?> hostPathOf(String guest, {bool forWrite = false}) {
    final root = AndroidRootfs.root;
    if (root == null) return Future.value();
    return resolveWithinRoot(root, guest, forWrite: forWrite);
  }

  /// What the guest needs in its environment.
  ///
  /// Android's `PATH` names directories that do not exist inside the rootfs,
  /// so a shell that inherits it finds none of its own tools.
  static Map<String, String> get environment => {
    'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
    'HOME': '/root',
    'TERM': 'xterm-256color',
    'LANG': 'C.UTF-8',
    // Where proot puts what it has to unpack. Left to itself it uses a temp
    // directory that may not exist inside an app's world.
    'PROOT_TMP_DIR': ?_container,
    // The loader has to be named. Left alone proot extracts the copy bundled
    // in its own binary into a temp file — which lands in the app's directory,
    // cannot be executed, and proot falls back to the `execve` it exists to
    // avoid, reporting it as a permission error.
    'PROOT_LOADER': ?_loader,
  };

  static Future<String> _sha256Of(File file) async {
    // Streamed: the tarball is a few megabytes now and there is no reason for
    // that to be a limit.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
