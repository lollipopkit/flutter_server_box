import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';

void main() {
  test('parses the legacy default home tabs without recurring migration', () {
    final tabs = AppTab.parseAppTabsFromObj([
      'server',
      'ssh',
      'file',
      'snippet',
    ]);

    expect(tabs, [AppTab.server, AppTab.ssh, AppTab.file, AppTab.snippet]);
  });

  test('preserves an existing Agent tab without duplication', () {
    final tabs = AppTab.parseAppTabsFromObj([
      'server',
      'ssh',
      'file',
      'snippet',
      'agent',
    ]);

    expect(tabs, AppTab.values);
    expect(tabs.where((tab) => tab == AppTab.agent), hasLength(1));
  });

  test('preserves an intentionally customized home tab list', () {
    final tabs = AppTab.parseAppTabsFromObj(['server', 'ssh']);

    expect(tabs, [AppTab.server, AppTab.ssh]);
  });

  test('uses defaults for null and empty tab values', () {
    expect(AppTab.parseAppTabsFromObj(null), AppTab.values);
    expect(AppTab.parseAppTabsFromObj(const []), AppTab.values);
  });

  test('uses non-null defaults when every stored tab name is unknown', () {
    expect(AppTab.parseAppTabsFromObj(['unknown']), AppTab.values);
  });
}
