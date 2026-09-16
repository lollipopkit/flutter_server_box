import 'dart:convert';

final _whitespaceRegExp = RegExp(r'\s+');
final _nonWhitespaceRegExp = RegExp(r'\S+');

class _ProcValIdxMap {
  final int pid;
  final int? ppid;
  final int? user;
  final int? cpu;
  final int? mem;
  final int? vsz;
  final int? rss;
  final int? tty;
  final int? stat;
  final int? nice;
  final int? threads;
  final int? start;
  final int? startId;
  final int? time;
  final int? elapsed;
  final int? readBytes;
  final int? writeBytes;
  final int command;

  const _ProcValIdxMap({
    required this.pid,
    this.ppid,
    this.user,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.nice,
    this.threads,
    this.start,
    this.startId,
    this.time,
    this.elapsed,
    this.readBytes,
    this.writeBytes,
    required this.command,
  });
}

/// The first line of the process function's output when the machine has a
/// load average. Mirrors `script::PROCESS_LOAD_MARKER` in `sbm_parser`, whose
/// output the fixtures under `test/fixtures/process/` were captured from.
const kProcessLoadMarker = 'SrvBoxProc.Load';

/// Beyond this an elapsed time is not a measurement. A container whose boot
/// time disagrees with its host's makes procps print a start date thousands
/// of years back, and "running for 1.2 million years" says nothing true.
const _kMaxElapsedSeconds = 100 * 365 * 24 * 3600;

/// Some field can be null due to incompatible format on `BSD` and `Alpine`
class Proc {
  final String? user;
  final int pid;

  /// Null where the platform did not say, which is not the same as 0: PID 0
  /// is the parent a Linux kernel reports for `init` and `kthreadd`.
  final int? ppid;
  final double? cpu;
  final double? mem;
  final String? vsz;
  final String? rss;
  final String? tty;
  final String? stat;
  final int? nice;
  final int? threads;
  final String? start;
  final String? startId;
  final String? time;

  /// Seconds since the process started, as the server counted them.
  final int? elapsedSeconds;
  final int? readBytes;
  final int? writeBytes;
  final double? readSpeed;
  final double? writeSpeed;
  final String command;

  /// The image name Windows reports (`nginx.exe`). A Windows command line
  /// starts with a path that may hold spaces and quotes, so splitting it on
  /// whitespace would name the process `"C:\Program`.
  final String? processName;

  late final binary = _parseBinary();
  late final args = _parseArgs();
  late final rssKb = _parseRssKb();

  /// What to call the process where its whole command line does not fit: the
  /// last path component of the executable, without the colon a process that
  /// rewrites its title leaves after its own name (`nginx: worker process`).
  late final name = _parseName();

  /// A Linux kernel thread: `kthreadd` itself, or one of its children.
  ///
  /// The command is checked too, because PPID 2 only means `kthreadd` in the
  /// root PID namespace. Inside a container PID 2 is whatever started second,
  /// and its children are ordinary processes — whose command lines, unlike a
  /// kernel thread's, are not a name in brackets.
  bool get isKernelThread =>
      (pid == 2 || ppid == 2) && command.trimLeft().startsWith('[');

  Proc({
    this.user,
    required this.pid,
    this.ppid,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.nice,
    this.threads,
    this.start,
    this.startId,
    this.time,
    this.elapsedSeconds,
    this.readBytes,
    this.writeBytes,
    this.readSpeed,
    this.writeSpeed,
    required this.command,
    this.processName,
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
          ppid == other.ppid &&
          cpu == other.cpu &&
          mem == other.mem &&
          vsz == other.vsz &&
          rss == other.rss &&
          tty == other.tty &&
          stat == other.stat &&
          nice == other.nice &&
          threads == other.threads &&
          start == other.start &&
          startId == other.startId &&
          time == other.time &&
          elapsedSeconds == other.elapsedSeconds &&
          readBytes == other.readBytes &&
          writeBytes == other.writeBytes &&
          readSpeed == other.readSpeed &&
          writeSpeed == other.writeSpeed &&
          command == other.command &&
          processName == other.processName;

  @override
  int get hashCode => Object.hashAll([
    user,
    pid,
    ppid,
    cpu,
    mem,
    vsz,
    rss,
    tty,
    stat,
    nice,
    threads,
    start,
    startId,
    time,
    elapsedSeconds,
    readBytes,
    writeBytes,
    readSpeed,
    writeSpeed,
    command,
    processName,
  ]);

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
    final readBytes = _parseNullableInt(
      parts,
      map.readBytes,
      nonNegative: true,
    );
    final writeBytes = _parseNullableInt(
      parts,
      map.writeBytes,
      nonNegative: true,
    );
    final (readSpeed, writeSpeed) = _calculateSpeeds(
      readBytes: readBytes,
      writeBytes: writeBytes,
      previous: matchingPrevious,
      elapsedSeconds: elapsedSeconds,
    );
    return Proc(
      user: map.user == null ? null : parts[map.user!],
      pid: pid,
      ppid: _parseNullableInt(parts, map.ppid, nonNegative: true),
      cpu: _parseNullableDouble(parts, map.cpu),
      mem: _parseNullableDouble(parts, map.mem),
      vsz: map.vsz == null ? null : parts[map.vsz!],
      rss: map.rss == null ? null : parts[map.rss!],
      tty: map.tty == null ? null : parts[map.tty!],
      stat: map.stat == null ? null : parts[map.stat!],
      nice: _parseNullableInt(parts, map.nice),
      threads: _parseNullableInt(parts, map.threads, nonNegative: true),
      start: start,
      startId: startId,
      time: map.time == null ? null : parts[map.time!],
      elapsedSeconds: map.elapsed == null
          ? null
          : _parseElapsed(parts[map.elapsed!]),
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
    final elapsed = _parseDynamicInt(raw['ElapsedSeconds']);
    return Proc(
      pid: pid,
      ppid: _firstParsedInt([raw['ParentId']], nonNegative: true),
      threads: _firstParsedInt([raw['Threads']], nonNegative: true),
      elapsedSeconds:
          elapsed != null && elapsed >= 0 && elapsed <= _kMaxElapsedSeconds
          ? elapsed
          : null,
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
      processName: name,
    );
  }

  String _parseBinary() {
    return _nonWhitespaceRegExp.firstMatch(command)?.group(0) ?? '';
  }

  String _parseName() {
    if (processName case final name? when name.trim().isNotEmpty) {
      return name.trim();
    }
    final bin = binary;
    if (bin.startsWith('[')) return command.trim();
    final slash = bin.lastIndexOf('/');
    var base = slash >= 0 && slash < bin.length - 1
        ? bin.substring(slash + 1)
        : bin;
    if (base.length > 1 && base.endsWith(':')) {
      base = base.substring(0, base.length - 1);
    }
    return base.isEmpty ? command.trim() : base;
  }

  String _parseArgs() {
    final match = _nonWhitespaceRegExp.firstMatch(command);
    if (match == null) return '';
    return command.substring(match.end).trimLeft();
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

/// The 1, 5 and 15 minute load averages.
typedef ProcLoad = ({double one, double five, double fifteen});

class PsResult {
  final List<Proc> procs;
  final PsParseIssue? issue;
  final int sampledAtMillis;

  /// Null where the machine has none to report — Windows — or ran a script
  /// older than the line that carries it.
  final ProcLoad? load;

  const PsResult({
    required this.procs,
    this.issue,
    this.sampledAtMillis = 0,
    this.load,
  });

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
    final load = _takeLoad(lines);
    if (lines.isEmpty) {
      return PsResult(
        procs: const [],
        sampledAtMillis: currentSampledAtMillis,
        load: load,
      );
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
        load: load,
      );
    }
    final map = _ProcValIdxMap(
      pid: pidIdx,
      ppid: parts.indexOfOrNull('PPID'),
      user: parts.indexOfOrNull('USER'),
      cpu: parts.indexOfOrNull('%CPU'),
      mem: parts.indexOfOrNull('%MEM'),
      vsz: parts.indexOfOrNull('VSZ'),
      rss: parts.indexOfOrNull('RSS'),
      tty: parts.indexOfOrNull('TTY'),
      stat: parts.indexOfOrNull('STAT'),
      nice: parts.indexOfOrNull('NI'),
      threads: parts.indexOfOrNull('NLWP'),
      start: parts.indexOfOrNull('START'),
      startId: parts.indexOfOrNull('START_ID'),
      time: parts.indexOfOrNull('TIME'),
      elapsed: parts.indexOfOrNull('ELAPSED'),
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
      load: load,
    );
  }

  /// Removes the load line from [lines] and answers what it said.
  ///
  /// Taken out before the header is looked for, because the table's header is
  /// whatever line comes first.
  static ProcLoad? _takeLoad(List<String> lines) {
    final index = lines.indexWhere(
      (line) => line.startsWith('$kProcessLoadMarker '),
    );
    if (index < 0) return null;
    final values = lines
        .removeAt(index)
        .substring(kProcessLoadMarker.length)
        .trim()
        .split(_whitespaceRegExp)
        .map(double.tryParse)
        .toList();
    if (values.length != 3 || values.any((v) => v == null || v < 0)) {
      return null;
    }
    return (one: values[0]!, five: values[1]!, fifteen: values[2]!);
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
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      try {
        json.decode(trimmed);
      } catch (_) {
        return null;
      }
    }
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
      load: load,
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

int? _parseNullableInt(
  List<String> parts,
  int? idx, {
  bool nonNegative = false,
}) {
  if (idx == null || idx >= parts.length) return null;
  final parsed = _parseDynamicInt(parts[idx]);
  return parsed != null && (!nonNegative || parsed >= 0) ? parsed : null;
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

/// `etime`: `[[dd-]hh:]mm:ss`.
int? _parseElapsed(String raw) {
  if (raw.isEmpty || raw == '-') return null;
  var days = 0;
  var rest = raw;
  final dash = raw.indexOf('-');
  if (dash >= 0) {
    final parsed = int.tryParse(raw.substring(0, dash));
    if (parsed == null || parsed < 0) return null;
    days = parsed;
    rest = raw.substring(dash + 1);
  }
  final fields = rest.split(':');
  if (fields.length < 2 || fields.length > 3) return null;
  var seconds = 0;
  for (final field in fields) {
    final value = int.tryParse(field);
    if (value == null || value < 0) return null;
    seconds = seconds * 60 + value;
  }
  final total = days * 86400 + seconds;
  return total <= _kMaxElapsedSeconds ? total : null;
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
