import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/diag.dart';
import 'package:server_box/core/utils/privileged_exec.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/service/detector.dart';
import 'package:server_box/data/service/openrc.dart';
import 'package:server_box/data/service/procd.dart';
import 'package:server_box/data/service/service_manager.dart';
import 'package:server_box/data/service/systemd.dart';

part 'services.freezed.dart';
part 'services.g.dart';

enum ServiceIssue {
  unsupported,
  listFailed,
  unreachable,
}

final class ServiceFailure {
  const ServiceFailure(
    this.issue, {
    this.detail,
    this.detectedManager,
  });

  final ServiceIssue issue;
  final String? detail;
  final String? detectedManager;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceFailure &&
          other.issue == issue &&
          other.detail == detail &&
          other.detectedManager == detectedManager;

  @override
  int get hashCode => Object.hash(issue, detail, detectedManager);
}

@freezed
abstract class ServicesState with _$ServicesState {
  const factory ServicesState({
    @Default(false) bool isBusy,
    @Default(<ServiceUnit>[]) List<ServiceUnit> units,
    @Default(ServiceScopeFilter.all) ServiceScopeFilter scopeFilter,
    ServiceManagerType? manager,
    ServiceListingNotice? notice,
    String? noticeDetail,
    ServiceFailure? failure,
  }) = _ServicesState;
}

@riverpod
class ServicesNotifier extends _$ServicesNotifier {
  late final Spi _spi;
  ServiceManagerBackend? _manager;

  /// Whether the account commands run as is root, asked of the server once.
  /// [Spi.isRoot] only knows the SSH user, and a server reached through its
  /// monitor agent runs commands as whoever the agent runs as.
  bool? _root;

  @override
  ServicesState build(Spi spi) {
    _spi = spi;
    return const ServicesState();
  }

  List<ServiceUnit> get filteredUnits {
    switch (state.scopeFilter) {
      case ServiceScopeFilter.all:
        return state.units;
      case ServiceScopeFilter.system:
        return state.units
            .where((unit) => unit.scope == ServiceScope.system)
            .toList();
      case ServiceScopeFilter.user:
        return state.units
            .where((unit) => unit.scope == ServiceScope.user)
            .toList();
    }
  }

  void setScopeFilter(ServiceScopeFilter filter) {
    state = state.copyWith(scopeFilter: filter);
  }

  /// The command [action] runs, as the confirmation shows it. Null before a
  /// listing has said which manager this is.
  String? commandFor(ServiceUnit unit, ServiceAction action) {
    final manager = _manager;
    if (manager == null) return null;
    return terminalCommand(
      manager.commandFor(unit, action),
      needsRoot: manager.needsRoot(unit),
      isRoot: _spi.isRoot,
    );
  }

  /// Runs [action] on [unit] here, as root where the unit needs it.
  ///
  /// Answers the result for the page to read: a [kSudoPasswordRejected] exit
  /// is the page's cue to ask for a password and call again with it. Null
  /// before a listing has said which manager this is.
  Future<ExecResult?> runAction(
    ServiceUnit unit,
    ServiceAction action, {
    String? password,
  }) async {
    final manager = _manager;
    if (manager == null) return null;
    // The verb and the init system, never the unit's name — that is what runs
    // on the user's machine. Counted when it runs, after any confirmation.
    Diag.crumb(
      SbDiag.service,
      'action',
      data: {'action': action.name, 'via': state.manager?.name ?? '-'},
    );
    final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
    final command = manager.commandFor(unit, action);
    if (!manager.needsRoot(unit)) return exec.run(command);
    return PrivilegedExec.run(
      exec,
      command,
      isRoot: password == null && await _isRoot(exec),
      password: password,
    );
  }

  Future<bool> _isRoot(ServerExec exec) async {
    if (_spi.isRoot) return true;
    if (_root case final root?) return root;
    final result = await exec.run('id -u');
    return _root = result.succeeded && result.stdout.trim() == '0';
  }

  /// The unit's last few log lines. Null where the manager keeps no log it can
  /// read by unit, and where reading failed outright.
  Future<ServiceLog?> recentLog(ServiceUnit unit, {int lines = 5}) async {
    final manager = _manager;
    if (manager == null) return null;
    try {
      final exec = await ref
          .read(serverProvider(_spi.id).notifier)
          .ensureExec();
      return await manager.recentLog(exec, unit, lines: lines);
    } catch (e, s) {
      dprint('Service log', e, s);
      return null;
    }
  }

  /// What to type into a terminal to read the whole log.
  String? logTerminalCommand(ServiceUnit unit) {
    final manager = _manager;
    final command = manager?.logCommand(unit);
    if (manager == null || command == null) return null;
    return terminalCommand(
      command,
      needsRoot: manager.needsRoot(unit),
      isRoot: _spi.isRoot,
    );
  }

  /// What to type into a terminal to read the unit's definition. Unit files
  /// and init scripts are world-readable, so never through sudo.
  String? definitionTerminalCommand(ServiceUnit unit) =>
      _manager?.definitionCommand(unit);

  /// The listed unit with [key], as of the latest listing.
  ServiceUnit? unitFor(String key) =>
      state.units.firstWhereOrNull((unit) => unit.key == key);

  /// Lists the units, and writes nothing once this provider is gone.
  ///
  /// **Every write below an `await` is guarded.** This is keyed by the whole
  /// [Spi], so saving an edit makes a *different* provider and disposes this
  /// one — while a listing started before the edit is still in flight. Writing
  /// `state` then throws `UnmountedRefException` out of a `Future` nobody is
  /// awaiting, which reaches the zone handler and is reported as a crash.
  Future<void> getServices() async {
    state = state.copyWith(isBusy: true);

    final ServerExec exec;
    try {
      exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();
    } catch (e, s) {
      dprint('Services exec', e, s);
      if (!ref.mounted) return;
      state = state.copyWith(
        isBusy: false,
        failure: ServiceFailure(ServiceIssue.unreachable, detail: '$e'),
      );
      return;
    }
    if (!ref.mounted) return;

    try {
      final probe = await ServiceManagerDetector.probe(exec);
      final type = probe.type;
      // Which init system, or that there was none to find. This is the half
      // worth having: systemd is assumed far more often than it is true, and
      // openrc and procd are the reason `ServiceManager` is an abstraction
      // rather than a systemd client. `none` is a real answer too — it is what
      // a container or a busybox appliance reports.
      Diag.crumb(SbDiag.service, 'list', data: {'via': type?.name ?? 'none'});
      if (!ref.mounted) return;
      if (type == null) {
        _manager = null;
        state = state.copyWith(
          units: const [],
          manager: null,
          notice: null,
          noticeDetail: null,
          failure: ServiceFailure(
            ServiceIssue.unsupported,
            detectedManager: probe.description.isEmpty
                ? null
                : probe.description,
          ),
        );
        return;
      }

      final manager = _managerFor(type);
      final listing = await manager.list(exec);
      if (!ref.mounted) return;
      _manager = manager;
      state = state.copyWith(
        units: listing.units,
        scopeFilter: type.supportsUserScope
            ? state.scopeFilter
            : ServiceScopeFilter.all,
        manager: type,
        notice: listing.notice,
        noticeDetail: listing.detail,
        failure: null,
      );
    } catch (e, s) {
      dprint('Services refresh', e, s);
      if (!ref.mounted) return;
      state = state.copyWith(
        units: const [],
        notice: null,
        noticeDetail: null,
        failure: ServiceFailure(ServiceIssue.listFailed, detail: '$e'),
      );
    } finally {
      // Also reached by every `return` above, which is why it is guarded too.
      if (ref.mounted) state = state.copyWith(isBusy: false);
    }
  }

  ServiceManagerBackend _managerFor(ServiceManagerType type) {
    return switch (type) {
      ServiceManagerType.systemd => const SystemdServiceManager(),
      ServiceManagerType.procd => const ProcdServiceManager(),
      ServiceManagerType.openrc => const OpenRcServiceManager(),
    };
  }
}
