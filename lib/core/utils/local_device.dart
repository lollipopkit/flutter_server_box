import 'package:fl_tty/fl_tty.dart';
import 'package:server_box/data/res/store.dart';

/// This device, where ServerBox names machines: fl_tty's [LocalExec] runs
/// the commands, this says what the device is called and whether the Agent
/// may use it.
abstract final class LocalDevice {
  /// What names this machine where a server id is expected.
  ///
  /// Reserved rather than generated: server ids come from `ShortId`, whose
  /// alphabet has no `#`, so nothing the user configures can collide with it.
  /// One spelling, shared with the terminal's `LocalSource`.
  static const id = '#local';

  /// Whether the Agent may be told this machine exists at all.
  ///
  /// Three gates where the local target is a container and two elsewhere: the
  /// platform, the setting the user turned on, and a userland to run in.
  /// Asked in one place so the instructions and the tool cannot disagree: a
  /// model told about a machine its tools then refuse spends a turn proposing
  /// commands for it.
  static bool get isOffered {
    final exec = LocalExec.forThisDevice();
    if (exec == null) return false;
    if (!Stores.setting.agentLocalExec.fetch()) return false;
    if (exec.inRootfs && !Rootfs.isReady) return false;
    return true;
  }
}
