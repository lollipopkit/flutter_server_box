import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/benchmark/yabs_options.dart';
import 'package:server_box/data/model/server/benchmark/yabs_result.dart';

/// Where a run got to.
///
/// Stored by name, never by index — these rows outlive the build that wrote
/// them, and inserting a case would silently change what every older row means.
enum BenchmarkStatus {
  /// Started, and the far side has not reported an exit code.
  ///
  /// This is the state a row is in across an app restart, a network change and
  /// a dropped connection, which is the whole reason a run is detached and the
  /// row is written at the start rather than at the end.
  running,

  /// Exited zero. It may still have skipped phases — a host with less than 2 GB
  /// free skips the disk test and says so only in the log.
  completed,

  /// Exited non-zero, or stopped existing without writing an exit code, which
  /// is what an out-of-memory kill looks like from here.
  failed,

  /// Stopped by the user.
  cancelled;

  bool get isTerminal => this != running;

  static BenchmarkStatus? byName(String? name) =>
      BenchmarkStatus.values.firstWhereOrNull((e) => e.name == name);
}

/// One benchmark, from the moment it was started.
///
/// Immutable, and rebuilt with [copyWith] on every poll: the page renders from
/// whatever the last poll produced, and a partially-updated record on screen is
/// worse than a whole one a few seconds old.
class BenchmarkRun {
  BenchmarkRun({
    required this.id,
    required this.serverId,
    required this.startedAt,
    required this.status,
    required this.options,
    required this.runDir,
    this.finishedAt,
    this.resultJson,
    this.log = '',
    this.exitCode,
    this.error = '',
  });

  final String id;
  final String serverId;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final BenchmarkStatus status;

  /// What was asked for. Kept with the result because a benchmark whose
  /// parameters are unknown cannot be compared with another one.
  final YabsOptions options;

  /// Where the run lives on the far side. Stored rather than recomputed: it
  /// follows [YabsOptions.workDir], so a later launch of the app could not
  /// derive it from the server id alone.
  final String runDir;

  /// yabs' `-w` output, verbatim and unparsed.
  final String? resultJson;

  /// Everything the run printed, which is where a skipped phase explains
  /// itself.
  final String log;

  final int? exitCode;

  /// Why this app gave up on the run — a transport failure, or output that was
  /// not a benchmark. Never yabs' own diagnostics, which are in [log].
  final String error;

  /// [resultJson] parsed, or null when there is none or it was not JSON at all.
  ///
  /// Computed once and lazily. The history list builds a row per run and does
  /// not read this; the detail page reads it repeatedly.
  ///
  /// A parse failure is null rather than an exception. yabs assembles this
  /// document with `+=` on a shell string, so a value containing a quote
  /// produces something no parser accepts — and losing the whole page over it
  /// would be worse than showing the raw text, which the page falls back to.
  late final YabsResult? result = _parseResult();

  YabsResult? _parseResult() {
    final raw = resultJson;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return YabsResult.fromJson(decoded);
    } catch (e) {
      Loggers.app.warning('Benchmark $id: result JSON is unreadable: $e');
      return null;
    }
  }

  /// True when there is a result to show, whether or not it parsed.
  bool get hasResult => resultJson?.trim().isNotEmpty ?? false;

  Duration get elapsed =>
      (finishedAt ?? DateTime.now()).difference(startedAt).abs();

  BenchmarkRun copyWith({
    BenchmarkStatus? status,
    DateTime? finishedAt,
    String? resultJson,
    String? log,
    int? exitCode,
    String? error,
  }) {
    return BenchmarkRun(
      id: id,
      serverId: serverId,
      startedAt: startedAt,
      status: status ?? this.status,
      options: options,
      runDir: runDir,
      finishedAt: finishedAt ?? this.finishedAt,
      resultJson: resultJson ?? this.resultJson,
      log: log ?? this.log,
      exitCode: exitCode ?? this.exitCode,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'BenchmarkRun($id, $serverId, ${status.name}, exit=$exitCode)';
}
