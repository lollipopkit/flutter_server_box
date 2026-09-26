import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final clipboardCalls = <MethodCall>[];
  final clipboardChannel = SystemChannels.platform;
  var clipboardText = 'clipboard text';

  Future<Object?> clipboardHandler(MethodCall call) async {
    clipboardCalls.add(call);
    if (call.method == 'Clipboard.getData') {
      return {'text': clipboardText};
    }
    return null;
  }

  setUp(() {
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, clipboardHandler);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(clipboardChannel, null);
  });

  Spi server() => Spi(
    name: 'ssh',
    id: 'ssh',
    ssh: const SshCredential(ip: '10.0.0.1'),
  );

  test('OSC 52 sets the system clipboard', () async {
    final session = TerminalSession(source: ServerSource(server()));
    addTearDown(session.dispose);

    session.terminal.write(
      '\x1b]52;c;${base64.encode(utf8.encode('remote text'))}\x07',
    );
    await Future<void>.delayed(Duration.zero);

    expect(clipboardCalls.single.method, 'Clipboard.setData');
    expect(clipboardCalls.single.arguments['text'], 'remote text');
  });

  test('OSC 52 query answers through terminal output', () async {
    final session = TerminalSession(source: ServerSource(server()));
    addTearDown(session.dispose);
    final output = <String>[];
    session.terminal.onOutput = output.add;

    session.terminal.write('\x1b]52;c;?\x07');
    await Future<void>.delayed(Duration.zero);

    expect(
      output.single,
      '\x1b]52;c;${base64.encode(utf8.encode('clipboard text'))}\x1b\\',
    );
  });

  test('a primary-only OSC 52 request leaves the clipboard alone', () async {
    final session = TerminalSession(source: ServerSource(server()));
    addTearDown(session.dispose);

    session.terminal.write(
      '\x1b]52;p;${base64.encode(utf8.encode('primary text'))}\x07',
    );
    await Future<void>.delayed(Duration.zero);

    expect(clipboardCalls, isEmpty);
  });

  test('malformed OSC 52 data leaves the clipboard alone', () async {
    final session = TerminalSession(source: ServerSource(server()));
    addTearDown(session.dispose);

    session.terminal.write('\x1b]52;c;not-base64!\x07');
    await Future<void>.delayed(Duration.zero);

    expect(clipboardCalls, isEmpty);
  });

  test(
    'an oversized encoded OSC 52 request is refused before decoding',
    () async {
      final session = TerminalSession(source: ServerSource(server()));
      addTearDown(session.dispose);

      session.terminal.write('\x1b]52;c;${'A' * 2 * 1024 * 1024}\x07');
      await Future<void>.delayed(Duration.zero);

      expect(clipboardCalls, isEmpty);
    },
  );

  test('an oversized clipboard is not answered through OSC 52', () async {
    clipboardText = 'x' * 2 * 1024 * 1024;
    final session = TerminalSession(source: ServerSource(server()));
    addTearDown(session.dispose);
    final output = <String>[];
    session.terminal.onOutput = output.add;

    session.terminal.write('\x1b]52;c;?\x07');
    await Future<void>.delayed(Duration.zero);

    expect(clipboardCalls, isNotEmpty);
    expect(output, isEmpty);
  });
}
