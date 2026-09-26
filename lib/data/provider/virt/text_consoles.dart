import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/ssh/terminal_session.dart';

part 'text_consoles.g.dart';

/// Guests' text consoles that are still running with no terminal page showing
/// them, by console id — the ids [SessionKeepAlive] knows them by.
///
/// A text console is a terminal page pushed over the window, and leaving that
/// page used to close its shell. Now the page hands its session here instead
/// ([park]), where [SessionKeepAlive] closes it once it has been left long
/// enough, and the guest's Console view offers it back ([take]) in the
/// meantime. Only one page shows a console at a time: a parked one is taken
/// out before a page is given it, and parked again when that page goes.
@Riverpod(keepAlive: true)
class VirtTextConsoles extends _$VirtTextConsoles {
  final _parked = <String, TerminalSession>{};

  @override
  Set<String> build() {
    ref.onDispose(() {
      for (final session in _parked.values) {
        session.close();
      }
      _parked.clear();
    });
    return const {};
  }

  /// Keeps [session] running for console [id], its page gone.
  ///
  /// A session whose shell has already ended — it failed to connect, or the
  /// guest's console hung up, which is also what took the page away — has
  /// nothing to come back to, and is closed instead.
  void park(
    String id,
    TerminalSession session, {
    required String name,
    required String host,
  }) {
    _parked.remove(id)?.close();
    if (session.foreground == null) {
      session.close();
      _publish();
      return;
    }
    _parked[id] = session;
    // Nothing is showing it: a shell that ends now ends the console.
    session.onForegroundDone = (_) => close(id);
    ref
        .read(sessionKeepAliveProvider.notifier)
        .register(
          id,
          name: name,
          host: host,
          onClose: () => close(id),
          visible: false,
        );
    _publish();
  }

  /// The running session for console [id], handed over to a page that is
  /// about to show it. Null when there is none.
  TerminalSession? take(String id) {
    final session = _parked.remove(id);
    if (session == null) return null;
    session.onForegroundDone = null;
    ref.read(sessionKeepAliveProvider.notifier).unregister(id);
    _publish();
    return session;
  }

  /// Ends console [id]'s shell, and its connection with it.
  void close(String id) {
    final session = _parked.remove(id);
    if (session == null) return;
    session.onForegroundDone = null;
    ref.read(sessionKeepAliveProvider.notifier).unregister(id);
    session.close();
    _publish();
  }

  void _publish() {
    if (!ref.mounted) return;
    state = Set.unmodifiable(_parked.keys);
  }
}
