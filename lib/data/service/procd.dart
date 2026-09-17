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
  String commandFor(ServiceUnit unit, ServiceAction action) {
    final script = quotedServiceName('/etc/init.d/${unit.name}');
    return '$script ${action.name}';
  }

  @override
  bool needsRoot(ServiceUnit unit) => true;

  /// `logread`'s ring buffer, filtered to lines naming the service. OpenWrt
  /// tags a service's lines with its process name, which is the init script's
  /// name for nearly every package — close enough for "what did it last say",
  /// and the full buffer is one tap away.
  @override
  Future<ServiceLog?> recentLog(
    ServerExec exec,
    ServiceUnit unit, {
    int lines = 5,
  }) async {
    final result = await exec.run(
      'logread -e ${quotedServiceName(unit.name)} | tail -n $lines',
    );
    if (!result.succeeded) return null;
    return ServiceLog(lines: parseLogread(result.stdout));
  }

  /// `Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1234]: message`.
  static List<ServiceLogLine> parseLogread(String output) {
    final pattern = RegExp(
      r'^\w{3} \w{3} +\d+ (\d{2}:\d{2}:\d{2}) \d{4} \S+ (.*)$',
    );
    return [
      for (final line in output.split('\n'))
        if (line.trim().isNotEmpty)
          switch (pattern.firstMatch(line)) {
            final match? => ServiceLogLine(
              time: match.group(1),
              text: match.group(2)!,
            ),
            null => ServiceLogLine(text: line),
          },
    ];
  }

  @override
  String unitStatusCommand(ServiceUnit unit) =>
      '${quotedServiceName('/etc/init.d/${unit.name}')} status';

  @override
  String? logCommand(ServiceUnit unit) =>
      'logread -e ${quotedServiceName(unit.name)}';

  @override
  String? definitionCommand(ServiceUnit unit) =>
      'cat ${quotedServiceName('/etc/init.d/${unit.name}')}';
}
