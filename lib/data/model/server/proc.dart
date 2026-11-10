import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/src/rust/api/proc.dart';

/// The process table as `sbm_parser::proc` reads it — the rules the monitor
/// agent's panel reads it by too. A [ProcRow] is the process ([ProcRow.proc])
/// and what is derived from it there; any of the process's fields can be
/// null, since the columns differ per platform and per `ps`.
export 'package:server_box/src/rust/api/proc.dart'
    show Proc, ProcColumns, ProcKillOutcome, ProcLoad, ProcRow, ProcSignal, ProcSortMode, PsParseFailure, PsParseIssue, PsView;

abstract final class ProcTable {
  static const empty = PsView(
    procs: [],
    sampledAtMillis: 0,
    columns: ProcColumns(
      user: false,
      cpu: false,
      mem: false,
      rss: false,
      read: false,
      write: false,
      readSpeed: false,
      writeSpeed: false,
    ),
    sorts: [],
    sort: ProcSortMode.cpu,
    ascending: false,
    signals: [],
  );

  /// No rows, and why.
  static PsView failed(PsParseIssue? issue) => PsView(
    procs: const [],
    issue: issue,
    sampledAtMillis: 0,
    columns: empty.columns,
    sorts: const [],
    sort: empty.sort,
    ascending: empty.ascending,
    signals: const [],
  );

  /// Reads what the process function printed ([raw]) on [system], ordered
  /// by [sort] where the table can answer it (null: its default) and
  /// [ascending] (null: that order's own default). [previous] is the last
  /// reading that parsed cleanly, which read/write speeds are differenced
  /// against; [sampledAtMillis] is when [raw] was produced.
  static Future<PsView> parse(
    String raw,
    SystemType system, {
    ProcSortMode? sort,
    bool? ascending,
    PsView? previous,
    int? sampledAtMillis,
  }) => procView(
    raw: raw,
    system: system.ffi,
    sort: sort,
    ascending: ascending,
    previous: previous,
    sampledAtMillis: sampledAtMillis ?? DateTime.now().millisecondsSinceEpoch,
  );
}

extension PsViewX on PsView {
  /// This reading ordered by [sort] (null: its default), [ascending] (null:
  /// that order's own default).
  Future<PsView> sortedBy(SystemType system, ProcSortMode? sort, {bool? ascending}) =>
      procSorted(view: this, system: system.ffi, sort: sort, ascending: ascending);
}

