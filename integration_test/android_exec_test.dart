import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';

/// Stage 3 of TODOS.md's "本机 shell 与 rootfs", measured rather than argued.
///
/// Android 10 removed execute permission on an app's own data directory for
/// anything targeting API 29 or later, and this app targets 36. That is what
/// decides whether a Linux rootfs is possible here at all: a package manager
/// exists to write new binaries into the rootfs, and the rootfs would live in
/// exactly that directory.
///
/// The experiment is one binary in two places. `/system/bin/sh` is the control
/// — if the copy in app data will not run and the original will, the location
/// is the reason and nothing else is.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => Paths.init(BuildData.name, bakName: Miscs.bakFileName));

  /// Runs [exe] and says what happened, without throwing: a refusal is the
  /// measurement, not an error.
  Future<String> attempt(String exe, List<String> args) async {
    try {
      final r = await Process.run(exe, args);
      final out = (r.stdout as String).trim();
      final err = (r.stderr as String).trim();
      return 'exit=${r.exitCode} out="$out" err="$err"';
    } on ProcessException catch (e) {
      return 'ProcessException: ${e.message} (errno ${e.errorCode})';
    } catch (e) {
      return 'threw: $e';
    }
  }

  testWidgets('what an app targeting 36 may execute from its own data dir', (
    _,
  ) async {
    final sdk = (await Process.run('/system/bin/getprop', [
      'ro.build.version.sdk',
    ])).stdout.toString().trim();

    // Two directories, because they are refused for different reasons and
    // only one of them is the question. `Paths.doc` is external storage, which
    // is mounted `noexec` whatever the target SDK; the internal one is the
    // app's home, which is what Android 10's W^X rule is about — and where a
    // rootfs would have to live.
    final internal = (await getApplicationSupportDirectory()).path;
    final control = await attempt('/system/bin/sh', ['-c', 'echo SBM_OK']);

    debugPrint('STAGE3 device sdk   = $sdk');
    debugPrint('STAGE3 control      = $control');

    for (final dir in {'internal': internal, 'external': Paths.doc}.entries) {
      final copy = dir.value.joinPath('sh_copy');
      try {
        await File('/system/bin/sh').copy(copy);
      } catch (e) {
        debugPrint('STAGE3 ${dir.key}: cannot even copy: $e');
        continue;
      }
      // Dart cannot chmod, and a copy is not executable by default.
      final chmod = await attempt('/system/bin/chmod', ['755', copy]);
      final direct = await attempt(copy, ['-c', 'echo SBM_OK']);
      // The widely repeated workaround: the dynamic linker maps the file
      // rather than exec'ing it, so the check on the app's directory is said
      // not to apply. This is the claim the plan had no source for.
      final viaLinker = await attempt('/system/bin/linker64', [
        copy,
        '-c',
        'echo SBM_OK',
      ]);

      debugPrint('STAGE3 ${dir.key} dir     = ${dir.value}');
      debugPrint('STAGE3 ${dir.key} chmod   = $chmod');
      debugPrint('STAGE3 ${dir.key} direct  = $direct');
      debugPrint('STAGE3 ${dir.key} linker  = $viaLinker');
    }

    // A rootfs would not be bionic. `linker64` is Android's own loader, and
    // everything in an Alpine image is linked against musl's — so whether the
    // trick above extends to a rootfs is a different question from whether it
    // works at all. Measured with a real aarch64 musl binary and its loader,
    // staged into /data/local/tmp by the harness.
    const staged = '/data/local/tmp';
    final musl = File(staged.joinPath('busybox_musl'));
    if (await musl.exists()) {
      final box = internal.joinPath('busybox_musl');
      final ld = internal.joinPath('ld-musl-aarch64.so.1');
      await musl.copy(box);
      await File(staged.joinPath('ld-musl-aarch64.so.1')).copy(ld);
      await attempt('/system/bin/chmod', ['755', box]);
      await attempt('/system/bin/chmod', ['755', ld]);

      debugPrint('STAGE3 musl direct  = ${await attempt(box, ['true'])}');
      // Android's loader, on a binary that asks for musl's.
      debugPrint(
        'STAGE3 musl+linker64= ${await attempt('/system/bin/linker64', [box, 'true'])}',
      );
      // musl's own loader, itself launched the same way.
      debugPrint(
        'STAGE3 musl+musl-ld = ${await attempt('/system/bin/linker64', [ld, box, 'true'])}',
      );

      // In Alpine the loader and the C library are one file under two names,
      // so the lookup above failed on the name and the search path rather than
      // on anything structural. This is the question stage 4 turns on.
      final libc = internal.joinPath('libc.musl-aarch64.so.1');
      await File(ld).copy(libc);
      await attempt('/system/bin/chmod', ['755', libc]);
      try {
        final r = await Process.run(
          '/system/bin/linker64',
          [box, 'true'],
          environment: {'LD_LIBRARY_PATH': internal},
        );
        debugPrint(
          'STAGE3 musl+LD_PATH = exit=${r.exitCode} err="${(r.stderr as String).trim()}"',
        );
      } catch (e) {
        debugPrint('STAGE3 musl+LD_PATH = threw: $e');
      }
    }

    // The control has to work, or the other two say nothing.
    expect(control, contains('SBM_OK'));
  }, skip: !Platform.isAndroid);
}
