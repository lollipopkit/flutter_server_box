import 'dart:convert';

import 'package:server_box/data/res/misc.dart';

final _whitespaceRegExp = RegExp(r'\s+');

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
  final String? time;
  final int? readBytes;
  final int? writeBytes;
  final double? readSpeed;
  final double? writeSpeed;
  final String command;

  late final binary = _parseBinary();

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
    this.time,
    this.readBytes,
    this.writeBytes,
    this.readSpeed,
    this.writeSpeed,
    required this.command,
  });

  factory Proc._parse(
    String raw,
    _ProcValIdxMap map, {
    Proc? previous,
    double? elapsedSeconds,
  }) {
    final parts = raw.split(_whitespaceRegExp);
    final readBytes = _parseNullableInt(parts, map.readBytes);
    final writeBytes = _parseNullableInt(parts, map.writeBytes);
    final (readSpeed, writeSpeed) = _calculateSpeeds(
      readBytes: readBytes,
      writeBytes: writeBytes,
      previous: previous,
      elapsedSeconds: elapsedSeconds,
    );
    return Proc(
      user: map.user == null ? null : parts[map.user!],
      pid: int.parse(parts[map.pid]),
      cpu: map.cpu == null ? null : double.parse(parts[map.cpu!]),
      mem: map.mem == null ? null : double.parse(parts[map.mem!]),
      vsz: map.vsz == null ? null : parts[map.vsz!],
      rss: map.rss == null ? null : parts[map.rss!],
      tty: map.tty == null ? null : parts[map.tty!],
      stat: map.stat == null ? null : parts[map.stat!],
      start: map.start == null ? null : parts[map.start!],
      time: map.time == null ? null : parts[map.time!],
      readBytes: readBytes,
      writeBytes: writeBytes,
      readSpeed: readSpeed,
      writeSpeed: writeSpeed,
      command: parts.sublist(map.command).join(' '),
    );
  }

  factory Proc._parseWindowsJson(
    Map<String, dynamic> raw, {
    Proc? previous,
    double? elapsedSeconds,
  }) {
    final readBytes = _parseDynamicInt(
      raw['IOReadBytes'] ?? raw['ReadTransferCount'],
    );
    final writeBytes = _parseDynamicInt(
      raw['IOWriteBytes'] ?? raw['WriteTransferCount'],
    );
    final (readSpeed, writeSpeed) = _calculateSpeeds(
      readBytes: readBytes,
      writeBytes: writeBytes,
      previous: previous,
      elapsedSeconds: elapsedSeconds,
    );
    final name = raw['ProcessName'] ?? raw['Name'];
    final command = raw['CommandLine'] ?? raw['Path'] ?? name ?? '';
    return Proc(
      pid: _parseDynamicInt(raw['Id'] ?? raw['ProcessId'])!,
      cpu: _parseDynamicDouble(raw['CPU']),
      rss: _parseDynamicInt(
        raw['WorkingSet'] ?? raw['WorkingSetSize'],
      )?.toString(),
      readBytes: readBytes,
      writeBytes: writeBytes,
      readSpeed: readSpeed,
      writeSpeed: writeSpeed,
      command: command.toString(),
    );
  }

  Map toJson() {
    return {
      'user': user,
      'pid': pid,
      'cpu': cpu,
      'mem': mem,
      'vsz': vsz,
      'rss': rss,
      'tty': tty,
      'stat': stat,
      'start': start,
      'time': time,
      'readBytes': readBytes,
      'writeBytes': writeBytes,
      'readSpeed': readSpeed,
      'writeSpeed': writeSpeed,
      'command': command,
    };
  }

  @override
  String toString() {
    return Miscs.jsonEncoder.convert(toJson());
  }

  String _parseBinary() {
    final parts = command.trim().split(' ').where((e) => e.isNotEmpty).toList();
    return parts.isNotEmpty ? parts[0] : '';
  }
}

// `ps -aux` result
class PsResult {
  final List<Proc> procs;
  final String? error;
  final int sampledAtMillis;

  const PsResult({required this.procs, this.error, this.sampledAtMillis = 0});

  factory PsResult.parse(
    String raw, {
    ProcSortMode sort = ProcSortMode.cpu,
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
    final map = _ProcValIdxMap(
      pid: parts.indexOfOrNull('PID')!,
      user: parts.indexOfOrNull('USER'),
      cpu: parts.indexOfOrNull('%CPU'),
      mem: parts.indexOfOrNull('%MEM'),
      vsz: parts.indexOfOrNull('VSZ'),
      rss: parts.indexOfOrNull('RSS'),
      tty: parts.indexOfOrNull('TTY'),
      stat: parts.indexOfOrNull('STAT'),
      start: parts.indexOfOrNull('START'),
      time: parts.indexOfOrNull('TIME'),
      readBytes: parts.indexOfOrNull('READ_BYTES'),
      writeBytes: parts.indexOfOrNull('WRITE_BYTES'),
      command: parts.indexOfOrNull('COMMAND') ?? parts.indexOfOrNull('CMD')!,
    );

    final procs = <Proc>[];
    final errs = <String>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      try {
        final pid = _parsePid(line, map.pid);
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

    _sort(procs, sort);
    return PsResult(
      procs: procs,
      error: errs.isEmpty ? null : errs.join('\n'),
      sampledAtMillis: currentSampledAtMillis,
    );
  }

  static PsResult? _parseWindowsJsonResult(
    String raw, {
    required Map<int, Proc> previousByPid,
    required double? elapsedSeconds,
    required int sampledAtMillis,
    required ProcSortMode sort,
  }) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;
    try {
      final decoded = json.decode(trimmed);
      final items = decoded is List ? decoded : [decoded];
      final procs = <Proc>[];
      final errs = <String>[];
      for (final item in items) {
        if (item is! Map) continue;
        try {
          final map = Map<String, dynamic>.from(item);
          final pid = _parseDynamicInt(map['Id'] ?? map['ProcessId']);
          if (pid == null) continue;
          procs.add(
            Proc._parseWindowsJson(
              map,
              previous: previousByPid[pid],
              elapsedSeconds: elapsedSeconds,
            ),
          );
        } catch (e) {
          errs.add('$item: $e');
        }
      }
      _sort(procs, sort);
      return PsResult(
        procs: procs,
        error: errs.isEmpty ? null : errs.join('\n'),
        sampledAtMillis: sampledAtMillis,
      );
    } catch (_) {
      return null;
    }
  }

  static void _sort(List<Proc> procs, ProcSortMode sort) {
    switch (sort) {
      case ProcSortMode.cpu:
        procs.sort((a, b) => _compareNullableDesc(a.cpu, b.cpu));
        break;
      case ProcSortMode.mem:
        procs.sort((a, b) => _compareNullableDesc(a.mem, b.mem));
        break;
      case ProcSortMode.read:
        procs.sort((a, b) => _compareNullableDesc(a.readSpeed, b.readSpeed));
        break;
      case ProcSortMode.write:
        procs.sort((a, b) => _compareNullableDesc(a.writeSpeed, b.writeSpeed));
        break;
      case ProcSortMode.pid:
        procs.sort((a, b) => a.pid.compareTo(b.pid));
        break;
      case ProcSortMode.user:
        procs.sort((a, b) => a.user?.compareTo(b.user ?? '') ?? 0);
        break;
      case ProcSortMode.name:
        procs.sort((a, b) => a.binary.compareTo(b.binary));
        break;
    }
  }
}

enum ProcSortMode { cpu, mem, read, write, pid, user, name }

extension _StrIndex on List<String> {
  int? indexOfOrNull(String val) {
    final idx = indexOf(val);
    return idx == -1 ? null : idx;
  }
}

int _parsePid(String raw, int pidIndex) {
  final parts = raw.split(_whitespaceRegExp);
  return int.parse(parts[pidIndex]);
}

int? _parseNullableInt(List<String> parts, int? idx) {
  if (idx == null || idx >= parts.length) return null;
  return _parseDynamicInt(parts[idx]);
}

int? _parseDynamicInt(Object? val) {
  if (val == null) return null;
  if (val is int) return val;
  if (val is num) return val.toInt();
  final str = val.toString();
  if (str.isEmpty || str == '-') return null;
  return int.tryParse(str);
}

double? _parseDynamicDouble(Object? val) {
  if (val == null) return null;
  if (val is double) return val;
  if (val is num) return val.toDouble();
  final str = val.toString();
  if (str.isEmpty || str == '-') return null;
  return double.tryParse(str);
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

int _compareNullableDesc(num? a, num? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
