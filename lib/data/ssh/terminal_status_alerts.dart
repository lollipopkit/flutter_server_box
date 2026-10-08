import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:xterm/core.dart';

/// Something a terminal's programs said that is worth telling a user who is
/// not looking at it.
sealed class TerminalStatusAlert {
  const TerminalStatusAlert();

  ProgramState get state;
}

/// A record became `blocked`, `done` or `error`, or changed what it says
/// while it is one.
final class RecordAlert extends TerminalStatusAlert {
  const RecordAlert(this.headline, {this.pane});

  final TerminalStatusHeadline headline;

  /// The tmux pane it is in, or null for the shell itself.
  final TmuxPaneId? pane;

  @override
  ProgramState get state => headline.state;
}

/// A command that ran for a while finished (OSC 133).
final class CommandAlert extends TerminalStatusAlert {
  const CommandAlert(this.exitCode, {this.pane});

  final int? exitCode;
  final TmuxPaneId? pane;

  @override
  ProgramState get state => exitCode == null || exitCode == 0
      ? ProgramState.done
      : ProgramState.error;
}

/// Picks out of a [TerminalStatus] what changed into something worth an alert
/// since it was last asked. Asked on every change, on screen or not, so what
/// the user watched happen is not announced once they look away.
final class TerminalStatusAlerts {
  TerminalStatusAlerts({
    this.longCommand = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// How long a command has to run for its end to be worth an alert.
  final Duration longCommand;

  final DateTime Function() _now;

  /// What each alerting record last said, by terminal and record.
  final _said = <String, String>{};

  /// When each terminal's running command was first seen running.
  final _commandSince = <String, DateTime>{};

  /// The alerts since the last call, the most urgent first.
  List<TerminalStatusAlert> take(TerminalStatus status) {
    final alerts = <TerminalStatusAlert>[];
    final present = <String>{};
    final terminals = <(String, TmuxPaneId?, ProgramStatusRecords)>[
      ('', null, status.shell),
      for (final pane in status.panes)
        (pane.value, pane, status.pane(pane)!),
    ];

    for (final (terminal, pane, records) in terminals) {
      for (final record in records.records) {
        if (!_alerting(record.state)) continue;
        final key = '$terminal\u0000${record.key}';
        present.add(key);
        final report = record.report;
        final said = '${record.state.name}\u0000${report.title}\u0000${report.msg}';
        if (_said[key] == said) continue;
        _said[key] = said;
        alerts.add(
          RecordAlert(
            TerminalStatusHeadline(
              state: record.state,
              report: report,
              progress: report.progress,
            ),
            pane: pane,
          ),
        );
      }

      final progressKey = '$terminal\u0000progress';
      if (records.progress?.state == TerminalProgressState.error) {
        present.add(progressKey);
        if (_said[progressKey] == null) {
          _said[progressKey] = 'error';
          alerts.add(
            RecordAlert(
              const TerminalStatusHeadline(state: ProgramState.error),
              pane: pane,
            ),
          );
        }
      }

      final command = records.command;
      if (command != null && command.running) {
        _commandSince.putIfAbsent(terminal, _now);
      } else if (_commandSince.remove(terminal) case final since?) {
        if (command != null && _now().difference(since) >= longCommand) {
          alerts.add(CommandAlert(command.exitCode, pane: pane));
        }
      }
    }

    _said.removeWhere((key, _) => !present.contains(key));
    final terminalKeys = {for (final (key, _, _) in terminals) key};
    _commandSince.removeWhere((key, _) => !terminalKeys.contains(key));
    alerts.sort((a, b) => a.state.index.compareTo(b.state.index));
    return alerts;
  }

  static bool _alerting(ProgramState state) =>
      state == ProgramState.blocked ||
      state == ProgramState.done ||
      state == ProgramState.error;
}
