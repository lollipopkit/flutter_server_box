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
  static Future<ServiceManagerProbe> probe(CommandExec exec) async {
    final result = await exec.run(ffi.serviceDetectScript(), entry: 'sh');
    if (!result.succeeded) throw CommandFailed('service detection', result);
    final probe = ffi.serviceParseProbe(raw: result.stdout);
    return ServiceManagerProbe(type: probe.manager, description: probe.description);
  }

  /// One listing. Its commands are run at once — each is its own round trip
  /// and none depends on another — and each is settled as it is started: one
  /// that throws (a dropped connection) is a command that failed, not an
  /// unobserved error.
  Future<ServiceListing> list(CommandExec exec) async {
    final commands = ffi.serviceListingCommands(manager: type);
    final outputs = await Future.wait([
      for (final c in commands) _run(exec, c),
    ]);
    // The device's clock as the answers arrived: what the machine's is
    // differenced against.
    final now = DateTime.now();
    try {
      return await ffi.serviceParseListing(manager: type, outputs: outputs, nowMillis: now.millisecondsSinceEpoch);
    } on String catch (detail) {
      throw ServiceManagerLoadException(detail);
    }
  }

  static Future<ffi.ServiceCommandOutput> _run(CommandExec exec, ffi.ServiceCommand c) async {
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

  /// The command, without `sudo`; whether it needs root is [needsRoot].
  String commandFor(ServiceUnit unit, ServiceAction action) =>
      ffi.serviceCommand(manager: type, unit: unit, action: action);

  /// A systemd user unit is the one that must not: `sudo systemctl --user`
  /// talks to root's user manager, not this account's.
  bool needsRoot(ServiceUnit unit) => ffi.serviceNeedsRoot(manager: type, unit: unit);

  /// The last [lines] of the unit's log. Null where the manager keeps no log
  /// that can be read by unit.
  Future<ServiceLog?> recentLog(CommandExec exec, ServiceUnit unit, {int lines = 5}) async {
    final command = ffi.serviceRecentLogCommand(manager: type, unit: unit, lines: lines);
    if (command == null) return null;
    final r = await exec.run(command);
    return ffi.serviceParseRecentLog(manager: type, stdout: r.stdout, stderr: r.stderr, succeeded: r.succeeded);
  }

  /// A command to read the whole log in a terminal, null with no such log.
  String? logCommand(ServiceUnit unit) => ffi.serviceLogCommand(manager: type, unit: unit);

  /// A command that prints the unit's definition.
  String definitionCommand(ServiceUnit unit) =>
      ffi.serviceDefinitionCommand(manager: type, unit: unit);

  /// What the manager itself says about the unit, for a terminal.
  String unitStatusCommand(ServiceUnit unit) =>
      ffi.serviceUnitStatusCommand(manager: type, unit: unit);
}

/// [command] as typed into a terminal: prefixed with `sudo` when it needs root
/// and the account is not root, so the terminal asks for the password.
String terminalCommand(String command, {required bool needsRoot, required bool isRoot}) =>
    ffi.serviceTerminalCommand(command: command, needsRoot: needsRoot, isRoot: isRoot);
