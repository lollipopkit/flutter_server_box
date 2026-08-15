import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';

/// The Linux userland on iOS, through the API the app will use.
///
/// Inside a real app, which is the only place any of this is true: the engine
/// is linked into the app binary and reached by looking its symbols up in the
/// running process, so a plain `flutter test` would find nothing to call.
///
/// Skipped where the switch is off (`SBM_ISH = 0` in
/// `ios/Flutter/Ish.xcconfig`), which is the default — a checkout that has not
/// run `scripts/build-ish-ios.sh` has no engine to link.
///
/// The filesystem is staged by the harness, exactly as the first Android
/// measurement staged proot: `fakefsify` is a host tool, and putting one on a
/// device is a separate piece of work this does not pretend to have done.
Future<void> _copyDirectory(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final entry in from.list(recursive: false)) {
    final name = entry.path.split('/').last;
    if (entry is Directory) {
      await _copyDirectory(entry, Directory('${to.path}/$name'));
    } else if (entry is File) {
      await entry.copy('${to.path}/$name');
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Where `scripts/build-ish-ios.sh` leaves the filesystem it built.
  ///
  /// Reachable because a simulator shares the Mac's filesystem. On a device
  /// this line is the part that does not exist yet.
  const staged = String.fromEnvironment('ISH_FAKEFS');

  setUpAll(() => IosRootfs.prepare());

  testWidgets('the engine is there, or says it is not', (_) async {
    // Not an assertion either way: this test runs on a build that may have
    // been made with the switch off, and that is a valid build.
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    expect(IosRootfs.root, isNotNull);
  }, skip: !Platform.isIOS);

  testWidgets('a guest runs inside the app and answers', (_) async {
    if (!IosRootfs.isAvailable) {
      markTestSkipped('this build carries no engine (SBM_ISH = 0)');
      return;
    }
    if (staged.isEmpty) {
      markTestSkipped(
        'no filesystem staged; pass --dart-define=ISH_FAKEFS=<path>',
      );
      return;
    }

    // Copied into the app's own container, because that is where it will live
    // and because the guest writes to it.
    //
    // In Dart rather than `/bin/cp`: iOS refuses to start a process at all,
    // even in the simulator — "Starting new processes is not supported on
    // iOS", which is the whole reason this platform gets an interpreter
    // instead of a rootfs and proot. Every file in a fakefs is an ordinary
    // host file, with the guest's metadata in the sqlite db beside them, so a
    // plain recursive copy is enough.
    final root = Directory(IosRootfs.root!);
    if (!await root.exists()) {
      await _copyDirectory(Directory(staged), root);
    }
    expect(await IosRootfs.isInstalled, isTrue);

    final err = IosRootfs.boot(
      'cat /etc/alpine-release; uname -m; id -un; echo SBM_"" IOS_OK',
    );
    expect(err, 0, reason: 'boot returned $err');

    // Read until the guest ends. The engine reports that by returning null
    // rather than an empty string, which is the difference between a quiet
    // guest and a finished one.
    final output = StringBuffer();
    for (var round = 0; round < 200; round++) {
      final chunk = IosRootfs.read(timeout: const Duration(milliseconds: 100));
      if (chunk == null) break;
      output.write(chunk);
    }

    final text = output.toString();
    expect(text, contains(IosRootfs.version));
    expect(text, contains('aarch64'));
    // proot's `-0` has an equivalent here: the guest is its own machine, and
    // the first process is root in it.
    expect(text, contains('root'));
    expect(text, contains('SBM_IOS_OK'));
    expect(IosRootfs.exitCode, 0);
  }, skip: !Platform.isIOS);
}
