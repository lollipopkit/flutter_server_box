import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';

/// Socket implementation that communicates through a Process stdin/stdout
/// This is used for ProxyCommand functionality where the SSH connection
/// is proxied through an external command
class ProxySocket implements SSHSocket {
  final Process _process;
  final StreamController<Uint8List> _incomingController =
      StreamController<Uint8List>();
  final StreamController<List<int>> _outgoingController =
      StreamController<List<int>>();
  final Completer<void> _doneCompleter = Completer<void>();

  bool _closed = false;
  late StreamSubscription<Uint8List> _stdoutSubscription;
  late StreamSubscription<Uint8List> _stderrSubscription;

  ProxySocket(this._process) {
    // Set up stdout reading
    _stdoutSubscription = _process.stdout
        .transform(Uint8ListStreamTransformer())
        .listen(_onIncomingData,
            onError: _onError,
            onDone: _onProcessDone,
            cancelOnError: true);

    // Set up stderr reading (for logging)
    _stderrSubscription = _process.stderr
        .transform(Uint8ListStreamTransformer())
        .listen((data) {
      Loggers.app.warning('Proxy stderr: ${String.fromCharCodes(data)}');
    });

    // Set up outgoing data
    _outgoingController.stream.listen(_onOutgoingData);

    // Handle process exit
    _process.exitCode.then((code) {
      if (!_closed && code != 0) {
        _onError('Proxy process exited with code: $code');
      }
    });
  }

  @override
  Stream<Uint8List> get stream => _incomingController.stream;

  @override
  StreamSink<List<int>> get sink => _outgoingController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  /// Check if the socket is closed
  bool get closed => _closed;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    await _stdoutSubscription.cancel();
    await _stderrSubscription.cancel();
    await _outgoingController.close();
    await _incomingController.close();

    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }

    // Kill the process if it's still running
    try {
      _process.kill();
    } catch (e) {
      Loggers.app.warning('Error killing proxy process: $e');
    }
  }

  @override
  void destroy() {
    close();
  }

  void _onIncomingData(Uint8List data) {
    if (!_closed) {
      _incomingController.add(data);
    }
  }

  void _onOutgoingData(List<int> data) {
    if (!_closed) {
      _process.stdin.add(data);
    }
  }

  void _onError(dynamic error, [StackTrace? stackTrace]) {
    if (!_closed) {
      _incomingController.addError(error, stackTrace);
      close();
    }
  }

  void _onProcessDone() {
    if (!_closed) {
      _incomingController.close();
      close();
    }
  }
}

/// Transformer to convert `Stream<List<int>>` to `Stream<Uint8List>`
class Uint8ListStreamTransformer
    extends StreamTransformerBase<List<int>, Uint8List> {
  const Uint8ListStreamTransformer();

  @override
  Stream<Uint8List> bind(Stream<List<int>> stream) {
    return stream.map((data) => Uint8List.fromList(data));
  }
}