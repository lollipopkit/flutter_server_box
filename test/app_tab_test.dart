import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';

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

  test('names one tab twice and gets it once, in the order it first appeared', () {
    // The home page indexes its pages and its nav bar by position, so a repeat
    // puts the same page on screen twice and leaves "which position is
    // Terminal" without an answer — which is also what the reorder handler
    // asks when the set changes under it.
    final tabs = AppTab.parseAppTabsFromObj([
      'ssh',
      'server',
      'ssh',
      'file',
      'server',
    ]);

    expect(tabs, [AppTab.ssh, AppTab.server, AppTab.file]);
  });

  test('and mixes the ways a tab can be named without repeating it', () {
    // A record written by a build that stored indices, merged with one that
    // stored names: the same tab, said two ways.
    expect(
      AppTab.parseAppTabsFromObj(['server', AppTab.server.index, AppTab.server]),
      [AppTab.server],
    );
  });

  test('offers Agent when only the legacy home tabs are selected', () {
    final available = availableHomeTabs(const [
      AppTab.server,
      AppTab.ssh,
      AppTab.file,
      AppTab.snippet,
    ]);

    expect(available, [AppTab.agent]);
  });

  group('reorderHomeTabs', () {
    // [server, file] | separator at 2 | [ssh, snippet, agent]
    const enabled = [AppTab.server, AppTab.file];
    const disabled = [AppTab.ssh, AppTab.snippet, AppTab.agent];

    test('dragging past the separator enables a tab', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 3,
        newIndex: 1,
      );

      expect(next?.enabled, [AppTab.server, AppTab.ssh, AppTab.file]);
      expect(next?.disabled, [AppTab.snippet, AppTab.agent]);
    });

    test('dragging under the separator disables a tab', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 1,
        newIndex: 3,
      );

      expect(next?.enabled, [AppTab.server]);
      expect(next?.disabled, [AppTab.ssh, AppTab.file, AppTab.snippet, AppTab.agent]);
    });

    test('reorders within one half without changing what is enabled', () {
      final next = reorderHomeTabs(
        enabled: const [AppTab.server, AppTab.file, AppTab.ssh],
        disabled: disabled,
        oldIndex: 2,
        newIndex: 0,
      );

      expect(next?.enabled, [AppTab.ssh, AppTab.server, AppTab.file]);
      expect(next?.disabled, disabled);
    });

    test('reports the server tab leaving, for the caller to refuse', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 0,
        newIndex: 3,
      );

      expect(next?.enabled, isNot(contains(AppTab.server)));
    });

    test('moves nothing for a drag that lands where it started', () {
      expect(
        reorderHomeTabs(
          enabled: enabled,
          disabled: disabled,
          oldIndex: 1,
          newIndex: 1,
        ),
        isNull,
      );
    });

    test('moves nothing when the separator itself is dragged', () {
      expect(
        reorderHomeTabs(
          enabled: enabled,
          disabled: disabled,
          oldIndex: 2,
          newIndex: 0,
        ),
        isNull,
      );
    });
  });
}
