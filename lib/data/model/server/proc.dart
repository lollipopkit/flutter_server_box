import 'dart:convert';

final _whitespaceRegExp = RegExp(r'\s+');
final _nonWhitespaceRegExp = RegExp(r'\S+');

class _ProcValIdxMap {
  final int pid;
  final int? user;
  final int? cpu;
  final int? mem;
  final int? vsz;
  final int? rss;
  final int? tty;
  final int? stat;
  final int? start;
  final int? startId;
  final int? time;
  final int? readBytes;
  final int? writeBytes;
  final int command;

  const _ProcValIdxMap({
    required this.pid,
    this.user,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.start,
    this.startId,
    this.time,
    this.readBytes,
    this.writeBytes,
    required this.command,
  });
}

/// Some field can be null due to incompatible format on `BSD` and `Alpine`
class Proc {
  final String? user;
  final int pid;
  final double? cpu;
  final double? mem;
  final String? vsz;
  final String? rss;
  final String? tty;
  final String? stat;
  final String? start;
  final String? startId;
  final String? time;
  final int? readBytes;
  final int? writeBytes;
  final double? readSpeed;
  final double? writeSpeed;
  final String command;

  late final binary = _parseBinary();
  late final args = _parseArgs();
  late final rssKb = _parseRssKb();

  Proc({
    this.user,
    required this.pid,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.start,
    this.startId,
    this.time,
    this.readBytes,
    this.writeBytes,
    this.readSpeed,
    this.writeSpeed,
    required this.command,
  });

  // Value equality based on all parsed fields lets ListView skip rebuilding
  // rows whose underlying process data is unchanged between refreshes, which
  // is the common case for idle processes. `binary` is derived from `command`
  // so it is intentionally excluded to avoid forcing its lazy initialization
  // during comparisons.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Proc &&
          runtimeType == other.runtimeType &&
          user == other.user &&
          pid == other.pid &&
          cpu == other.cpu &&
          mem == other.mem &&
          vsz == other.vsz &&
          rss == other.rss &&
          tty == other.tty &&
          stat == other.stat &&
          start == other.start &&
          startId == other.startId &&
          time == other.time &&
          readBytes == other.readBytes &&
          writeBytes == other.writeBytes &&
          readSpeed == other.readSpeed &&
          writeSpeed == other.writeSpeed &&
          command == other.command;

  @override
  int get hashCode => Object.hash(
    user,
    pid,
    cpu,
    mem,
    vsz,
    rss,
    tty,
    stat,
    start,
    startId,
    time,
    readBytes,
    writeBytes,
    readSpeed,
    writeSpeed,
    command,
  );

  factory Proc._parse(
    String raw,
    _ProcValIdxMap map, {
    Proc? previous,
    double? elapsedSeconds,
  }) {
    final matches = _nonWhitespaceRegExp.allMatches(raw).toList();
    final parts = [for (final match in matches) match.group(0)!];
    final pid = _parsePositivePid(parts[map.pid]);
    final start = map.start == null ? null : parts[map.start!];
    final startId = map.startId == null
        ? null
        : _parseProcessIdentity(parts[map.startId!]);
    final command = raw.substring(matches[map.command].start);
    final matchingPrevious = _matchingPrevious(
      previous,
      start: start,
      startId: startId,
    );
    final readBytes = _parseNullableInt(parts, map.readBytes);
    final writeBytes = _parseNullableInt(parts, map.writeBytes);
    final (readSpeed, writeSpeed) = _calculateSpeeds(
      readBytes: readBytes,
      writeBytes: writeBytes,
      previous: matchingPrevious,
      elapsedSeconds: elapsedSeconds,
    );
    return Proc(
      user: map.user == null ? null : parts[map.user!],
      pid: pid,
      cpu: _parseNullableDouble(parts, map.cpu),
      mem: _parseNullableDouble(parts, map.mem),
      vsz: map.vsz == null ? null : parts[map.vsz!],
      rss: map.rss == null ? null : parts[map.rss!],
      tty: map.tty == null ? null : parts[map.tty!],
      stat: map.stat == null ? null : parts[map.stat!],
      start: start,
      startId: startId,
      time: map.time == null ? null : parts[map.time!],
      readBytes: readBytes,
      writeBytes: writeBytes,
      readSpeed: readSpeed,
      writeSpeed: writeSpeed,
      command: command,
    );
  }

  factory Proc._parseWindowsJson(
    Map<String, dynamic> raw, {
    required int pid,
    Proc? previous,
    double? elapsedSeconds,
  }) {
    final name = _firstNonEmptyString([raw['ProcessName'], raw['Name']]);
    final command =
        _firstNonEmptyString([raw['CommandLine'], raw['Path'], name]) ?? '';
    final startId = _parseProcessIdentity(raw['StartId']);
    final matchingPrevious = _matchingPrevious(previous, startId: startId);
    final readBytes = _firstParsedInt([
      raw['IOReadBytes'],
      raw['ReadTransferCount'],
    ], nonNegative: true);
    final writeBytes = _firstParsedInt([
      raw['IOWriteBytes'],
      raw['WriteTransferCount'],
    ], nonNegative: true);
    final (readSpeed, writeSpeed) = _calculateSpeeds(
      readBytes: readBytes,
      writeBytes: writeBytes,
      previous: matchingPrevious,
      elapsedSeconds: elapsedSeconds,
    );
    final workingSetBytes = _firstParsedInt([
      raw['WorkingSet'],
      raw['WorkingSetSize'],
    ], nonNegative: true);
    return Proc(
      pid: pid,
      cpu: _firstParsedDouble([raw['CPUPercent'], raw['PercentProcessorTime']]),
      // Unix `ps` reports RSS in KiB. Normalize the Windows byte count to the
      // same unit so sorting and display stay consistent across platforms.
      rss: workingSetBytes == null
          ? null
          : ((workingSetBytes + 1023) ~/ 1024).toString(),
      readBytes: readBytes,
      writeBytes: writeBytes,
      readSpeed: readSpeed,
      writeSpeed: writeSpeed,
      startId: startId,
      command: command,
    );
  }

  String _parseBinary() {
    final parts = command.trim().split(' ').where((e) => e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts[0] : '';
  }

  String _parseArgs() {
    final trimmed = command.trim();
    if (trimmed.isEmpty) return '';
    final binary = this.binary;
    if (binary.isEmpty || trimmed.length <= binary.length) return '';
    return trimmed.substring(binary.length).trimLeft();
  }

  int? _parseRssKb() {
    final raw = rss;
    if (raw == null || raw.isEmpty || raw == '-') return null;
    final parsed = int.tryParse(raw);
    return parsed != null && parsed >= 0 ? parsed : null;
  }
}

// `ps -aux` result
enum PsParseFailure {
  unsupportedOutput,
  invalidRows,
  invalidWindowsJson,
  invalidWindowsRows,
}

class PsParseIssue {
  final PsParseFailure failure;
  final String diagnostics;

  const PsParseIssue({required this.failure, required this.diagnostics});
}

class PsResult {
  final List<Proc> procs;
  final PsParseIssue? issue;
  final int sampledAtMillis;

  const PsResult({required this.procs, this.issue, this.sampledAtMillis = 0});

  factory PsResult.parse(
    String raw, {
    ProcSortMode sort = ProcSortMode.cpu,
    bool? ascending,
    PsResult? previous,
    int? sampledAtMillis,
  }) {
    final currentSampledAtMillis =
        sampledAtMillis ?? DateTime.now().millisecondsSinceEpoch;
    final previousByPid = {
      for (final proc in previous?.procs ?? const <Proc>[]) proc.pid: proc,
    };
    final elapsedSeconds = previous == null || previous.sampledAtMillis <= 0
        ? null
        : (currentSampledAtMillis - previous.sampledAtMillis) / 1000.0;
    final jsonResult = _parseWindowsJsonResult(
      raw,
      previousByPid: previousByPid,
      elapsedSeconds: elapsedSeconds,
      sampledAtMillis: currentSampledAtMillis,
      sort: sort,
      ascending: ascending,
    );
    if (jsonResult != null) return jsonResult;

    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return PsResult(procs: const [], sampledAtMillis: currentSampledAtMillis);
    }

    final header = lines[0];
    final parts = header.split(_whitespaceRegExp);
    parts.removeWhere((element) => element.isEmpty);
    final pidIdx = parts.indexOfOrNull('PID');
    final commandIdx =
        parts.indexOfOrNull('COMMAND') ?? parts.indexOfOrNull('CMD');
    if (pidIdx == null || commandIdx == null) {
      return PsResult(
        procs: const [],
        issue: PsParseIssue(
          failure: PsParseFailure.unsupportedOutput,
          diagnostics: 'Unsupported process output header: $header',
        ),
        sampledAtMillis: currentSampledAtMillis,
      );
    }
    final map = _ProcValIdxMap(
      pid: pidIdx,
      user: parts.indexOfOrNull('USER'),
      cpu: parts.indexOfOrNull('%CPU'),
      mem: parts.indexOfOrNull('%MEM'),
      vsz: parts.indexOfOrNull('VSZ'),
      rss: parts.indexOfOrNull('RSS'),
      tty: parts.indexOfOrNull('TTY'),
      stat: parts.indexOfOrNull('STAT'),
      start: parts.indexOfOrNull('START'),
      startId: parts.indexOfOrNull('START_ID'),
      time: parts.indexOfOrNull('TIME'),
      readBytes: parts.indexOfOrNull('READ_BYTES'),
      writeBytes: parts.indexOfOrNull('WRITE_BYTES'),
      command: commandIdx,
    );

    final procs = <Proc>[];
    final errs = <String>[];
    final seenPids = <int>{};
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      try {
        final pid = _parsePid(line, map.pid);
        if (!seenPids.add(pid)) {
          throw FormatException('Duplicate process ID: $pid');
        }
        procs.add(
          Proc._parse(
            line,
            map,
            previous: previousByPid[pid],
            elapsedSeconds: elapsedSeconds,
          ),
        );
      } catch (e) {
        errs.add('$line: $e');
      }
    }

    _sort(procs, sort, ascending: ascending);
    return PsResult(
      procs: procs,
      issue: errs.isEmpty
          ? null
          : PsParseIssue(
              failure: PsParseFailure.invalidRows,
              diagnostics: errs.join('\n'),
            ),
      sampledAtMillis: currentSampledAtMillis,
    );
  }

  static PsResult? _parseWindowsJsonResult(
    String raw, {
    required Map<int, Proc> previousByPid,
    required double? elapsedSeconds,
    required int sampledAtMillis,
    required ProcSortMode sort,
    required bool? ascending,
  }) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      final decoded = json.decode(trimmed);
      final items = switch (decoded) {
        final List<Object?> values => values,
        final Map<Object?, Object?> value => <Object?>[value],
        _ => null,
      };
      if (items == null) {
        return PsResult(
          procs: const [],
          issue: const PsParseIssue(
            failure: PsParseFailure.invalidWindowsJson,
            diagnostics:
                'Invalid Windows process JSON: expected an object or array',
          ),
          sampledAtMillis: sampledAtMillis,
        );
      }
      final procs = <Proc>[];
      final errs = <String>[];
      final seenPids = <int>{};
      for (final (index, item) in items.indexed) {
        if (item is! Map) {
          errs.add('Invalid Windows process row $index: expected an object');
          continue;
        }
        try {
          final map = Map<String, dynamic>.from(item);
          final pid = _parseProcessId(map['Id'] ?? map['ProcessId']);
          if (pid == null) {
            errs.add(
              'Invalid Windows process row $index: missing or invalid PID',
            );
            continue;
          }
          if (!seenPids.add(pid)) {
            errs.add('Invalid Windows process row $index: duplicate PID $pid');
            continue;
          }
          procs.add(
            Proc._parseWindowsJson(
              map,
              pid: pid,
              previous: previousByPid[pid],
              elapsedSeconds: elapsedSeconds,
            ),
          );
        } catch (e) {
          errs.add('$item: $e');
        }
      }
      _sort(procs, sort, ascending: ascending);
      return PsResult(
        procs: procs,
        issue: errs.isEmpty
            ? null
            : PsParseIssue(
                failure: PsParseFailure.invalidWindowsRows,
                diagnostics: errs.join('\n'),
              ),
        sampledAtMillis: sampledAtMillis,
      );
    } catch (e) {
      return PsResult(
        procs: const [],
        issue: PsParseIssue(
          failure: PsParseFailure.invalidWindowsJson,
          diagnostics: 'Invalid Windows process JSON: $e',
        ),
        sampledAtMillis: sampledAtMillis,
      );
    }
  }

  PsResult sortedBy(ProcSortMode sort, {bool? ascending}) {
    final sorted = List<Proc>.of(procs);
    _sort(sorted, sort, ascending: ascending);
    return PsResult(
      procs: sorted,
      issue: issue,
      sampledAtMillis: sampledAtMillis,
    );
  }

  static void _sort(List<Proc> procs, ProcSortMode sort, {bool? ascending}) {
    final isAscending = ascending ?? sort.defaultAscending;
    procs.sort((a, b) {
      final compared = switch (sort) {
        ProcSortMode.cpu => _compareNullable(
          a.cpu,
          b.cpu,
          ascending: isAscending,
        ),
        ProcSortMode.mem => _compareNullable(
          a.mem,
          b.mem,
          ascending: isAscending,
        ),
        ProcSortMode.rss => _compareNullable(
          a.rssKb,
          b.rssKb,
          ascending: isAscending,
        ),
        ProcSortMode.read => _compareNullable(
          a.readSpeed,
          b.readSpeed,
          ascending: isAscending,
        ),
        ProcSortMode.write => _compareNullable(
          a.writeSpeed,
          b.writeSpeed,
          ascending: isAscending,
        ),
        ProcSortMode.pid => _applyDirection(
          a.pid.compareTo(b.pid),
          ascending: isAscending,
        ),
        ProcSortMode.user => _compareNullable(
          a.user?.toLowerCase(),
          b.user?.toLowerCase(),
          ascending: isAscending,
        ),
        ProcSortMode.name => _applyDirection(
          a.command.toLowerCase().compareTo(b.command.toLowerCase()),
          ascending: isAscending,
        ),
      };
      return compared == 0 ? a.pid.compareTo(b.pid) : compared;
    });
  }
}

enum ProcSortMode {
  cpu,
  mem,
  rss,
  read,
  write,
  pid,
  user,
  name;

  bool get defaultAscending => switch (this) {
    ProcSortMode.pid || ProcSortMode.user || ProcSortMode.name => true,
    ProcSortMode.cpu ||
    ProcSortMode.mem ||
    ProcSortMode.rss ||
    ProcSortMode.read ||
    ProcSortMode.write => false,
  };
}

extension _StrIndex on List<String> {
  int? indexOfOrNull(String val) {
    final idx = indexOf(val);
    return idx == -1 ? null : idx;
  }
}

int _parsePid(String raw, int pidIndex) {
  final parts = [
    for (final match in _nonWhitespaceRegExp.allMatches(raw)) match.group(0)!,
  ];
  return _parsePositivePid(parts[pidIndex]);
}

int _parsePositivePid(String value) {
  final pid = int.parse(value);
  if (pid <= 0) throw FormatException('Invalid process ID: $value');
  return pid;
}

int? _parseNullableInt(List<String> parts, int? idx) {
  if (idx == null || idx >= parts.length) return null;
  return _parseDynamicInt(parts[idx]);
}

double? _parseNullableDouble(List<String> parts, int? idx) {
  if (idx == null || idx >= parts.length) return null;
  return _parseDynamicDouble(parts[idx]);
}

int? _parseDynamicInt(Object? val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) {
    if (!val.isFinite || val != val.truncateToDouble()) return null;
    return val.toInt();
  }
  final str = val.toString();
  if (str.isEmpty || str == '-') return null;
  return int.tryParse(str);
}

int? _firstParsedInt(List<Object?> values, {bool nonNegative = false}) {
  for (final value in values) {
    final parsed = _parseDynamicInt(value);
    if (parsed != null && (!nonNegative || parsed >= 0)) return parsed;
  }
  return null;
}

int? _parseProcessId(Object? value) {
  final parsed = switch (value) {
    final int value => value,
    final num value when value.isFinite && value == value.truncateToDouble() =>
      value.toInt(),
    _ => int.tryParse(value?.toString() ?? ''),
  };
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _parseDynamicDouble(Object? val) {
  if (val == null) return null;
  if (val is num) {
    final parsed = val.toDouble();
    return parsed.isFinite ? parsed : null;
  }
  final str = val.toString();
  if (str.isEmpty || str == '-') return null;
  final parsed = double.tryParse(str);
  return parsed != null && parsed.isFinite ? parsed : null;
}

double? _firstParsedDouble(List<Object?> values) {
  for (final value in values) {
    final parsed = _parseDynamicDouble(value);
    if (parsed != null) return parsed;
  }
  return null;
}

String? _firstNonEmptyString(List<Object?> values) {
  for (final value in values) {
    final string = value?.toString();
    if (string != null && string.trim().isNotEmpty) return string;
  }
  return null;
}

String? _parseProcessIdentity(Object? value) {
  final identity = value?.toString().trim();
  if (identity == null || identity.isEmpty || identity == '-') return null;
  return identity;
}

Proc? _matchingPrevious(Proc? previous, {String? start, String? startId}) {
  if (previous == null) return null;
  if (startId != null || previous.startId != null) {
    if (startId == null || previous.startId == null) return null;
    return startId == previous.startId ? previous : null;
  }
  if (start != null || previous.start != null) {
    if (start == null || previous.start == null || start != previous.start) {
      return null;
    }
    return previous;
  }
  return null;
}

(double?, double?) _calculateSpeeds({
  required int? readBytes,
  required int? writeBytes,
  required Proc? previous,
  required double? elapsedSeconds,
}) {
  if (previous == null || elapsedSeconds == null || elapsedSeconds <= 0) {
    return (null, null);
  }
  return (
    _calculateSpeed(readBytes, previous.readBytes, elapsedSeconds),
    _calculateSpeed(writeBytes, previous.writeBytes, elapsedSeconds),
  );
}

double? _calculateSpeed(int? current, int? previous, double elapsedSeconds) {
  if (current == null || previous == null) return null;
  final diff = current - previous;
  if (diff < 0) return null;
  return diff / elapsedSeconds;
}

int _compareNullable<T extends Comparable<T>>(
  T? a,
  T? b, {
  required bool ascending,
}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return _applyDirection(a.compareTo(b), ascending: ascending);
}

int _applyDirection(int value, {required bool ascending}) =>
    ascending ? value : -value;
