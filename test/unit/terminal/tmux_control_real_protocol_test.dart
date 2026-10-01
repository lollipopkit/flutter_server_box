import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_shell_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';

/// Runs the CC parser and command queue against the real tmux binary.
///
/// The fake-shell tests prove bookkeeping; this test proves the protocol bytes
/// a PTY actually emits, including the DCS handshake, escaped `%output`, stable
/// IDs, and command result guards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('TmuxControlClient speaks real tmux control mode', () async {
    if (Platform.isWindows) {
      markTestSkipped('the real-PTY tmux harness is POSIX-only');
      return;
    }
    final ProcessResult version;
    try {
      version = Process.runSync('tmux', ['-V']);
    } on ProcessException {
      markTestSkipped('tmux is not installed');
      return;
    }
    if (version.exitCode != 0) {
      markTestSkipped('tmux is not installed');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'server-box-tmux-cc-',
    );
    final socketName =
        'sb${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final pty = await _startTmuxControlProcess(socketName, tempDir.path);
    final shell = _PtyShellSession(pty);
    final client = TmuxControlClient(shell);
    final output = StringBuffer();
    final echoed = Completer<void>();
    StreamSubscription<void>? subscription;

    try {
      subscription = client.paneOutput.listen((event) {
        if (event.paneId != client.snapshot?.activePaneId) return;
        output.write(utf8.decode(event.data, allowMalformed: true));
        if (output.toString().contains('serverbox-cc-real-input')) {
          if (!echoed.isCompleted) echoed.complete();
        }
      });

      await client.initialize().timeout(const Duration(seconds: 10));

      expect(client.snapshot, isNotNull);
      expect(client.snapshot!.session.id.value, startsWith(r'$'));
      expect(client.snapshot!.session.name, 'serverbox_real');
      expect(client.snapshot!.activeWindowId.value, startsWith('@'));
      expect(client.snapshot!.activePaneId.value, startsWith('%'));

      client.sendInput(utf8.encode('serverbox-cc-real-input\n'));
      await echoed.future.timeout(const Duration(seconds: 5));

      final created = await client.runRequired(
        "new-window -d -P -F '#{window_id}' -n second cat",
      );
      final secondWindowId = TmuxWindowId.parse(created.output.trim());
      expect(secondWindowId.value, startsWith('@'));
      await client.refreshState(captureActivePane: true);
      expect(client.snapshot!.windows, hasLength(2));

      await client.selectWindow(secondWindowId);
      expect(client.snapshot!.activeWindowId, secondWindowId);
      expect(
        client.snapshot!.windows
            .firstWhere((window) => window.id == secondWindowId)
            .name,
        'second',
      );

      final splitPane = await client.runRequired(
        "split-window -d -P -F '#{pane_id}' -t '$secondWindowId' cat",
      );
      final splitPaneId = TmuxPaneId.parse(splitPane.output.trim());
      expect(splitPaneId.value, startsWith('%'));
      await client.refreshState(captureActivePane: true);
      expect(client.snapshot!.activeWindow!.panes, hasLength(2));

      await client.selectPane(splitPaneId);
      expect(client.snapshot!.activePaneId, splitPaneId);
      expect(
        client.snapshot!.activeWindow!.panes
            .firstWhere((pane) => pane.id == splitPaneId)
            .active,
        isTrue,
      );

      // Older tmux stores ':' in a session name as '_', so compare with
      // the name tmux reports rather than the one requested.
      final special = await client.runRequired(
        "new-session -d -P -F '#{session_id} #{session_name}' -s 'a|b:c'",
      );
      final [specialIdRaw, specialName] = special.output.trim().split(' ');
      final specialId = TmuxSessionId.parse(specialIdRaw);
      expect(specialName, anyOf('a|b:c', 'a|b_c'));
      await client.switchSession(specialId);
      expect(client.snapshot!.session.id, specialId);
      expect(client.snapshot!.session.name, specialName);
      expect(
        client.snapshot!.sessions.map((session) => session.name),
        contains(specialName),
      );
    } finally {
      await subscription?.cancel();
      shell.close();
      await shell.done.timeout(const Duration(seconds: 5));
      await client.dispose();
      await Process.run(
        'tmux',
        ['-L', socketName, 'kill-server'],
        environment: {'TMUX_TMPDIR': tempDir.path},
      );
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // tmux can remove its socket directory concurrently with the test.
      }
    }
  });

  test('closing the last window exits the control client cleanly', () async {
    if (Platform.isWindows) {
      markTestSkipped('the real-PTY tmux harness is POSIX-only');
      return;
    }
    final ProcessResult version;
    try {
      version = Process.runSync('tmux', ['-V']);
    } on ProcessException {
      markTestSkipped('tmux is not installed');
      return;
    }
    if (version.exitCode != 0) {
      markTestSkipped('tmux is not installed');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp(
      'sb-tmux-last-window-',
    );
    final socketName =
        'lw${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final pty = await _startTmuxControlProcess(
      socketName,
      tempDir.path,
      sessionName: 'serverbox_last_window',
      paneCommand: const ['sh', '-c', 'sleep 60'],
    );
    final shell = _PtyShellSession(pty);
    final client = TmuxControlClient(shell);
    final exited = Completer<bool>();
    client.onClosed = exited.complete;

    try {
      await client.initialize().timeout(const Duration(seconds: 10));
      final windowId = client.snapshot!.activeWindowId;
      await client.closeWindow(windowId);

      final cleanExit = await exited.future.timeout(const Duration(seconds: 5));
      expect(cleanExit, isTrue);
      await shell.done.timeout(const Duration(seconds: 5));
    } finally {
      await client.dispose();
      shell.close();
      await Process.run(
        'tmux',
        ['-L', socketName, 'kill-server'],
        environment: {'TMUX_TMPDIR': tempDir.path},
      );
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // tmux can remove its socket directory concurrently with the test.
      }
    }
  });

  test('detaching exits the control client cleanly', () async {
    if (Platform.isWindows) {
      markTestSkipped('the real-PTY tmux harness is POSIX-only');
      return;
    }
    final ProcessResult version;
    try {
      version = Process.runSync('tmux', ['-V']);
    } on ProcessException {
      markTestSkipped('tmux is not installed');
      return;
    }
    if (version.exitCode != 0) {
      markTestSkipped('tmux is not installed');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('sb-tmux-detach-');
    final socketName =
        'dt${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    final pty = await _startTmuxControlProcess(
      socketName,
      tempDir.path,
      sessionName: 'serverbox_detach',
      paneCommand: const ['sh', '-c', 'sleep 60'],
    );
    final shell = _PtyShellSession(pty);
    final client = TmuxControlClient(shell);
    final exited = Completer<bool>();
    client.onClosed = exited.complete;

    try {
      await client.initialize().timeout(const Duration(seconds: 10));
      await client.detach();

      final cleanExit = await exited.future.timeout(const Duration(seconds: 5));
      expect(cleanExit, isTrue);
      await shell.done.timeout(const Duration(seconds: 5));
    } finally {
      await client.dispose();
      shell.close();
      await Process.run(
        'tmux',
        ['-L', socketName, 'kill-server'],
        environment: {'TMUX_TMPDIR': tempDir.path},
      );
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // tmux can remove its socket directory concurrently with the test.
      }
    }
  });

  test('forwards real tmux OSC 52 into the system clipboard', () async {
    if (Platform.isWindows) {
      markTestSkipped('the real-PTY tmux harness is POSIX-only');
      return;
    }
    final ProcessResult version;
    try {
      version = Process.runSync('tmux', ['-V']);
    } on ProcessException {
      markTestSkipped('tmux is not installed');
      return;
    }
    if (version.exitCode != 0) {
      markTestSkipped('tmux is not installed');
      return;
    }

    final clipboardCalls = <MethodCall>[];
    final copied = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method != 'Clipboard.setData') return null;
          clipboardCalls.add(call);
          if (!copied.isCompleted) copied.complete();
          return null;
        });

    final tempDir = await Directory.systemTemp.createTemp('sb-osc52-');
    final socketName =
        'clip${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final pty = await _startTmuxControlProcess(
      socketName,
      tempDir.path,
      sessionName: 'serverbox_clipboard',
      paneCommand: const [
        'sh',
        '-c',
        "sleep 1; printf '\\033]52;c;aGk=\\007'; cat",
      ],
    );
    final shell = _PtyShellSession(pty);
    final client = TmuxControlClient(shell);
    final terminalSession = TerminalSession(
      source: ServerSource(
        Spi(
          name: 'agent',
          id: 'osc52-test',
          ssh: const SshCredential(ip: '10.0.0.1'),
        ),
      ),
    );
    final tmuxSession = TmuxControlShellSession(client, shell);
    terminalSession.bindForeground(tmuxSession);

    try {
      await client.initialize().timeout(const Duration(seconds: 10));
      await copied.future.timeout(const Duration(seconds: 10));

      expect(clipboardCalls.single.method, 'Clipboard.setData');
      expect(clipboardCalls.single.arguments['text'], 'hi');
    } finally {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      terminalSession.dispose();
      await client.dispose();
      shell.close();
      await Process.run(
        'tmux',
        ['-L', socketName, 'kill-server'],
        environment: {'TMUX_TMPDIR': tempDir.path},
      );
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // tmux can remove its socket directory concurrently with the test.
      }
    }
  });

  test('queries real Vim pane modes before capture replay', () async {
    if (Platform.isWindows) {
      markTestSkipped('the real-PTY tmux harness is POSIX-only');
      return;
    }
    try {
      final result = Process.runSync('vim', ['--version']);
      if (result.exitCode != 0) {
        markTestSkipped('vim is not installed');
        return;
      }
    } on ProcessException {
      markTestSkipped('vim is not installed');
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp('sbvm-');
    final socketName = 'v${DateTime.now().microsecondsSinceEpoch % 1000000}';
    final pty = await _startTmuxControlProcess(
      socketName,
      tempDir.path,
      sessionName: 'serverbox_vim_mode',
      paneCommand: const ['vim -u NONE -n'],
    );
    final shell = _PtyShellSession(pty);
    final client = TmuxControlClient(shell);
    final output = <List<int>>[];
    StreamSubscription<void>? subscription;

    try {
      subscription = client.paneOutput.listen(
        (event) => output.add(event.data),
      );
      await client
          .initialize(captureActivePane: false)
          .timeout(const Duration(seconds: 10));

      // Ready means drawn, not only in its modes: Vim switches to the
      // alternate screen and keypad modes before it paints its `~` rows, and
      // on a slow runner a capture between the two replays a blank screen.
      var vimReady = false;
      for (var attempt = 0; attempt < 50; attempt++) {
        await client.refreshState(captureActivePane: false);
        final mode = client.snapshot!.mode;
        if (mode.alternateScreen &&
            mode.applicationCursorKeys &&
            mode.applicationKeypad) {
          final screen = await Process.run(
            'tmux',
            ['-L', socketName, 'capture-pane', '-p', '-t', 'serverbox_vim_mode'],
            environment: {'TMUX_TMPDIR': tempDir.path},
          );
          if ('${screen.stdout}'.contains('~')) {
            vimReady = true;
            break;
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      expect(vimReady, isTrue);
      output.clear();
      await client.refreshState(captureActivePane: true);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final mode = client.snapshot!.mode;
      expect(mode.alternateScreen, isTrue);
      expect(mode.applicationCursorKeys, isTrue);
      expect(mode.applicationKeypad, isTrue);

      final replay = utf8.decode(
        output.expand((chunk) => chunk).toList(),
        allowMalformed: true,
      );
      expect(replay, contains('\x1bc'));
      expect(replay, contains('\x1b[?1h'));
      expect(replay, contains('\x1b='));
      expect(replay, contains('\x1b[?1049h'));
      expect(replay.indexOf('\x1b[?1049h'), lessThan(replay.indexOf('~')));
    } finally {
      await subscription?.cancel();
      shell.close();
      try {
        await shell.done.timeout(const Duration(seconds: 2));
      } on TimeoutException {
        // Vim may still be running; the kill-server call below ends it.
      }
      await client.dispose();
      await Process.run(
        'tmux',
        ['-L', socketName, 'kill-server'],
        environment: {'TMUX_TMPDIR': tempDir.path},
      );
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // tmux can remove its socket directory concurrently with the test.
        // ignore: empty_catches
      }
    }
  });
}

Future<Process> _startTmuxControlProcess(
  String socketName,
  String tmpDir, {
  String sessionName = 'serverbox_real',
  List<String> paneCommand = const ['cat'],
}) async {
  final tmuxArgs = [
    '-L',
    socketName,
    '-u',
    '-CC',
    'new-session',
    '-s',
    sessionName,
    ...paneCommand,
  ];
  final environment = {
    ...Platform.environment,
    'TMUX_TMPDIR': tmpDir,
    // A test can itself run beneath tmux; the nested-session marker would make
    // this independent server look like a nested client.
    'TMUX': '',
    'TMUX_PANE': '',
    'TERM': 'xterm-256color',
  };
  if (Platform.isMacOS) {
    return Process.start('/usr/bin/script', [
      '-q',
      '/dev/null',
      'tmux',
      ...tmuxArgs,
    ], environment: environment);
  }
  final shellCommand = [
    'tmux',
    ...tmuxArgs,
  ].map((arg) => "'${arg.replaceAll("'", r"'\''")}'").join(' ');
  return Process.start('script', [
    '-q',
    '-c',
    shellCommand,
    '/dev/null',
  ], environment: environment);
}

final class _PtyShellSession implements ShellSession {
  final Process _process;

  _PtyShellSession(this._process);

  @override
  Stream<Uint8List>? get stdout => _process.stdout.cast<Uint8List>();

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _process.exitCode.then((_) {});

  @override
  void write(List<int> data) => _process.stdin.add(data);

  @override
  void resizeTerminal(int width, int height) {}

  @override
  void close() => _process.kill();
}
