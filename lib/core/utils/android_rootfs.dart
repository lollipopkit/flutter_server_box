import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/utils/guest_path.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/rootfs_lifecycle.dart';
import 'package:server_box/core/utils/rootfs_unpack.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

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
      // The marker rather than the rootfs readiness check: here it is written last and its
      // presence is what says the extraction finished.
      if (!await marker.exists()) continue;
      found.add(LinuxProfile.decode(id, await marker.readAsString()));
    }
    _profiles
      ..clear()
      ..addAll(found);
    // Every install, rename and removal ends here, and the file picker lists
    // the same directories as roots.
    unawaited(MethodChans.linuxSystemsChanged());
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

  /// Puts the downloaded rootfs on disk, whichever shape it came in — see
  /// [RootfsUnpack], which iOS uses too.
  ///
  /// Not the system's tar, which this used to be. Run as the app's uid it
  /// cannot `link()` in the app's own directory, so every hard link in Ubuntu
  /// and Rocky failed (#1697), and it creates a directory at its recorded
  /// `0555` before writing into it, which failed Rocky's
  /// `ca-trust/.../directory-hash`. [RootfsUnpack] makes a hard link that
  /// cannot be made a relative symlink, and keeps every directory
  /// owner-writable — which `rpm` needs later as well: a package manager
  /// cannot create its temp files in Rocky's `0555` `/usr/bin`.
  static Future<void> _unpack(
    String archivePath,
    String root, {
    required RootfsSource source,
  }) => RootfsUnpack.extract(File(archivePath), Directory(root), source: source);

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
    // Android's own, the app's cache directory, does not exist inside the
    // rootfs; a tool that makes a temporary file there fails (#1698).
    'TMPDIR': '/tmp',
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
