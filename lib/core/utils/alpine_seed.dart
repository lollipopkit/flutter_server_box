/// The two files a freshly unpacked Alpine needs before `apk` works.
///
/// Shared by both userlands rather than owned by either, because what they
/// share is the tarball: Android and iOS download the same
/// `alpine-minirootfs-<version>-aarch64.tar.gz` and check it against the same
/// digest. Kept apart they drifted — Android seeded both and iOS seeded
/// neither, so `apk` on a phone worked and `apk` on an iPad reported every
/// package as missing, which reads as a broken mirror rather than a missing
/// resolver.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';

/// A resolver, because the minirootfs ships without `/etc/resolv.conf` and
/// neither platform exposes one a guest can read.
///
/// Public resolvers rather than the host's: an app cannot read the system's
/// on either platform. This does not route around a VPN — the guest's sockets
/// are the host's, so a tunnel that covers the app covers this too.
///
/// Only when there is none. Called at install, where there never is, and again
/// at startup to repair a userland unpacked before this existed — and a guest
/// whose owner has since pointed it at their own resolver is not one to
/// overwrite.
Future<void> seedResolvConf(String root) async {
  final etc = Directory(root.joinPath('etc'));
  if (!await etc.exists()) await etc.create(recursive: true);
  final conf = File(etc.path.joinPath('resolv.conf'));
  if (await conf.exists()) return;
  await conf.writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
}

/// Where `apk` looks for packages, pinned to the branch the rootfs came from.
///
/// The tarball does ship this file, and as of 3.22.5 with these same two
/// lines. Written anyway, because what is being pinned is that the rootfs and
/// the packages come from one branch — a rootfs installing packages built for
/// another is how a distribution breaks — and that has to hold whatever a
/// future tarball defaults to.
Future<void> seedRepositories(
  String root, {
  required String mirror,
  required String branch,
}) async {
  final apk = Directory(root.joinPath('etc').joinPath('apk'));
  if (!await apk.exists()) await apk.create(recursive: true);
  await File(apk.path.joinPath('repositories'))
      .writeAsString('$mirror/$branch/main\n$mirror/$branch/community\n');
}
