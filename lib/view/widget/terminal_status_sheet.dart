import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/view/widget/terminal_status_dot.dart';
import 'package:xterm/core.dart';

/// Every record the programs of a terminal report, by the terminal they belong
/// to: the shell, then each tmux pane. Follows the records while it is open.
///
/// [paneLabel] names a pane for its heading, such as its window and title;
/// its id is used without one.
Future<void> showTerminalStatusSheet(
  BuildContext context,
  TerminalStatus status, {
  String? Function(TmuxPaneId pane)? paneLabel,
}) {
  return showRowsSheet<void>(
    context,
    rows: (_) => [
      ListenableBuilder(
        listenable: status,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ..._terminal(
              status.shell,
              heading: status.panes.isEmpty ? null : l10n.programThisShell,
              onDismiss: (id) => status.dismiss(id),
            ),
            for (final pane in status.panes.toList())
              ..._terminal(
                status.pane(pane)!,
                heading: paneLabel?.call(pane) ?? pane.value,
                onDismiss: (id) => status.dismiss(id, pane: pane),
              ),
          ],
        ),
      ),
    ],
  );
}

List<Widget> _terminal(
  ProgramStatusRecords records, {
  required String? heading,
  required void Function(List<String> id) onDismiss,
}) {
  final rows = [
    for (final record in records.records)
      _RecordRow(
        record: record,
        app: records.appOf(record),
        onDismiss: record.state.persists ? () => onDismiss(record.id) : null,
      ),
    if (records.progress case final progress?) _ProgressRow(progress),
    if (records.command case final command?
        when command.running || command.exitCode != null)
      _CommandRow(command),
  ];
  if (rows.isEmpty) return const [];
  return [
    if (heading != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(17, 11, 17, 3),
        child: Text(heading, style: UIs.textGrey),
      ),
    ...rows,
  ];
}

final class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.app, this.onDismiss});

  final ProgramStatusRecord record;
  final String? app;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final report = record.report;
    final headline = TerminalStatusHeadline(
      state: record.state,
      report: report,
      progress: report.progress,
    );
    final scheme = Theme.of(context).colorScheme;
    final color = headline.colorIn(scheme) ?? scheme.outline;
    final name = report.title ?? (record.id.isEmpty ? app : record.id.last);
    final progress = report.progress;
    final state = progress == null
        ? headline.stateLabel
        : '${headline.stateLabel} $progress%';
    return ListTile(
      contentPadding: EdgeInsetsDirectional.only(
        start: 17.0 + 16 * (record.id.length - 1).clamp(0, 7),
        end: 7,
      ),
      leading: _Mark(color),
      minLeadingWidth: 9,
      title: Text(
        name ?? state,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (name != null) state,
          if (app != null && app != name) app!,
          ?report.msg,
        ].join(' · '),
        style: UIs.textGrey,
      ),
      trailing: onDismiss == null
          ? null
          : IconButton(
              icon: const Icon(MingCute.close_line, size: 17),
              tooltip: libL10n.clear,
              onPressed: onDismiss,
            ),
    );
  }
}

final class _ProgressRow extends StatelessWidget {
  const _ProgressRow(this.progress);

  final TerminalProgress progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = progress.state == TerminalProgressState.error;
    final percent = progress.percent;
    return ListTile(
      leading: _Mark(failed ? scheme.error : scheme.primary),
      minLeadingWidth: 9,
      title: Text(
        percent == null
            ? l10n.programProgress
            : '${l10n.programProgress} $percent%',
      ),
      subtitle: failed ? Text(libL10n.error, style: UIs.textGrey) : null,
    );
  }
}

final class _CommandRow extends StatelessWidget {
  const _CommandRow(this.command);

  final ShellCommandStatus command;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exitCode = command.exitCode;
    return ListTile(
      leading: _Mark(
        command.running
            ? scheme.primary
            : command.failed
            ? scheme.error
            : scheme.outline,
      ),
      minLeadingWidth: 9,
      title: Text(
        command.running
            ? l10n.programCommandRunning
            : exitCode != 0
            ? l10n.programCommandFailed(exitCode!)
            : l10n.programCommandSucceeded,
      ),
    );
  }
}

final class _Mark extends StatelessWidget {
  const _Mark(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Opens [showTerminalStatusSheet] for a tab's session, coloured by its most
/// urgent state. Nothing while no program reports anything.
final class TerminalStatusButton extends StatelessWidget {
  const TerminalStatusButton({super.key, required this.session, this.paneLabel});

  final ValueListenable<TerminalSession?> session;
  final String? Function(TmuxPaneId pane)? paneLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        final status = session.status;
        return ListenableBuilder(
          listenable: status,
          builder: (context, _) {
            if (!status.hasReports) return const SizedBox.shrink();
            final color = status.headline?.colorIn(
              Theme.of(context).colorScheme,
            );
            return Btn.icon(
              text: l10n.programStatus,
              icon: Icon(MingCute.task_line, size: 18, color: color),
              onTap: () => showTerminalStatusSheet(
                context,
                status,
                paneLabel: paneLabel,
              ),
            );
          },
        );
      },
    );
  }
}
