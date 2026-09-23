import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';

// TODO(migration): the whole of this directory is ported to
// `sbm_parser::service` (model, commands and parsers, locked by
// `crates/sbm_parser/tests/service_compat.rs` against `test/fixtures/systemd/`)
// because the monitor agent lists a machine's units with the same rules this
// app does over SSH. Delete this implementation and read it through the FFI
// boundary once the FFI result is asserted identical against those fixtures.
abstract interface class ServiceManagerBackend {
  ServiceManagerType get type;

  Future<ServiceListing> list(ServerExec exec);

  /// The command, without `sudo`. Whether it needs root is [needsRoot]: a
  /// command run here goes through `PrivilegedExec`, and one typed into a
  /// terminal gets the prefix from [terminalCommand].
  String commandFor(ServiceUnit unit, ServiceAction action);

  /// A systemd user unit is the one that must not: `sudo systemctl --user`
  /// talks to root's user manager, not this account's.
  bool needsRoot(ServiceUnit unit);

  /// The last [lines] of the unit's log. Null where the manager keeps no log
  /// that can be read by unit.
  Future<ServiceLog?> recentLog(
    ServerExec exec,
    ServiceUnit unit, {
    int lines,
  });

  /// A command to read the whole log in a terminal, null with no such log.
  String? logCommand(ServiceUnit unit);

  /// A command that prints the unit's definition, null where there is none.
  String? definitionCommand(ServiceUnit unit);

  /// What the manager itself says about the unit, for a terminal. For OpenRC
  /// this is the only thing a unit has to read: it keeps no log by name.
  String unitStatusCommand(ServiceUnit unit);
}

/// [command] as typed into a terminal: prefixed with `sudo` when it needs root
/// and the account is not root, so the terminal asks for the password.
String terminalCommand(
  String command, {
  required bool needsRoot,
  required bool isRoot,
}) {
  return needsRoot && !isRoot ? 'sudo $command' : command;
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
  if (enabled == true) actions.add(ServiceAction.disable);
  if (enabled == false) actions.add(ServiceAction.enable);
  return List.unmodifiable(actions);
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
