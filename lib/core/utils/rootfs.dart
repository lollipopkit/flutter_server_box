import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';

/// The Linux userland this app can offer, whichever way it gets one.
///
/// Two platforms, two mechanisms, and nothing above this has a reason to know
/// which. Android unpacks a real rootfs and enters it with proot, because the
/// only thing in the way there is `execve` on the app's own directory. iOS
/// cannot start a process at all, so it carries an interpreter and the
/// "rootfs" is that interpreter's filesystem.
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

  /// What is installed, or what would be.
  static String get version => isAndroid
      ? (AndroidRootfs.installedVersion ?? AndroidRootfs.version)
      : IosRootfs.version;

  /// Whether a newer one is pinned than the one on disk.
  static bool get isOutdated => isAndroid && AndroidRootfs.isOutdated;

  /// Locates both, so a caller does not have to ask which platform it is on.
  static Future<void> prepare() async {
    await AndroidRootfs.prepare();
    await IosRootfs.prepare();
  }
}
