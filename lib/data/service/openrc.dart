import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/service_manager.dart';

final class OpenRcServiceManager implements ServiceManagerBackend {
  const OpenRcServiceManager();

  static const catalogCommand = r'''
for directory in /etc/init.d /usr/local/etc/init.d; do
  [ -d "$directory" ] || continue
  for path in "$directory"/*; do
    [ -f "$path" ] && [ -x "$path" ] || continue
    printf '%s\n' "${path##*/}"
  done
done
''';
  static const statusCommand = 'rc-status -s -C';
  static const startupCommand = 'rc-update show';

  @override
  ServiceManagerType get type => ServiceManagerType.openrc;

  @override
  Future<ServiceListing> list(ServerExec exec) async {
    final catalogResult = await exec.run(catalogCommand, entry: 'sh');
    final statusResult = await exec.run(statusCommand);
    if (!statusResult.succeeded) {
      throw ServiceManagerLoadException(statusResult.combined.trim());
    }
    final states = parseStatus(statusResult.stdout);

    final startupResult = await exec.run(startupCommand);
    final enabledNames = startupResult.succeeded
        ? parseEnabledServices(startupResult.stdout)
        : const <String>{};
    final canReportStartup = startupResult.succeeded;
    final catalog = catalogResult.succeeded
        ? parseCatalog(catalogResult.stdout)
        : const <String>{};
    final names = {...catalog, ...states.keys}.toList()..sort();
    final detail = [
      if (!catalogResult.succeeded) catalogResult.combined.trim(),
      if (!startupResult.succeeded) startupResult.combined.trim(),
    ].where((part) => part.isNotEmpty).join('\n');
    final units = [
      for (final name in names)
        ServiceUnit(
          name: name,
          type: ServiceUnitType.service,
          scope: ServiceScope.system,
          state: states[name] ?? ServiceState.unknown,
          enabled: canReportStartup
              ? enabledNames.contains(name)
              : null,
          actions: serviceActions(
            states[name] ?? ServiceState.unknown,
            enabled: canReportStartup
                ? enabledNames.contains(name)
                : null,
          ),
        ),
    ]..sort(compareServices);
    return ServiceListing(
      units: units,
      notice: canReportStartup && catalogResult.succeeded
          ? null
          : ServiceListingNotice.detailsUnavailable,
      detail: detail.isEmpty ? null : detail,
    );
  }

  static Set<String> parseCatalog(String output) {
    return output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  }

  static Map<String, ServiceState> parseStatus(String output) {
    final states = <String, ServiceState>{};
    final linePattern = RegExp(r'^\s*(\S+)\s+\[\s*([^\]]+)\]\s*$');
    for (final line in output.split('\n')) {
      final match = linePattern.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!;
      final raw = match.group(2)!.trim().toLowerCase();
      final state = switch (raw) {
        _ when raw.startsWith('started') => ServiceState.running,
        _ when raw.startsWith('stopped') => ServiceState.stopped,
        _ when raw.startsWith('inactive') => ServiceState.stopped,
        _ when raw.startsWith('crashed') => ServiceState.failed,
        _ when raw.startsWith('failed') => ServiceState.failed,
        _ when raw.startsWith('starting') => ServiceState.starting,
        _ when raw.startsWith('stopping') => ServiceState.stopping,
        _ => ServiceState.unknown,
      };
      states[name] = state;
    }
    return states;
  }

  static Set<String> parseEnabledServices(String output) {
    final services = <String>{};
    final linePattern = RegExp(r'^\s*([^\s|]+)\s*\|\s*(.+)$');
    for (final line in output.split('\n')) {
      final match = linePattern.firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!;
      if (name.toLowerCase() == 'service') continue;
      if (match.group(2)!.trim().isNotEmpty) services.add(name);
    }
    return services;
  }

  @override
  String commandFor(
    ServiceUnit unit,
    ServiceAction action, {
    required bool isRoot,
  }) {
    final name = quotedServiceName(unit.name);
    final command = switch (action) {
      ServiceAction.enable => 'rc-update add $name default',
      ServiceAction.disable => 'rc-update --all delete $name',
      _ => 'rc-service $name ${action.name}',
    };
    return privilegedCommand(command, isRoot: isRoot);
  }
}
