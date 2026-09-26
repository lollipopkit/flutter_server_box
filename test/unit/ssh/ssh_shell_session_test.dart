import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

void main() {
  test('resizing a session whose transport closed does not throw', () {
    // The terminal resizes from its layout, and a throw there left xterm's
    // buffers at the old size (SERVERBOX-M). A window-change is advisory; the
    // session reports its end through `done`.
    final session = SshShellSession(_ClosedSession());

    expect(() => session.resizeTerminal(80, 24), returnsNormally);
  });

  test('any other failure still reaches the caller', () {
    final session = SshShellSession(_ClosedSession());

    expect(() => session.resizeTerminal(-1, 24), throwsArgumentError);
  });
}

final class _ClosedSession implements SSHSession {
  @override
  void resizeTerminal(
    int width,
    int height, [
    int pixelWidth = 0,
    int pixelHeight = 0,
  ]) {
    if (width < 0) throw ArgumentError.value(width, 'width');
    throw SSHStateError('Transport is closed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
