import 'dart:ffi';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:ffi/ffi.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/core/utils/alpine_seed.dart';
import 'package:server_box/core/utils/guest_path.dart';

/// A Linux userland on iOS, and what it takes to get one.
///
/// The opposite problem from Android's. There, a real rootfs runs and only
/// `execve` is in the way, which proot steps around. Here an App Store app has
/// no `fork`/`exec` at all and no `/bin/sh` in its sandbox, so there is nothing
/// to enter a rootfs *with*. The answer is an interpreter — ish-arm64 — that
/// dispatches guest AArch64 to pre-compiled native gadgets, writes no machine
/// code at runtime (iOS grants no JIT entitlement) and never hands a guest
/// binary to the kernel.
///
/// The engine is C, linked into the app and reached through the eight functions
/// in `ios/Runner/ish/sbm_ish.h`. It is absent from any build made with
/// `SBM_ISH = 0` in `ios/Flutter/Ish.xcconfig` — the switch that exists so a
/// build without it is one edit away, should App Store review object — and
/// [isAvailable] is how everything else asks, exactly as on Android.
abstract final class IosRootfs {
  /// The same Alpine release the Android rootfs uses, so both platforms answer
  /// with the same userland — and on both it is an ordinary unpacked tree,
  /// since `realfs` mounts one directly.
  static const version = '3.22.5';

  static String? _root;

  /// Where the filesystem lives, or null before [prepare].
  static String? get root => _root;

  /// Whether this build carries the engine.
  ///
  /// Three ways to be false: not iOS, built with the switch off, or built
  /// before the shim existed — the last of which throws on lookup rather than
  /// answering, so it is caught here and treated as the absence it is.
  static bool get isAvailable {
    if (!Platform.isIOS) return false;
    final available = _available;
    if (available == null) return false;
    try {
      return available();
    } catch (e, s) {
      Loggers.app.warning('sbm_ish_available', e, s);
      return false;
    }
  }

  /// The last answer [isInstalled] gave, without asking the filesystem again.
  ///
  /// Synchronous for the same reason Android's is: what asks is a widget being
  /// built, and a file check per frame answers one question a hundred times.
  static bool get isReadySync => isAvailable && _installed;
  static bool _installed = false;

  /// Whether a filesystem is unpacked and ready to boot.
  static Future<bool> get isInstalled async {
    final root = _root;
    if (root == null) return false;
    // An ordinary tree, mounted by `realfs`. What makes it a userland rather
    // than a directory is that a shell is in it, so that is what this asks —
    // there is no manifest to check because there is nothing but files.
    return _installed = await File(root.joinPath('bin/busybox')).exists() &&
        await File(root.joinPath('etc/alpine-release')).exists();
  }

  /// Pinned and checked, like Android's — this is executable code fetched over
  /// the network, and the digest is what makes that different from running
  /// whatever the connection returned.
  static const _mirror = 'https://dl-cdn.alpinelinux.org/alpine';
  static const _branch = 'v3.22';
  static const _url =
      '$_mirror/$_branch/releases/aarch64/'
      'alpine-minirootfs-$version-aarch64.tar.gz';
  static const _sha256 =
      '3fbc6285032ed46821b511292633d7b2a6306a2e254f590e92bdafff56cf2f70';

  /// Downloads and unpacks the userland.
  ///
  /// Unpacked in Dart, because iOS will not start a process — no `tar`, and
  /// that refusal is the reason this platform has an interpreter at all. What
  /// `realfs` needs is only a directory tree, which is why this is possible;
  /// under `fakefs` it would have meant carrying a metadata database and the
  /// tool that writes one.
  static Future<void> install({
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) async {
    final root = _root;
    if (root == null) throw StateError('IosRootfs.prepare was not called');
    if (await isInstalled) return;

    final dir = Directory(root);
    // A userland is complete or absent; there is no repairing half of one.
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);

    final archivePath = root.joinPath('rootfs.tar.gz');
    try {
      await Dio().download(
        _url,
        archivePath,
        cancelToken: cancel,
        // The download is most of the wait, so it owns most of the bar; the
        // unpacking gets the last tenth.
        onReceiveProgress: (got, total) =>
            onProgress?.call(total > 0 ? (got / total) * 0.9 : null),
      );

      final file = File(archivePath);
      final digest = (await sha256.bind(file.openRead()).first).toString();
      if (digest != _sha256) {
        throw StateError(
          'The userland did not match its digest and was discarded. '
          'Expected $_sha256, got $digest.',
        );
      }

      await _extract(file, dir, onProgress: onProgress);
      // Without these `apk` reaches nothing: the guest's sockets work and an
      // address literal is fetched fine, but there is no resolver, so every
      // mirror is a "temporary error" and every package is missing.
      // Measured on a device by `integration_test/ios_load_test.dart`.
      await seedResolvConf(root);
      await seedRepositories(root, mirror: _mirror, branch: _branch);
      _installed = true;
    } catch (_) {
      // Nothing half-installed is left to be mistaken for a working one.
      if (await dir.exists()) await dir.delete(recursive: true);
      _installed = false;
      rethrow;
    } finally {
      final leftover = File(archivePath);
      if (await leftover.exists()) await leftover.delete();
    }
  }

  /// Removes the userland and everything in it.
  static Future<void> remove() async {
    _installed = false;
    final root = _root;
    if (root == null) return;
    final dir = Directory(root);
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  static Future<void> _extract(
    File archiveFile,
    Directory into, {
    void Function(double? progress)? onProgress,
  }) async {
    final bytes = await archiveFile.readAsBytes();
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));

    var done = 0;
    for (final entry in archive) {
      done++;
      if (done % 200 == 0) {
        onProgress?.call(0.9 + (done / archive.length) * 0.1);
      }
      final path = into.path.joinPath(entry.name);

      // Links as links, never followed. Under `realfs` a guest symlink is
      // resolved inside the guest, so `/bin/sh -> /bin/busybox` means the
      // guest's busybox; written as a copy of whatever the host has at that
      // path it is the wrong file, and skipped it is no file — which is how an
      // earlier attempt booted with no `/bin/sh` to run.
      if (entry.isSymbolicLink) {
        final link = Link(path);
        await link.parent.create(recursive: true);
        if (await link.exists()) await link.delete();
        await link.create(entry.symbolicLink!);
        continue;
      }
      if (entry.isDirectory) {
        await Directory(path).create(recursive: true);
        continue;
      }
      if (!entry.isFile) {
        // Device nodes, which a tarball carries and no unprivileged process
        // can create. `/dev` is built at boot instead — see the C side.
        continue;
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(entry.readBytes() ?? const []);
      // The mode the tarball recorded. It matters more here than under
      // `fakefs`: `realfs` reports the host's mode to the guest, so a busybox
      // written 0644 by Dart is a busybox the guest cannot execute.
      //
      // Through libc rather than `chmod(1)`: iOS refuses to start a process,
      // which is the same refusal that put an interpreter on this platform.
      _chmod(path, entry.mode & 0xfff);
    }
  }

  /// `chmod`, which `dart:io` does not have and this cannot do without.
  static void _chmod(String path, int mode) {
    final chmod = _chmodC;
    if (chmod == null || mode == 0) return;
    final pointer = path.toNativeUtf8();
    try {
      chmod(pointer.cast(), mode);
    } finally {
      malloc.free(pointer);
    }
  }

  static final _chmodC = _look(
    'chmod',
    (p) => p.lookupFunction<Int Function(Pointer<Char>, Uint16), int Function(Pointer<Char>, int)>('chmod'),
  );

  /// The host path a guest path names, or null when it names nothing inside.
  ///
  /// Simpler here than on Android and for the reason the whole platform is
  /// simpler: `realfs` mounts an ordinary directory tree, so the guest's `/etc`
  /// really is `<root>/etc` on the host. See [resolveWithinRoot] for what has
  /// to be refused — which is the same on both.
  static Future<String?> hostPathOf(String guest, {bool forWrite = false}) {
    final root = _root;
    if (root == null) return Future.value();
    return resolveWithinRoot(root, guest, forWrite: forWrite);
  }

  /// Locates where the filesystem would be. Call once, before anything asks.
  static Future<void> prepare() async {
    if (!Platform.isIOS) return;
    final root = _root =
        (await getApplicationSupportDirectory()).path.joinPath('alpine');
    if (!await isInstalled) return;
    // A userland unpacked before [install] seeded a resolver has none, and
    // nothing else would ever give it one: [install] returns early for a tree
    // that is already there, so every existing install would have stayed
    // without DNS. Writes only when the file is absent.
    await seedResolvConf(root);
  }

  /// What [boot] answers when the machine is already up — `-EEXIST`.
  ///
  /// Not an error anywhere: there is one machine per app process by design, so
  /// the second caller to ask for it is a terminal opening beside the Agent,
  /// or the other way round.
  static const alreadyBooted = -17;

  /// Starts the machine, once. Returns 0, [alreadyBooted] if it is already up,
  /// or a negative errno.
  ///
  /// One machine per app process, because the engine keeps its kernel state in
  /// globals — but a machine runs as many processes as it is asked to, which
  /// is what [open] is for.
  static int boot() {
    final boot = _boot;
    final root = _root;
    if (boot == null || root == null) return -1;
    final pointer = root.toNativeUtf8();
    try {
      return boot(pointer.cast());
    } finally {
      malloc.free(pointer);
    }
  }

  /// Opens a session: a process in the machine, on a pty of its own.
  ///
  /// [command] null or empty gives an interactive shell. Sessions do not share
  /// a console, so a terminal and a one-shot command cannot land on each
  /// other's output.
  static int open({String? command, int columns = 80, int rows = 25}) {
    final open = _open;
    if (open == null) return -1;
    final pointer = (command ?? '').toNativeUtf8();
    try {
      return open(pointer.cast(), columns, rows);
    } finally {
      malloc.free(pointer);
    }
  }

  /// What [session] has printed, waiting up to [timeout] for the first byte.
  ///
  /// Null once it has ended and its output is drained; empty when it simply
  /// had nothing to say yet. A caller has to tell those apart.
  static String? read(
    int session, {
    Duration timeout = const Duration(milliseconds: 200),
    int limit = 8192,
  }) {
    final read = _read;
    if (read == null) return null;
    final buffer = malloc<Uint8>(limit);
    try {
      final count = read(session, buffer.cast(), limit, timeout.inMilliseconds);
      // -EBUSY: a guest thread died holding the output lock. Told apart from
      // the session having ended, because the answer is different — that one
      // is over, this one is broken.
      if (count == -16) throw StateError('The guest stopped holding its lock');
      if (count < 0) return null;
      if (count == 0) return '';
      return String.fromCharCodes(buffer.asTypedList(count));
    } finally {
      malloc.free(buffer);
    }
  }

  /// Types [input] at [session].
  static int write(int session, String input) {
    final write = _write;
    if (write == null) return -1;
    final pointer = input.toNativeUtf8();
    try {
      return write(session, pointer.cast(), pointer.length);
    } finally {
      malloc.free(pointer);
    }
  }

  /// Tells [session] its terminal changed size.
  static void resize(int session, int columns, int rows) =>
      _resize?.call(session, columns, rows);

  /// [session]'s exit status, or null while it is still running.
  static int? exitCode(int session) {
    final code = _exitCode?.call(session) ?? -1;
    return code < 0 ? null : code;
  }

  /// Ends [session]. Its process is hung up, not killed: a shell ignores
  /// SIGTERM and takes SIGHUP as its terminal going away, which it has.
  static void close(int session) => _close?.call(session);

  // — The engine's functions ————————————————————————————————————————
  //
  // Looked up in the running process rather than a `.dylib` of their own: the
  // shim is compiled into the app, not shipped beside it. Each is resolved
  // once and left null when it is not there, which is the same answer the
  // switch being off gives — and the reason nothing above has to know which of
  // the two happened.

  static final DynamicLibrary? _process = Platform.isIOS
      ? DynamicLibrary.process()
      : null;

  static T? _look<T extends Function>(String name, T Function(DynamicLibrary) f) {
    final process = _process;
    if (process == null) return null;
    try {
      return f(process);
    } catch (_) {
      return null;
    }
  }

  static final _available = _look(
    'sbm_ish_available',
    (p) => p.lookupFunction<Bool Function(), bool Function()>('sbm_ish_available'),
  );
  static final _boot = _look(
    'sbm_ish_boot',
    (p) => p.lookupFunction<Int Function(Pointer<Char>), int Function(Pointer<Char>)>('sbm_ish_boot'),
  );
  static final _open = _look(
    'sbm_ish_open',
    (p) => p.lookupFunction<Int Function(Pointer<Char>, Int, Int), int Function(Pointer<Char>, int, int)>('sbm_ish_open'),
  );
  static final _read = _look(
    'sbm_ish_read',
    (p) => p.lookupFunction<Int Function(Int, Pointer<Char>, Int, Int), int Function(int, Pointer<Char>, int, int)>('sbm_ish_read'),
  );
  static final _write = _look(
    'sbm_ish_write',
    (p) => p.lookupFunction<Int Function(Int, Pointer<Char>, Int), int Function(int, Pointer<Char>, int)>('sbm_ish_write'),
  );
  static final _resize = _look(
    'sbm_ish_resize',
    (p) => p.lookupFunction<Void Function(Int, Int, Int), void Function(int, int, int)>('sbm_ish_resize'),
  );
  static final _exitCode = _look(
    'sbm_ish_exit_code',
    (p) => p.lookupFunction<Int Function(Int), int Function(int)>('sbm_ish_exit_code'),
  );
  static final _close = _look(
    'sbm_ish_close',
    (p) => p.lookupFunction<Void Function(Int), void Function(int)>('sbm_ish_close'),
  );
}
