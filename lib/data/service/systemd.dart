import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/service_manager.dart';

final class SystemdServiceManager implements ServiceManagerBackend {
  const SystemdServiceManager();

  static const _types = 'service,socket,mount,timer';

  /// What the list needs beyond `list-units`' four columns. Read in one call
  /// per scope rather than one per unit: a machine has a few hundred.
  static const detailProperties = [
    'Id',
    'UnitFileState',
    'SubState',
    'Result',
    'ExecMainStatus',
    'MemoryCurrent',
    'ActiveEnterTimestamp',
    'ActiveExitTimestamp',
    'InactiveEnterTimestamp',
    'InactiveExitTimestamp',
    'NextElapseUSecRealtime',
  ];

  @override
  ServiceManagerType get type => ServiceManagerType.systemd;

  @override
  Future<ServiceListing> list(ServerExec exec) async {
    // All four started before any is awaited: each is its own round trip, and
    // nothing about one depends on another.
    //
    // Each is settled as it is started. Awaited one after another, the first
    // to throw — a dropped connection, a refused channel — would leave the
    // others' errors unobserved, and an unobserved Future error reaches the
    // zone handler and is reported as a crash.
    final systemList = _settle(_listScope(exec, ServiceScope.system));
    final systemDetails = _settle(exec.run(detailsCommand(ServiceScope.system)));
    final userList = _settle(_listScope(exec, ServiceScope.user));
    final userDetails = _settle(exec.run(detailsCommand(ServiceScope.user)));

    final system = await systemList;
    final user = await userList;
    final details = [await systemDetails, await userDetails];

    // The system listing is the page: without it there is nothing to show.
    if (system.error case final error?) {
      Error.throwWithStackTrace(error, system.stack!);
    }
    final systemUnits = system.value!;
    if (systemUnits.failed) throw ServiceManagerLoadException(systemUnits.raw);

    // The user scope is optional, and missing it has a notice of its own
    // whether the command failed or could not be run at all.
    final userUnits =
        user.value ??
        (units: const <ServiceUnit>[], failed: true, raw: '${user.error}');

    final byKey = <String, SystemdUnitDetails>{};
    var detailsFailed = false;
    final now = DateTime.now();
    for (final (scope, settled) in [
      (ServiceScope.system, details[0]),
      (ServiceScope.user, details[1]),
    ]) {
      final result = settled.value;
      if (result == null || !result.succeeded) {
        // The user scope's details fail for the same reason its listing does,
        // which already has a notice of its own.
        if (scope == ServiceScope.system || !userUnits.failed) {
          detailsFailed = true;
        }
        continue;
      }
      for (final entry in parseDetails(result.stdout, now: now).entries) {
        byKey['${scope.name}:${entry.key}'] = entry.value;
      }
    }

    final units = [
      for (final unit in [...userUnits.units, ...systemUnits.units])
        withDetails(unit, byKey[unit.key]),
    ]..sort(compareServices);
    return ServiceListing(
      units: units,
      notice: userUnits.failed
          ? ServiceListingNotice.userScopeUnavailable
          : detailsFailed
          ? ServiceListingNotice.detailsUnavailable
          : null,
      detail: userUnits.failed ? userUnits.raw : null,
    );
  }

  static Future<({T? value, Object? error, StackTrace? stack})> _settle<T>(
    Future<T> future,
  ) {
    return future.then(
      (value) => (value: value, error: null, stack: null),
      onError: (Object error, StackTrace stack) =>
          (value: null, error: error, stack: stack),
    );
  }

  Future<({List<ServiceUnit> units, bool failed, String raw})> _listScope(
    ServerExec exec,
    ServiceScope scope,
  ) async {
    final result = await exec.run(listCommand(scope));
    final raw = result.combined;
    final units = parseListUnits(result.stdout, scope);
    final failed = !result.succeeded;
    return (units: units, failed: failed, raw: raw);
  }

  static String _systemctl(ServiceScope scope) =>
      scope == ServiceScope.system ? 'systemctl' : 'systemctl --user';

  static String listCommand(ServiceScope scope) {
    return '${_systemctl(scope)} list-units --all --no-legend --no-pager '
        '--plain --type=$_types';
  }

  /// `systemctl show` for every loaded unit of the four types, preceded by the
  /// server's clock.
  ///
  /// Timestamps are printed in UTC and the C locale, which makes them one
  /// fixed format: in the server's own zone they end in an abbreviation like
  /// `CST`, which names three different offsets. `--timestamp=unix` would
  /// avoid parsing at all but arrived in systemd 251, after Debian 11 and
  /// RHEL 8. `env` rather than a `TZ=` prefix, because this runs in the
  /// account's login shell and that may not be a POSIX one.
  ///
  /// The server's clock comes along because a duration is only right on the
  /// clock the timestamps were taken on.
  static String detailsCommand(ServiceScope scope) {
    final systemctl = _systemctl(scope);
    final patterns = _types.split(',').map((t) => "'*.$t'").join(' ');
    return 'date +%s; env TZ=UTC LC_ALL=C $systemctl show --no-pager '
        '--property=${detailProperties.join(',')} -- $patterns';
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
        subState: parts[3],
        description: parts.length > 4 ? parts.sublist(4).join(' ') : null,
      ));
    }
    return units;
  }

  /// Blocks of `Key=value` lines separated by blank ones, keyed by `Id`.
  ///
  /// The first line is the server's `date +%s`. Every timestamp is moved onto
  /// this device's clock by the difference between that and [now], so a
  /// duration the page computes later is right however far the two clocks
  /// disagree. Without that line the timestamps are taken as they are.
  static Map<String, SystemdUnitDetails> parseDetails(
    String output, {
    required DateTime now,
  }) {
    final lines = output.split('\n');
    var skew = Duration.zero;
    var start = 0;
    if (lines.isNotEmpty) {
      final serverSeconds = int.tryParse(lines.first.trim());
      if (serverSeconds != null) {
        skew = now.difference(
          DateTime.fromMillisecondsSinceEpoch(serverSeconds * 1000, isUtc: true),
        );
        start = 1;
      }
    }

    final details = <String, SystemdUnitDetails>{};
    var block = <String, String>{};
    void flush() {
      final id = block['Id'];
      if (id != null && id.isNotEmpty) {
        details[id] = SystemdUnitDetails.fromProperties(block, skew: skew);
      }
      block = <String, String>{};
    }

    for (final line in lines.skip(start)) {
      if (line.trim().isEmpty) {
        flush();
        continue;
      }
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      block[line.substring(0, eq)] = line.substring(eq + 1).trim();
    }
    flush();
    return details;
  }

  static ServiceUnit withDetails(ServiceUnit unit, SystemdUnitDetails? d) {
    if (d == null) return unit;
    final enabled = switch (d.unitFileState) {
      'enabled' || 'enabled-runtime' => true,
      'disabled' => false,
      _ => null,
    };
    return ServiceUnit(
      name: unit.name,
      type: unit.type,
      scope: unit.scope,
      state: unit.state,
      description: unit.description,
      subState: d.subState ?? unit.subState,
      unitFileState: d.unitFileState,
      enabled: enabled,
      actions: serviceActions(unit.state, enabled: enabled),
      result: unit.state == ServiceState.failed ? d.result : null,
      exitStatus: unit.state == ServiceState.failed && d.result == 'exit-code'
          ? d.exitStatus
          : null,
      memoryBytes: d.memoryBytes,
      since: switch (unit.state) {
        ServiceState.running => d.activeEnter,
        ServiceState.stopped || ServiceState.failed => d.inactiveEnter,
        ServiceState.starting => d.inactiveExit,
        ServiceState.stopping => d.activeExit,
        ServiceState.unknown => null,
      },
      nextElapse: unit.type == ServiceUnitType.timer ? d.nextElapse : null,
    );
  }

  @override
  String commandFor(ServiceUnit unit, ServiceAction action) {
    return '${_systemctl(unit.scope)} ${action.name} '
        '${quotedServiceName(unit.fullName)}';
  }

  @override
  bool needsRoot(ServiceUnit unit) => unit.scope == ServiceScope.system;

  static String recentLogCommand(ServiceUnit unit, {required int lines}) {
    final journalctl = unit.scope == ServiceScope.system
        ? 'journalctl'
        : 'journalctl --user';
    return '$journalctl --no-pager --output=short-iso -n $lines '
        '-u ${quotedServiceName(unit.fullName)}';
  }

  /// Read as this account, never through sudo: this runs when a unit is
  /// opened, not because the user asked for anything, and a password prompt
  /// belongs to an action the user took. An account outside `adm` and
  /// `systemd-journal` sees no system unit's lines, and is told so.
  @override
  Future<ServiceLog?> recentLog(
    ServerExec exec,
    ServiceUnit unit, {
    int lines = 5,
  }) async {
    final result = await exec.run(recentLogCommand(unit, lines: lines));
    return parseJournal(result.stdout, stderr: result.stderr);
  }

  static final _journalLine = RegExp(
    r'^\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2})\S* \S+ (.*)$',
  );

  /// `2026-09-16T21:09:58+0800 host nginx[8840]: message`, without the date
  /// and the host: the date is almost always today's, and every line of one
  /// machine's log has the same host.
  ///
  /// Newlines are normalized first, the way `CronManager.parse` and
  /// `UserManager.parse` do: a carriage return left at the end of a line is
  /// not something `(.*)$` can match — `.` excludes it — so every line of a
  /// CRLF transcript came back as an unparsed one with no time on it.
  static ServiceLog parseJournal(String stdout, {String stderr = ''}) {
    final lines = <ServiceLogLine>[];
    final normalized = stdout.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    for (final line in normalized.split('\n')) {
      if (line.trim().isEmpty || line.startsWith('-- ')) continue;
      final match = _journalLine.firstMatch(line);
      lines.add(
        match == null
            ? ServiceLogLine(text: line)
            : ServiceLogLine(time: match.group(1), text: match.group(2)!),
      );
    }
    final unreadable =
        lines.isEmpty &&
        (stderr.contains('insufficient permissions') ||
            stderr.contains('not seeing messages from other users'));
    return ServiceLog(lines: lines, unreadable: unreadable);
  }

  @override
  String? logCommand(ServiceUnit unit) {
    final journalctl = unit.scope == ServiceScope.system
        ? 'journalctl'
        : 'journalctl --user';
    return '$journalctl -e -u ${quotedServiceName(unit.fullName)}';
  }

  @override
  String? definitionCommand(ServiceUnit unit) =>
      '${_systemctl(unit.scope)} cat ${quotedServiceName(unit.fullName)}';

  @override
  String unitStatusCommand(ServiceUnit unit) =>
      '${_systemctl(unit.scope)} status --no-pager --full '
      '${quotedServiceName(unit.fullName)}';
}

/// What `systemctl show` said about one unit.
final class SystemdUnitDetails {
  const SystemdUnitDetails({
    this.unitFileState,
    this.subState,
    this.result,
    this.exitStatus,
    this.memoryBytes,
    this.activeEnter,
    this.activeExit,
    this.inactiveEnter,
    this.inactiveExit,
    this.nextElapse,
  });

  factory SystemdUnitDetails.fromProperties(
    Map<String, String> properties, {
    Duration skew = Duration.zero,
  }) {
    String? text(String key) {
      final value = properties[key];
      return value == null || value.isEmpty ? null : value;
    }

    DateTime? time(String key) =>
        parseTimestamp(properties[key] ?? '')?.add(skew);

    final result = text('Result');
    return SystemdUnitDetails(
      unitFileState: text('UnitFileState'),
      subState: text('SubState'),
      result: result == 'success' ? null : result,
      exitStatus: int.tryParse(properties['ExecMainStatus'] ?? ''),
      memoryBytes: parseMemory(properties['MemoryCurrent'] ?? ''),
      activeEnter: time('ActiveEnterTimestamp'),
      activeExit: time('ActiveExitTimestamp'),
      inactiveEnter: time('InactiveEnterTimestamp'),
      inactiveExit: time('InactiveExitTimestamp'),
      nextElapse: time('NextElapseUSecRealtime'),
    );
  }

  final String? unitFileState;
  final String? subState;
  final String? result;
  final int? exitStatus;
  final int? memoryBytes;
  final DateTime? activeEnter;
  final DateTime? activeExit;
  final DateTime? inactiveEnter;
  final DateTime? inactiveExit;
  final DateTime? nextElapse;

  static final _timestamp = RegExp(
    r'(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) UTC$',
  );

  /// `Wed 2026-09-16 04:04:31 UTC`. Null for the empty value systemd prints
  /// for "never", and for `n/a`.
  static DateTime? parseTimestamp(String value) {
    final match = _timestamp.firstMatch(value.trim());
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
    return DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
      parts[3],
      parts[4],
      parts[5],
    );
  }

  /// Null for `[not set]`, and for the all-ones value older systemd prints
  /// when a unit has no memory accounting — `18446744073709551615`, which is
  /// not a number of bytes anything is using.
  static int? parseMemory(String value) {
    final parsed = int.tryParse(value.trim());
    return parsed != null && parsed >= 0 ? parsed : null;
  }
}
