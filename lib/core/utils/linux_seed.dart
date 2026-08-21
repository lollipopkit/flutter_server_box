/// The two files a freshly unpacked Linux system needs before its package
/// manager works, and the settings that decide what goes in them.
///
/// Shared by both platforms rather than owned by either, because what they
/// share is the tarball: Android and iOS download the same rootfs and check it
/// against the same digest. Kept apart they drifted — Android seeded both and
/// iOS seeded neither, so `apk` on a phone worked and `apk` on an iPad reported
/// every package as missing, which reads as a broken mirror rather than a
/// missing resolver.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/res/default.dart';
import 'package:server_box/data/res/store.dart';

/// Which system the app would install, which is not necessarily the one on
/// disk — see `Rootfs.installedDistro` for that.
LinuxDistro linuxDistro() =>
    LinuxDistro.fromName(Stores.setting.linuxDistro.fetch());

/// Where [distro] is fetched from, without a trailing slash so a caller can
/// join a path onto it.
///
/// A setting because the official mirror is not reachable from every network,
/// and every mirror of one distribution carries the same tree under the same
/// layout.
///
/// It decides where the bytes come from and not which bytes are accepted: the
/// release is pinned and its digest checked by the caller that downloads it,
/// and the package manager verifies each package against the keys in the
/// rootfs. A mirror serving something else fails both of those, not this.
///
/// Per distribution, because a mirror of one is not a mirror of another — held
/// as a map so that switching away and back does not quietly drop what was
/// typed.
///
/// Falls back rather than throws. What is stored is whatever a text field last
/// held, and a system that will not install because a setting is malformed is
/// worse than one installed from the default.
String linuxMirror([LinuxDistro? distro]) {
  final it = distro ?? linuxDistro();
  final raw = (Stores.setting.linuxMirrors.fetch()[it.id] ?? '').trim();
  if (!isMirrorValid(raw)) return it.defaultMirror;
  return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
}

/// Records [mirror] as [distro]'s, or forgets it when [mirror] is empty.
///
/// Empty rather than a separate reset: a field cleared to nothing is how
/// someone asks for the default back, and storing the default verbatim would
/// pin it against a future release that moves it.
void setLinuxMirror(LinuxDistro distro, String mirror) {
  final next = Map<String, String>.from(Stores.setting.linuxMirrors.fetch());
  if (mirror.trim().isEmpty) {
    next.remove(distro.id);
  } else {
    next[distro.id] = mirror.trim();
  }
  Stores.setting.linuxMirrors.put(next);
}

/// Whether [value] is a URL a mirror could be at.
///
/// What the settings page refuses, and what [linuxMirror] falls back from.
/// `http` is allowed beside `https` because some mirrors are only reachable
/// that way, and neither the tarball's digest nor the package signatures depend
/// on the transport.
bool isMirrorValid(String value) {
  final url = Uri.tryParse(value);
  return url != null &&
      url.hasAuthority &&
      (url.isScheme('http') || url.isScheme('https'));
}

/// The resolvers to write into the guest's `/etc/resolv.conf`.
///
/// Not per distribution: this is the network the device is on, and every
/// distribution reads the same file. A setting for the same reason the mirror
/// is one, and with less to go on when it is wrong — a package manager reports
/// a resolver it cannot reach as a temporary error against the *mirror*, so the
/// address that is actually failing is never named.
List<String> linuxNameservers() {
  final chosen = parseNameservers(Stores.setting.linuxDns.fetch());
  return chosen.isEmpty ? parseNameservers(Defaults.linuxDns) : chosen;
}

/// The addresses in [value], which is whatever was typed into a text field —
/// commas, spaces or newlines between them.
///
/// Anything that is not an IP address is dropped. `resolv.conf` takes addresses
/// only, and a resolver library reads a name there as a resolver at an address
/// it can never reach — so a hostname typed here would fail as a timeout rather
/// than as the mistake it is.
List<String> parseNameservers(String value) => value
    .split(RegExp(r'[\s,;]+'))
    .where((e) => e.isNotEmpty && InternetAddress.tryParse(e) != null)
    .toList();

/// Whether [root] holds an unpacked Linux system rather than a directory.
///
/// `bin/sh` and `etc/os-release` rather than anything of one distribution's:
/// every distribution ships both, and the question here is whether *a* system
/// is there. There is no manifest to consult — under `realfs` the tree is all
/// there is.
///
/// **Nothing here is followed.** Alpine's `/bin/sh` is an absolute symlink to
/// `/bin/busybox`, which is a path inside the *guest*; resolved against the
/// host it names a file iOS does not have, so `File.exists()` answers false for
/// a tree that is perfectly fine. Measured against a device's own rootfs: every
/// existing install would have read as absent, been offered for reinstall, and
/// taken everything in it.
Future<bool> looksUnpacked(String root) async {
  for (final path in const ['bin/sh', 'etc/os-release']) {
    final type = await FileSystemEntity.type(
      root.joinPath(path),
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) return false;
  }
  return true;
}

/// A resolver, because a minirootfs ships without `/etc/resolv.conf` and
/// neither platform exposes one a guest can read.
///
/// [overwrite] false writes only when there is none — the install path, and the
/// startup path that repairs a system unpacked before any of this existed. A
/// guest whose owner has since pointed it at their own resolver by editing the
/// file is not one to overwrite behind their back. The settings page passes
/// true, because there the owner is the one asking.
///
/// [nameservers] rather than reading the setting here: what this does is write
/// a file, and a function that writes a file is worth being able to call
/// without a database behind it.
Future<void> seedResolvConf(
  String root, {
  required List<String> nameservers,
  bool overwrite = false,
}) async {
  final etc = Directory(root.joinPath('etc'));
  if (!await etc.exists()) await etc.create(recursive: true);
  final conf = File(etc.path.joinPath('resolv.conf'));
  if (!overwrite && await conf.exists()) return;
  await conf.writeAsString(nameservers.map((e) => 'nameserver $e\n').join());
}

/// Where the package manager looks, pinned to the branch the rootfs came from.
///
/// The tarball does ship this file, and with the default mirror in it. Written
/// anyway, because what is being pinned is that the rootfs and the packages
/// come from one branch — a rootfs installing packages built for another is how
/// a distribution breaks — and that has to hold whatever a future tarball
/// defaults to.
///
/// [distro] decides both the path and the format; [mirror] is passed in for the
/// reason [seedResolvConf] takes its nameservers.
Future<void> seedRepositories(
  String root, {
  required LinuxDistro distro,
  required String mirror,
}) async {
  final repo = distro.repositories(mirror);
  final file = File(root.joinPath(repo.path));
  await file.parent.create(recursive: true);
  await file.writeAsString(repo.content);
}
