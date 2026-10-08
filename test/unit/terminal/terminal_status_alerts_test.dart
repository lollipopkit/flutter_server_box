import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/terminal_status_alerts.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:xterm/core.dart';

ProgramStatusReport report(String payload) =>
    ProgramStatusReport.parse([payload])!;

void main() {
  test('alerts once per state a record enters, most urgent first', () {
    final status = TerminalStatus();
    final alerts = TerminalStatusAlerts();

    status.shell.apply(report('state=working'));
    expect(alerts.take(status), isEmpty);

    status.shell.apply(report('state=done:id=a'));
    status.applyPane(TmuxPaneId('%1'), report('state=blocked'));
    final taken = alerts.take(status);
    expect(taken.map((a) => a.state), [ProgramState.blocked, ProgramState.done]);
    expect((taken.first as RecordAlert).pane, TmuxPaneId('%1'));

    // Nothing new.
    expect(alerts.take(status), isEmpty);

    // The same record saying something else is news.
    status.applyPane(TmuxPaneId('%1'), report('state=blocked:msg=aGk'));
    expect(alerts.take(status).single.state, ProgramState.blocked);
  });

  test('a record that went and came back alerts again', () {
    final status = TerminalStatus();
    final alerts = TerminalStatusAlerts();
    status.shell.apply(report('state=error'));
    expect(alerts.take(status), hasLength(1));
    status.shell.apply(report('state=clear'));
    expect(alerts.take(status), isEmpty);
    status.shell.apply(report('state=error'));
    expect(alerts.take(status), hasLength(1));
  });

  test('a failed progress bar alerts', () {
    final status = TerminalStatus();
    final alerts = TerminalStatusAlerts();
    status.shell.apply(const TerminalProgress(TerminalProgressState.normal, 3));
    expect(alerts.take(status), isEmpty);
    status.shell.apply(const TerminalProgress(TerminalProgressState.error));
    expect(alerts.take(status).single.state, ProgramState.error);
  });

  test('only a command that ran a while alerts when it ends', () {
    var now = DateTime(2026);
    final status = TerminalStatus();
    final alerts = TerminalStatusAlerts(now: () => now);

    status.shell.apply(const ShellMark(ShellMarkKind.commandExecuted));
    expect(alerts.take(status), isEmpty);
    now = now.add(const Duration(seconds: 5));
    status.shell.apply(const ShellMark(ShellMarkKind.commandFinished, exitCode: 0));
    expect(alerts.take(status), isEmpty);

    status.shell.apply(const ShellMark(ShellMarkKind.commandExecuted));
    expect(alerts.take(status), isEmpty);
    now = now.add(const Duration(minutes: 2));
    status.shell.apply(const ShellMark(ShellMarkKind.commandFinished, exitCode: 2));
    final alert = alerts.take(status).single as CommandAlert;
    expect(alert.exitCode, 2);
    expect(alert.state, ProgramState.error);
  });
}
