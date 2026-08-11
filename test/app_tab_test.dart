import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';

void main() {
  test('adds Agent when migrating the legacy default home tabs', () {
    final tabs = AppTab.parseAppTabsFromObj([
      'server',
      'ssh',
      'file',
      'snippet',
    ]);

    expect(tabs, [
      AppTab.server,
      AppTab.ssh,
      AppTab.file,
      AppTab.snippet,
      AppTab.agent,
    ]);
  });

  test('preserves an intentionally customized home tab list', () {
    final tabs = AppTab.parseAppTabsFromObj(['server', 'ssh']);

    expect(tabs, [AppTab.server, AppTab.ssh]);
  });
}
