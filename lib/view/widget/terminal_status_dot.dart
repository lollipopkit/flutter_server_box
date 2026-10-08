import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_status.dart';
import 'package:xterm/core.dart';

/// The most urgent thing the programs in a terminal say about themselves, as
/// a dot before its name. Nothing while they say nothing, or are only idle.
///
/// Listens for itself: the bars it sits in draw a snapshot.
class TerminalStatusDot extends StatelessWidget {
  const TerminalStatusDot(this.session, {super.key});

  /// The tab's session, which exists once its page has been built.
  final ValueListenable<TerminalSession?> session;

  static const _size = 7.0;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        return ListenableBuilder(
          listenable: session.status,
          builder: (context, _) => _build(context, session.status.headline),
        );
      },
    );
  }

  Widget _build(BuildContext context, TerminalStatusHeadline? headline) {
    final color = headline?.colorIn(Theme.of(context).colorScheme);
    if (headline == null || color == null) return const SizedBox.shrink();
    final progress = headline.progress;
    final Widget mark = headline.state == ProgramState.working && progress != null
        ? SizedBox.square(
            dimension: _size + 2,
            child: CircularProgressIndicator(
              value: progress / 100,
              strokeWidth: 2,
              color: color,
              backgroundColor: color.withValues(alpha: 0.25),
            ),
          )
        : Container(
            width: _size,
            height: _size,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
    final description = headline.describe();
    return Tooltip(
      message: description,
      child: Semantics(label: description, child: mark),
    );
  }
}

extension TerminalStatusHeadlineUi on TerminalStatusHeadline {
  /// The colour of a mark for it, or null when there is nothing to mark: a
  /// program at rest is the ordinary state of a terminal.
  Color? colorIn(ColorScheme scheme) => switch (state) {
    ProgramState.blocked => Colors.orange,
    ProgramState.error => scheme.error,
    ProgramState.done => Colors.green,
    ProgramState.working => scheme.primary,
    ProgramState.idle => null,
  };

  /// The state in words; for `blocked`, what it waits for.
  String get stateLabel => switch (state) {
    ProgramState.blocked => switch (report?.kind) {
      ProgramBlockKind.permission => l10n.programWaitingPermission,
      ProgramBlockKind.question => l10n.programWaitingQuestion,
      ProgramBlockKind.auth => l10n.programWaitingAuth,
      null => l10n.programWaiting,
    },
    ProgramState.error => libL10n.error,
    ProgramState.done => libL10n.done,
    ProgramState.working => libL10n.running,
    ProgramState.idle => l10n.programIdle,
  };

  /// One line: the record's title, the state and progress, and its message.
  String describe() {
    final progress = this.progress;
    return [
      ?report?.title,
      progress == null ? stateLabel : '$stateLabel $progress%',
      ?report?.msg,
    ].join(' · ');
  }
}
