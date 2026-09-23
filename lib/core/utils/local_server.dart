import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/data/model/server/system.dart';

/// The device the app runs on, added as a server — see `Spi.local`.
abstract final class LocalServer {
  /// Whether this build can read this device's status and run its commands.
  ///
  /// Desktop only. Android's shell runs as the app inside its own sandbox,
  /// with a `/proc` the platform increasingly hides, and iOS starts no
  /// processes at all, so neither would be describing the machine.
  ///
  /// [ProcessExec.isSupported] as well, for the sandboxed macOS build: that
  /// one is the App Store's, and it cannot open a terminal either — a server
  /// whose terminal button fails is not one to offer.
  static bool get isSupported =>
      (isLinux || isMacOS || isWindows) && ProcessExec.isSupported;

  /// What the status script is generated for on this device.
  ///
  /// Known without running anything, which over SSH takes a round trip:
  /// `SystemDetector` reads `uname`, and this is the answer it would give.
  static SystemType get systemType {
    if (isWindows) return SystemType.windows;
    if (isMacOS) return SystemType.bsd;
    return SystemType.linux;
  }

  /// A fresh [ProcessExec] on the host, never inside a userland: the machine
  /// this server stands for is the host.
  static ProcessExec exec() => const ProcessExec();
}
