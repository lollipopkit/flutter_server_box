import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/terminal_platform.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:xterm/core.dart';

/// Which keyboard the terminal thinks it is being typed on.
///
/// `Terminal`'s default is `unknown`, and this app passed it for as long as it
/// had a terminal. Nothing failed: every keytab entry that distinguishes a Mac
/// simply took the other branch, so Option+Left sent `\E[1;5D` — which a shell
/// ignores — and word movement did nothing at all. Found by pressing the keys,
/// not by anything here, which is why the wiring is now asserted.
void main() {
  test('a session hands its terminal the host platform', () {
    // The wiring, which is what was missing. `Terminal()` without this is
    // `unknown`, and `unknown` is wrong everywhere rather than wrong somewhere.
    final session = TerminalSession(source: const LocalSource());

    expect(session.terminal.platform, hostTerminalPlatform);
    expect(session.terminal.platform, isNot(TerminalTargetPlatform.unknown));
  });

  // iOS is deliberately absent from its own branch below: `Keytab` matches
  // `platform == macos` exactly, and what that selects is the Apple keyboard
  // convention — Option composes a character rather than sending an escape,
  // and Option+arrow moves by word. An iPad with a hardware keyboard keeps
  // that convention, so answering `ios` would opt it out of its own keyboard.
  test('this host answers with itself', () {
    final expected = switch (true) {
      _ when Platform.isMacOS || Platform.isIOS => TerminalTargetPlatform.macos,
      _ when Platform.isAndroid => TerminalTargetPlatform.android,
      _ when Platform.isLinux => TerminalTargetPlatform.linux,
      _ when Platform.isWindows => TerminalTargetPlatform.windows,
      _ => TerminalTargetPlatform.unknown,
    };

    expect(hostTerminalPlatform, expected);
  });
}
