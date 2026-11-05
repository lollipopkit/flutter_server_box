/// `TermSessionRegistry`: the sessions the notification and the Live Activity
/// show, and whether a change is one worth telling them about.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/terminal/session_manager.dart';
import 'package:xterm/core.dart' show ProgramState;

TermSessionInfo _info(String id) => TermSessionInfo(
  id: id,
  title: 'srv-$id',
  subtitle: '',
  startTimeMs: 0,
  status: TermSessionStatus.connecting,
);

void main() {
  late TermSessionRegistry registry;

  setUp(() {
    registry = TermSessionRegistry()
      ..add(_info('a'), () {}, setAsActive: true)
      ..add(_info('b'), () {});
  });

  test('a status or program that did not change is no change', () {
    expect(registry.updateStatus('a', TermSessionStatus.connecting), isFalse);
    expect(registry.updateStatus('a', TermSessionStatus.connected), isTrue);
    expect(registry.entries['a']!.info.status, TermSessionStatus.connected);

    expect(registry.updateProgram('a', ProgramState.blocked, 'build'), isTrue);
    expect(registry.updateProgram('a', ProgramState.blocked, 'build'), isFalse);
    expect(registry.updateStatus('missing', TermSessionStatus.connected), isFalse);
  });

  test('the most urgent program is the lowest state, among those with words', () {
    expect(registry.mostUrgentProgram, isNull);
    registry
      ..updateProgram('a', ProgramState.values.last, 'later')
      ..updateProgram('b', ProgramState.values.first, null);
    expect(registry.mostUrgentProgram?.info.id, 'a', reason: 'b says nothing');

    registry.updateProgram('b', ProgramState.values.first, 'now');
    expect(registry.mostUrgentProgram?.info.id, 'b');
  });

  test('removing the session on screen puts the first one left there', () {
    registry.remove('a');
    expect(registry.activeId, 'b');
    registry.remove('b');
    expect(registry.activeId, isNull);
    expect(registry.entries, isEmpty);
  });

  test('which session is on screen, and whether its terminal is shown', () {
    expect(registry.setActive('b', hasTerminal: false), isTrue);
    expect(registry.activeId, 'b');
    expect(registry.entries['b']!.hasTerminalUI, isFalse);

    expect(registry.hideTerminal('a'), isTrue);
    expect(registry.activeId, 'b', reason: 'hiding another one moves nothing');
    expect(registry.hideTerminal('b'), isTrue);
    expect(registry.activeId, isNull);

    expect(registry.setActive('missing'), isFalse);
    expect(registry.hideTerminal('missing'), isFalse);
  });

  test('clear forgets every session and the one on screen', () {
    registry.clear();
    expect(registry.entries, isEmpty);
    expect(registry.activeId, isNull);
  });
}
