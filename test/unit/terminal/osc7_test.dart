/// OSC 7, a shell's report of where it is.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';

void main() {
  test('the host and the decoded path of a file URL', () {
    expect(osc7Report('file://box/var/log'), (host: 'box', path: '/var/log'));
    expect(osc7Report('file:///srv/a%20b'), (host: '', path: '/srv/a b'));
    expect(osc7Report('file://box/%E6%97%A5%E5%BF%97')?.path, '/日志');
  });

  test('anything else is no answer', () {
    expect(osc7Report('kitty-shell-cwd://box/tmp'), isNull);
    expect(osc7Report('file://box'), isNull);
    expect(osc7Report('file://box/%E6'), isNull);
    expect(osc7Report(''), isNull);
  });

  test('a session follows what its shell reports', () {
    final session = TerminalSession(source: const LocalSource());
    session.terminal.write('\x1b]7;file://box/var/log\x07');
    expect(session.cwd.value, '/var/log');
    // A `;` is a separator to the parser and part of the path here.
    session.terminal.write('\x1b]7;file://box/a;b\x1b\\');
    expect(session.cwd.value, '/a;b');
    session.terminal.write('\x1b]7;nonsense\x07');
    expect(session.cwd.value, '/a;b');
  });

  test('a report from another host is an ssh inside the terminal', () {
    final session = TerminalSession(source: const LocalSource());
    session.terminal.write('\x1b]7;file://a/home/u\x07');
    session.terminal.write('\x1b]7;file://b/srv\x07');
    expect(session.cwd.value, '/home/u');
    session.terminal.write('\x1b]7;file://a/tmp\x07');
    expect(session.cwd.value, '/tmp');
  });
}
