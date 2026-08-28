import 'dart:convert';

import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/service_manager.dart';

final class ProcdServiceManager implements ServiceManagerBackend {
  const ProcdServiceManager();

  static const catalogCommand = r'''
if [ ! -d /etc/init.d ]; then exit 1; fi
for path in /etc/init.d/*; do
  [ -f "$path" ] && [ -x "$path" ] || continue
  name=${path##*/}
  enabled=0
  for link in /etc/rc.d/S??"$name"; do
    if [ -e "$link" ]; then enabled=1; break; fi
  done
  printf '%s\t%s\n' "$name" "$enabled"
done
''';

  static const statusCommand = 'ubus call service list';

  @override
  ServiceManagerType get type => ServiceManagerType.procd;

  @override
  Future<ServiceListing> list(ServerExec exec) async {
    final catalogResult = await exec.run(catalogCommand, entry: 'sh');
    if (!catalogResult.succeeded) {
      throw ServiceManagerLoadException(catalogResult.combined.trim());
    }

    final enabledByName = parseCatalog(catalogResult.stdout);
    final statusResult = await exec.run(statusCommand);
    Map<String, ServiceState> states = const {};
    String? detail;
    if (statusResult.succeeded) {
      try {
        states = parseServiceStates(statusResult.stdout);
      } catch (e) {
        detail = '$e';
      }
    } else {
      detail = statusResult.combined.trim();
    }

    // Only init scripts are actionable. `ubus` can also expose transient
    // instances with no `/etc/init.d` entry; showing an action for one would
    // manufacture a path from remote JSON that does not exist.
    final names = enabledByName.keys.toList()..sort();
    final units = [
      for (final name in names)
        ServiceUnit(
          name: name,
          type: ServiceUnitType.service,
          scope: ServiceScope.system,
          state: states[name] ?? ServiceState.unknown,
          enabled: enabledByName[name],
          actions: serviceActions(
            states[name] ?? ServiceState.unknown,
            enabled: enabledByName[name],
          ),
        ),
    ]..sort(compareServices);
    return ServiceListing(
      units: units,
      notice: detail == null
          ? null
          : ServiceListingNotice.detailsUnavailable,
      detail: detail,
    );
  }

  static Map<String, bool> parseCatalog(String output) {
    final services = <String, bool>{};
    for (final line in output.split('\n')) {
      final parts = line.trim().split('\t');
      if (parts.length != 2 || parts[0].isEmpty) continue;
      services[parts[0]] = parts[1] == '1';
    }
    return services;
  }

  static Map<String, ServiceState> parseServiceStates(String output) {
    final decoded = jsonDecode(output);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('procd service list is not an object');
    }

    final states = <String, ServiceState>{};
    for (final entry in decoded.entries) {
      final service = entry.value;
      if (service is! Map) {
        states[entry.key] = ServiceState.unknown;
        continue;
      }
      final instances = service['instances'];
      if (instances is! Map || instances.isEmpty) {
        states[entry.key] = ServiceState.stopped;
        continue;
      }
      final running = instances.values.any((instance) {
        return instance is Map && instance['running'] == true;
      });
      states[entry.key] = running
          ? ServiceState.running
          : ServiceState.stopped;
    }
    return states;
  }

  @override
  String commandFor(
    ServiceUnit unit,
    ServiceAction action, {
    required bool isRoot,
  }) {
    final script = quotedServiceName('/etc/init.d/${unit.name}');
    return privilegedCommand(
      '$script ${action.name}',
      isRoot: isRoot,
    );
  }
}
