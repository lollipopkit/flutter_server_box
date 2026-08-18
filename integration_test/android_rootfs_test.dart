import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Stage 4's Android half, reduced to the one question that decides it.
///
/// `android_exec_test.dart` established that an app targeting 36 cannot
/// `execve` a file in its own directory, and that Android's linker will run a
/// bionic binary from there but segfaults on a musl one. That looked like the
/// end of an Alpine rootfs — until OpenMinis' Android side turned out not to
/// use either path: proot carries **its own loader**, which maps a guest ELF
/// and hands it to the guest's own interpreter.
///
/// So: does a musl binary in the app's directory run under proot, on a device
/// where it cannot run any other way?
///
/// The harness stages two things this test cannot fetch for itself:
///   * `libproot.so` in `jniLibs/arm64-v8a` — the one place an app may execute
///     from, and where the real thing would ship;
///   * an Alpine aarch64 minirootfs at `/data/local/tmp/alpine.tar.gz`.
/// Absent either, the test skips rather than pretending to have measured.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<String> attempt(
    String exe,
    List<String> args, {
    Map<String, String>? env,
  }) async {
    try {
      final r = await Process.run(exe, args, environment: env);
      final out = (r.stdout as String).trim();
      final err = (r.stderr as String).trim();
      return 'exit=${r.exitCode} out="$out" err="${err.split('\n').take(3).join(' | ')}"';
    } on ProcessException catch (e) {
      return 'ProcessException: ${e.message} (errno ${e.errorCode})';
    } catch (e) {
      return 'threw: $e';
    }
  }

  testWidgets('does a musl rootfs run under proot from the app directory', (
    _,
  ) async {
    final files = (await getApplicationSupportDirectory()).path;
    final rootfs = '$files/alpine';
    const staged = '/data/local/tmp/alpine.tar.gz';

    // The native library directory is not exposed to Dart, so it is derived
    // from where this process's own libraries were unpacked.
    final maps = await File('/proc/self/maps').readAsString();
    final soPaths = RegExp(r'(/\S+\.so)\b')
        .allMatches(maps)
        .map((e) => e.group(1)!)
        .toSet();
    for (final p in soPaths.where(
      (e) => e.contains('flutter') || e.contains('libapp') || e.contains('proot'),
    )) {
      debugPrint('ROOTFS mapped        $p');
    }
    // An app's own libraries are either extracted next to its data or mapped
    // straight out of the APK — and only the first of those is a file that can
    // be executed.
    final match = RegExp(r'(/data/app/\S*?/lib/arm64(?:-v8a)?)').firstMatch(maps);
    final nativeLibDir = match?.group(1);
    debugPrint('ROOTFS nativeLibDir = $nativeLibDir');
    if (nativeLibDir == null) {
      markTestSkipped('could not locate the native library directory');
      return;
    }

    final proot = '$nativeLibDir/libproot.so';
    if (!await File(proot).exists()) {
      markTestSkipped('libproot.so was not staged into jniLibs');
      return;
    }
    if (!await File(staged).exists()) {
      markTestSkipped('no Alpine rootfs staged at $staged');
      return;
    }

    // Unpack with the system's own tar, which can exec because it is a system
    // binary. What lands in the rootfs cannot.
    await Directory(rootfs).create(recursive: true);
    debugPrint(
      'ROOTFS untar        = ${await attempt('/system/bin/tar', ['xzf', staged, '-C', rootfs])}',
    );

    final busybox = '$rootfs/bin/busybox';
    debugPrint('ROOTFS busybox is   = ${await File(busybox).exists()}');

    // The control: the same binary, run the only two ways that do not involve
    // proot. Both are expected to fail, and that is what makes the third
    // result mean something.
    debugPrint('ROOTFS direct       = ${await attempt(busybox, ['true'])}');
    debugPrint(
      'ROOTFS via linker64 = ${await attempt('/system/bin/linker64', [busybox, 'true'])}',
    );

    // And under proot, which brings its own loader.
    // proot's loader has to be somewhere executable too. Left to itself it
    // extracts the copy bundled in its own binary into a temp file — which on
    // Android lands in the app's directory, where it cannot be run either, and
    // proot then falls back to a plain execve and is refused. Shipping the
    // loader beside proot and naming it is what makes the mechanism work.
    final loader = '$nativeLibDir/libproot-loader.so';
    final hasLoader = await File(loader).exists();
    debugPrint('ROOTFS loader is    = $hasLoader');

    final env = {
      'PROOT_TMP_DIR': files,
      'HOME': '/root',
      // Android's own PATH names directories that do not exist inside the
      // rootfs, so without this a shell finds none of its own tools.
      'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
      if (hasLoader) 'PROOT_LOADER': loader,
    };
    final underProot = await attempt(proot, [
      '-r', rootfs,
      '/bin/busybox', 'echo', 'SBM_ROOTFS_OK',
    ], env: env);
    debugPrint('ROOTFS under proot  = $underProot');

    // Not a single binary that happened to start: a shell, reading the
    // rootfs's own files, is what "a Linux userland" means here.
    debugPrint(
      'ROOTFS release      = ${await attempt(proot, ['-r', rootfs, '/bin/sh', '-c', 'cat /etc/alpine-release; uname -m'], env: env)}',
    );
  }, skip: !Platform.isAndroid);
}
