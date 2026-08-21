import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/linux_seed.dart';
import 'package:server_box/data/model/app/linux_distro.dart';

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

  /// Where the tree is on the host, or null before [prepare].
  static String? get root => isAndroid ? AndroidRootfs.root : IosRootfs.root;

  /// Which distribution the settings name — what [installed] would become.
  static LinuxDistro get selected => linuxDistro();

  /// What is on disk, or null with nothing installed.
  ///
  /// Distinct from [selected] on purpose: the two differ exactly while a switch
  /// is pending, and that gap is what the settings page acts on.
  static InstalledGuest? get installed =>
      isAndroid ? AndroidRootfs.installed : IosRootfs.installed;

  /// Whether a switch is pending: something is installed, and it is not what
  /// the settings ask for.
  static bool get isDistroMismatched {
    final guest = installed;
    return guest != null && guest.distro != selected;
  }

  /// What is installed, or what would be.
  static String get version => installed?.version ?? selected.version;

  /// Whether a newer release of the installed distribution is pinned than the
  /// one on disk. A *different* distribution is not this — see [isDistroMismatched].
  static bool get isOutdated => isAndroid && AndroidRootfs.isOutdated;

  /// Locates both, so a caller does not have to ask which platform it is on.
  static Future<void> prepare() async {
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

  /// Deletes what is installed, and everything in it.
  ///
  /// The caller asks first. This is what switching distributions goes through,
  /// and what it costs.
  static Future<void> remove() async {
    if (isAndroid) {
      await AndroidRootfs.remove();
    } else {
      await IosRootfs.remove();
    }
  }
}
