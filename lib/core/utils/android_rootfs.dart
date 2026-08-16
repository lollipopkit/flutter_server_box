import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/core/chan.dart';
import 'package:server_box/core/utils/guest_path.dart';

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
  /// Pinned, and checked. This is a tarball of executable code fetched over
  /// the network and then run; the digest is the only thing that makes that
  /// different from running whatever the connection handed back.
  ///
  /// The branch is 3.22 rather than the newest, and that is not for want of
  /// updating: 3.23 and later ship apk-tools 3, whose network fetches fail
  /// under proot on Android with `Permission denied` on every repository —
  /// measured on API 36, where the same rootfs installs happily from a local
  /// file repository and busybox `wget` fetches the same URLs over both HTTP
  /// and HTTPS. Cause not established. 3.22 is the last branch with apk-tools
  /// 2.14, which works; `integration_test/rootfs_shell_test.dart` installs a
  /// package over the network and is what would notice this changing.
  static const version = '3.22.5';
  static const _mirror = 'https://dl-cdn.alpinelinux.org/alpine';
  static const _branch = 'v3.22';
  static const _url =
      '$_mirror/$_branch/releases/aarch64/'
      'alpine-minirootfs-$version-aarch64.tar.gz';
  static const _sha256 =
      '3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70';

  /// Written once the extraction finished. Its presence is the whole record:
  /// a half-unpacked rootfs must not look installed, and re-downloading a
  /// working one wastes the user's data. It holds the version it was unpacked
  /// from, which is what [installedVersion] reads.
  static const _marker = '.installed';

  static String? _root;
  static String? _proot;
  static String? _loader;

  /// Where the rootfs lives, or null before [prepare].
  ///
  /// Internal storage. `Paths.doc` is external on Android and mounted
  /// `noexec`, so a rootfs there could never run even under proot.
  static String? get root => _root;

  /// Whether this build carries proot at all.
  static bool get isAvailable => _proot != null && _loader != null;

  /// Whether a rootfs is unpacked and ready to enter.
  static Future<bool> get isInstalled async {
    final root = _root;
    if (root == null) return false;
    final marker = File(root.joinPath(_marker));
    if (!await marker.exists()) {
      _installedVersion = null;
      return _installed = false;
    }
    // Empty for a rootfs unpacked before the marker carried a version. Read as
    // "some older one", which is exactly what it is.
    // TODO(migration residue; remove once no install predates the versioned
    // marker): the `?? '0'` below is what makes that read as outdated.
    final written = (await marker.readAsString()).trim();
    _installedVersion = written.isEmpty ? '0' : written;
    return _installed = true;
  }

  /// The last answer [isInstalled] gave, without asking the filesystem again.
  ///
  /// A synchronous question, because the callers that decide whether to *offer*
  /// the rootfs — building the Agent's instructions, listing what a target can
  /// do — are on paths that cannot await one, and a file check per prompt would
  /// be answering the same question a hundred times. Kept true by the two
  /// things that change it, [install] and [remove].
  static bool get isReady => isAvailable && _installed;
  static bool _installed = false;

  /// The version on disk, or null when there is nothing installed.
  ///
  /// Read at [prepare] and kept by [install] and [remove], for the same reason
  /// [isReady] is synchronous: what asks is a widget being built.
  static String? get installedVersion => _installed ? _installedVersion : null;
  static String? _installedVersion;

  /// Whether what is installed is older than what this build would install.
  ///
  /// Not acted on by itself. Reinstalling means downloading the rootfs again
  /// and losing everything `apk add` put in the old one, which is the user's
  /// call — so this only decides whether to offer.
  static bool get isOutdated =>
      isReady && _installedVersion != null && _installedVersion != version;

  /// Locates proot and the rootfs. Call once, before anything asks.
  static Future<void> prepare() async {
    if (!isAndroid) return;
    _root = (await getApplicationSupportDirectory()).path.joinPath('alpine');

    final libDir = await MethodChans.nativeLibDir();
    if (libDir == null) return;
    final proot = libDir.joinPath('libproot.so');
    final loader = libDir.joinPath('libproot-loader.so');
    // Both, or neither is any use: without the loader proot falls back to a
    // plain `execve` and is refused by the very rule it exists to avoid.
    if (await File(proot).exists() && await File(loader).exists()) {
      _proot = proot;
      _loader = loader;
    }
    await isInstalled;
  }

  /// Downloads and unpacks the rootfs.
  ///
  /// [onProgress] is fed a fraction, or null while the size is unknown.
  /// [replace] unpacks over whatever is there, for the version pin having
  /// moved. Everything installed into the old one goes with it.
  static Future<void> install({
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
    bool replace = false,
  }) async {
    final root = _root;
    if (root == null) throw StateError('AndroidRootfs.prepare was not called');
    if (!replace && await isInstalled) return;

    final dir = Directory(root);
    // Whatever a previous attempt left. A rootfs is only ever complete or
    // absent; there is no repairing a partial one.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final archive = root.joinPath('rootfs.tar.gz');
    try {
      await Dio().download(
        _url,
        archive,
        cancelToken: cancel,
        onReceiveProgress: (got, total) =>
            onProgress?.call(total > 0 ? got / total : null),
      );

      final digest = await _sha256Of(File(archive));
      if (digest != _sha256) {
        throw StateError(
          'The rootfs did not match its digest and was discarded. '
          'Expected $_sha256, got $digest.',
        );
      }

      // The system's own tar, not a Dart one. It is a system binary so it may
      // execute, it is far faster on a few thousand files, and — the part that
      // matters — it restores the symlinks that make `/bin/sh` a name for
      // busybox. A rootfs whose links became copies is a rootfs of one
      // program pretending to be two hundred.
      final untar = await Process.run('/system/bin/tar', [
        'xzf',
        archive,
        '-C',
        root,
      ]);
      if (untar.exitCode != 0) {
        throw StateError('Could not unpack the rootfs: ${untar.stderr}');
      }

      await _seedResolvConf(root);
      await _seedRepositories(root);
      await File(root.joinPath(_marker)).writeAsString(version);
      _installed = true;
      _installedVersion = version;
    } catch (_) {
      // Nothing half-installed is left to be mistaken for a working one.
      if (await dir.exists()) await dir.delete(recursive: true);
      rethrow;
    } finally {
      final leftover = File(archive);
      if (await leftover.exists()) await leftover.delete();
    }
  }

  /// Removes the rootfs and everything in it.
  static Future<void> remove() async {
    _installed = false;
    _installedVersion = null;
    final root = _root;
    if (root == null) return;
    final dir = Directory(root);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// The command that enters the rootfs, or null when it cannot be entered.
  ///
  /// [command] is what to run inside; null opens a shell.
  static ({String executable, List<String> arguments})? enter({
    String? command,
  }) {
    final root = _root;
    final proot = _proot;
    if (root == null || proot == null || !isAvailable) return null;
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
        if (command == null) '/bin/sh' else ...['/bin/sh', '-lc', command],
      ],
    );
  }

  /// The host path a guest path names, or null when it names nothing inside.
  ///
  /// See [resolveWithinRoot], which iOS's guest shares: what has to be refused
  /// is the same on both, and only the root differs.
  static Future<String?> hostPathOf(String guest, {bool forWrite = false}) {
    final root = _root;
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
    'PROOT_TMP_DIR': ?_root,
    // The loader has to be named. Left alone proot extracts the copy bundled
    // in its own binary into a temp file — which lands in the app's directory,
    // cannot be executed, and proot falls back to the `execve` it exists to
    // avoid, reporting it as a permission error.
    'PROOT_LOADER': ?_loader,
  };

  /// A resolver, because the guest has no `/etc/resolv.conf` of its own and
  /// Android does not expose one a container can read.
  static Future<void> _seedResolvConf(String root) async {
    final etc = Directory(root.joinPath('etc'));
    if (!await etc.exists()) await etc.create(recursive: true);
    await File(etc.path.joinPath('resolv.conf'))
        .writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
  }

  /// Where `apk` looks for packages.
  ///
  /// A minirootfs ships without this — the Docker image is what adds it — so
  /// `apk add` in a freshly unpacked one reports every package as missing.
  /// Pinned to the same branch the rootfs came from: a rootfs on one branch
  /// installing packages built for another is how a distribution breaks.
  static Future<void> _seedRepositories(String root) async {
    final apk = Directory(root.joinPath('etc').joinPath('apk'));
    if (!await apk.exists()) await apk.create(recursive: true);
    await File(apk.path.joinPath('repositories')).writeAsString(
      '$_mirror/$_branch/main\n$_mirror/$_branch/community\n',
    );
  }

  static Future<String> _sha256Of(File file) async {
    // Streamed: the tarball is a few megabytes now and there is no reason for
    // that to be a limit.
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
