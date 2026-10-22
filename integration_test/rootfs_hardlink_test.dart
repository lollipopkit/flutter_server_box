import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:server_box/data/res/build_data.dart';
import 'package:server_box/data/res/misc.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../test/helpers/test_db.dart';

/// The systems whose archives carry hard links, installed and run.
///
/// Android refuses `link()` in the app's data directory, so unpacking these
/// with the system tar alone failed on every hard-link entry (#1697): Ubuntu's
/// coreutils and perl, Rocky's zoneinfo and `.pyc` files. Alpine has none,
/// which is why `rootfs_shell_test.dart` never saw it.
///
/// Downloads each system, so it needs the network and a few minutes. Skipped
/// where there is no proot to run.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Paths.init(BuildData.name, bakName: Miscs.bakFileName);
    // The install reads its mirror from the settings.
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // The manifest as well as proot: what each system is and where to get it.
    await Rootfs.prepare();
    for (final profile in AndroidRootfs.profiles.toList()) {
      await AndroidRootfs.removeProfile(profile.id);
    }
  });

  /// What [command] prints inside [profileId], stdout and stderr together.
  Future<String> inside(String profileId, String command) async {
    final entry = await AndroidRootfs.enter(
      command: command,
      profileId: profileId,
    );
    expect(entry, isNotNull);
    try {
      final res = await Process.run(
        entry!.executable,
        entry.arguments,
        environment: AndroidRootfs.environment,
      );
      return '${res.stdout}${res.stderr}';
    } finally {
      entry!.release();
    }
  }

  // What each system ships as a hard link, and a command that runs it.
  final cases = {
    // uutils coreutils is one binary with every tool a hard link to it, and
    // perl-base links `perl` to `perl5.x`.
    LinuxDistro.ubuntu: 'ls --version | head -1; perl -e \'print "perl-ok\\n"\'',
    // zoneinfo's `right/UTC` is a hard link to `right/Etc/UCT`.
    LinuxDistro.rocky: 'cat /etc/rocky-release; test -s /usr/share/zoneinfo/right/UTC && echo tz-ok',
  };

  for (final MapEntry(key: distro, value: command) in cases.entries) {
    testWidgets('${distro.name} installs, hard links and all', (_) async {
      if (!AndroidRootfs.isAvailable) {
        markTestSkipped('this build carries no proot');
        return;
      }
      final profile = await AndroidRootfs.install(distro: distro);
      addTearDown(() => AndroidRootfs.removeProfile(profile.id));

      final out = await inside(profile.id, command);
      if (distro == LinuxDistro.ubuntu) {
        expect(out, contains('uutils coreutils'));
        expect(out, contains('perl-ok'));
      } else {
        expect(out, contains('Rocky Linux'));
        expect(out, contains('tz-ok'));
      }

      // #1698: a temporary file goes where the guest has one.
      final tmp = await inside(
        profile.id,
        r'echo "tmpdir=$TMPDIR"; f=$(mktemp) && echo made && rm "$f"',
      );
      expect(tmp, contains('tmpdir=/tmp'));
      expect(tmp, contains('made'));
    }, skip: !Platform.isAndroid, timeout: const Timeout(Duration(minutes: 15)));
  }
}
