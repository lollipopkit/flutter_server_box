import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/service_manager.dart';

final class SystemdServiceManager implements ServiceManagerBackend {
  const SystemdServiceManager();

  @override
  ServiceManagerType get type => ServiceManagerType.systemd;

  @override
  Future<ServiceListing> list(ServerExec exec) async {
    final system = await _listScope(exec, ServiceScope.system);
    if (system.failed) throw ServiceManagerLoadException(system.raw);

    final user = await _listScope(exec, ServiceScope.user);
    final units = [...user.units, ...system.units]..sort(compareServices);
    return ServiceListing(
      units: units,
      notice: user.failed
          ? ServiceListingNotice.userScopeUnavailable
          : null,
      detail: user.failed ? user.raw : null,
    );
  }

  Future<({List<ServiceUnit> units, bool failed, String raw})> _listScope(
    ServerExec exec,
    ServiceScope scope,
  ) async {
    final result = await exec.run(listCommand(scope));
    final raw = result.combined;
    final units = parseListUnits(raw, scope);
    final failed = units.isEmpty && raw.trim().isNotEmpty;
    return (units: units, failed: failed, raw: raw);
  }

  static String listCommand(ServiceScope scope) {
    final prefix = scope == ServiceScope.system
        ? 'systemctl'
        : 'systemctl --user';
    return '$prefix list-units --all --no-legend --no-pager --plain '
        '--type=service,socket,mount,timer';
  }

  static List<ServiceUnit> parseListUnits(
    String output,
    ServiceScope scope,
  ) {
    final units = <ServiceUnit>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 4) continue;

      final fullName = parts[0];
      final lastDot = fullName.lastIndexOf('.');
      if (lastDot <= 0) continue;

      final type = ServiceUnitType.fromString(fullName.substring(lastDot + 1));
      if (type == null) continue;

      final state = switch (parts[2].toLowerCase()) {
        'active' => ServiceState.running,
        'inactive' => ServiceState.stopped,
        'failed' => ServiceState.failed,
        'activating' => ServiceState.starting,
        'deactivating' => ServiceState.stopping,
        _ => null,
      };
      if (state == null) continue;

      units.add(ServiceUnit(
        name: fullName.substring(0, lastDot),
        type: type,
        scope: scope,
        state: state,
        actions: serviceActions(state),
        description: parts.length > 4 ? parts.sublist(4).join(' ') : null,
      ));
    }
    return units;
  }

  @override
  String commandFor(
    ServiceUnit unit,
    ServiceAction action, {
    required bool isRoot,
  }) {
    final prefix = unit.scope == ServiceScope.user
        ? 'systemctl --user'
        : isRoot
        ? 'systemctl'
        : 'sudo systemctl';
    final name = '${unit.name}.${unit.type.name}';
    return '$prefix ${action.name} ${quotedServiceName(name)}';
  }
}
