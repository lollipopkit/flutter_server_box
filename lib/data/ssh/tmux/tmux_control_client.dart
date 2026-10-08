import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_command_executor.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_protocol.dart';
import 'package:server_box/data/ssh/tmux/tmux_format.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
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

  /// The local terminal's scrollback capacity.
  ///
  /// tmux may retain more history than the app-side `xterm` buffer can hold;
  /// replay is clamped to the smaller of the two so the oldest line is not
  /// immediately discarded after being written.
  final int maxScrollbackLines;

  final ShellSession _session;
  final TmuxControlProtocolParser _parser = TmuxControlProtocolParser();
  late final TmuxCommandExecutor _commands = TmuxCommandExecutor(
    writeCommand: _writeCommand,
  );
  final _stateController = StreamController<TmuxControlSnapshot>.broadcast();
  final _paneOutputController =
      StreamController<TmuxControlPaneOutput>.broadcast();
  StreamSubscription<Uint8List>? _outputSubscription;
  Timer? _refreshTimer;
  bool _captureAfterRefresh = false;

  /// The refresh running now, and the one queued behind it. A request made
  /// while one runs joins the follow-up, so its caller waits for state read
  /// after the request rather than for a refresh that started before it.
  Future<void>? _refreshInFlight;
  Future<void>? _refreshFollowUp;
  bool _followUpCapture = false;

  /// The server's `major * 100 + minor`, or 0 when it could not be read.
  int _tmuxVersion = 0;

  /// Whether tmux itself ended this client with `%exit`, as opposed to the
  /// transport or the parser failing under it.
  bool _exitedCleanly = false;
  TmuxControlSnapshot? _snapshot;

  /// The current session's `history-limit`, refreshed with session identity.
  int _historyLimit = 2000;

  /// Called for fire-and-forget commands (notably keyboard input) which fail.
  void Function(String command, Object error)? onCommandError;

  /// Called when a notification-driven refresh fails without an explicit caller.
  void Function(Object error)? onStateError;

  /// Called once the CC client has ended.
  ///
  /// [cleanExit] is true only for tmux's own `%exit` notification. A transport
  /// close is false: the page must preserve restoration state for reconnect.
  void Function(bool cleanExit)? onClosed;

  TmuxControlClient(this._session, {this.maxScrollbackLines = 1000}) {
    _historyLimit = maxScrollbackLines;
    _outputSubscription = _session.stdout?.listen(
      _handleData,
      onError: _handleStreamError,
      onDone: () => _handleDone(cleanExit: false),
    );
  }

  Stream<TmuxControlSnapshot> get snapshots => _stateController.stream;
  Stream<TmuxControlPaneOutput> get paneOutput => _paneOutputController.stream;
  TmuxControlSnapshot? get snapshot => _snapshot;

  /// Waits for the command which launched the CC client, then builds the first
  /// snapshot and, by default, captures the active pane's existing screen.
  Future<void> initialize({bool captureActivePane = true}) async {
    final startup = await _commands.startup.timeout(_startupTimeout);
    if (startup.error) {
      throw TmuxControlCommandException('<attach>', startup.output);
    }
    final version = await run("display-message -p '#{version}'");
    _tmuxVersion = version.error ? 0 : parseTmuxVersion(version.output);
    await refreshState(captureActivePane: captureActivePane);
  }

  /// Runs a tmux command and returns its `%begin/%end` output.
  Future<TmuxControlCommandResult> run(String command) =>
      _commands.run(command);

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
    // A pending notification refresh is folded in, capture request included.
    final capture = captureActivePane || _captureAfterRefresh;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _captureAfterRefresh = false;
    return _refreshNow(captureActivePane: capture);
  }

  /// Sizes the attached CC client and its active window.
  ///
  /// `refresh-client -C WxH` alone does not necessarily resize an existing
  /// window when another, larger client is attached and `window-size` is
  /// `latest`. tmux's explicit `<window-id>:WxH` form does, from tmux 3.3;
  /// older servers answer it with "bad size argument".
  void resizeWindow(int width, int height) {
    final windowId = _snapshot?.activeWindowId;
    final target = windowId == null || _tmuxVersion < 303 ? '' : '$windowId:';
    send('refresh-client -C $target${width}x$height');
  }

  Future<void> selectWindow(TmuxWindowId windowId) async {
    await runRequired("select-window -t '$windowId'");
    await refreshState(captureActivePane: true);
  }

  Future<void> selectPane(TmuxPaneId paneId) async {
    await runRequired("select-pane -t '$paneId'");
    await refreshState(captureActivePane: true);
  }

  Future<void> closePane(TmuxPaneId paneId) async {
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

  Future<TmuxWindowId> newWindow({String? name}) async {
    final target = _snapshot?.session.id;
    final nameArg = name == null ? '' : ' -n ${quoteTmux(name)}';
    final command =
        "new-window -P -F '#{window_id}'"
        "${target == null ? '' : " -t '$target'"}$nameArg";
    final result = await runRequired(command);
    final id = TmuxWindowId.tryParse(result.output.trim());
    if (id == null) {
      throw TmuxControlCommandException(command, result.output);
    }
    await refreshState(captureActivePane: true);
    return id;
  }

  Future<void> closeWindow(TmuxWindowId windowId) async {
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
  /// That is not a command failure. Anything else rethrows, including a
  /// transport that dropped before tmux answered: whether the command ran is
  /// then unknown.
  Future<void> _runRequiredUnlessClientEnded(String command) async {
    try {
      await runRequired(command);
    } catch (error) {
      if (!_exitedCleanly) rethrow;
    }
  }

  Future<void> switchSession(TmuxSessionId sessionId) async {
    await runRequired("switch-client -t '$sessionId'");
    await refreshState(captureActivePane: true);
  }

  Future<TmuxSessionId> createSession(String name) async {
    final command =
        "new-session -d -P -F '#{session_id}' -s ${quoteTmux(name)}";
    final result = await runRequired(command);
    final id = TmuxSessionId.tryParse(result.output.trim());
    if (id == null) {
      throw TmuxControlCommandException(command, result.output);
    }
    await switchSession(id);
    return id;
  }

  Future<void> dispose() async {
    if (_commands.isClosed) return;
    _commands.close();
    _refreshTimer?.cancel();
    _refreshTimer = null;

    await _outputSubscription?.cancel();
    await _stateController.close();
    await _paneOutputController.close();
  }

  void _writeCommand(String command) {
    _session.write(utf8.encode('$command\n'));
  }

  void _handleData(Uint8List data) {
    if (_commands.isClosed) return;
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
    _commands.complete(result);
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
    if (_commands.isClosed) return;
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

  Future<void> _refreshNow({required bool captureActivePane}) {
    if (_commands.isClosed) return Future.value();
    final followUp = _refreshFollowUp;
    if (followUp != null) {
      _followUpCapture = _followUpCapture || captureActivePane;
      return followUp;
    }
    final inFlight = _refreshInFlight;
    if (inFlight == null) return _startRefresh(captureActivePane);

    _followUpCapture = captureActivePane;
    return _refreshFollowUp = inFlight.then<void>((_) {}, onError: (_) {}).then(
      (_) {
        _refreshFollowUp = null;
        final capture = _followUpCapture;
        _followUpCapture = false;
        if (_commands.isClosed) return Future.value();
        return _startRefresh(capture);
      },
    );
  }

  Future<void> _startRefresh(bool captureActivePane) {
    final refresh = _refresh(captureActivePane: captureActivePane);
    _refreshInFlight = refresh;
    return refresh.whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
  }

  Future<void> _refresh({required bool captureActivePane}) async {
    final current = await runRequired(
      "display-message -p '#{session_id}\t#{q:session_name}"
      "\t#{history-limit}'",
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

    final sessionId = TmuxSessionId.tryParse(
      unescapeTmuxField(currentParts[0]),
    );
    final sessionName = unescapeTmuxField(currentParts[1]);
    final historyLimit = currentParts.length > 2
        ? int.tryParse(currentParts[2]) ?? maxScrollbackLines
        : maxScrollbackLines;
    _historyLimit = historyLimit < 0 ? 0 : historyLimit;
    if (sessionId == null) {
      throw const TmuxControlCommandException(
        'display-message',
        'session identity was malformed',
      );
    }
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
      "\t#{cursor_x}\t#{cursor_y}\t#{pane_height}'",
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

    final allPanesResult = await runRequired(
      "list-panes -s -t '$sessionId' -F '#{pane_id}\t#{window_id}'",
    );
    final paneWindows = <TmuxPaneId, TmuxWindowId>{};
    for (final line in allPanesResult.lines) {
      final fields = splitTmuxFields(line);
      if (fields.length < 2) continue;
      final pane = TmuxPaneId.tryParse(fields[0]);
      final window = TmuxWindowId.tryParse(fields[1]);
      if (pane != null && window != null) paneWindows[pane] = window;
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
      paneWindows: paneWindows,
    );
    _stateController.add(_snapshot!);
    if (captureActivePane) await _captureActivePane();
  }

  Future<void> _captureActivePane() async {
    final paneId = _snapshot?.activePaneId;
    if (paneId == null) return;

    // Freeze pane delivery around the capture. Without this boundary, output
    // can arrive between the capture and its control-mode result and then be
    // erased when the older captured screen is replayed. tmux before 3.2 has
    // no pause, and takes that race.
    final pause = _tmuxVersion >= 302;
    if (pause) await runRequired("refresh-client -A '$paneId:pause'");
    final mode = _snapshot?.mode ?? const TmuxPaneModeSnapshot();
    final activePane = _snapshot?.activeWindow?.panes
        .where((pane) => pane.id == paneId)
        .firstOrNull;
    final paneHeight = activePane?.height ?? 24;
    final effectiveHistoryLimit = math.min(_historyLimit, maxScrollbackLines);
    // Alternate-screen applications own their screen and have no scrollback in
    // xterm, so replaying tmux history there would only throw lines away.
    final captureHistory = !mode.alternateScreen && effectiveHistoryLimit > 0;
    final command = captureHistory
        ? "capture-pane -p -e -S -$effectiveHistoryLimit -t '$paneId'"
        : "capture-pane -p -e -t '$paneId'";
    final TmuxControlCommandResult result;
    try {
      result = await runRequired(command);
    } catch (error) {
      if (pause) _resumePaneOutput(paneId);
      rethrow;
    }

    // Replay history in pane-sized chunks. Each chunk is written by absolute
    // row so escapes in the captured line cannot move later rows, then the
    // cursor is moved to the bottom and the chunk is scrolled off with exactly
    // chunk.length line feeds. This preserves the chunk in scrollback without
    // leaving blank lines between history and the live screen.
    final captured = StringBuffer();
    final historyCount = captureHistory && result.lines.length > paneHeight
        ? result.lines.length - paneHeight
        : 0;
    for (var at = 0; at < historyCount; at += paneHeight) {
      var end = at + paneHeight;
      if (end > historyCount) end = historyCount;
      final chunk = result.lines.sublist(at, end);
      for (var row = 0; row < chunk.length; row++) {
        captured
          ..write('\x1b[${row + 1};1H')
          ..write(chunk[row]);
      }
      captured
        ..write('\x1b[$paneHeight;1H')
        ..write('\r\n' * chunk.length);
    }

    // Replay the live screen at its absolute rows. Advancing with LF/CR would
    // work on an empty terminal, but a viewport resize or an output race can
    // turn trailing blank rows into scrollback and leave the prompt detached
    // from its tmux row.
    final screenStart = historyCount;
    for (var row = screenStart; row < result.lines.length; row++) {
      captured
        ..write('\x1b[${row - screenStart + 1};1H')
        ..write(result.lines[row]);
    }

    final cursorX = activePane?.cursorX ?? 0;
    final cursorY = activePane?.cursorY ?? 0;
    final restoreCursor = '\x1b[${cursorY + 1};${cursorX + 1}H';
    final bytes = utf8.encode(
      '\x1bc${mode.restorePrefix}$captured$restoreCursor',
    );
    _paneOutputController.add(TmuxControlPaneOutput(paneId, bytes));
    if (pause) _resumePaneOutput(paneId);
  }

  void _resumePaneOutput(TmuxPaneId paneId) {
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
    final id = TmuxSessionId.tryParse(unescapeTmuxField(fields[0]));
    final windows = int.tryParse(unescapeTmuxField(fields[2]));
    final attached = int.tryParse(unescapeTmuxField(fields[3]));
    if (id == null || windows == null || attached == null) return null;
    return TmuxControlSessionSummary(
      id: id,
      name: unescapeTmuxField(fields[1]),
      windows: windows,
      attached: attached > 0,
    );
  }

  TmuxControlWindow? _parseWindow(String line) {
    final fields = splitTmuxFields(line);
    if (fields.length < 4) return null;
    final id = TmuxWindowId.tryParse(unescapeTmuxField(fields[0]));
    final index = int.tryParse(unescapeTmuxField(fields[1]));
    final active = int.tryParse(unescapeTmuxField(fields[3]));
    if (id == null || index == null || active == null) return null;
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
    final id = TmuxPaneId.tryParse(unescapeTmuxField(fields[0]));
    final index = int.tryParse(unescapeTmuxField(fields[1]));
    final active = int.tryParse(unescapeTmuxField(fields[2]));
    if (id == null || index == null || active == null) return null;
    final cursorX = fields.length > 5
        ? int.tryParse(unescapeTmuxField(fields[5])) ?? 0
        : 0;
    final cursorY = fields.length > 6
        ? int.tryParse(unescapeTmuxField(fields[6])) ?? 0
        : 0;
    final height = fields.length > 7
        ? int.tryParse(unescapeTmuxField(fields[7])) ?? 24
        : 24;
    return TmuxControlPane(
      id: id,
      index: index,
      title: unescapeTmuxField(fields[3]),
      currentCommand: unescapeTmuxField(fields[4]),
      active: active > 0,
      cursorX: cursorX < 0 ? 0 : cursorX,
      cursorY: cursorY < 0 ? 0 : cursorY,
      height: height <= 0 ? 24 : height,
    );
  }

  void _handleStreamError(Object error, StackTrace stackTrace) {
    if (_commands.isClosed) return;
    _commands.fail(error, stackTrace);
    _handleDone();
    // The PTY may still be up — a protocol overflow is raised here, not by
    // the transport — and nothing can speak to that client any more.
    _session.close();
  }

  void _handleDone({bool cleanExit = false}) {
    if (_commands.isClosed) return;
    _exitedCleanly = cleanExit;
    _commands.close();
    _refreshTimer?.cancel();
    _refreshTimer = null;

    _paneOutputController.close();
    _stateController.close();
    onClosed?.call(cleanExit);
    unawaited(_outputSubscription?.cancel());
  }
}

/// Parses `#{version}` ("3.4", "3.2a", "next-3.6") into `major * 100 + minor`,
/// or 0 when there is no version in it.
int parseTmuxVersion(String value) {
  final match = RegExp(r'(\d+)\.(\d+)').firstMatch(value);
  if (match == null) return 0;
  return int.parse(match[1]!) * 100 + int.parse(match[2]!);
}

/// Quotes an argument using tmux command syntax.
String quoteTmux(String value) {
  final escaped = value.replaceAll("'", r"'\''");
  return "'$escaped'";
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
