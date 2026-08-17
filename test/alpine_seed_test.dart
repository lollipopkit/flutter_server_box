import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/alpine_seed.dart';

/// The two files `apk` needs, and which of them may be overwritten.
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
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('alpine_seed_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File resolv() => File('${root.path}/etc/resolv.conf');
  File repositories() => File('${root.path}/etc/apk/repositories');

  group('the resolver', () {
    test('is written into a tree that has no `etc` yet', () async {
      await seedResolvConf(root.path);

      expect(await resolv().readAsString(), contains('nameserver'));
    });

    test('is left alone when the guest already has one', () async {
      await Directory('${root.path}/etc').create(recursive: true);
      await resolv().writeAsString('nameserver 192.168.1.1\n');

      await seedResolvConf(root.path);

      expect(
        await resolv().readAsString(),
        'nameserver 192.168.1.1\n',
        reason: 'startup repairs every launch, so overwriting here would '
            'undo the user\'s own resolver on every launch',
      );
    });

    test('is written for a userland unpacked before it existed', () async {
      // What an install from an older build looks like: a complete tree, with
      // an `etc` full of everything the tarball ships and no resolver in it.
      await Directory('${root.path}/etc').create(recursive: true);
      await File('${root.path}/etc/alpine-release').writeAsString('3.22.5\n');

      await seedResolvConf(root.path);

      expect(await resolv().exists(), isTrue);
    });
  });

  group('the repositories', () {
    test('are pinned to the branch the rootfs came from', () async {
      await seedRepositories(root.path, mirror: 'https://m', branch: 'v3.22');

      expect(
        await repositories().readAsString(),
        'https://m/v3.22/main\nhttps://m/v3.22/community\n',
      );
    });

    test('replace whatever the tarball shipped', () async {
      // Unlike the resolver: this one is a pin, and a tarball whose default
      // pointed at another branch would have the guest installing packages
      // built for a different Alpine.
      await Directory('${root.path}/etc/apk').create(recursive: true);
      await repositories().writeAsString('https://elsewhere/edge/main\n');

      await seedRepositories(root.path, mirror: 'https://m', branch: 'v3.22');

      expect(await repositories().readAsString(), isNot(contains('edge')));
    });
  });
}
