import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/ssh/ssh_terminal_environment.dart';

/// Where a terminal's shell comes from.
///
/// A server is one answer and this device is another, and almost nothing about
/// a terminal depends on which: it has a name, an environment, and something
/// that hands out shells. What does depend on it — a sudo password, a snippet's
/// `${ip}`, the status the app polls — is exactly what only a server has, so
/// those read [ServerSource] rather than being offered a device pretending to
/// be one.
///
/// The same shape the file tab uses for the same reason
/// (`view/page/storage/tab.dart`): two ways to reach something, and no other
/// difference the page cares about.
sealed class TerminalSource {
  const TerminalSource();

  /// What to call this session, on a tab and in the notification.
  String get label;

  /// Distinguishes one session's saved state from another's.
  String get id;

  /// What the shell starts with. Null where there is nothing to add.
  Map<String, String>? get environment;

  /// The locale tmux is launched under, where one is configured.
  String? get tmuxLang;
}

/// A machine in the app's server list.
final class ServerSource extends TerminalSource {
  const ServerSource(this.spi);

  final Spi spi;

  @override
  String get label => spi.name;

  @override
  String get id => spi.id;

  @override
  Map<String, String>? get environment =>
      buildSshTerminalEnvironment(spi.envs);

  @override
  String? get tmuxLang => resolveTmuxLang(spi.envs);

  @override
  bool operator ==(Object other) =>
      other is ServerSource && other.spi.id == spi.id;

  @override
  int get hashCode => spi.id.hashCode;
}

/// The machine the app is running on.
final class LocalSource extends TerminalSource {
  const LocalSource();

  @override
  String get label => libL10n.device;

  /// Reserved, and not a server id: server ids are generated, so nothing else
  /// can claim it, and a saved session that names it is unambiguous. The same
  /// spelling the Agent uses to name this machine.
  @override
  String get id => LocalExec.deviceId;

  /// Whatever the shell inherits. Adding to it would be second-guessing a
  /// login shell about its own machine.
  @override
  Map<String, String>? get environment => null;

  @override
  String? get tmuxLang => null;

  @override
  bool operator ==(Object other) => other is LocalSource;

  @override
  int get hashCode => id.hashCode;
}
