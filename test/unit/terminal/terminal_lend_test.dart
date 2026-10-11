/// A terminal lent to a companion panel is given back only by the panel that
/// holds it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/provider/app/terminal_lend.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';

void main() {
  test('a panel letting go does not clear what another just took', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final lend = container.read(lentTerminalProvider.notifier);
    final session = TerminalSession(source: const LocalSource());
    final serverTab = Object();
    final fileTab = Object();

    // Switching from the file tab to the server tab: the server tab's panel
    // takes the terminal first, then the file tab's lets go of it.
    lend.lend(session, holder: fileTab);
    lend.lend(session, holder: serverTab);
    lend.giveBack(fileTab);
    expect(container.read(lentTerminalProvider)?.holder, same(serverTab));

    lend.giveBack(serverTab);
    expect(container.read(lentTerminalProvider), isNull);
  });
}
