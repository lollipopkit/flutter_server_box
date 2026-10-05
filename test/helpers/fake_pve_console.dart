import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:server_box/core/utils/pve_console.dart';

/// A [PveConsoleLink] the test plays the console's side of: [output] is what
/// the console says, [calls] what was asked of it, in order.
class FakePveConsole implements PveConsoleLink {
  final _queue = Queue<Uint8List?>();
  Completer<void>? _arrived;

  /// `send:<bytes>`, `resize:<cols>x<rows>`, `close`.
  final calls = <String>[];
  final _called = StreamController<String>.broadcast();

  /// How many `recv` calls have been made.
  var reads = 0;

  bool closed = false;

  /// Makes `send` fail, as a console that has gone does.
  bool failSends = false;

  /// The console says [bytes].
  void output(List<int> bytes) => _push(Uint8List.fromList(bytes));

  /// The console ends.
  void end() => _push(null);

  void _push(Uint8List? item) {
    _queue.add(item);
    _arrived?.complete();
    _arrived = null;
  }

  /// The next call matching [test], made already or still to come.
  Future<String> next(bool Function(String call) test) {
    for (final call in calls) {
      if (test(call)) return Future.value(call);
    }
    return _called.stream.firstWhere(test).timeout(const Duration(seconds: 5));
  }

  void _call(String call) {
    calls.add(call);
    _called.add(call);
  }

  @override
  Future<Uint8List?> recv() async {
    reads++;
    while (_queue.isEmpty) {
      if (closed) return null;
      await (_arrived ??= Completer<void>()).future;
    }
    return _queue.removeFirst();
  }

  @override
  Future<void> send(List<int> data) async {
    // A hop, as an FFI call is: what comes after it must not overtake it.
    await Future<void>.delayed(Duration.zero);
    if (failSends) throw StateError('closed');
    _call('send:${String.fromCharCodes(data)}');
  }

  @override
  Future<void> resize(int cols, int rows) async {
    _call('resize:${cols}x$rows');
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _call('close');
    _arrived?.complete();
    _arrived = null;
  }
}
