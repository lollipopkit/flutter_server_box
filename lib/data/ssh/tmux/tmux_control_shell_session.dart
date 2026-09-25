import 'dart:async';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:server_box/data/ssh/tmux/tmux_output_normalizer.dart';

/// Presents a `tmux -CC` client to [TerminalSession] as an ordinary shell.
///
/// Only the active pane is rendered. Split-pane layout remains tmux state,
/// not Flutter UI; switching panes/windows is followed through control-mode
/// notifications and `capture-pane`.
final class TmuxControlShellSession implements ShellSession {
  final TmuxControlClient _client;
  final ShellSession _session;
  final _outputController = StreamController<Uint8List>();
  late final TmuxOutputNormalizer _normalizeOutput = TmuxOutputNormalizer()
    ..onUnknownEscape = (escape) {
      Loggers.app.warning('tmux pane used unsupported $escape');
    };
  StreamSubscription<TmuxControlPaneOutput>? _paneOutputSubscription;
  Future<void> _done = Future.value();
  bool _closed = false;
  TmuxPaneId? _normalizedPaneId;

  TmuxControlShellSession(this._client, this._session) {
    _paneOutputSubscription = _client.paneOutput.listen(_handlePaneOutput);
    _done = _session.done;
    unawaited(_done.whenComplete(_handleDone));
  }

  TmuxControlClient get client => _client;

  @override
  Stream<Uint8List>? get stdout => _outputController.stream;

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) {
    if (_closed) return;
    _client.sendInput(data);
  }

  @override
  void resizeTerminal(int width, int height) {
    if (_closed) return;
    _session.resizeTerminal(width, height);
    _client.resizeWindow(width, height);
  }

  @override
  Future<void> get done => _done;

  @override
  void close() {
    if (_closed) return;
    _flushOutputNormalizer();
    _closed = true;
    unawaited(_client.dispose());
    unawaited(
      _paneOutputSubscription?.cancel().then((_) {
        if (!_outputController.isClosed) {
          _outputController.close();
        }
      }),
    );
    _session.close();
  }

  void _handlePaneOutput(TmuxControlPaneOutput event) {
    if (_closed) return;
    final activePane = _client.snapshot?.activePaneId;
    if (activePane == null || event.paneId != activePane) return;

    // A partial escape from the previous pane has no meaning at this boundary.
    // The same applies to capture replay, which deliberately starts with RIS.
    if (_normalizedPaneId != event.paneId) {
      _normalizedPaneId = event.paneId;
      _normalizeOutput.reset();
    }
    final data = event.data;
    if (data.length >= 2 && data[0] == 0x1b && data[1] == 0x63) {
      _normalizeOutput.reset();
    }
    final normalized = _normalizeOutput(data);
    if (normalized.isEmpty) return;
    _outputController.add(normalized);
  }

  void _handleDone() {
    _flushOutputNormalizer();
    if (_outputController.isClosed) return;
    _outputController.close();
  }

  void _flushOutputNormalizer() {
    final pending = _normalizeOutput.close();
    if (pending.isEmpty || _outputController.isClosed) return;
    _outputController.add(pending);
  }
}
