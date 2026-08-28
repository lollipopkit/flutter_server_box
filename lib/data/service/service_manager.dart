import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';

abstract interface class ServiceManagerBackend {
  ServiceManagerType get type;

  Future<ServiceListing> list(ServerExec exec);

  String commandFor(
    ServiceUnit unit,
    ServiceAction action, {
    required bool isRoot,
  });
}

final class ServiceManagerLoadException implements Exception {
  const ServiceManagerLoadException(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

List<ServiceAction> serviceActions(
  ServiceState state, {
  bool? enabled,
}) {
  final actions = <ServiceAction>[];
  switch (state) {
    case ServiceState.running:
      actions.addAll([ServiceAction.stop, ServiceAction.restart]);
      break;
    case ServiceState.stopped:
      actions.add(ServiceAction.start);
      break;
    case ServiceState.failed:
      actions.add(ServiceAction.restart);
      break;
    case ServiceState.starting:
      actions.add(ServiceAction.stop);
      break;
    case ServiceState.stopping:
      actions.add(ServiceAction.start);
      break;
    case ServiceState.unknown:
      actions.addAll([ServiceAction.start, ServiceAction.restart]);
      break;
  }
  actions.add(ServiceAction.status);
  if (enabled == true) actions.add(ServiceAction.disable);
  if (enabled == false) actions.add(ServiceAction.enable);
  return List.unmodifiable(actions);
}

String privilegedCommand(String command, {required bool isRoot}) {
  return isRoot ? command : 'sudo $command';
}

String quotedServiceName(String value) => shellSingleQuote(value);

int compareServices(ServiceUnit a, ServiceUnit b) {
  if (a.scope != b.scope) {
    return a.scope == ServiceScope.user ? -1 : 1;
  }
  if (a.state != b.state) {
    if (a.state == ServiceState.running) return -1;
    if (b.state == ServiceState.running) return 1;
  }
  return a.name.compareTo(b.name);
}
