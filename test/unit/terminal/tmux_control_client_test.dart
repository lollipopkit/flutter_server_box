import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/data/model/server/shell_backend.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_client.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_models.dart';
import 'package:server_box/data/ssh/tmux/tmux_control_shell_session.dart';
import 'package:server_box/data/ssh/tmux/tmux_format.dart';
import 'package:server_box/data/ssh/tmux/tmux_ids.dart';
import 'package:test/test.dart';
import 'package:xterm/core.dart';

void main() {
  group('TmuxControlClient', () {
    test('initializes state and captures the active pane', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final terminalSession = TmuxControlShellSession(client, shell);
      final output = <List<int>>[];
      terminalSession.stdout!.listen(output.add);

      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      final snapshot = client.snapshot!;
      expect(snapshot.session.id, TmuxSessionId(r'$0'));
      expect(snapshot.session.name, 'main');
      expect(snapshot.sessions, hasLength(2));
      expect(snapshot.session.windows, 2);
      expect(snapshot.windows, hasLength(2));
      expect(snapshot.activeWindowId, TmuxWindowId('@0'));
      expect(snapshot.activePaneId, TmuxPaneId('%0'));
      expect(snapshot.activeWindow!.panes, hasLength(1));
      expect(snapshot.activeWindow!.panes.single.displayName, 'shell');
      expect(
        shell.writes,
        contains(
          r"display-message -p '#{session_id}	#{q:session_name}"
          "\t#{history-limit}'",
        ),
      );
      expect(
        shell.writes,
        contains(
          r"list-windows -t '$0' -F '#{window_id}	#{window_index}	#{q:window_name}	#{window_active}'",
        ),
      );
      expect(shell.writes, contains("capture-pane -p -e -S -1000 -t '%0'"));
      final pauseAt = shell.writes.indexOf("refresh-client -A '%0:pause'");
      final captureAt = shell.writes.indexOf(
        "capture-pane -p -e -S -1000 -t '%0'",
      );
      final continueAt = shell.writes.indexOf(
        "refresh-client -A '%0:continue'",
      );
      expect(pauseAt, greaterThanOrEqualTo(0));
      expect(captureAt, greaterThan(pauseAt));
      expect(continueAt, greaterThan(captureAt));

      expect(output, isNotEmpty);
      final captured = utf8.decode(output.last);
      expect(captured, contains('\x1bc'));
      expect(captured, contains('main prompt'));

      terminalSession.close();
    });

    test(
      'capture output restores rows by absolute position and cursor',
      () async {
        final shell = _FakeTmuxShell();
        shell.captureOutput = 'first row\nsecond row\n\nthird row';
        final client = TmuxControlClient(shell);
        final output = <List<int>>[];
        final subscription = client.paneOutput.listen(
          (event) => output.add(event.data),
        );

        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        final captured = utf8.decode(output.last);
        expect(captured, contains('\x1bc'));
        expect(
          captured,
          contains(
            '\x1b[1;1H%0 first row'
            '\x1b[2;1Hsecond row'
            '\x1b[3;1H'
            '\x1b[4;1Hthird row',
          ),
        );
        expect(captured.endsWith('\x1b[3;6H'), isTrue);
        expect(captured, isNot(contains('\n')));

        final terminal = Terminal();
        terminal.write(captured);
        expect(terminal.buffer.cursorX, 5);
        expect(terminal.buffer.cursorY, 2);
        expect(
          terminal.buffer.getText(
            BufferRangeLine(CellOffset(0, 0), CellOffset(80, 4)),
          ),
          contains('first row'),
        );
        expect(
          terminal.buffer.getText(
            BufferRangeLine(CellOffset(0, 0), CellOffset(80, 4)),
          ),
          contains('second row'),
        );
        expect(
          terminal.buffer.getText(
            BufferRangeLine(CellOffset(0, 0), CellOffset(80, 4)),
          ),
          contains('third row'),
        );

        await subscription.cancel();
        await client.dispose();
        shell.close();
      },
    );

    test('replays tmux history into xterm scrollback', () async {
      final shell = _FakeTmuxShell();
      shell.paneHeight = 5;
      shell.historyLimit = 12;
      shell.captureOutput = [
        for (var i = 0; i < 12; i++) 'history $i',
        for (var i = 0; i < 5; i++) 'screen $i',
      ].join('\n');
      final client = TmuxControlClient(shell, maxScrollbackLines: 100);
      final output = <List<int>>[];
      final subscription = client.paneOutput.listen(
        (event) => output.add(event.data),
      );

      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      expect(shell.writes, contains("capture-pane -p -e -S -12 -t '%0'"));
      final terminal = Terminal(maxLines: 100)..resize(80, 5);
      terminal.write(utf8.decode(output.last));

      expect(terminal.buffer.height, 17);
      expect(terminal.buffer.lines[0].getText(), '%0 history 0');
      for (var i = 1; i < 12; i++) {
        expect(terminal.buffer.lines[i].getText(), 'history $i');
      }
      for (var i = 0; i < 5; i++) {
        expect(terminal.buffer.lines[12 + i].getText(), 'screen $i');
      }
      expect(terminal.buffer.cursorX, 5);
      expect(terminal.buffer.cursorY, 2);

      await subscription.cancel();
      await client.dispose();
      shell.close();
    });

    test('uses the smaller of tmux and local scrollback limits', () async {
      final shell = _FakeTmuxShell();
      shell.paneHeight = 5;
      shell.historyLimit = 100000;
      shell.captureOutput = 'history\nscreen';
      final client = TmuxControlClient(shell, maxScrollbackLines: 7);
      final output = <List<int>>[];
      final subscription = client.paneOutput.listen(
        (event) => output.add(event.data),
      );

      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      expect(shell.writes, contains("capture-pane -p -e -S -7 -t '%0'"));

      await subscription.cancel();
      await client.dispose();
      shell.close();
    });

    test(
      'queries pane modes and restores them before captured screen content',
      () async {
        final shell = _FakeTmuxShell();
        shell.paneModeOutput =
            '1\t3\t4\t1\t0\tblock\t0\t0\t0\t1\t1\t1\t1'
            '\t0\t1\t1\t0\t1\t0\tVT10x';
        shell.captureOutput = 'screen';
        final client = TmuxControlClient(shell);
        final output = <List<int>>[];
        final subscription = client.paneOutput.listen(
          (event) => output.add(event.data),
        );

        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        final mode = client.snapshot!.mode;
        expect(mode.alternateScreen, isTrue);
        expect(mode.alternateSavedX, 3);
        expect(mode.alternateSavedY, 4);
        expect(mode.applicationCursorKeys, isTrue);
        expect(mode.applicationKeypad, isTrue);
        expect(mode.bracketedPaste, isTrue);
        expect(mode.mouseButton, isTrue);
        expect(mode.mouseSgr, isTrue);

        final captured = utf8.decode(output.last);
        expect(captured, contains('\x1bc'));
        expect(captured, contains('\x1b[?1h\x1b[?6l\x1b[?7h\x1b[?25h'));
        expect(captured, contains('\x1b[?2004h'));
        expect(captured, contains('\x1b[?1002h\x1b[?1006h'));
        expect(captured, isNot(contains('\x1b[?1000h')));
        expect(captured, contains('\x1b='));
        expect(captured, contains('\x1b[5;4H\x1b[?1049h'));
        expect(
          captured.indexOf('\x1b[?1049h'),
          lessThan(captured.indexOf('screen')),
        );
        expect(captured.endsWith('\x1b[3;6H'), isTrue);

        final terminal = Terminal();
        terminal.write(captured);
        expect(terminal.cursorKeysMode, isTrue);
        expect(terminal.appKeypadMode, isTrue);
        expect(terminal.bracketedPasteMode, isTrue);
        expect(terminal.isUsingAltBuffer, isTrue);

        await subscription.cancel();
        await client.dispose();
        shell.close();
      },
    );

    test('forwards terminal bytes as hexadecimal send-keys commands', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      final terminalSession = TmuxControlShellSession(client, shell);
      terminalSession.write(utf8.encode('ls\r'));

      expect(shell.writes, contains("send-keys -t '%0' -H 6c 73 0d"));
      await _pumpEventQueue();
      terminalSession.close();
    });

    test('the shell adapter renders only the active pane stream', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final terminalSession = TmuxControlShellSession(client, shell);
      final output = <String>[];
      final subscription = terminalSession.stdout!.listen(
        (data) => output.add(utf8.decode(data, allowMalformed: true)),
      );
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.emit('%output %3 inactive\n%output %0 active\n');
      await _pumpEventQueue();

      expect(output.join(), contains('active'));
      expect(output.join(), isNot(contains('inactive')));
      await subscription.cancel();
      terminalSession.close();
    });

    test('resize targets the active window for the control client', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      final terminalSession = TmuxControlShellSession(client, shell);
      terminalSession.resizeTerminal(44, 15);
      await _pumpEventQueue();

      expect(shell.writes, contains('refresh-client -C @0:44x15'));
      terminalSession.close();
    });

    test('resize before tmux 3.3 sizes the client, not a window', () async {
      final shell = _FakeTmuxShell()..version = '3.2a';
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      final terminalSession = TmuxControlShellSession(client, shell);
      terminalSession.resizeTerminal(44, 15);
      await _pumpEventQueue();

      expect(shell.writes, contains('refresh-client -C 44x15'));
      expect(shell.writes, isNot(contains('refresh-client -C @0:44x15')));
      terminalSession.close();
    });

    test('tmux before 3.2 captures without pausing pane output', () async {
      final shell = _FakeTmuxShell()..version = '3.0a';
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      expect(shell.writes, contains("capture-pane -p -e -S -1000 -t '%0'"));
      expect(
        shell.writes.where((command) => command.startsWith('refresh-client -A')),
        isEmpty,
      );
      await client.dispose();
      shell.close();
    });

    test('a refresh requested during another waits for its own', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize(captureActivePane: false);
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      int count(String prefix) =>
          shell.writes.where((command) => command.startsWith(prefix)).length;
      final refreshesBefore = count("display-message -p '#{session_id}");

      final first = client.refreshState();
      final second = client.refreshState(captureActivePane: true);
      final third = client.refreshState();
      await second;

      // The second and third join one follow-up, which keeps the capture.
      expect(count("display-message -p '#{session_id}"), refreshesBefore + 2);
      expect(count('capture-pane'), 1);
      await first;
      await third;
      await client.dispose();
      shell.close();
    });

    test('selects a window through the same CC client', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.activeWindowId = '@1';
      await client.selectWindow(TmuxWindowId('@1'));

      expect(shell.writes, contains("select-window -t '@1'"));
      expect(client.snapshot!.activeWindowId, TmuxWindowId('@1'));
      expect(client.snapshot!.activePaneId, TmuxPaneId('%3'));
      expect(shell.writes, contains("capture-pane -p -e -S -1000 -t '%3'"));
      await client.dispose();
      shell.close();
    });

    test('tracks and switches panes in the active window', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.splitPanes = true;
      await client.refreshState();

      final panes = client.snapshot!.activeWindow!.panes;
      expect(panes, hasLength(2));
      expect(client.snapshot!.activePaneId, TmuxPaneId('%0'));
      expect(
        shell.writes,
        contains(
          'list-panes -t \'@0\' -F \'#{pane_id}\t#{pane_index}\t#{pane_active}'
          '\t#{q:pane_title}\t#{q:pane_current_command}'
          '\t#{cursor_x}\t#{cursor_y}\t#{pane_height}\'',
        ),
      );

      await client.selectPane(TmuxPaneId('%3'));

      expect(shell.writes, contains("select-pane -t '%3'"));
      expect(client.snapshot!.activePaneId, TmuxPaneId('%3'));
      expect(client.snapshot!.activeWindow!.panes.last.active, isTrue);
      expect(shell.writes, contains("capture-pane -p -e -S -1000 -t '%3'"));
      await client.dispose();
      shell.close();
    });

    test('closes a pane and refreshes the remaining pane', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.splitPanes = true;
      await client.refreshState();
      await client.closePane(TmuxPaneId('%0'));

      expect(shell.writes, contains("kill-pane -t '%0'"));
      expect(client.snapshot!.activeWindow!.panes, hasLength(1));
      expect(client.snapshot!.activePaneId, TmuxPaneId('%3'));
      await client.dispose();
      shell.close();
    });

    test(
      'closing the last pane does not refresh the departing client',
      () async {
        final shell = _FakeTmuxShell();
        final client = TmuxControlClient(shell);
        client.onStateError = (_) =>
            fail('notification refresh should not run');
        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        shell.onlyOneWindow = true;
        await client.refreshState();
        await client.closePane(TmuxPaneId('%0'));

        expect(shell.writes, contains("kill-pane -t '%0'"));
        final killAt = shell.writes.indexOf("kill-pane -t '%0'");
        expect(
          shell.writes
              .skip(killAt + 1)
              .any((command) => command.startsWith('display-message')),
          isFalse,
        );
        await client.dispose();
        shell.close();
      },
    );

    test('switches and creates sessions with stable ids', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      await client.switchSession(TmuxSessionId(r'$1'));
      expect(shell.writes, contains("switch-client -t '\$1'"));
      expect(client.snapshot!.session.id, TmuxSessionId(r'$1'));

      final id = await client.createSession("work 'quotes'");
      expect(id, TmuxSessionId(r'$1'));
      expect(
        shell.writes,
        contains(
          r"new-session -d -P -F '#{session_id}' -s 'work '\''quotes'\'''",
        ),
      );
      expect(client.snapshot!.session.id, TmuxSessionId(r'$1'));
      await client.dispose();
      shell.close();
    });

    test('follows asynchronous window changes', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.activeWindowId = '@1';
      shell.emit(
        r'%session-window-changed $0 @1'
        '\n',
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _pumpEventQueue();

      expect(client.snapshot!.activeWindowId, TmuxWindowId('@1'));
      expect(client.snapshot!.activePaneId, TmuxPaneId('%3'));
      expect(shell.writes, contains("capture-pane -p -e -S -1000 -t '%3'"));

      final capturesBefore = shell.writes
          .where((command) => command == "capture-pane -p -e -S -1000 -t '%3'")
          .length;
      shell.emit('%layout-change @1 ca2a,80x24,0,0,0 80x24,0,0,0 *\n');
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await _pumpEventQueue();

      expect(
        shell.writes
            .where(
              (command) => command == "capture-pane -p -e -S -1000 -t '%3'",
            )
            .length,
        capturesBefore + 1,
      );
      await client.dispose();
      shell.close();
    });

    test('creates a window with tmux command quoting', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.nextWindowId = '@2';
      final id = await client.newWindow(name: "work 'quotes'");

      expect(id, TmuxWindowId('@2'));
      expect(
        shell.writes,
        contains(
          r"new-window -P -F '#{window_id}' -t '$0' -n 'work '\''quotes'\'''",
        ),
      );
      await client.dispose();
      shell.close();
    });

    test(
      'closing the last window does not refresh the departing client',
      () async {
        final shell = _FakeTmuxShell();
        final client = TmuxControlClient(shell);
        client.onStateError = (_) =>
            fail('notification refresh should not run');
        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        shell.onlyOneWindow = true;
        await client.refreshState();
        await client.closeWindow(TmuxWindowId('@0'));

        expect(shell.writes, contains("kill-window -t '@0'"));
        final killAt = shell.writes.indexOf("kill-window -t '@0'");
        expect(
          shell.writes
              .skip(killAt + 1)
              .any((command) => command.startsWith('display-message')),
          isFalse,
        );
        await client.dispose();
        shell.close();
      },
    );

    test(
      'closing the last window tolerates exit before command result',
      () async {
        final shell = _FakeTmuxShell()..onlyOneWindow = true;
        final client = TmuxControlClient(shell);
        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        shell.exitBeforeNextCommandResult = true;
        await client.closeWindow(TmuxWindowId('@0'));

        expect(shell.writes, contains("kill-window -t '@0'"));
        await client.dispose();
        shell.close();
      },
    );

    test(
      'closing the last pane tolerates exit before command result',
      () async {
        final shell = _FakeTmuxShell()..onlyOneWindow = true;
        final client = TmuxControlClient(shell);
        final initialized = client.initialize();
        shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
        await initialized;
        await _pumpEventQueue();

        shell.exitBeforeNextCommandResult = true;
        await client.closePane(TmuxPaneId('%0'));

        expect(shell.writes, contains("kill-pane -t '%0'"));
        await client.dispose();
        shell.close();
      },
    );

    test('a transport lost before kill-window answers is an error', () async {
      final shell = _FakeTmuxShell()..onlyOneWindow = true;
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.dropBeforeNextCommandResult = true;
      await expectLater(client.closeWindow(TmuxWindowId('@0')), throwsA(anything));
      await client.dispose();
    });

    test('a protocol overflow closes the shell under the client', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      bool? cleanExit;
      client.onClosed = (clean) => cleanExit = clean;
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.emit('x' * (65 * 1024));
      await _pumpEventQueue();

      expect(cleanExit, isFalse);
      expect(shell.isClosed, isTrue);
    });

    test('detaches the current client', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      await client.detach();

      expect(shell.writes, contains('detach-client'));
      await client.dispose();
      shell.close();
    });

    test('detach tolerates exit before command result', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.exitBeforeNextCommandResult = true;
      await client.detach();

      expect(shell.writes, contains('detach-client'));
      await client.dispose();
      shell.close();
    });

    test('reports tmux exit separately from a transport close', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      bool? cleanExit;
      client.onClosed = (value) => cleanExit = value;
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      await _pumpEventQueue();

      shell.emit('%exit\n');
      await _pumpEventQueue();

      expect(cleanExit, isTrue);
      shell.close();
    });

    test('fails command results as TmuxControlCommandException', () async {
      final shell = _FakeTmuxShell();
      final client = TmuxControlClient(shell);
      final initialized = client.initialize();
      shell.emit('\x1bP1000p%begin 1 100 1\n%end 1 100 1\n');
      await initialized;
      shell.errorNextCommand = true;

      await expectLater(
        client.runRequired('unknown-command'),
        throwsA(isA<TmuxControlCommandException>()),
      );
      await client.dispose();
      shell.close();
    });
  });

  group('tmux format field helpers', () {
    test('reads the tmux version as major and minor', () {
      expect(parseTmuxVersion('3.4'), 304);
      expect(parseTmuxVersion('3.2a'), 302);
      expect(parseTmuxVersion('next-3.6'), 306);
      expect(parseTmuxVersion('master'), 0);
      expect(parseTmuxVersion(''), 0);
    });

    test('splits only unescaped tabs', () {
      expect(splitTmuxFields(r'$0	has\ space	1'), [r'$0', r'has\ space', '1']);
    });

    test('unescapes q format fields', () {
      expect(unescapeTmuxField(r'has\ space'), 'has space');
      expect(unescapeTmuxField(r"quote\'name"), "quote'name");
      expect(unescapeTmuxField(r'unicode\344\275\240'), 'unicode你');
    });
  });
}

Future<void> _pumpEventQueue() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

final class _FakeTmuxShell implements ShellSession {
  final _stdout = StreamController<Uint8List>();
  final _done = Completer<void>();
  final writes = <String>[];
  String activeWindowId = '@0';
  String activePaneId = '%0';
  String sessionId = r'$0';
  String sessionName = 'main';
  String version = '3.4';
  int historyLimit = 100000;
  String nextWindowId = '@2';
  bool splitPanes = false;
  bool errorNextCommand = false;
  bool exitBeforeNextCommandResult = false;
  bool dropBeforeNextCommandResult = false;
  bool onlyOneWindow = false;
  String captureOutput = 'main prompt';
  int paneHeight = 24;
  String paneModeOutput =
      '0\t0\t0\t1\t0\tdefault\t0\t0\t0\t1\t0\t0\t0'
      '\t0\t0\t0\t0\t0\t0\tVT10x';
  bool _closed = false;
  bool get isClosed => _closed;

  _FakeTmuxShell();

  @override
  Stream<Uint8List>? get stdout => _stdout.stream;

  @override
  Stream<Uint8List>? get stderr => null;

  @override
  Future<void> get done => _done.future;

  @override
  void write(List<int> data) {
    final command = utf8.decode(data).trim();
    if (command.isEmpty) return;
    writes.add(command);
    if (errorNextCommand) {
      errorNextCommand = false;
      emit('%begin 2 101 1\nparse error\n%error 2 101 1\n');
      return;
    }
    if (dropBeforeNextCommandResult) {
      dropBeforeNextCommandResult = false;
      close();
      return;
    }
    if (exitBeforeNextCommandResult) {
      exitBeforeNextCommandResult = false;
      emit('%exit\n');
      return;
    }
    _answer(command);
  }

  @override
  void resizeTerminal(int width, int height) {}

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_stdout.close());
    _done.complete();
  }

  void emit(String data) {
    _stdout.add(utf8.encode(data));
  }

  void _answer(String command) {
    if (command.startsWith('display-message')) {
      if (command.contains('#{version}')) {
        _result(version);
        return;
      }
      if (command.contains('alternate_on')) {
        _result(paneModeOutput);
        return;
      }
      _result('$sessionId\t$sessionName\t$historyLimit');
      return;
    }
    if (command.startsWith('list-sessions')) {
      _result(
        r'$0	main	2	1'
        '\n'
        r'$1	work	1	0',
      );
      return;
    }
    if (command.startsWith('list-windows')) {
      if (onlyOneWindow) {
        _result('@0\t0\tshell\t1');
      } else if (activeWindowId == '@1') {
        _result('@0\t0\tshell\t0\n@1\t1\tlogs\t1');
      } else {
        _result('@0\t0\tshell\t1\n@1\t1\tlogs\t0');
      }
      return;
    }
    if (command.startsWith('list-panes')) {
      if (activeWindowId == '@1') {
        _result('%3\t0\t1\tlogs\tcat\t0\t0\t$paneHeight');
      } else if (splitPanes) {
        _result(
          '%0\t0\t${activePaneId == '%0' ? 1 : 0}\tshell\tzsh\t5\t2\t$paneHeight\n'
          '%3\t1\t${activePaneId == '%3' ? 1 : 0}\tlogs\tcat\t0\t0\t$paneHeight',
        );
      } else {
        _result('$activePaneId\t0\t1\tshell\tzsh\t5\t2\t$paneHeight');
      }
      return;
    }
    if (command.startsWith('capture-pane')) {
      final pane = command.contains('%3') ? '%3' : '%0';
      _result('$pane $captureOutput');
      return;
    }
    if (command.startsWith('new-window')) {
      _result(nextWindowId);
      activeWindowId = nextWindowId;
      return;
    }
    if (command.startsWith('select-window')) {
      activeWindowId = command.contains('@1') ? '@1' : '@0';
      activePaneId = activeWindowId == '@1' ? '%3' : '%0';
      _result('');
      return;
    }
    if (command.startsWith('select-pane')) {
      activePaneId = command.contains('%3') ? '%3' : '%0';
      _result('');
      return;
    }
    if (command.startsWith('kill-pane')) {
      if (splitPanes) {
        splitPanes = false;
        activePaneId = '%3';
      }
      _result('');
      return;
    }
    if (command.startsWith('new-session')) {
      sessionId = r'$1';
      sessionName = 'work';
      _result(sessionId);
      return;
    }
    if (command.startsWith('switch-client')) {
      sessionId = command.contains(r'$1') ? r'$1' : r'$0';
      sessionName = sessionId == r'$1' ? 'work' : 'main';
      _result('');
      return;
    }
    if (command.startsWith('kill-window')) {
      _result('');
      return;
    }
    _result('');
  }

  void _result(String output) {
    final id = writes.length;
    final lines = output.isEmpty ? '' : '$output\n';
    emit('%begin 2 $id 1\n$lines%end 2 $id 1\n');
  }
}
