import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:path_provider/path_provider.dart';

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
/// The engine is C, linked into the app and reached through the six functions
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

  /// Locates where the filesystem would be. Call once, before anything asks.
  static Future<void> prepare() async {
    if (!Platform.isIOS) return;
    _root = (await getApplicationSupportDirectory()).path.joinPath('alpine');
    await isInstalled;
  }

  /// Starts the machine, once. Returns 0, -EEXIST if it is already up, or a
  /// negative errno.
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
