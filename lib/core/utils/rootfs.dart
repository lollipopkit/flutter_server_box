import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/core/utils/rootfs_manifest_source.dart';
import 'package:server_box/data/model/app/linux_distro.dart';
import 'package:server_box/data/model/app/linux_distros.dart';
import 'package:server_box/data/model/app/rootfs_manifest.dart';

/// The Linux system this app can offer, whichever way it gets one.
///
/// Two platforms, two mechanisms, and nothing above this has a reason to know
/// which. Android unpacks a real rootfs and enters it with proot, because the
/// only thing in the way there is `execve` on the app's own directory. iOS
/// cannot start a process at all, so it carries an interpreter and the "rootfs"
/// is that interpreter's filesystem.
///
/// Both are absent by default — Android's proot is not in this repository and
/// iOS ships with the engine switched off — so every question here can be
/// answered "no", and the terminal tab is written to expect that.
abstract final class Rootfs {
  /// Whether this build could offer one.
  static bool get isAvailable =>
      isAndroid ? AndroidRootfs.isAvailable : IosRootfs.isAvailable;

  /// Whether one is installed and ready to enter.
  static bool get isReady =>
      isAndroid ? AndroidRootfs.isReady : IosRootfs.isReadySync;

  /// Where the selected profile's tree is, or null before [prepare].
  static String? get root => isAndroid ? AndroidRootfs.root : IosRootfs.root;

  /// Where one profile's tree is.
  static String? rootOf(String? id) =>
      isAndroid ? AndroidRootfs.rootOf(id) : IosRootfs.rootOf(id);

  /// Every system installed on this device, in one list whichever platform it
  /// is.
  static List<LinuxProfile> get profiles =>
      isAndroid ? AndroidRootfs.profiles : IosRootfs.profiles;

  /// The one a terminal opens in: what the settings point at, or the first
  /// there is. Null when nothing is installed.
  static LinuxProfile? get selected =>
      isAndroid ? AndroidRootfs.selected : IosRootfs.selected;

  /// Which distribution a *new* profile would be of.
  static LinuxDistro get nextDistro => linuxDistro();

  /// What the selected profile is a release of, or what a new one would be.
  static String get version => selected?.version ?? nextDistro.version;

  /// Whether [profile] is older than what this build would install. Per
  /// profile, since they are of different distributions and different ages.
  ///
  /// This used to answer `isAndroid && …`, and that was right when it was
  /// written: `IosRootfs.version` was a compile-time constant then, so iOS did
  /// not record what was actually on disk and could not answer the question at
  /// all. Both platforms have written a versioned marker since profiles
  /// arrived, and what answers it — two fields of a [LinuxProfile] compared —
  /// has nothing platform-specific in it. The gate was residue, and it meant
  /// iOS never offered an update for a system that had one.
  ///
  /// False when the manifest no longer describes the distribution. There is
  /// nothing to offer as an update, and asking for a version would throw
  /// rather than guess at one.
  ///
  /// Within the series and never across it. An update replaces the tree and
  /// destroys everything installed in it, so offering 26.04 to someone
  /// running 24.04 would be a migration wearing an update's clothes. What it
  /// answers is "there is a newer build of the release you chose".
  static bool isOutdated(LinuxProfile profile) {
    final described = LinuxDistros.describe(profile.distro);
    if (described == null) return false;
    // A marker written before the series was recorded says nothing about
    // which one it is, so it is compared against the preferred release —
    // which is what every build did when there was only one.
    final current = profile.branch.isEmpty
        ? described.preferred
        : described.newestIn(profile.branch);
    if (current == null) return false;
    return profile.version != current.version;
  }

  /// What an install would put on the device, as one answer rather than two
  /// that could disagree.
  ///
  /// Three cases, and the middle one is the whole reason this is not written
  /// inline at the call site:
  ///
  /// - replacing [into]: its own distribution, and the newest build of the
  ///   series already there. Never another series — an install replaces the
  ///   tree and destroys everything in it, so crossing that line would be a
  ///   migration wearing an update's clothes. If that series is gone from the
  ///   manifest there is nothing to update to, so the preferred release is
  ///   the only remaining answer and the caller's dialog names it.
  /// - [picked] by the user: taken as given, distribution and release
  ///   together. They arrive together because a release does not name its
  ///   distribution, and pairing a release from one with a distribution read
  ///   back out of a setting is how they come to disagree.
  /// - neither: the distribution the settings point at, and its preferred
  ///   release.
  static ({LinuxDistro distro, RootfsRelease release}) target({
    LinuxProfile? into,
    ({LinuxDistro distro, RootfsRelease release})? picked,
  }) {
    if (into != null) {
      final distro = into.distro;
      return (
        distro: distro,
        release: distro.info.newestIn(into.branch) ?? distro.preferred,
      );
    }
    if (picked != null) return picked;
    final distro = nextDistro;
    return (distro: distro, release: distro.preferred);
  }

  /// How many terminals are open in [profile], where that can be asked.
  ///
  /// iOS only: its sessions live in one engine that can be asked. Android runs
  /// each in its own proot process and keeps no such list, and answering 0
  /// there means the delete goes ahead as it always has — which is also what
  /// it does when the engine is absent.
  static int openSessions(LinuxProfile profile) =>
      isAndroid ? 0 : IosRootfs.openSessions(profile.id);

  /// Locates both, so a caller does not have to ask which platform it is on.
  static Future<void> prepare() async {
    await RootfsManifestSource.loadLocal();
    await AndroidRootfs.prepare();
    await IosRootfs.prepare();
  }

  /// Rewrites an installed system's mirror and resolver from the settings.
  ///
  /// Both platforms, for the reason [prepare] does both: each answers for
  /// itself when there is nothing on this platform to rewrite.
  static Future<void> applyNetSettings() async {
    await AndroidRootfs.applyNetSettings();
    await IosRootfs.applyNetSettings();
  }

  /// Renames one system, which changes its label and not its directory.
  ///
  /// The id is a path and stays put: renaming a directory out from under a
  /// running session would be the one thing a label change must not do.
  static Future<void> rename(LinuxProfile profile, String label) async {
    final root = rootOf(profile.id);
    if (root == null) return;
    await File(
      root.joinPath(LinuxProfile.marker),
    ).writeAsString(profile.copyWith(label: label).encode());
    if (isAndroid) {
      await AndroidRootfs.scan();
    } else {
      await IosRootfs.scan();
    }
  }

  /// The id of the system deleted most recently.
  ///
  /// Two places delete — the terminal tab and the settings page — and only one
  /// of them holds the sessions that were running inside. A notifier rather
  /// than a callback, because what listens outlives any one deletion.
  static final removed = ValueNotifier<String?>(null);

  /// Deletes one system and everything in it. The others stay.
  ///
  /// The caller asks first.
  static Future<void> removeProfile(String id) async {
    if (isAndroid) {
      await AndroidRootfs.removeProfile(id);
    } else {
      await IosRootfs.removeProfile(id);
    }
    // After the tree is gone, so a listener that closes tabs cannot race the
    // deletion it is reacting to.
    removed.value = id;
  }

  /// Downloads and unpacks a new system of [distro], beside whatever is there.
  static Future<LinuxProfile> install({
    required LinuxDistro distro,
    RootfsRelease? release,
    LinuxProfile? into,
    String? label,
    void Function(double? progress)? onProgress,
    CancelToken? cancel,
  }) {
    return isAndroid
        ? AndroidRootfs.install(
            distro: distro,
            release: release,
            into: into,
            label: label,
            onProgress: onProgress,
            cancel: cancel,
          )
        : IosRootfs.install(
            distro: distro,
            release: release,
            into: into,
            label: label,
            onProgress: onProgress,
            cancel: cancel,
          );
  }
}
