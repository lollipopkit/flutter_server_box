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
  /// with the same userland. Built into iSH's own on-disk format by
  /// `fakefsify`, which is why this is a directory rather than a tarball.
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

  /// Whether a filesystem is unpacked and ready to boot.
  static Future<bool> get isInstalled async {
    final root = _root;
    if (root == null) return false;
    // iSH keeps the files under `data` and their metadata in a sqlite db
    // beside it. Both, because either alone is not a filesystem.
    return await Directory(root.joinPath('data')).exists() &&
        await File(root.joinPath('meta.db')).exists();
  }

  /// Locates where the filesystem would be. Call once, before anything asks.
  static Future<void> prepare() async {
    if (!Platform.isIOS) return;
    _root = (await getApplicationSupportDirectory()).path.joinPath('alpine');
  }

  /// Boots the guest and runs [command] in it.
  ///
  /// One guest per app process: the engine keeps its state in globals, so a
  /// second boot is refused rather than allowed to corrupt the first. That is
  /// a constraint on the app, not a detail — a terminal and the Agent share
  /// one machine, and two things at once are two processes inside it.
  static int boot(String command, {int columns = 80, int rows = 25}) {
    final boot = _boot;
    final root = _root;
    if (boot == null || root == null) return -1;
    final rootPointer = root.toNativeUtf8();
    final commandPointer = command.toNativeUtf8();
    try {
      return boot(rootPointer.cast(), commandPointer.cast(), columns, rows);
    } finally {
      malloc.free(rootPointer);
      malloc.free(commandPointer);
    }
  }

  /// What the guest has printed, waiting up to [timeout] for the first byte.
  ///
  /// Null once it has exited and its output has been drained; empty when it
  /// simply had nothing to say yet. A caller has to tell those apart, which is
  /// why this is not just an empty string for both.
  static String? read({
    Duration timeout = const Duration(milliseconds: 200),
    int limit = 8192,
  }) {
    final read = _read;
    if (read == null) return null;
    final buffer = malloc<Uint8>(limit);
    try {
      final count = read(buffer.cast(), limit, timeout.inMilliseconds);
      // -EBUSY: the guest holds the output lock and is not giving it back,
      // which means a guest thread died holding it. Told apart from the guest
      // having exited, because the answer is different — that one is over,
      // this one is broken.
      if (count == -16) throw StateError('The guest stopped holding its lock');
      if (count < 0) return null;
      if (count == 0) return '';
      return String.fromCharCodes(buffer.asTypedList(count));
    } finally {
      malloc.free(buffer);
    }
  }

  /// Types [input] at the guest.
  static int write(String input) {
    final write = _write;
    if (write == null) return -1;
    final pointer = input.toNativeUtf8();
    try {
      return write(pointer.cast(), pointer.length);
    } finally {
      malloc.free(pointer);
    }
  }

  /// Tells the guest its terminal changed size.
  static void resize(int columns, int rows) => _resize?.call(columns, rows);

  /// The guest's exit status, or null while it is still running.
  static int? get exitCode {
    final code = _exitCode?.call() ?? -1;
    return code < 0 ? null : code;
  }

  // — The engine's six functions ————————————————————————————————————
  //
  // Looked up in the running process rather than a `.dylib` of their own: the
  // shim is compiled into the app, not shipped beside it. Each is resolved
  // once and left null when it is not there, which is the same answer the
  // switch being off gives — and the reason nothing above has to know which of
  // the two happened.

  static final DynamicLibrary? _process = Platform.isIOS
      ? DynamicLibrary.process()
      : null;

  static final _available = _lookupAvailable();
  static final _boot = _lookupBoot();
  static final _read = _lookupRead();
  static final _write = _lookupWrite();
  static final _resize = _lookupResize();
  static final _exitCode = _lookupExitCode();

  static bool Function()? _lookupAvailable() {
    try {
      return _process
          ?.lookupFunction<Bool Function(), bool Function()>(
            'sbm_ish_available',
          );
    } catch (_) {
      return null;
    }
  }

  static int Function(Pointer<Char>, Pointer<Char>, int, int)? _lookupBoot() {
    try {
      return _process?.lookupFunction<
        Int Function(Pointer<Char>, Pointer<Char>, Int, Int),
        int Function(Pointer<Char>, Pointer<Char>, int, int)
      >('sbm_ish_boot');
    } catch (_) {
      return null;
    }
  }

  static int Function(Pointer<Char>, int, int)? _lookupRead() {
    try {
      return _process?.lookupFunction<
        Int Function(Pointer<Char>, Int, Int),
        int Function(Pointer<Char>, int, int)
      >('sbm_ish_read');
    } catch (_) {
      return null;
    }
  }

  static int Function(Pointer<Char>, int)? _lookupWrite() {
    try {
      return _process?.lookupFunction<
        Int Function(Pointer<Char>, Int),
        int Function(Pointer<Char>, int)
      >('sbm_ish_write');
    } catch (_) {
      return null;
    }
  }

  static void Function(int, int)? _lookupResize() {
    try {
      return _process
          ?.lookupFunction<Void Function(Int, Int), void Function(int, int)>(
            'sbm_ish_resize',
          );
    } catch (_) {
      return null;
    }
  }

  static int Function()? _lookupExitCode() {
    try {
      return _process?.lookupFunction<Int Function(), int Function()>(
        'sbm_ish_exit_code',
      );
    } catch (_) {
      return null;
    }
  }
}
