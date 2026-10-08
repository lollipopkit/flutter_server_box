import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:xterm/core.dart';

/// What the programs of one terminal session say about themselves: OSC 7501
/// reports, OSC 9;4 progress and OSC 133 marks, by the lifetime rules of
/// [ProgramStatusRecords].
///
/// A plain shell is one terminal. Under `tmux -CC` every pane is one: the
/// local xterm only shows them in turn, so each keeps records of its own and
/// they go when the pane closes.
final class TerminalStatus extends ChangeNotifier {
  TerminalStatus() {
    shell.addListener(notifyListeners);
  }

  /// The terminal's own records, when no tmux client runs in it.
  final shell = ProgramStatusRecords();

  final _panes = <TmuxPaneId, ProgramStatusRecords>{};

  ProgramStatusRecords? pane(TmuxPaneId id) => _panes[id];

  /// The panes that report anything, in the order they first did.
  Iterable<TmuxPaneId> get panes => _panes.keys;

  /// Whether any program reports a state or a progress bar. A shell's last
  /// command (OSC 133) alone does not count: with shell integration on, there
  /// always is one.
  bool get hasReports => [shell, ..._panes.values].any(
    (records) => records.records.isNotEmpty || records.progress != null,
  );

  /// Every record as plain lines, for a reader that is not a person: the
  /// Agent. Empty when nothing is reported. The text in it is the programs'
  /// own, and so data rather than anything to follow.
  String describeForAgent({String? Function(TmuxPaneId pane)? paneLabel}) {
    final lines = <String>[];
    void terminal(String name, ProgramStatusRecords records) {
      for (final record in records.records) {
        final report = record.report;
        lines.add(
          [
            '$name${record.key.isEmpty ? '' : ' [${record.key}]'}:',
            record.state.name,
            if (report.kind case final kind?) '(${kind.name})',
            if (records.appOf(record) case final app?) 'app=$app',
            if (report.progress case final progress?) 'progress=$progress%',
            if (report.title case final title?) 'title=${jsonEncode(title)}',
            if (report.msg case final msg?) 'msg=${jsonEncode(msg)}',
          ].join(' '),
        );
      }
      if (records.progress case final bar?) {
        lines.add(
          '$name: progress bar ${bar.state!.name}'
          '${bar.percent == null ? '' : ' ${bar.percent}%'}',
        );
      }
      if (records.command case final command?) {
        lines.add(
          command.running
              ? '$name: a command is running'
              : '$name: last command exited ${command.exitCode ?? 'unknown'}',
        );
      }
    }

    terminal('shell', shell);
    for (final pane in _panes.keys) {
      final label = paneLabel?.call(pane);
      terminal(
        label == null ? 'tmux pane $pane' : 'tmux pane $pane ($label)',
        _panes[pane]!,
      );
    }
    return lines.join('\n');
  }

  /// Removes a record the user has seen, with its descendants: [pane]'s, or
  /// the shell's when null.
  void dismiss(List<String> id, {TmuxPaneId? pane}) {
    final clear = ProgramStatusReport.clear(id: id);
    if (pane == null) return shell.apply(clear);
    applyPane(pane, clear);
  }

  /// The most urgent state of the shell and every pane.
  ProgramState? get state => _mostUrgent([shell, ..._panes.values]);

  /// What to say about the session: its most urgent state, the record saying
  /// so (the most recently reported, among equals) and how far along it is.
  /// Null when nothing reports a state.
  TerminalStatusHeadline? get headline =>
      _headline([shell, ..._panes.values]);

  /// [headline] of [panes] alone, such as the panes of one tmux window.
  TerminalStatusHeadline? headlineOf(Iterable<TmuxPaneId> panes) =>
      _headline(panes.map((id) => _panes[id]).nonNulls.toList());

  static TerminalStatusHeadline? _headline(List<ProgramStatusRecords> all) {
    final state = _mostUrgent(all);
    if (state == null) return null;
    ProgramStatusReport? report;
    TerminalProgress? bar;
    for (final records in all) {
      for (final record in records.records) {
        if (record.state == state) report = record.report;
      }
      bar ??= records.progress;
    }
    return TerminalStatusHeadline(
      state: state,
      report: report,
      progress: report?.progress ?? (report == null ? bar?.percent : null),
    );
  }

  void applyPane(TmuxPaneId id, TerminalStatusEvent event) {
    final existing = _panes[id];
    if (existing != null) {
      existing.apply(event);
      if (existing.isEmpty) _removePane(id);
      return;
    }
    final records = ProgramStatusRecords()..apply(event);
    if (records.isEmpty) return;
    _panes[id] = records..addListener(notifyListeners);
    notifyListeners();
  }

  /// Drops the records of every pane not in [live]: those panes have closed.
  void retainPanes(Iterable<TmuxPaneId> live) {
    final keep = live.toSet();
    final gone = _panes.keys.where((id) => !keep.contains(id)).toList();
    if (gone.isEmpty) return;
    for (final id in gone) {
      _panes.remove(id)!.removeListener(notifyListeners);
    }
    notifyListeners();
  }

  /// No tmux client runs any more: nothing would update or close its panes'
  /// records.
  void clearPanes() => retainPanes(const []);

  void _removePane(TmuxPaneId id) {
    _panes.remove(id)?.removeListener(notifyListeners);
  }

  static ProgramState? _mostUrgent(Iterable<ProgramStatusRecords> records) {
    ProgramState? best;
    for (final record in records) {
      final state = record.state;
      if (state != null && (best == null || state.index < best.index)) {
        best = state;
      }
    }
    return best;
  }

  @override
  void dispose() {
    shell.removeListener(notifyListeners);
    for (final records in _panes.values) {
      records.removeListener(notifyListeners);
    }
    _panes.clear();
    super.dispose();
  }
}

/// See [TerminalStatus.headline].
final class TerminalStatusHeadline {
  const TerminalStatusHeadline({
    required this.state,
    this.report,
    this.progress,
  });

  final ProgramState state;

  /// Null when only an OSC 9;4 progress bar says it.
  final ProgramStatusReport? report;

  /// 0–100, or null when unknown.
  final int? progress;
}
