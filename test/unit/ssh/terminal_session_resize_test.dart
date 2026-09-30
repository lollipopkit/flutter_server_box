import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/fake_shell.dart';
import '../../helpers/test_db.dart';

/// A shell that can no longer be told its size: the SSH channel of a
/// connection that has gone, which throws.
class _ClosedShell extends FakeShellSession {
  @override
  void resizeTerminal(int width, int height) => throw StateError('Transport is closed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  // Released builds reported this by the thousand: the keyboard resized the
  // terminal of a dropped connection, the throw escaped the layout, and every
  // write after it indexed rows the buffer did not have.
  test('resizing past a shell that cannot hear it is not an error', () {
    final s = TerminalSession(
      source: ConsoleSource(id: 'c', label: 'web-01', connect: () async => FakeShellBackend()),
      backend: FakeShellBackend(),
    )..bindForeground(_ClosedShell());
    final terminal = s.terminal;

    terminal.resize(40, 30);

    expect(terminal.viewHeight, 30);
    expect(terminal.buffer.height, 30);
    terminal.write('\x1b[30;1H${'x' * 40}\n');
  });
}
