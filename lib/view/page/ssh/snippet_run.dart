import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/terminal.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:xterm/ui.dart' hide TerminalThemes;

/// Runs [snippet] on [spi] in a terminal, without leaving the page.
///
/// Returns the session when the user asked to carry on with it in the terminal
/// tab, and null when they were done — in which case the shell is closed, and
/// the connection with it if this dialog is what opened it.
///
/// The session is made here rather than inside the dialog because it is the
/// answer: the dialog can only say "keep this", and moving a terminal to a tab
/// is the calling page's job — a dialog that navigated for itself would be
/// popping a navigator it is not on.
Future<TerminalSession?> showSnippetRun(
  BuildContext context,
  WidgetRef ref, {
  required Spi spi,
  required Snippet snippet,
}) async {
  final server = ref.read(serverProvider(spi.id));
  final granted = server.remoteAccess;
  final session = TerminalSession(spi: spi)
    ..adopt(server.client, granted: granted);

  // Whether there is still a shell to carry on with. A snippet that has run to
  // completion leaves output worth reading but nothing worth moving.
  final running = ValueNotifier(true);

  try {
    final carryOn = await context.showRoundDialog<bool>(
      title: snippet.name,
      contentPadding: const EdgeInsets.fromLTRB(11, 11, 11, 0),
      child: _SnippetRunView(
        session: session,
        snippet: snippet,
        granted: granted,
        running: running,
      ),
      actions: [
        ListenBuilder(
          listenable: running,
          builder: () => TextButton(
            onPressed: running.value
                ? () => context.popDialog(true)
                : null,
            child: Text(l10n.continueInTerminal),
          ),
        ),
        Btn.ok(onTap: () => context.popDialog(false)),
      ],
    );

    if (carryOn == true) return session;
    session.close();
    return null;
  } finally {
    running.dispose();
  }
}

/// The terminal inside the dialog, and the shell it is waiting on.
class _SnippetRunView extends StatefulWidget {
  const _SnippetRunView({
    required this.session,
    required this.snippet,
    required this.granted,
    required this.running,
  });

  final TerminalSession session;
  final Snippet snippet;
  final MonitorRemoteAccess? granted;
  final ValueNotifier<bool> running;

  @override
  State<_SnippetRunView> createState() => _SnippetRunViewState();
}

class _SnippetRunViewState extends State<_SnippetRunView>
    with TickerProviderStateMixin {
  late final _controller = TerminalController(vsync: this);
  final _focusNode = FocusNode();

  TerminalSession get _sess => widget.session;

  /// Held rather than torn off at each use: this is compared against what the
  /// session currently holds, and two tear-offs of one method need not be the
  /// same object.
  late final void Function(ShellSession) _onDone = _handleDone;

  void _handleDone(ShellSession _) => _stopped();

  @override
  void initState() {
    super.initState();
    _sess.onForegroundDone = _onDone;
    unawaited(_run());
  }

  @override
  void dispose() {
    // The session outlives this view when it is on its way to a tab, so only
    // this view's own callback is withdrawn — and it must be, because the
    // notifier it writes to is disposed with the dialog. The page that
    // receives the session installs one of its own.
    if (identical(_sess.onForegroundDone, _onDone)) {
      _sess.onForegroundDone = null;
    }
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Connect if needed, open a shell, then type the snippet into it.
  ///
  /// Failures are written into the terminal rather than raised as a dialog
  /// over this one: the terminal is what the user is already looking at, and
  /// it is where the same failure would appear in a tab.
  Future<void> _run() async {
    try {
      if (_sess.backend == null) {
        _sess.writeLn(l10n.waitConnection);
        await _sess.connect(
          granted: widget.granted,
          context: mounted ? context : null,
        );
      }

      final shell = await _sess.openShell();
      if (shell == null) {
        _sess.writeLn(libL10n.fail);
        _stopped();
        return;
      }
      _sess.bindForeground(shell);

      // Entered, unlike the terminal page's own snippet paths: there the user
      // is at a prompt and can finish the line themselves, whereas this dialog
      // exists to run the thing and show what it printed.
      await widget.snippet.runInTerm(
        _sess.terminal,
        _sess.spi,
        autoEnter: true,
      );
    } catch (e, s) {
      Loggers.app.warning('Snippet run failed', e, s);
      _sess.writeLn('${libL10n.fail}: $e');
      _stopped();
    }
  }

  /// Nothing left to carry on with. Only while this view is still up: the
  /// notifier belongs to the dialog and goes with it.
  void _stopped() {
    if (!mounted) return;
    widget.running.value = false;
  }

  @override
  Widget build(BuildContext context) {
    final media = context.mediaQuery;
    // Tall enough to read a command's output in, and never taller than the
    // window it is floating over.
    final width = (media.size.width * .9).clamp(0.0, 520.0);
    final height = (media.size.height * .5).clamp(0.0, 380.0);
    final isDark = TerminalLook.isDark(context);
    final theme = TerminalLook.themeOf(context);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: ColoredBox(
          color: theme.background,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            child: TerminalView(
              _sess.terminal,
              controller: _controller,
              focusNode: _focusNode,
              textStyle: TerminalLook.style,
              theme: theme,
              backgroundOpacity: 0,
              keyboardType: TextInputType.text,
              keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
              deleteDetection: isMobile,
              autofocus: false,
              hideScrollBar: false,
            ),
          ),
        ),
      ),
    );
  }
}
