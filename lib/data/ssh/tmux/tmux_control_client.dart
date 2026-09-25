import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_protocol.dart';
import 'package:server_box/data/ssh/tmux/tmux_format.dart';
import 'package:server_box/data/ssh/tmux/tmux_pane_mode_snapshot.dart';

/// A client attached to tmux through the real `tmux -CC` protocol.
///
/// This is not a second shell running `tmux list-*`. One SSH PTY speaks the
/// control protocol; commands, asynchronous state changes, and active-pane
/// output all travel over that client.
final class TmuxControlClient {
  static const _refreshDelay = Duration(milliseconds: 50);
  static const _startupTimeout = Duration(seconds: 5);
  static const _inputChunkBytes = 1024;

  final ShellSession _session;
  final TmuxControlProtocolParser _parser = TmuxControlProtocolParser();
  final _pending = Queue<Completer<TmuxControlCommandResult>>();
  final _startupCompleter = Completer<TmuxControlCommandResult>();
  final _stateController = StreamController<TmuxControlSnapshot>.broadcast();
  final _paneOutputController =
      StreamController<TmuxControlPaneOutput>.broadcast();
  StreamSubscription<Uint8List>? _outputSubscription;
  Timer? _refreshTimer;
  bool _refreshing = false;
  bool _refreshQueued = false;
  bool _captureAfterRefresh = false;
  bool _closed = false;
  TmuxControlSnapshot? _snapshot;

  /// Called for fire-and-forget commands (notably keyboard input) which fail.
  void Function(String command, Object error)? onCommandError;

  /// Called when a notification-driven refresh fails without an explicit caller.
  void Function(Object error)? onStateError;

  /// Called once the CC client has ended.
  ///
  /// [cleanExit] is true only for tmux's own `%exit` notification. A transport
  /// close is false: the page must preserve restoration state for reconnect.
  void Function(bool cleanExit)? onClosed;

  TmuxControlClient(this._session) {
    _outputSubscription = _session.stdout?.listen(
      _handleData,
      onError: _handleStreamError,
      onDone: () => _handleDone(cleanExit: false),
    );
    unawaited(_startupCompleter.future.then((_) {}, onError: (_) {}));
  }

  Stream<TmuxControlSnapshot> get snapshots => _stateController.stream;
  Stream<TmuxControlPaneOutput> get paneOutput => _paneOutputController.stream;
  TmuxControlSnapshot? get snapshot => _snapshot;

  /// Waits for the command which launched the CC client, then builds the first
  /// snapshot and, by default, captures the active pane's existing screen.
  Future<void> initialize({bool captureActivePane = true}) async {
    final startup = await _startupCompleter.future.timeout(_startupTimeout);
    if (startup.error) {
      throw TmuxControlCommandException('<attach>', startup.output);
    }
    await refreshState(captureActivePane: captureActivePane);
  }

  /// Runs a tmux command and returns its `%begin/%end` output.
  Future<TmuxControlCommandResult> run(String command) {
    if (_closed) {
      return Future.error(StateError('tmux control client is closed'));
    }
    final completer = Completer<TmuxControlCommandResult>();
    _pending.add(completer);
    _writeCommand(command);
    return completer.future;
  }

  Future<TmuxControlCommandResult> runRequired(String command) async {
    final result = await run(command);
    if (result.error) {
      throw TmuxControlCommandException(command, result.output);
    }
    return result;
  }

  /// Sends a command without waiting for its answer.
  ///
  /// Used on the resize path, where Flutter should not block a layout change
  /// on a round trip to the server.
  void send(String command) {
    unawaited(
      run(command).catchError((Object error) {
        onCommandError?.call(command, error);
        return TmuxControlCommandResult(lines: const [], error: false);
      }),
    );
  }

  /// Converts bytes emitted by the terminal emulator into `send-keys -H`.
  ///
  /// Hex input avoids a second shell and avoids tmux command-parser quoting
  /// for arbitrary text. The pane receives exactly the bytes xterm produced.
  void sendInput(List<int> data) {
    if (data.isEmpty) return;
    final paneId = _snapshot?.activePaneId;
    if (paneId == null) return;

    for (var at = 0; at < data.length; at += _inputChunkBytes) {
      final end = (at + _inputChunkBytes).clamp(0, data.length);
      final chunk = data.sublist(at, end);
      final hex = chunk
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      unawaited(
        runRequired("send-keys -t '$paneId' -H $hex").catchError((
          Object error,
        ) {
          onCommandError?.call('send-keys', error);
          return TmuxControlCommandResult(lines: const [], error: false);
        }),
      );
    }
  }

  Future<void> refreshState({bool captureActivePane = false}) {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    return _refreshNow(captureActivePane: captureActivePane);
  }

  /// Sizes the attached CC client and its active window.
  ///
  /// `refresh-client -C WxH` alone does not necessarily resize an existing
  /// window when another, larger client is attached and `window-size` is
  /// `latest`. tmux's explicit `<window-id>:WxH` form does.
  void resizeWindow(int width, int height) {
    final windowId = _snapshot?.activeWindowId;
    final target = windowId == null ? '' : '$windowId:';
    send('refresh-client -C $target${width}x$height');
  }

  Future<void> selectWindow(String windowId) async {
    await runRequired("select-window -t '$windowId'");
    await refreshState(captureActivePane: true);
  }

  Future<void> selectPane(String paneId) async {
    await runRequired("select-pane -t '$paneId'");
    await refreshState(captureActivePane: true);
  }

  Future<void> closePane(String paneId) async {
    // Closing the final pane of the final window destroys the session and this
    // CC client. As with `kill-window`, do not ask the departing client for a
    // refresh that can race `%exit` and turn success into a failure.
    final activeWindow = _snapshot?.activeWindow;
    final destroysSession =
        activeWindow != null &&
        activeWindow.panes.length == 1 &&
        _snapshot?.windows.length == 1;
    await _runRequiredUnlessClientEnded("kill-pane -t '$paneId'");
    if (!destroysSession) {
      await refreshState(captureActivePane: true);
    }
  }

  Future<String> newWindow({String? name}) async {
    final target = _snapshot?.session.id;
    final nameArg = name == null ? '' : ' -n ${quoteTmux(name)}';
    final command =
        "new-window -P -F '#{window_id}'"
        "${target == null ? '' : " -t '$target'"}$nameArg";
    final result = await runRequired(command);
    final id = result.output.trim();
    if (!id.startsWith('@')) {
      throw TmuxControlCommandException(command, result.output);
    }
    await refreshState(captureActivePane: true);
    return id;
  }

  Future<void> closeWindow(String windowId) async {
    // Killing the last window also destroys the session and exits this CC
    // client. Do not ask the departing client for a new snapshot: tmux may
    // answer `kill-window` and then immediately send `%exit`, so a refresh can
    // race the shutdown and turn a successful close into a spurious error.
    final destroysSession = _snapshot?.windows.length == 1;
    await _runRequiredUnlessClientEnded("kill-window -t '$windowId'");
    if (!destroysSession) {
      await refreshState(captureActivePane: true);
    }
  }

  /// Detaches this CC client from its current tmux session.
  ///
  /// The session stays alive on the server; the page's clean-exit handler
  /// replaces the foreground with a raw shell.
  Future<void> detach() async {
    await _runRequiredUnlessClientEnded('detach-client');
  }

  /// Runs a command whose success may be reported by the client ending.
  ///
  /// `kill-pane` and `kill-window` can destroy the session that owns this CC
  /// client. tmux may emit `%exit` before the command's `%end`, in which case
  /// the pending command future is completed with the transport-ended error.
  /// That is not a command failure; a genuine error still rethrows while the
  /// client is alive.
  Future<void> _runRequiredUnlessClientEnded(String command) async {
    try {
      await runRequired(command);
    } catch (error) {
      if (!_closed) rethrow;
    }
  }

  Future<void> switchSession(String sessionId) async {
    await runRequired("switch-client -t '$sessionId'");
    await refreshState(captureActivePane: true);
  }

  Future<String> createSession(String name) async {
    final command =
        "new-session -d -P -F '#{session_id}' -s ${quoteTmux(name)}";
    final result = await runRequired(command);
    final id = result.output.trim();
    if (!id.startsWith(r'$')) {
      throw TmuxControlCommandException(command, result.output);
    }
    await switchSession(id);
    return id;
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;

    final error = StateError('tmux control client disposed');
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.completeError(error);
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(error);
    }

    await _outputSubscription?.cancel();
    await _stateController.close();
    await _paneOutputController.close();
  }

  void _writeCommand(String command) {
    _session.write(utf8.encode('$command\n'));
  }

  void _handleData(Uint8List data) {
    if (_closed) return;
    try {
      for (final event in _parser.push(data)) {
        switch (event) {
          case TmuxControlProtocolCommandResult():
            _completeCommand(event.result);
          case TmuxControlProtocolOutput():
            _paneOutputController.add(
              TmuxControlPaneOutput(event.paneId, event.data),
            );
          case TmuxControlProtocolNotification():
            _handleNotification(event);
        }
      }
    } on Object catch (error) {
      _handleStreamError(error, StackTrace.current);
    }
  }

  void _completeCommand(TmuxControlCommandResult result) {
    if (!_startupCompleter.isCompleted) {
      if (result.error) {
        _startupCompleter.completeError(
          TmuxControlCommandException('<attach>', result.output),
        );
      } else {
        _startupCompleter.complete(result);
      }
      return;
    }
    if (_pending.isEmpty) return;
    _pending.removeFirst().complete(result);
  }

  void _handleNotification(TmuxControlProtocolNotification event) {
    switch (event.name) {
      case 'session-changed':
      case 'sessions-changed':
      case 'session-renamed':
      case 'window-add':
      case 'window-close':
      case 'window-renamed':
      case 'unlinked-window-add':
      case 'unlinked-window-close':
      case 'unlinked-window-renamed':
        _scheduleRefresh();
      case 'session-window-changed':
        _scheduleRefresh(captureActivePane: true);
      case 'window-pane-changed':
        _scheduleRefresh(captureActivePane: true);
      case 'exit':
        _handleDone(cleanExit: true);
      case 'client-detached':
      case 'client-session-changed':
      case 'config-error':
      case 'message':
      case 'pane-mode-changed':
      case 'paste-buffer-changed':
      case 'paste-buffer-deleted':
      case 'subscription-changed':
        break;
      case 'layout-change':
        // A split or server-side window resize redraws the active pane. tmux
        // usually sends that redraw as `%output`, but capturing after the
        // debounced refresh also restores the full screen when it does not.
        _scheduleRefresh(captureActivePane: true);
      default:
        break;
    }
  }

  void _scheduleRefresh({bool captureActivePane = false}) {
    if (_closed) return;
    _captureAfterRefresh = _captureAfterRefresh || captureActivePane;
    _refreshTimer ??= Timer(_refreshDelay, () {
      _refreshTimer = null;
      final capture = _captureAfterRefresh;
      _captureAfterRefresh = false;
      unawaited(
        _refreshNow(captureActivePane: capture).catchError((Object error) {
          onStateError?.call(error);
        }),
      );
    });
  }

  Future<void> _refreshNow({required bool captureActivePane}) async {
    if (_closed) return;
    if (_refreshing) {
      _refreshQueued = true;
      _captureAfterRefresh = _captureAfterRefresh || captureActivePane;
      return;
    }
    _refreshing = true;
    try {
      final current = await runRequired(
        "display-message -p '#{session_id}\t#{q:session_name}'",
      );
      final currentParts = splitTmuxFields(current.output);
      if (currentParts.length < 2) {
        throw const TmuxControlCommandException(
          'display-message',
          'session identity was malformed',
        );
      }

      final sessionsResult = await runRequired(
        "list-sessions -F '#{session_id}\t#{q:session_name}"
        "\t#{session_windows}\t#{session_attached}'",
      );
      final sessions = <TmuxControlSessionSummary>[];
      for (final line in sessionsResult.lines) {
        if (line.trim().isEmpty) continue;
        final parsed = _parseSession(line);
        if (parsed != null) sessions.add(parsed);
      }

      final sessionId = unescapeTmuxField(currentParts[0]);
      final sessionName = unescapeTmuxField(currentParts[1]);
      var session = sessions.where((item) => item.id == sessionId).firstOrNull;
      session ??= TmuxControlSessionSummary(
        id: sessionId,
        name: sessionName,
        windows: 0,
        attached: true,
      );

      final windowsResult = await runRequired(
        "list-windows -t '$sessionId' -F '#{window_id}\t#{window_index}"
        "\t#{q:window_name}\t#{window_active}'",
      );
      final windows = <TmuxControlWindow>[];
      for (final line in windowsResult.lines) {
        if (line.trim().isEmpty) continue;
        final parsed = _parseWindow(line);
        if (parsed != null) windows.add(parsed);
      }

      final activeWindow = windows.where((window) => window.active).firstOrNull;
      if (activeWindow == null) {
        throw const TmuxControlCommandException(
          'list-windows',
          'no active window',
        );
      }

      // Panes are queried only for the active window: they exist to make splits
      // addressable in the UI, and inactive windows stay summaries until selected.
      final panesResult = await runRequired(
        "list-panes -t '${activeWindow.id}' -F '#{pane_id}\t#{pane_index}"
        '\t#{pane_active}\t#{q:pane_title}\t#{q:pane_current_command}'
        "\t#{cursor_x}\t#{cursor_y}'",
      );
      final panes = <TmuxControlPane>[];
      for (final line in panesResult.lines) {
        if (line.trim().isEmpty) continue;
        final parsed = _parsePane(line);
        if (parsed != null) panes.add(parsed);
      }
      final activePane = panes.where((pane) => pane.active).firstOrNull;
      if (activePane == null) {
        throw TmuxControlCommandException(
          'list-panes',
          'active window ${activeWindow.id} has no active pane',
        );
      }

      final activeWindowWithPanes = TmuxControlWindow(
        id: activeWindow.id,
        index: activeWindow.index,
        name: activeWindow.name,
        active: true,
        panes: panes,
      );
      final windowsWithPanes = [
        for (final window in windows)
          window.id == activeWindow.id ? activeWindowWithPanes : window,
      ];
      final activePaneId = activePane.id;
      // Query pane modes before state is published or a capture is replayed.
      // The screen snapshot is not enough: Vim can be in the alternate screen
      // with application cursor/keypad modes while local xterm is still reset
      // to its defaults.
      final modeResult = await runRequired(
        "display-message -p -t '$activePaneId' "
        "'${TmuxPaneModeSnapshot.queryFormat}'",
      );
      final mode = TmuxPaneModeSnapshot.parse(modeResult.output);

      _snapshot = TmuxControlSnapshot(
        sessions: sessions,
        session: session,
        windows: windowsWithPanes,
        activeWindowId: activeWindow.id,
        activePaneId: activePaneId,
        mode: mode,
      );
      _stateController.add(_snapshot!);
      if (captureActivePane) await _captureActivePane();
    } finally {
      _refreshing = false;
      if (_refreshQueued && !_closed) {
        _refreshQueued = false;
        _scheduleRefresh(captureActivePane: _captureAfterRefresh);
        _captureAfterRefresh = false;
      }
    }
  }

  Future<void> _captureActivePane() async {
    final paneId = _snapshot?.activePaneId;
    if (paneId == null) return;

    // Freeze pane delivery around the capture. Without this boundary, output
    // can arrive between the capture and its control-mode result and then be
    // erased when the older captured screen is replayed.
    await runRequired("refresh-client -A '$paneId:pause'");
    final TmuxControlCommandResult result;
    try {
      result = await runRequired("capture-pane -p -e -t '$paneId'");
    } catch (error) {
      _resumePaneOutput(paneId);
      rethrow;
    }
    // Replay each captured row at its absolute screen position. Advancing with
    // LF/CR would work on an empty terminal, but a viewport resize or an
    // output race can turn trailing blank rows into scrollback and leave the
    // prompt detached from its tmux row.
    final captured = StringBuffer();
    for (var row = 0; row < result.lines.length; row++) {
      captured
        ..write('\x1b[${row + 1};1H')
        ..write(result.lines[row]);
    }
    final mode = _snapshot?.mode ?? const TmuxPaneModeSnapshot();
    final activePane = _snapshot?.activeWindow?.panes
        .where((pane) => pane.id == paneId)
        .firstOrNull;
    final cursorX = activePane?.cursorX ?? 0;
    final cursorY = activePane?.cursorY ?? 0;
    final restoreCursor = '\x1b[${cursorY + 1};${cursorX + 1}H';
    final bytes = utf8.encode(
      '\x1bc${mode.restorePrefix}$captured$restoreCursor',
    );
    _paneOutputController.add(TmuxControlPaneOutput(paneId, bytes));
    _resumePaneOutput(paneId);
  }

  void _resumePaneOutput(String paneId) {
    unawaited(
      runRequired("refresh-client -A '$paneId:continue'").catchError((
        Object error,
      ) {
        onCommandError?.call('refresh-client', error);
        return TmuxControlCommandResult(lines: const [], error: false);
      }),
    );
  }

  TmuxControlSessionSummary? _parseSession(String line) {
    final fields = splitTmuxFields(line);
    if (fields.length < 4) return null;
    final id = unescapeTmuxField(fields[0]);
    final windows = int.tryParse(unescapeTmuxField(fields[2]));
    final attached = int.tryParse(unescapeTmuxField(fields[3]));
    if (!id.startsWith(r'$') || windows == null) return null;
    return TmuxControlSessionSummary(
      id: id,
      name: unescapeTmuxField(fields[1]),
      windows: windows,
      attached: (attached ?? 0) > 0,
    );
  }

  TmuxControlWindow? _parseWindow(String line) {
    final fields = splitTmuxFields(line);
    if (fields.length < 4) return null;
    final id = unescapeTmuxField(fields[0]);
    final index = int.tryParse(unescapeTmuxField(fields[1]));
    final active = int.tryParse(unescapeTmuxField(fields[3]));
    if (!id.startsWith('@') || index == null || active == null) return null;
    return TmuxControlWindow(
      id: id,
      index: index,
      name: unescapeTmuxField(fields[2]),
      active: active > 0,
    );
  }

  TmuxControlPane? _parsePane(String line) {
    final fields = splitTmuxFields(line);
    if (fields.length < 5) return null;
    final id = unescapeTmuxField(fields[0]);
    final index = int.tryParse(unescapeTmuxField(fields[1]));
    final active = int.tryParse(unescapeTmuxField(fields[2]));
    if (!id.startsWith('%') || index == null || active == null) return null;
    final cursorX = fields.length > 5
        ? int.tryParse(unescapeTmuxField(fields[5])) ?? 0
        : 0;
    final cursorY = fields.length > 6
        ? int.tryParse(unescapeTmuxField(fields[6])) ?? 0
        : 0;
    return TmuxControlPane(
      id: id,
      index: index,
      title: unescapeTmuxField(fields[3]),
      currentCommand: unescapeTmuxField(fields[4]),
      active: active > 0,
      cursorX: cursorX < 0 ? 0 : cursorX,
      cursorY: cursorY < 0 ? 0 : cursorY,
    );
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_closed) return;
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.completeError(error, stackTrace);
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(error, stackTrace);
    }
    _handleDone();
  }

  void _handleDone({bool cleanExit = false}) {
    if (_closed) return;
    _closed = true;
    _refreshTimer?.cancel();
    _refreshTimer = null;

    final error = StateError('tmux control client ended');
    if (!_startupCompleter.isCompleted) {
      _startupCompleter.completeError(error);
    }
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completeError(error);
    }
    _paneOutputController.close();
    _stateController.close();
    onClosed?.call(cleanExit);
    unawaited(_outputSubscription?.cancel());
  }
}

/// Quotes an argument using tmux command syntax.
String quoteTmux(String value) {
  final escaped = value.replaceAll("'", r"'\''");
  return "'$escaped'";
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
