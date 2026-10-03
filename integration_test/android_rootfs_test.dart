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
/// The two answers are asserted rather than printed, because they are the
/// point: the rootfs runs under proot, and it does **not** run either of the
/// two ways proot exists to avoid. A test that only printed them passed when
/// proot was broken and when nothing was staged.
///
/// The harness stages two things this test cannot fetch for itself:
///   * `libproot.so` in `jniLibs/arm64-v8a` — the one place an app may execute
///     from, and where the real thing would ship;
///   * an Alpine aarch64 minirootfs at `/data/local/tmp/alpine.tar.gz`.
/// Absent either, the test skips rather than pretending to have measured.
///
/// The unpacked tree is the test's own — under the support directory, where an
/// app may run a tree from, but under a name no install uses — and the run
/// removes it, so nothing is left on the device. `tar` overlays rather than
/// replaces, so a tree kept from a previous run would let the release and
/// machine read back belong to either.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// One attempt's result. [attempt] keeps what happened even when it threw.
  Future<({int? exit, String out, String err})> attempt(
    String exe,
    List<String> args, {
    Map<String, String>? env,
  }) async {
    try {
      final r = await Process.run(exe, args, environment: env);
      return (
        exit: r.exitCode,
        out: (r.stdout as String).trim(),
        err: (r.stderr as String).trim(),
      );
    } on ProcessException catch (e) {
      return (exit: null, out: '', err: '${e.message} (errno ${e.errorCode})');
    } catch (e) {
      return (exit: null, out: '', err: 'threw: $e');
    }
  }

  /// The same attempt, as the one line worth printing either way.
  String describe(({int? exit, String out, String err}) r) =>
      'exit=${r.exit} out="${r.out}" '
      'err="${r.err.split('\n').take(3).join(' | ')}"';

  testWidgets('does a musl rootfs run under proot from the app directory', (
    _,
  ) async {
    final files = (await getApplicationSupportDirectory()).path;
    // Under the support directory, where an app may put a tree it will run from
    // — but a name of this test's own. `alpine/` at the root of it is where a
    // release before the `linux/` container unpacked, and that tree is not this
    // test's to delete.
    final rootfs = '$files/.rootfs-proot-probe';
    const staged = '/data/local/tmp/alpine.tar.gz';

    // The native library directory is not exposed to Dart, so it is derived
    // from where this process's own libraries were unpacked.
    final maps = await File('/proc/self/maps').readAsString();
    final soPaths = RegExp(r'(/\S+\.so)\b')
        .allMatches(maps)
        .map((e) => e.group(1)!)
        .toSet();
    for (final p in soPaths.where(
      (e) =>
          e.contains('flutter') || e.contains('libapp') || e.contains('proot'),
    )) {
      debugPrint('ROOTFS mapped        $p');
    }
    // An app's own libraries are either extracted next to its data or mapped
    // straight out of the APK — and only the first of those is a file that can
    // be executed.
    final match = RegExp(
      r'(/data/app/\S*?/lib/arm64(?:-v8a)?)',
    ).firstMatch(maps);
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
    //
    // A fresh tree each run: `tar` overlays, so a previous run's files would
    // survive where the archive does not carry them, and the release and
    // machine this reads back could be either run's. `-C` also needs its
    // directory to exist, which the same call settles.
    if (await Directory(rootfs).exists()) {
      await Directory(rootfs).delete(recursive: true);
    }
    await Directory(rootfs).create(recursive: true);
    // The test's own directory, so it goes when the test does — the device
    // keeps nothing between runs.
    addTearDown(() async {
      if (await Directory(rootfs).exists()) {
        await Directory(rootfs).delete(recursive: true);
      }
    });

    final untar = await attempt('/system/bin/tar', [
      'xzf',
      staged,
      '-C',
      rootfs,
    ]);
    debugPrint('ROOTFS untar        = ${describe(untar)}');
    expect(
      untar.exit,
      0,
      reason: 'the staged rootfs did not unpack: ${untar.err}',
    );

    final busybox = '$rootfs/bin/busybox';
    expect(
      await File(busybox).exists(),
      isTrue,
      reason: 'the rootfs unpacked without a busybox at $busybox',
    );
    debugPrint('ROOTFS busybox is   = true');

    // The control: the same binary, run the only two ways that do not involve
    // proot. Both are expected to fail, and that is what makes the third
    // result mean something — if either started working, proot would no longer
    // be the reason the rootfs runs, and this test would be measuring nothing.
    final direct = await attempt(busybox, ['true']);
    final viaLinker = await attempt('/system/bin/linker64', [busybox, 'true']);
    debugPrint('ROOTFS direct       = ${describe(direct)}');
    debugPrint('ROOTFS via linker64 = ${describe(viaLinker)}');
    expect(
      direct.exit,
      isNot(0),
      reason:
          'a musl binary in the app directory ran without proot '
          '(${describe(direct)}): the premise of this test is gone',
    );
    expect(
      viaLinker.exit,
      isNot(0),
      reason:
          'Android\'s linker ran a musl binary (${describe(viaLinker)}): '
          'the premise of this test is gone',
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
      '-r',
      rootfs,
      '/bin/busybox',
      'echo',
      'SBM_ROOTFS_OK',
    ], env: env);
    debugPrint('ROOTFS under proot  = ${describe(underProot)}');
    expect(
      underProot.exit,
      0,
      reason: 'proot did not run the rootfs\'s own binary: ${underProot.err}',
    );
    expect(
      underProot.out,
      contains('SBM_ROOTFS_OK'),
      reason: 'proot ran something, but not the marker the rootfs printed',
    );

    // Not a single binary that happened to start: a shell, reading the
    // rootfs's own files, is what "a Linux userland" means here.
    final release = await attempt(proot, [
      '-r',
      rootfs,
      '/bin/sh',
      '-c',
      'cat /etc/alpine-release; uname -m',
    ], env: env);
    debugPrint('ROOTFS release      = ${describe(release)}');
    expect(
      release.exit,
      0,
      reason: 'the rootfs shell did not run: ${release.err}',
    );
    final lines = release.out
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    expect(
      lines,
      hasLength(2),
      reason: 'expected the release and the machine, got: $lines',
    );
    // Alpine's version is `x.y.z`; anything else means the file was not read
    // out of the rootfs.
    expect(
      lines.first,
      matches(RegExp(r'^\d+\.\d+')),
      reason: 'not an Alpine release: "${lines.first}"',
    );
    expect(
      lines.last,
      'aarch64',
      reason: 'the guest is not the aarch64 userland that was staged',
    );
  }, skip: !Platform.isAndroid);
}
