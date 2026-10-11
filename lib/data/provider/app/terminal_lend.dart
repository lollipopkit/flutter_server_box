import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/ssh/terminal_session.dart';

part 'terminal_lend.g.dart';

/// A terminal the terminal tab holds, as the rest of the app may know it.
class OpenTerminal {
  const OpenTerminal({required this.name, required this.session});

  /// The tab's name: the server, numbered when it has more than one shell.
  final String name;

  final TerminalSession session;
}

/// The terminal tab's running shells, published for a panel elsewhere that
/// shows one of them rather than starting another.
///
/// Only those with a session: a tab restored but never looked at has not
/// connected, and there is nothing in it to show.
@Riverpod(keepAlive: true)
class OpenTerminals extends _$OpenTerminals {
  @override
  List<OpenTerminal> build() => const [];

  void publish(List<OpenTerminal> terminals) => state = terminals;
}

/// A terminal lent to a panel, and which panel holds it.
class TerminalLend {
  const TerminalLend({required this.session, required this.holder});

  final TerminalSession session;

  /// Who has it — the panel's state. What gives it back is checked against
  /// this rather than against the session: two panels can be after the same
  /// one, and the second to let go must not clear what the first just took.
  final Object holder;
}

/// The terminal a companion panel is drawing, which its tab then does not.
///
/// The reason is [FloatingTerminal]'s: two views of one terminal each resize
/// it to themselves. One at a time, because a panel lends only while it is on
/// screen.
@Riverpod(keepAlive: true)
class LentTerminal extends _$LentTerminal {
  @override
  TerminalLend? build() => null;

  void lend(TerminalSession session, {required Object holder}) =>
      state = TerminalLend(session: session, holder: holder);

  /// Gives back what [holder] holds, if it still holds anything. Called on the
  /// way out of a panel, which can be the frame the whole tree goes — see
  /// `TerminalShell.hideIf`.
  void giveBack(Object holder) {
    if (!ref.mounted) return;
    if (identical(state?.holder, holder)) state = null;
  }
}
