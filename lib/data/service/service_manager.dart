import 'dart:convert';

import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/src/rust/api/service.dart' as ffi;

/// Which manager a machine runs, from `sbm_parser::service`'s detector.
final class ServiceManagerProbe {
  const ServiceManagerProbe({required this.description, this.type});

  /// Null for a manager this app cannot list.
  final ServiceManagerType? type;

  /// What the machine called it, with its OS: `systemd (Debian GNU/Linux)`.
  final String description;
}

final class ServiceManagerLoadException implements Exception {
  const ServiceManagerLoadException(this.detail);

  final String detail;

  @override
  String toString() => detail;
}

/// A machine's units, as `sbm_parser::service` reads and acts on them — the
/// rules the monitor agent's panel uses too. This class only runs the
/// commands and carries what they printed; which commands, what their output
/// means and what an action is, is decided on the Rust side.
final class ServiceManager {
  const ServiceManager(this.type);

  final ServiceManagerType type;

  /// Asks the machine which manager it runs. Handed to `sh`: the account's
  /// login shell may be fish, which does not read the script.
  static Future<ServiceManagerProbe> probe(ServerExec exec) async {
    final result = await exec.run(ffi.serviceDetectScript(), entry: 'sh');
    if (!result.succeeded) throw StateError(result.combined.trim());
    final probe = ffi.serviceParseProbe(raw: result.stdout);
    return ServiceManagerProbe(
      type: switch (probe.manager) {
        final m? => ServiceManagerType.values.byName(m),
        null => null,
      },
      description: probe.description,
    );
  }

  /// One listing. Its commands are run at once — each is its own round trip
  /// and none depends on another — and each is settled as it is started: one
  /// that throws (a dropped connection) is a command that failed, not an
  /// unobserved error.
  Future<ServiceListing> list(ServerExec exec) async {
    final commands = ffi.serviceListingCommands(managerName: type.name);
    final outputs = await Future.wait([
      for (final c in commands) _run(exec, c),
    ]);
    // The device's clock as the answers arrived: what the machine's is
    // differenced against.
    final now = DateTime.now();
    try {
      final json = await ffi.serviceParseListingJson(managerName: type.name, outputs: outputs);
      return ServiceListing.fromJson(jsonDecode(json) as Map<String, Object?>).onDeviceClock(now);
    } on String catch (detail) {
      throw ServiceManagerLoadException(detail);
    }
  }

  static Future<ffi.ServiceCommandOutput> _run(ServerExec exec, ffi.ServiceCommand c) async {
    final command = c.command;
    if (command == null) {
      return ffi.ServiceCommandOutput(name: c.name, stdout: '', stderr: 'no such command', succeeded: false);
    }
    try {
      final r = await exec.run(command);
      return ffi.ServiceCommandOutput(name: c.name, stdout: r.stdout, stderr: r.stderr, succeeded: r.succeeded);
    } catch (e) {
      return ffi.ServiceCommandOutput(name: c.name, stdout: '', stderr: '$e', succeeded: false);
    }
  }

  String _unit(ServiceUnit unit) => jsonEncode(unit.toJson());

  /// The command, without `sudo`; whether it needs root is [needsRoot].
  String commandFor(ServiceUnit unit, ServiceAction action) =>
      ffi.serviceCommand(managerName: type.name, unitJson: _unit(unit), action: action.name);

  /// A systemd user unit is the one that must not: `sudo systemctl --user`
  /// talks to root's user manager, not this account's.
  bool needsRoot(ServiceUnit unit) => ffi.serviceNeedsRoot(managerName: type.name, unitJson: _unit(unit));

  /// The last [lines] of the unit's log. Null where the manager keeps no log
  /// that can be read by unit.
  Future<ServiceLog?> recentLog(ServerExec exec, ServiceUnit unit, {int lines = 5}) async {
    final command = ffi.serviceRecentLogCommand(managerName: type.name, unitJson: _unit(unit), lines: lines);
    if (command == null) return null;
    final r = await exec.run(command);
    final json = ffi.serviceParseRecentLogJson(
      managerName: type.name,
      stdout: r.stdout,
      stderr: r.stderr,
      succeeded: r.succeeded,
    );
    return json == null ? null : ServiceLog.fromJson(jsonDecode(json) as Map<String, Object?>);
  }

  /// A command to read the whole log in a terminal, null with no such log.
  String? logCommand(ServiceUnit unit) => ffi.serviceLogCommand(managerName: type.name, unitJson: _unit(unit));

  /// A command that prints the unit's definition.
  String definitionCommand(ServiceUnit unit) =>
      ffi.serviceDefinitionCommand(managerName: type.name, unitJson: _unit(unit));

  /// What the manager itself says about the unit, for a terminal.
  String unitStatusCommand(ServiceUnit unit) =>
      ffi.serviceUnitStatusCommand(managerName: type.name, unitJson: _unit(unit));
}

/// [command] as typed into a terminal: prefixed with `sudo` when it needs root
/// and the account is not root, so the terminal asks for the password.
String terminalCommand(String command, {required bool needsRoot, required bool isRoot}) =>
    ffi.serviceTerminalCommand(command: command, needsRoot: needsRoot, isRoot: isRoot);
