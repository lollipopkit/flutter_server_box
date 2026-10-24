import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/fake_shell.dart';
import '../../helpers/test_db.dart';

/// `releaseBackend`, which a failed reconnect cleans up with (#1782): the
/// shell always goes, the connection only when this session opened it.
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

  test('a borrowed connection stays open; the shell ends', () async {
    final borrowed = FakeShellBackend();
    final shell = FakeShellSession();
    var ended = false;
    unawaited(shell.done.then((_) => ended = true));
    final s = TerminalSession(
      source: ConsoleSource(id: 'c', label: 'web-01', connect: () async => FakeShellBackend()),
      backend: borrowed,
    )..bindForeground(shell);

    s.releaseBackend();
    await Future<void>.delayed(Duration.zero);

    expect(borrowed.isClosed, isFalse);
    expect(ended, isTrue);
    expect(s.backend, isNull);
    expect(s.foreground, isNull);
    s.close();
  });

  test('a connection this session opened is closed', () async {
    final owned = FakeShellBackend();
    final s = TerminalSession(
      source: ConsoleSource(id: 'c', label: 'web-01', connect: () async => owned),
    );
    await s.connect();

    s.releaseBackend();

    expect(owned.isClosed, isTrue);
    expect(s.backend, isNull);
    s.close();
  });
}
