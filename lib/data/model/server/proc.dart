import 'dart:convert';

import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/proc.dart' as ffi;

/// One row of a process table, as `sbm_parser::proc::ProcRow` sends it: the
/// process, and what is derived from it there (its [name], [rssKb], whether
/// it is a kernel thread, whether it may be signalled). The table is read on
/// the Rust side — the rules the monitor agent's panel reads it by too; this
/// only carries the row.
///
/// Any field can be null: the columns differ per platform and per `ps`, and
/// null means the platform did not say, which is not the same as zero.
class Proc {
  final String? user;
  final int pid;
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

  /// What a stop checks the PID against: the process's start identity.
  final String? startId;
  final String? time;
  final int? elapsedSeconds;
  final int? readBytes;
  final int? writeBytes;

  /// Bytes per second since the previous reading; null on the first one.
  final double? readSpeed;
  final double? writeSpeed;
  final String command;

  /// What to call the process where its whole command line does not fit.
  final String name;

  /// `RSS` in KiB as a number; null where `ps` printed none.
  final int? rssKb;

  /// `kthreadd` or one of its children.
  final bool isKernelThread;

  /// Whether this row may be signalled at all.
  final bool killable;

  const Proc({
    required this.pid,
    required this.command,
    this.user,
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
    String? name,
    this.rssKb,
    this.isKernelThread = false,
    this.killable = false,
  }) : name = name ?? command;

  factory Proc.fromJson(Map<String, Object?> j) => Proc(
    pid: (j['pid'] as num).toInt(),
    command: j['command'] as String,
    user: j['user'] as String?,
    ppid: (j['ppid'] as num?)?.toInt(),
    cpu: (j['cpu'] as num?)?.toDouble(),
    mem: (j['mem'] as num?)?.toDouble(),
    vsz: j['vsz'] as String?,
    rss: j['rss'] as String?,
    tty: j['tty'] as String?,
    stat: j['stat'] as String?,
    nice: (j['nice'] as num?)?.toInt(),
    threads: (j['threads'] as num?)?.toInt(),
    start: j['start'] as String?,
    startId: j['start_id'] as String?,
    time: j['time'] as String?,
    elapsedSeconds: (j['elapsed_seconds'] as num?)?.toInt(),
    readBytes: (j['read_bytes'] as num?)?.toInt(),
    writeBytes: (j['write_bytes'] as num?)?.toInt(),
    readSpeed: (j['read_speed'] as num?)?.toDouble(),
    writeSpeed: (j['write_speed'] as num?)?.toDouble(),
    name: j['name'] as String,
    rssKb: (j['rss_kb'] as num?)?.toInt(),
    isKernelThread: j['is_kernel_thread'] as bool? ?? false,
    killable: j['killable'] as bool? ?? false,
  );
}

enum PsParseFailure {
  unsupportedOutput,
  invalidRows,
  invalidWindowsJson,
  invalidWindowsRows;

  static PsParseFailure? fromWire(String? name) => switch (name) {
    'unsupported_output' => unsupportedOutput,
    'invalid_rows' => invalidRows,
    'invalid_windows_json' => invalidWindowsJson,
    'invalid_windows_rows' => invalidWindowsRows,
    _ => null,
  };
}

class PsParseIssue {
  final PsParseFailure failure;
  final String diagnostics;

  const PsParseIssue({required this.failure, required this.diagnostics});
}

/// The 1, 5 and 15 minute load averages.
typedef ProcLoad = ({double one, double five, double fifteen});

/// The orders a table can be read in. Which of them one table can answer is
/// [PsResult.sorts].
enum ProcSortMode {
  cpu,
  mem,
  rss,
  read,
  write,
  pid,
  user,
  name;

  static ProcSortMode? fromWire(String? name) =>
      values.where((m) => m.name == name).firstOrNull;
}

enum ProcSignal {
  /// Asks the process to end.
  term,

  /// Ends it.
  kill;

  static ProcSignal? fromWire(String? name) =>
      values.where((s) => s.name == name).firstOrNull;
}

/// Which of the machine's columns carried a value in any row.
class ProcColumns {
  final bool user;
  final bool cpu;
  final bool mem;
  final bool rss;
  final bool read;
  final bool write;
  final bool readSpeed;
  final bool writeSpeed;

  const ProcColumns({
    this.user = false,
    this.cpu = false,
    this.mem = false,
    this.rss = false,
    this.read = false,
    this.write = false,
    this.readSpeed = false,
    this.writeSpeed = false,
  });

  factory ProcColumns.fromJson(Map<String, Object?> j) => ProcColumns(
    user: j['user'] == true,
    cpu: j['cpu'] == true,
    mem: j['mem'] == true,
    rss: j['rss'] == true,
    read: j['read'] == true,
    write: j['write'] == true,
    readSpeed: j['read_speed'] == true,
    writeSpeed: j['write_speed'] == true,
  );
}

/// One reading of the process table as `sbm_parser::proc::PsView` gives it:
/// its rows in [sort] order, the columns it has, the orders it can answer
/// and the signals the platform offers.
class PsResult {
  final List<Proc> procs;
  final PsParseIssue? issue;
  final int sampledAtMillis;

  /// Null where the machine has none to report — Windows — or ran a script
  /// older than the line that carries it.
  final ProcLoad? load;
  final ProcColumns columns;
  final List<ProcSortMode> sorts;
  final ProcSortMode sort;
  final bool ascending;

  /// Empty where the platform has none implemented: no stop at all.
  final List<ProcSignal> signals;

  /// The reading as it came, handed back to order it again or to difference
  /// the next one's speeds against.
  final String? _json;

  const PsResult({
    required this.procs,
    this.issue,
    this.sampledAtMillis = 0,
    this.load,
    this.columns = const ProcColumns(),
    this.sorts = const [],
    this.sort = ProcSortMode.cpu,
    this.ascending = false,
    this.signals = const [],
  }) : _json = null;

  PsResult._fromJson(Map<String, Object?> j, String json)
    : procs = [
        for (final row in j['procs'] as List) Proc.fromJson(row as Map<String, Object?>),
      ],
      issue = switch (j['issue']) {
        final Map<String, Object?> i => PsParseIssue(
          failure:
              PsParseFailure.fromWire(i['failure'] as String?) ?? PsParseFailure.unsupportedOutput,
          diagnostics: i['diagnostics'] as String? ?? '',
        ),
        _ => null,
      },
      sampledAtMillis = (j['sampled_at_millis'] as num?)?.toInt() ?? 0,
      load = switch (j['load']) {
        final Map<String, Object?> l => (
          one: (l['one'] as num).toDouble(),
          five: (l['five'] as num).toDouble(),
          fifteen: (l['fifteen'] as num).toDouble(),
        ),
        _ => null,
      },
      columns = ProcColumns.fromJson(j['columns'] as Map<String, Object?>? ?? const {}),
      sorts = [
        for (final s in j['sorts'] as List? ?? const []) ?ProcSortMode.fromWire(s as String?),
      ],
      sort = ProcSortMode.fromWire(j['sort'] as String?) ?? ProcSortMode.pid,
      ascending = j['ascending'] as bool? ?? true,
      signals = [
        for (final s in j['signals'] as List? ?? const []) ?ProcSignal.fromWire(s as String?),
      ],
      _json = json;

  static PsResult _read(String json) =>
      PsResult._fromJson(jsonDecode(json) as Map<String, Object?>, json);

  /// Reads what the process function printed ([raw]) on [system], ordered
  /// by [sort] where the table can answer it (null: its default) and
  /// [ascending] (null: that order's own default). [previous] is the last
  /// reading that parsed cleanly, which read/write speeds are differenced
  /// against; [sampledAtMillis] is when [raw] was produced.
  static Future<PsResult> parse(
    String raw,
    SystemType system, {
    ProcSortMode? sort,
    bool? ascending,
    PsResult? previous,
    int? sampledAtMillis,
  }) async => _read(
    await ffi.procViewJson(
      raw: raw,
      system: system.name,
      sort: sort?.name,
      ascending: ascending,
      previousJson: previous?._json,
      sampledAtMillis: sampledAtMillis ?? DateTime.now().millisecondsSinceEpoch,
    ),
  );

  /// This reading ordered by [sort] (null: its default), [ascending] (null:
  /// that order's own default).
  Future<PsResult> sortedBy(
    SystemType system,
    ProcSortMode? sort, {
    bool? ascending,
  }) async {
    final json = _json;
    if (json == null) return this;
    return _read(
      await ffi.procSortedJson(
        viewJsonIn: json,
        system: system.name,
        sort: sort?.name,
        ascending: ascending,
      ),
    );
  }
}
