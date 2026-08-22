import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// The two files a package manager needs, which of them may be overwritten,
/// and what the settings behind them accept.
///
/// Written after a device run found the iOS guest had no `/etc/resolv.conf`:
/// its sockets worked and an address literal fetched fine, but every mirror
/// answered "temporary error" and every package was missing. Android had
/// seeded one since it was written and iOS never had, which is what happens
/// when two platforms unpack the same tarball from two copies of the code.
///
/// The asymmetry below is the part worth locking: the resolver is repaired at
/// every startup, so overwriting one would take a guest the user had pointed
/// at their own DNS and quietly point it back.
void main() {
  // Distribution data comes from the manifest now; `Rootfs.prepare` loads
  // it in the app, and a test reads the same file off disk.
  setUpAll(() {
    LinuxDistros.adoptForTest(
      RootfsManifest.parse(
        File('assets/rootfs_manifest.json').readAsStringSync(),
      ),
    );
  });

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('linux_seed_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File resolv() => File('${root.path}/etc/resolv.conf');
  File repositories() => File('${root.path}/etc/apk/repositories');

  group('the resolver', () {
    test('is written into a tree that has no `etc` yet', () async {
      await seedResolvConf(root.path, nameservers: const ['8.8.8.8']);

      expect(await resolv().readAsString(), 'nameserver 8.8.8.8\n');
    });

    test('takes one line per address, in the order given', () async {
      await seedResolvConf(
        root.path,
        nameservers: const ['223.5.5.5', '1.1.1.1'],
      );

      expect(
        await resolv().readAsString(),
        'nameserver 223.5.5.5\nnameserver 1.1.1.1\n',
      );
    });

    test('is left alone when the guest already has one', () async {
      await Directory('${root.path}/etc').create(recursive: true);
      await resolv().writeAsString('nameserver 192.168.1.1\n');

      await seedResolvConf(root.path, nameservers: const ['8.8.8.8']);

      expect(
        await resolv().readAsString(),
        'nameserver 192.168.1.1\n',
        reason:
            'startup repairs every launch, so overwriting here would '
            'undo the user\'s own resolver on every launch',
      );
    });

    test('is replaced when the owner is the one asking', () async {
      await Directory('${root.path}/etc').create(recursive: true);
      await resolv().writeAsString('nameserver 192.168.1.1\n');

      await seedResolvConf(
        root.path,
        nameservers: const ['223.5.5.5'],
        overwrite: true,
      );

      expect(
        await resolv().readAsString(),
        'nameserver 223.5.5.5\n',
        reason: 'the settings page saving a resolver has to reach the file, '
            'which is the only thing `apk` reads',
      );
    });

    test('is written for a userland unpacked before it existed', () async {
      // What an install from an older build looks like: a complete tree, with
      // an `etc` full of everything the tarball ships and no resolver in it.
      await Directory('${root.path}/etc').create(recursive: true);
      await File('${root.path}/etc/alpine-release').writeAsString('3.22.5\n');

      await seedResolvConf(root.path, nameservers: const ['8.8.8.8']);

      expect(await resolv().exists(), isTrue);
    });
  });

  group('whether a tree is an unpacked system', () {
    Future<void> unpackLikeAlpine() async {
      await Directory('${root.path}/bin').create(recursive: true);
      await Directory('${root.path}/usr/lib').create(recursive: true);
      await File('${root.path}/usr/lib/os-release').writeAsString('ID=alpine\n');
      // Exactly what the tarball carries, and the whole point of this group:
      // `/bin/busybox` is a path inside the *guest*. Followed from the host it
      // names a file that is not there — on iOS, never there.
      await Link('${root.path}/bin/sh').create('/bin/busybox');
      await Link('${root.path}/etc/os-release').create('../usr/lib/os-release');
    }

    setUp(() => Directory('${root.path}/etc').create(recursive: true));

    test('an absolute guest symlink still counts', () async {
      await unpackLikeAlpine();

      // The trap this locks, stated as a property of the link rather than of
      // the machine running the test: the target is absolute *in the guest*,
      // so following it from the host leaves the tree altogether. Where the
      // host has no `/bin/busybox` that reads as absent, and every existing
      // install looks uninstalled — which is the bug. Where the host has one,
      // and a Linux runner does, it reads as present for a file in the wrong
      // tree. Neither answer is about this one, which is why [looksUnpacked]
      // does not follow links.
      //
      // Asserting the first of those two — `File(...).exists()` is false — is
      // what this used to do, and it passed on macOS and failed on CI.
      expect(await Link('${root.path}/bin/sh').target(), startsWith('/'));
      expect(await looksUnpacked(root.path), isTrue);
    });

    test('an empty directory does not', () async {
      expect(await looksUnpacked(root.path), isFalse);
    });

    test('neither does half of one', () async {
      await Directory('${root.path}/bin').create(recursive: true);
      await Link('${root.path}/bin/sh').create('/bin/busybox');

      expect(await looksUnpacked(root.path), isFalse);
    });
  });

  group('the repositories', () {
    test('are pinned to the branch the rootfs came from', () async {
      await seedRepositories(
        root.path,
        distro: LinuxDistro.alpine,
        mirror: 'https://m',
      );

      expect(
        await repositories().readAsString(),
        'https://m/v3.22/main\nhttps://m/v3.22/community\n',
      );
    });

    test('replace whatever the tarball shipped', () async {
      // Unlike the resolver: this one is a pin, and a tarball whose default
      // pointed at another branch would have the guest installing packages
      // built for a different release.
      await Directory('${root.path}/etc/apk').create(recursive: true);
      await repositories().writeAsString('https://elsewhere/edge/main\n');

      await seedRepositories(
        root.path,
        distro: LinuxDistro.alpine,
        mirror: 'https://m',
      );

      expect(await repositories().readAsString(), isNot(contains('edge')));
    });
  });

  group('what a nameserver setting accepts', () {
    test('splits on commas, spaces and newlines alike', () {
      expect(
        parseNameservers('223.5.5.5, 1.1.1.1\n8.8.8.8;9.9.9.9'),
        ['223.5.5.5', '1.1.1.1', '8.8.8.8', '9.9.9.9'],
      );
    });

    test('keeps IPv6', () {
      expect(parseNameservers('2001:4860:4860::8888'), [
        '2001:4860:4860::8888',
      ]);
    });

    test('drops anything that is not an address', () {
      // `resolv.conf` takes addresses only. musl reads a name there as a
      // resolver at an address it can never reach, so this would fail as a
      // timeout rather than as the mistake it is.
      expect(parseNameservers('dns.google, 1.1.1.1'), ['1.1.1.1']);
    });

    test('is empty for nothing at all', () {
      expect(parseNameservers('   '), isEmpty);
    });
  });

  group('what a mirror setting accepts', () {
    test('takes http and https', () {
      expect(isMirrorValid('https://mirrors.ustc.edu.cn/alpine'), isTrue);
      expect(isMirrorValid('http://mirrors.ustc.edu.cn/alpine'), isTrue);
    });

    test('refuses a bare host, which has no scheme to fetch with', () {
      expect(isMirrorValid('mirrors.ustc.edu.cn/alpine'), isFalse);
    });

    test('refuses a scheme `Dio` would not download over', () {
      expect(isMirrorValid('ftp://mirrors.ustc.edu.cn/alpine'), isFalse);
      expect(isMirrorValid('file:///tmp/alpine'), isFalse);
    });

    test('refuses nothing at all', () {
      expect(isMirrorValid(''), isFalse);
    });
  });

  group('what a shell setting accepts', () {
    test('a guest-absolute path', () {
      expect(isShellPathValid('/bin/sh'), isTrue);
      expect(isShellPathValid('/usr/bin/fish'), isTrue);
    });

    test('nothing relative', () {
      // It would be resolved against a working directory the session has not
      // got yet, and the engine would answer ENOENT from inside
      // `sbm_ish_open` — a terminal that opens and dies with the reason
      // nowhere on screen.
      expect(isShellPathValid('fish'), isFalse);
      expect(isShellPathValid('bin/sh'), isFalse);
      expect(isShellPathValid(''), isFalse);
    });

    test('nothing with whitespace in it', () {
      // argv is built as one NUL-separated block in `sbm_ish_open`; a path with
      // a space would not split back into what was meant.
      expect(isShellPathValid('/bin/sh -l'), isFalse);
    });

    test('is checked against the tree, links and all', () async {
      await Directory('${root.path}/bin').create(recursive: true);
      await File('${root.path}/bin/ash').writeAsString('');
      // Alpine's shells are links to busybox, and the target is a guest path
      // that does not resolve host-side — the same trap `looksUnpacked` locks.
      await Link('${root.path}/bin/sh').create('/bin/busybox');

      expect(await shellExistsIn(root.path, '/bin/ash'), isTrue);
      expect(await shellExistsIn(root.path, '/bin/sh'), isTrue);
      expect(await shellExistsIn(root.path, '/usr/bin/fish'), isFalse);
      expect(await shellExistsIn(root.path, 'fish'), isFalse);
    });
  });

  group('the shell a system records', () {
    test('is /bin/sh until the file says otherwise', () async {
      expect(linuxShell(root.path), '/bin/sh');
      expect(linuxShell(null), '/bin/sh');
    });

    test('round-trips through the file `chsh` writes', () async {
      await setLinuxShell(root.path, '/usr/bin/fish');

      expect(linuxShell(root.path), '/usr/bin/fish');
      expect(
        await File('${root.path}/$shellConfPath').readAsString(),
        '/usr/bin/fish\n',
        reason: 'the guest reads this file too, so its shape is a contract',
      );
    });

    test('is /bin/sh for a file holding something that is not a path', () {
      // Whatever a text field or a `chsh` argument last left there. A terminal
      // that cannot open is worse than one that opens on the wrong shell.
      File('${root.path}/$shellConfPath')
        ..createSync(recursive: true)
        ..writeAsStringSync('fish\n');

      expect(linuxShell(root.path), '/bin/sh');
    });

    test('is per system, not one for all of them', () async {
      // A shell is a path to a file inside one tree: `/usr/bin/fish` being
      // installed in one says nothing about another.
      final other = await Directory.systemTemp.createTemp('linux_seed_other');
      addTearDown(() => other.delete(recursive: true));
      await setLinuxShell(root.path, '/usr/bin/fish');

      expect(linuxShell(other.path), '/bin/sh');
    });
  });

  group('the chsh stand-in', () {
    test('is written with the file it edits', () async {
      await seedChsh(root.path);

      final script = File('${root.path}/usr/local/bin/chsh');
      expect(await script.exists(), isTrue);
      expect(await script.readAsString(), contains('serverbox-chsh v'));
      expect(linuxShell(root.path), '/bin/sh');
    });

    test('goes to /usr/local/bin, which the PATH reaches first', () async {
      // So it also shadows the real `chsh` for anyone who installs `shadow`
      // afterwards — which is what to want, since that one edits /etc/passwd
      // and nothing here reads it.
      await seedChsh(root.path);

      expect(
        await File('${root.path}/usr/local/bin/chsh').exists(),
        isTrue,
      );
    });

    test('leaves a shell the system already recorded alone', () async {
      await setLinuxShell(root.path, '/usr/bin/fish');

      await seedChsh(root.path);

      expect(linuxShell(root.path), '/usr/bin/fish');
    });

    test('does not overwrite a chsh that is not ours', () async {
      // `apk add shadow` puts a real one there. Overwriting a package's file
      // would have `apk` reporting a modified system, and PATH puts ours first
      // regardless.
      final script = File('${root.path}/usr/local/bin/chsh');
      await script.parent.create(recursive: true);
      await script.writeAsString('#!/bin/sh\n# not ours\n');

      await seedChsh(root.path);

      expect(await script.readAsString(), contains('not ours'));
    });
  });

  group('what the settings answer', () {
    setUp(() async {
      await openTestDb();
      await getIt.reset();
      getIt.registerSingleton<SettingStore>(SettingStore.forTest()..init());
    });

    tearDown(() async {
      await getIt.reset();
      SqliteDb.close();
    });

    test('the default, until something is stored', () {
      expect(linuxDistro(), LinuxDistro.alpine);
      expect(linuxMirror(), LinuxDistro.alpine.defaultMirror);
      expect(linuxNameservers(), ['8.8.8.8', '1.1.1.1']);
    });

    test('Alpine for a distribution name no build knows', () {
      // What an install downgraded from a build that had more of them would
      // leave behind. Falling back beats throwing on a string read from a
      // store.
      Stores.setting.linuxDistro.put('plan9');

      expect(linuxDistro(), LinuxDistro.alpine);
    });

    test('a stored mirror, without its trailing slash', () {
      setLinuxMirror(
        LinuxDistro.alpine,
        'https://mirrors.ustc.edu.cn/alpine/',
      );

      expect(
        linuxMirror(),
        'https://mirrors.ustc.edu.cn/alpine',
        reason: 'callers join a path onto this, and `//` is a different path',
      );
    });

    test('the default for a mirror that is not a URL', () {
      // This holds whatever a text field last had in it. A system that will not
      // install because a setting is malformed is worse than one installed from
      // the default.
      setLinuxMirror(LinuxDistro.alpine, 'mirrors.ustc.edu.cn');

      expect(linuxMirror(), LinuxDistro.alpine.defaultMirror);
    });

    test('a mirror is kept per distribution, not shared', () {
      // The point of the map: a mirror of one distribution is not a mirror of
      // another, so asking for one must never answer with the other's.
      setLinuxMirror(LinuxDistro.alpine, 'https://mirrors.ustc.edu.cn/alpine');

      expect(
        Stores.setting.linuxMirrors.fetch(),
        {LinuxDistro.alpine.id: 'https://mirrors.ustc.edu.cn/alpine'},
      );
    });

    test('an emptied mirror is forgotten rather than stored', () {
      setLinuxMirror(LinuxDistro.alpine, 'https://mirrors.ustc.edu.cn/alpine');
      setLinuxMirror(LinuxDistro.alpine, '  ');

      expect(
        Stores.setting.linuxMirrors.fetch(),
        isEmpty,
        reason: 'storing the default verbatim would pin it against a release '
            'that moves it',
      );
      expect(linuxMirror(), LinuxDistro.alpine.defaultMirror);
    });

    test('the default for resolvers that are all unusable', () {
      Stores.setting.linuxDns.put('dns.google');

      expect(linuxNameservers(), ['8.8.8.8', '1.1.1.1']);
    });


  });
}
