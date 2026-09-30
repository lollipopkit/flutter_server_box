import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/scope.dart';

TerminalHost _host(String name) => TerminalHost(
  serverName: name,
  run: (_) => throw UnimplementedError(),
  insert: (_) {},
  screen: () => name,
  cancel: () async {},
);

void main() {
  test('a second terminal of a server does not take the first one away', () {
    final a = _host('a'), b = _host('b');
    final removeA = TerminalHosts.register('srv', a);
    final removeB = TerminalHosts.register('srv', b);
    expect(TerminalHosts.of('srv'), same(b), reason: 'the newest answers');

    removeB();
    expect(TerminalHosts.of('srv'), same(a), reason: 'closing it hands back to the one still open');

    removeB();
    expect(TerminalHosts.of('srv'), same(a), reason: 'removing twice removes nothing else');

    removeA();
    expect(TerminalHosts.of('srv'), isNull);
  });

  test('closing the older one keeps the newer', () {
    final a = _host('a'), b = _host('b');
    final removeA = TerminalHosts.register('srv2', a);
    final removeB = TerminalHosts.register('srv2', b);
    removeA();
    expect(TerminalHosts.of('srv2'), same(b));
    removeB();
  });
}
