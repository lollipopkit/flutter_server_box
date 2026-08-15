import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/widgets.dart';
import 'package:server_box/core/app_navigator.dart';
import 'package:server_box/core/utils/ish_shell.dart';
import 'package:server_box/core/utils/local_shell.dart';
import 'package:server_box/core/utils/monitor_terminal.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/terminal_output_buffer.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:xterm/core.dart';

/// A terminal and the shell feeding it, with no page attached.
///
/// This used to be fields on the terminal page, and had to leave it once a
/// shell could start before there was a page to show it: the snippet dialog
/// runs one in place, and "continue in the terminal tab" then hands that same
/// running session to a tab — which is built when first visited, so it does
/// not exist at the moment the connection is made.
///
/// What lives here is what a shell *is*: a terminal, a source of bytes for it,
/// and the plumbing between them. What a particular *view* of one needs — tmux,
/// keep-alive, the virtual keyboard, state restoration — stays on the page.
class TerminalSession {
  TerminalSession({required this.source});

  /// Where this terminal's shell comes from — a server, or this device.
  final TerminalSource source;

  /// The server behind [source], or null when there is none. What genuinely
  /// needs one asks for it here; everything else works from [source].
  Spi? get spi => switch (source) {
    ServerSource(:final spi) => spi,
    LocalSource() => null,
  };

  final terminal = Terminal();

  /// Where this terminal's shell comes from. Usually SSH; for a server reached
  /// only through its monitor agent it is the agent's own PTY, which answers
  /// strictly less — see [ShellBackend.supportsExec].
  ///
  /// Set only by [adopt] and [connect], which is what keeps [_ownsBackend]
  /// true to the connection it describes.
  ShellBackend? get backend => _backend;
  ShellBackend? _backend;

  ShellSession? _foreground;

  /// Whether closing this session should close [backend] with it.
  ///
  /// An adopted connection belongs to the status poller and is shared with the
  /// rest of the app: hanging it up because a terminal went away would stop
  /// the server refreshing.
  bool _ownsBackend = false;

  /// The shell the terminal is bound to, if one is running.
  ShellSession? get foreground => _foreground;

  /// Called when the foreground shell ends for good, and only for the shell
  /// that is still current — a session replaced by tmux or by a reconnect
  /// finishes too, and that is not the terminal ending.
  void Function(ShellSession session)? onForegroundDone;

  /// The SSH connection behind [backend], when there is one. tmux is the only
  /// thing that needs it: it drives a second channel of its own, so it cannot
  /// be expressed through [ShellBackend].
  SSHClient? get client => switch (_backend) {
    SshShellBackend(:final client) => client,
    _ => null,
  };

  /// Whether a second command can run beside the interactive shell.
  bool get canExec => _backend?.supportsExec ?? false;

  /// Whether the source of shells is gone, as opposed to merely absent.
  bool get isBackendClosed => _backend?.isClosed ?? true;

  Map<String, String>? get environment => source.environment;

  String? get tmuxLang => source.tmuxLang;

  // — Connecting ————————————————————————————————————————————————————

  /// Reuses the connection the status poller already holds, when there is one.
  ///
  /// A monitor-only server has none — its shell is opened lazily and is the
  /// agent's own PTY — so this is where the two diverge without the caller
  /// having to know which it got.
  void adopt(SSHClient? client, {MonitorRemoteAccess? granted}) {
    if (_backend != null) return;
    // Nothing to adopt on this device: there is no connection anybody else
    // could be holding, so the shell this session opens is its own.
    if (source case LocalSource(:final rootfs)) {
      _backend = _localBackend(rootfs);
      _ownsBackend = true;
      return;
    }
    if (client != null && !client.isClosed) {
      _backend = SshShellBackend(client);
      _ownsBackend = false;
      return;
    }
    _backend = _grantedBackend(granted);
    _ownsBackend = _backend != null;
  }

  /// Connects a new source of shells, replacing whatever [backend] held.
  ///
  /// [granted] is what the agent said it allows, read by the caller at the
  /// moment of use: a stored "yes" the agent would refuse is a dead button,
  /// and a stored "no" hides a shell that is there.
  ///
  /// [context] is only for interactive authentication; the navigator's own is
  /// used when there is no page in front of this session.
  Future<ShellBackend> connect({
    MonitorRemoteAccess? granted,
    BuildContext? context,
  }) async {
    _ownsBackend = true;
    if (source case LocalSource(:final rootfs)) {
      return _backend = _localBackend(rootfs);
    }

    final agent = _grantedBackend(granted);
    if (agent != null) return _backend = agent;

    final client = await genClient(
      spi!,
      onKeyboardInteractive: (server, request) => KeyboardInteractiveAuth.handle(
        server,
        request,
        context: context ?? AppNavigator.context,
      ),
    );
    return _backend = SshShellBackend(client);
  }

  /// A shell on this device, in its Linux userland or on the host.
  ///
  /// Two mechanisms behind one source: Android enters a real rootfs with proot
  /// through the same pty a host shell uses, and iOS has no process to start at
  /// all, so its guest is an interpreter with a console of its own. The page
  /// above knows neither.
  ShellBackend _localBackend(bool rootfs) {
    if (rootfs && isIOS) return IshShellBackend();
    return LocalShellBackend(inRootfs: rootfs);
  }

  /// The agent's own shell, when the agent said it allows one.
  ///
  /// Only when the server has no SSH credential at all: [Spix.validate]
  /// rejects having both, and if one slipped through, SSH is the answer that
  /// can do more.
  ShellBackend? _grantedBackend(MonitorRemoteAccess? granted) {
    final spi = this.spi;
    if (spi == null || spi.ssh != null) return null;
    final monitor = spi.monitorHttp;
    if (monitor == null) return null;
    if (granted?.fullAccess != true) return null;
    return MonitorShellBackend(monitor);
  }

  // — Shells ————————————————————————————————————————————————————————

  Future<ShellSession?> openShell() => switch (_backend) {
    final backend? => backend.openShell(
      width: terminal.viewWidth,
      height: terminal.viewHeight,
      environment: environment,
    ),
    null => Future.value(),
  };

  /// Runs [command] on a channel of its own. Only where [canExec] says so.
  Future<ShellSession?> execute(String command) => switch (_backend) {
    final backend? => backend.execute(
      command,
      width: terminal.viewWidth,
      height: terminal.viewHeight,
      environment: environment,
    ),
    null => Future.value(),
  };

  /// Puts [session] on the screen: its bytes into the terminal, the terminal's
  /// keystrokes and size into it.
  void bindForeground(ShellSession session) {
    terminal.buffer.clear();
    terminal.buffer.setCursor(0, 0);
    _cancelOutputSubscriptions();

    terminal.onOutput = (data) => session.write(utf8.encode(data));
    terminal.onResize = (width, height, _, _) =>
        session.resizeTerminal(width, height);

    _listen(session.stdout);
    _listen(session.stderr);

    _foreground = session;
    unawaited(_awaitDone(session));
  }

  Future<void> _awaitDone(ShellSession session) async {
    await session.done;
    if (!identical(_foreground, session)) return;
    _foreground = null;
    drainOutput();
    onForegroundDone?.call(session);
  }

  /// Drops the foreground shell without touching the source behind it, which
  /// is what a reconnect and a tmux switch both want.
  void unbindForeground() {
    _foreground = null;
    _cancelOutputSubscriptions();
  }

  /// Drops the shell and the source behind it, whoever it belongs to. For a
  /// source already known to be dead — a failed reconnect, a lost link.
  void closeBackend() {
    unbindForeground();
    final closing = _backend;
    _backend = null;
    _ownsBackend = false;
    try {
      closing?.close();
    } catch (e, st) {
      Loggers.app.warning('Failed to close shell backend', e, st);
    }
  }

  /// Ends the session: the shell goes, and the connection with it when this
  /// session is the one that opened it. See [_ownsBackend].
  void close() {
    final foreground = _foreground;
    if (foreground != null) {
      try {
        foreground.close();
      } catch (e, st) {
        Loggers.app.warning('Failed to close foreground shell', e, st);
      }
    }
    if (_ownsBackend) {
      closeBackend();
    } else {
      unbindForeground();
    }
    dispose();
  }

  /// Releases what this object holds without touching the connection — the
  /// terminal is going away, but a shared client outlives it.
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _cancelOutputSubscriptions();
  }

  // — Output ————————————————————————————————————————————————————————

  static const _flushInterval = Duration(milliseconds: 16);
  static const _flushCharLimit = 32768;
  static const _tailCharLimit = 8192;

  final _buffer = TerminalOutputBuffer();
  Timer? _flushTimer;
  final List<StreamSubscription<String>> _subscriptions = [];
  String _tail = '';

  /// The last of what the shell printed, as text.
  ///
  /// Read rather than the terminal's own buffer where the *raw* bytes matter:
  /// a prompt that ends without a newline has not been laid out yet.
  String get outputTail => _tail;

  void clearOutputTail() => _tail = '';

  void writeLn(String line) => terminal.write('$line\r\n');

  void _listen(Stream<Uint8List>? stream) {
    if (stream == null) return;
    final subscription = stream
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(
          _queue,
          onError: (Object error, StackTrace stack) {
            Loggers.root.warning('Error in shell stream', error, stack);
          },
          cancelOnError: false,
        );
    _subscriptions.add(subscription);
  }

  void _cancelOutputSubscriptions() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  void _queue(String data) {
    _buffer.add(data);
    _appendTail(data);
    _scheduleFlush();
  }

  void _appendTail(String data) {
    if (data.isEmpty) return;
    _tail += data;
    if (_tail.length > _tailCharLimit) {
      _tail = _tail.substring(_tail.length - _tailCharLimit);
    }
  }

  void _scheduleFlush() {
    _flushTimer ??= Timer(_flushInterval, _flush);
  }

  void _flush({bool scheduleNext = true}) {
    _flushTimer = null;
    if (!_buffer.hasPending) return;
    final output = _buffer.take(_flushCharLimit);
    if (output.isNotEmpty) terminal.write(output);
    if (scheduleNext && _buffer.hasPending) _scheduleFlush();
  }

  /// Writes everything buffered right now, for a reader that cannot wait for
  /// the next frame — the sudo prompt detector, and the end of a shell.
  void drainOutput() {
    _flushTimer?.cancel();
    _flushTimer = null;
    while (_buffer.hasPending) {
      _flush(scheduleNext: false);
    }
  }
}
