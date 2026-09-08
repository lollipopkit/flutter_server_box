import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/view/page/setting/entries/home_tabs.dart';

void main() {
  group('the default order', () {
    test('is the bar, and the rest are behind "more"', () {
      // The list *is* the bar now, so it is a subset rather than everything.
      expect(AppTab.defaultOrder, [
        AppTab.server,
        AppTab.ssh,
        AppTab.file,
        AppTab.agent,
      ]);
      // Snippets are a library rather than a place, a benchmark is a quarter
      // of an hour started deliberately, and updates are read when somebody
      // goes looking — none is wanted a tap away.
      expect(AppTab.overflowOf(AppTab.defaultOrder), [
        AppTab.snippet,
        AppTab.benchmark,
        AppTab.pkg,
      ]);
    });

    test('every tab is reachable, in the bar or behind more', () {
      // Anything in neither is a tab a fresh install could not reach at all.
      expect(
        {...AppTab.defaultOrder, ...AppTab.overflowOf(AppTab.defaultOrder)},
        AppTab.values.toSet(),
      );
    });

    test('turning every tab on leaves nothing behind "more"', () {
      // Which is what removes the "more" destination — and why the settings
      // one beside it is pinned rather than being an `AppTab`: it is the only
      // way into the settings on a phone, and "more" used to carry it.
      expect(AppTab.overflowOf(AppTab.values), isEmpty);
      expect(availableHomeTabs(AppTab.values.map((e) => e.name)), isEmpty);
    });

    /// The declaration order is the `@HiveField` index and what an `int` in a
    /// stored record resolves against, so it is not free to follow the bar.
    test('is allowed to differ from the declaration order', () {
      expect(AppTab.defaultOrder, isNot(AppTab.values));
      expect(AppTab.server.index, 0);
      expect(AppTab.snippet.index, 3);
      expect(AppTab.agent.index, 4);
    });
  });

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

    // The stored order, kept as it was -- not the default, which the two
    // happen to differ from since Agent moved ahead of snippets.
    expect(tabs, [
      AppTab.server,
      AppTab.ssh,
      AppTab.file,
      AppTab.snippet,
      AppTab.agent,
    ]);
    expect(tabs.where((tab) => tab == AppTab.agent), hasLength(1));
  });

  test('preserves an intentionally customized home tab list', () {
    final tabs = AppTab.parseAppTabsFromObj(['server', 'ssh']);

    expect(tabs, [AppTab.server, AppTab.ssh]);
  });

  test('uses defaults for null and empty tab values', () {
    expect(AppTab.parseAppTabsFromObj(null), AppTab.defaultOrder);
    expect(AppTab.parseAppTabsFromObj(const []), AppTab.defaultOrder);
  });

  test('uses non-null defaults when every stored tab name is unknown', () {
    expect(AppTab.parseAppTabsFromObj(['unknown']), AppTab.defaultOrder);
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

  /// Ids, not enum cases, since m023: a plugin's tab is not a case of `AppTab`
  /// and a page that listed only those would leave one permanently behind
  /// "more" with no way to move it into the bar.
  test('offers every arrangeable tab the stored list does not name', () {
    // The legacy four. Everything added since has to be reachable from here,
    // or an install that stored that list could never turn one on.
    final available = availableHomeTabs(const [
      'server',
      'ssh',
      'file',
      'snippet',
    ]);

    expect(available, ['agent', 'benchmark', 'pkg']);
  });

  group('reorderHomeTabs', () {
    // [server, file] | separator at 2 | [ssh, snippet, agent]
    const enabled = ['server', 'file'];
    const disabled = ['ssh', 'snippet', 'agent'];

    test('dragging past the separator enables a tab', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 3,
        newIndex: 1,
      );

      expect(next?.enabled, ['server', 'ssh', 'file']);
      expect(next?.disabled, ['snippet', 'agent']);
    });

    test('dragging under the separator disables a tab', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 1,
        newIndex: 3,
      );

      expect(next?.enabled, ['server']);
      expect(next?.disabled, ['ssh', 'file', 'snippet', 'agent']);
    });

    test('reorders within one half without changing what is enabled', () {
      final next = reorderHomeTabs(
        enabled: const ['server', 'file', 'ssh'],
        disabled: disabled,
        oldIndex: 2,
        newIndex: 0,
      );

      expect(next?.enabled, ['ssh', 'server', 'file']);
      expect(next?.disabled, disabled);
    });

    test('reports the server tab leaving, for the caller to refuse', () {
      final next = reorderHomeTabs(
        enabled: enabled,
        disabled: disabled,
        oldIndex: 0,
        newIndex: 3,
      );

      expect(next?.enabled, isNot(contains('server')));
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
