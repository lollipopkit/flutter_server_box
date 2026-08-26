import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
import 'package:server_box/core/utils/local_exec.dart';
import 'package:server_box/core/utils/rootfs.dart';
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
  Map<String, String>? get environment => buildSshTerminalEnvironment(spi.envs);

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
  const LocalSource({this.rootfs = false, this.profileId});

  /// Whether the shell runs inside the Linux userland this app installed,
  /// rather than being the platform's own.
  ///
  /// Still this device — the same process tree, the same storage, no network —
  /// so it is a flag here rather than a third kind of source. What differs is
  /// which `/bin/sh` answers, and on Android that is the difference between
  /// toybox and a distribution with a package manager. See [AndroidRootfs].
  final bool rootfs;

  /// Which of the installed systems, when [rootfs]. Null means whichever the
  /// settings select, resolved when the shell is opened rather than here — a
  /// tab restored from a backup made on another device names a profile this one
  /// may not have.
  ///
  /// It is what makes two terminals in two systems two tabs rather than one:
  /// they differ in nothing else.
  final String? profileId;

  @override
  String get label {
    if (!rootfs) return libL10n.device;
    final id = profileId;
    final profile = id == null
        ? Rootfs.selected
        : Rootfs.profiles.firstWhereOrNull((e) => e.id == id);
    return profile?.label ?? Rootfs.nextDistro.label;
  }

  /// Reserved, and not a server id: server ids are generated, so nothing else
  /// can claim it, and a saved session that names it is unambiguous. The same
  /// spelling the Agent uses to name this machine.
  @override
  String get id => rootfs ? '$rootfsId/${profileId ?? ''}' : LocalExec.deviceId;

  /// What every system's id starts with, so a restored tab reopens the shell it
  /// was — and so a saved tab set from before profiles existed still reads as
  /// one, since it is exactly this prefix.
  ///
  /// TODO(migration residue; remove once no saved tab set predates profiles):
  /// `alpine` is the word an earlier build used for the whole feature, kept
  /// because it is what is in those saved sets.
  static const rootfsId = '${LocalExec.deviceId}/alpine';

  /// The profile a saved [id] names, or null for "whichever is selected".
  static String? profileIdOf(String id) {
    if (!id.startsWith('$rootfsId/')) return null;
    final tail = id.substring(rootfsId.length + 1);
    return tail.isEmpty ? null : tail;
  }

  /// Whatever the shell inherits, unless it is a guest — inside the rootfs
  /// Android's `PATH` names directories that do not exist, and a shell that
  /// took it would find none of its own tools.
  @override
  Map<String, String>? get environment =>
      rootfs ? AndroidRootfs.environment : null;

  @override
  String? get tmuxLang => null;

  @override
  bool operator ==(Object other) =>
      other is LocalSource &&
      other.rootfs == rootfs &&
      other.profileId == profileId;

  @override
  int get hashCode => id.hashCode;
}
