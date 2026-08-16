import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/guest_path.dart';

/// What the Agent's file tools may reach when the local target is a userland.
///
/// This is the boundary itself, not a convenience: `read_file` is the one tool
/// that is deliberately not reviewed before it runs, and on the host it is
/// `dart:io` with no notion of a container. Exercised here rather than only on
/// a device because it is filesystem logic and belongs to neither platform —
/// Android's rootfs and iOS's guest tree are the same question.
void main() {
  late Directory root;
  late String realRoot;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('rootfs_test');
    // Resolved: macOS puts temp directories under a symlinked `/var`, which is
    // the same shape as Android's `/data/user/0` and would otherwise make
    // every comparison below fail for the wrong reason.
    realRoot = await root.resolveSymbolicLinks();
    await Directory('${root.path}/etc').create(recursive: true);
    await File('${root.path}/etc/alpine-release').writeAsString('3.22.5\n');
    await Directory('${root.path}/tmp').create(recursive: true);
  });

  tearDown(() => root.delete(recursive: true));

  Future<String?> resolve(String guest, {bool forWrite = false}) =>
      resolveWithinRoot(root.path, guest, forWrite: forWrite);

  group('a path inside the container', () {
    test('is the same path under the rootfs', () async {
      expect(await resolve('/etc/alpine-release'), '$realRoot/etc/alpine-release');
    });

    test('is the root itself when that is what was asked for', () async {
      expect(await resolve('/'), realRoot);
    });

    test('resolves . and redundant separators', () async {
      expect(await resolve('/./etc//alpine-release'), '$realRoot/etc/alpine-release');
    });

    test('a file that does not exist yet can still be written', () async {
      expect(await resolve('/tmp/new.txt', forWrite: true), '$realRoot/tmp/new.txt');
    });
  });

  group('a path that leaves it', () {
    test('..  is resolved against the container root, not the host', () async {
      // Not an escape: inside a container `/../etc` is `/etc`, and clamping it
      // silently would hand back a different file than the one named.
      expect(await resolve('/../etc/alpine-release'), '$realRoot/etc/alpine-release');
      expect(await resolve('/etc/../../etc/alpine-release'), '$realRoot/etc/alpine-release');
    });

    test('a symlink out of the container is refused', () async {
      // One reviewed `ln -s` away, and `File.readAsBytes` would follow it
      // without asking anybody.
      final outside = await Directory.systemTemp.createTemp('outside');
      addTearDown(() => outside.delete(recursive: true));
      await File('${outside.path}/secret').writeAsString('not yours');
      await Link('${root.path}/tmp/out').create(outside.path);

      expect(await resolve('/tmp/out/secret'), isNull);
      expect(await resolve('/tmp/out/secret', forWrite: true), isNull);
    });

    test('a symlink within the container is followed', () async {
      await Link('${root.path}/tmp/release').create('$realRoot/etc/alpine-release');

      expect(await resolve('/tmp/release'), '$realRoot/etc/alpine-release');
    });

    test('a relative path means nothing here', () async {
      // The guest's working directory is not this process's, so there is
      // nothing for one to be relative to.
      expect(await resolve('etc/alpine-release'), isNull);
    });

    test('a path that does not exist is not readable', () async {
      expect(await resolve('/etc/nope'), isNull);
    });

    test('a write into a directory that does not exist is refused', () async {
      expect(await resolve('/nope/new.txt', forWrite: true), isNull);
    });
  });

  test('no rootfs on disk means nothing is inside one', () async {
    expect(await resolveWithinRoot('${root.path}/gone', '/etc/hosts'), isNull);
  });
}
