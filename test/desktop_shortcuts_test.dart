import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/desktop_shortcuts.dart';

/// The bindings, with their keys typed.
///
/// `SingleActivator` has no value equality — `Shortcuts` matches by calling
/// `accepts()`, not by looking a chord up in a map — so these are read rather
/// than searched for.
List<({SingleActivator chord, VoidCallback run})> chords({
  int tabCount = 5,
  void Function(int)? onTab,
  VoidCallback? onSettings,
  required bool meta,
}) {
  final bindings = desktopShortcuts(
    tabCount: tabCount,
    onTab: onTab ?? (_) {},
    onSettings: onSettings ?? () {},
    useMeta: meta,
  );
  return [
    for (final entry in bindings.entries)
      (chord: entry.key as SingleActivator, run: entry.value),
  ];
}

void main() {
  test('one chord per tab, in order', () {
    final picked = <int>[];

    for (final binding in chords(onTab: picked.add, meta: true)) {
      if (binding.chord.trigger == LogicalKeyboardKey.comma) continue;
      binding.run();
    }

    expect(picked, [0, 1, 2, 3, 4]);
  });

  test('digit1 through digit5 for five tabs', () {
    final triggers = [
      for (final binding in chords(tabCount: 5, meta: true))
        if (binding.chord.trigger != LogicalKeyboardKey.comma)
          binding.chord.trigger,
    ];

    expect(triggers, [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ]);
  });

  test('meta on macOS, control everywhere else', () {
    // Not folded together: on Linux the Super key belongs to the window
    // manager, and binding it would take a chord meant for that.
    expect(
      chords(meta: true).every((b) => b.chord.meta && !b.chord.control),
      isTrue,
    );
    expect(
      chords(meta: false).every((b) => b.chord.control && !b.chord.meta),
      isTrue,
    );
  });

  test('settings has its own chord, beside the tabs', () {
    var opened = 0;

    final comma = chords(
      onSettings: () => opened++,
      meta: true,
    ).singleWhere((b) => b.chord.trigger == LogicalKeyboardKey.comma);
    comma.run();

    expect(opened, 1);
  });

  test('no more than nine, whatever the tab count', () {
    // A tenth would want `0`, and nobody reads that as "the tenth".
    expect(chords(tabCount: 12, meta: true), hasLength(10));
  });

  test('a short tab list binds only what it has', () {
    expect(chords(tabCount: 2, meta: true), hasLength(3));
  });
}
