import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The keys a desktop expects for switching tabs and opening settings.
///
/// macOS states them in its menu bar, which is where somebody finds out they
/// exist — but `PlatformMenuBar` is a macOS API and it was also the only thing
/// *binding* them, so on Linux and Windows the same keys did nothing at all.
/// The menu bar stays for discovery; this is what makes them work.
///
/// A map rather than a widget, so which chord reaches which tab is testable
/// without pumping the home page.
Map<ShortcutActivator, VoidCallback> desktopShortcuts({
  required int tabCount,
  required void Function(int index) onTab,
  required VoidCallback onSettings,
  bool? useMeta,
}) {
  // Meta on macOS, Control elsewhere. `SingleActivator` does not fold the two,
  // and on Linux the Super key belongs to the window manager — a user pressing
  // Super+1 is asking it for something else.
  final meta = useMeta ?? Platform.isMacOS;
  SingleActivator chord(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: meta, control: !meta);

  return {
    for (var i = 0; i < tabCount && i < _digits.length; i++)
      chord(_digits[i]): () => onTab(i),
    chord(LogicalKeyboardKey.comma): onSettings,
  };
}

/// Nine, because a tenth tab would want `0` and nobody reads that as "the
/// tenth". A home with more than nine tabs is reachable by clicking.
const _digits = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];
