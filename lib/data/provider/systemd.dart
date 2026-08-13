import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'systemd.freezed.dart';
part 'systemd.g.dart';

/// Why the unit list is not there.
///
/// Told apart because the answers are different things to say: one machine has
/// no systemd at all and never will, another could not be reached, and a third
/// listed its system units fine and only has no user session.
enum SystemdIssue {
  /// `systemctl` is not on the machine. Alpine, most containers, and anything
  /// running OpenRC, runit or s6 land here.
  noSystemd,

  /// `systemctl` is there and did not produce a list.
  listFailed,

  /// No command could be run on this server at all.
  unreachable,

  /// System units listed; the `--user` scope did not. Not fatal — what is on
  /// screen is real, just incomplete.
  noUserScope,
}

/// What is wrong, in as much detail as the machine was willing to give.
class SystemdFailure {
  const SystemdFailure(this.issue, {this.detail, this.initSystem});

  final SystemdIssue issue;

  /// What the server printed, for the cases where [issue] is a reading of it
  /// rather than a certainty.
  final String? detail;

  /// What this machine runs instead, when [issue] is [SystemdIssue.noSystemd]
  /// — the difference between "this did not work" and "this machine is Alpine,
  /// which uses OpenRC".
  final String? initSystem;
}

@freezed
abstract class SystemdState with _$SystemdState {
  const factory SystemdState({
    @Default(false) bool isBusy,
    @Default(<SystemdUnit>[]) List<SystemdUnit> units,
    @Default(SystemdScopeFilter.all) SystemdScopeFilter scopeFilter,

    /// Null once a refresh has produced a list. Held on the state rather than
    /// returned to the caller so the page can keep showing it: a failure is
    /// what that page *is* until it succeeds.
    SystemdFailure? failure,
  }) = _SystemdState;
}

@riverpod
class SystemdNotifier extends _$SystemdNotifier {
  late final Spi _spi;

  @override
  SystemdState build(Spi spi) {
    _spi = spi;
    // The initial load is driven by the view so it can surface failures.
    return const SystemdState();
  }

  List<SystemdUnit> get filteredUnits {
    switch (state.scopeFilter) {
      case SystemdScopeFilter.all:
        return state.units;
      case SystemdScopeFilter.system:
        return state.units
            .where((unit) => unit.scope == SystemdUnitScope.system)
            .toList();
      case SystemdScopeFilter.user:
        return state.units
            .where((unit) => unit.scope == SystemdUnitScope.user)
            .toList();
    }
  }

  void setScopeFilter(SystemdScopeFilter filter) {
    state = state.copyWith(scopeFilter: filter);
  }

  /// System units are essential; user units are optional and only reported.
  Future<void> getUnits() async {
    state = state.copyWith(isBusy: true, failure: null);

    final ServerExec exec;
    try {
      // Asked for rather than taken from the state: a server reached over its
      // monitor agent has no client sitting there, and one is opened on
      // demand — which is the same path the terminal and SFTP take.
      exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
    } catch (e, s) {
      dprint('Systemd exec', e, s);
      state = state.copyWith(
        isBusy: false,
        failure: SystemdFailure(SystemdIssue.unreachable, detail: '$e'),
      );
      return;
    }

    try {
      final system = await _listScope(exec, SystemdUnitScope.system);
      if (system.failure != null) {
        state = state.copyWith(
          units: const [],
          failure: system.failure == SystemdIssue.noSystemd
              // Only worth asking once the answer is "no systemd": on a machine
              // that has it, nobody is wondering what runs the services.
              ? SystemdFailure(
                  SystemdIssue.noSystemd,
                  detail: system.raw,
                  initSystem: await _probeInitSystem(exec),
                )
              : SystemdFailure(SystemdIssue.listFailed, detail: system.raw),
        );
        return;
      }

      final user = await _listScope(exec, SystemdUnitScope.user);
      final units = [...user.units, ...system.units]..sort(_compareUnits);
      state = state.copyWith(
        units: units,
        // Not fatal, and not a snackbar either: the list on screen is real and
        // the note says what is missing from it.
        failure: user.failure == null
            ? null
            : SystemdFailure(SystemdIssue.noUserScope, detail: user.raw),
      );
    } catch (e, s) {
      dprint('Systemd refresh', e, s);
      state = state.copyWith(
        failure: SystemdFailure(SystemdIssue.listFailed, detail: '$e'),
      );
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// systemctl prints nothing for an empty list, so non-empty output yielding
  /// no units means it reported an error rather than an empty list.
  Future<({List<SystemdUnit> units, SystemdIssue? failure, String? raw})>
  _listScope(ServerExec exec, SystemdUnitScope scope) async {
    try {
      final result = await exec.run(scope.listUnitsCmd);
      final raw = result.combined;
      final units = SystemdUnit.parseListUnits(raw, scope);
      if (units.isNotEmpty) return (units: units, failure: null, raw: raw);
      if (raw.trim().isEmpty) return (units: units, failure: null, raw: raw);
      return (
        units: units,
        failure: _missingCommand(result.exitCode, raw)
            ? SystemdIssue.noSystemd
            : SystemdIssue.listFailed,
        raw: raw,
      );
    } catch (e, s) {
      dprint('Systemd ${scope.name} units', e, s);
      return (
        units: const <SystemdUnit>[],
        failure: SystemdIssue.listFailed,
        raw: '$e',
      );
    }
  }

  /// Whether the shell could not find `systemctl` at all.
  ///
  /// 127 is the POSIX shell's answer for that, and the wording differs between
  /// shells (`not found`, `command not found`, busybox's `applet not found`),
  /// so both are checked rather than trusting either alone.
  static bool _missingCommand(int? exitCode, String raw) {
    if (exitCode == 127) return true;
    final said = raw.toLowerCase();
    return said.contains('not found') ||
        said.contains('no such file or directory');
  }

  /// What the machine runs instead of systemd.
  ///
  /// Best effort and one command: the answer only makes an error message
  /// concrete, so a machine that does not answer simply gets the shorter
  /// message.
  Future<String?> _probeInitSystem(ServerExec exec) async {
    const script = r'''
. /etc/os-release 2>/dev/null
if command -v rc-status >/dev/null 2>&1; then init=OpenRC
elif command -v s6-rc >/dev/null 2>&1; then init=s6
elif command -v sv >/dev/null 2>&1 && [ -d /etc/service ]; then init=runit
elif command -v initctl >/dev/null 2>&1; then init=Upstart
elif [ -d /etc/init.d ]; then init=SysVinit
else init=$(cat /proc/1/comm 2>/dev/null)
fi
printf '%s	%s' "${init:-}" "${PRETTY_NAME:-}"
''';
    try {
      final result = await exec.run(script);
      if (!result.succeeded) return null;
      final parts = result.stdout.trim().split('	');
      final init = parts.firstOrNull?.trim() ?? '';
      final os = parts.length > 1 ? parts[1].trim() : '';
      if (init.isEmpty && os.isEmpty) return null;
      if (init.isEmpty) return os;
      if (os.isEmpty) return init;
      return '$init ($os)';
    } catch (e, s) {
      dprint('Probe init system', e, s);
      return null;
    }
  }
}

int _compareUnits(SystemdUnit a, SystemdUnit b) {
  // user units first
  if (a.scope != b.scope) {
    return a.scope == SystemdUnitScope.user ? -1 : 1;
  }
  // active units first
  if (a.state != b.state) {
    return a.state == SystemdUnitState.active ? -1 : 1;
  }
  return a.name.compareTo(b.name);
}
