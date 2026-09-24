import 'dart:ui' show Brightness;

import 'package:server_box/data/model/app/tab.dart';

/// The icon set a package draws with, spelled as its manifest spells it.
///
/// Stored by name and never by index, like every enum here: the value is
/// written into the settings and outlives the build that wrote it, so a case
/// inserted in the middle would silently change what an install means.
enum IconStyle {
  /// The icons the app ships.
  classic,

  /// MingCute, which a package carrying its own icon files provides.
  mingcute;

  /// The style a manifest or a stored setting names, or null when it names
  /// something this build does not know.
  static IconStyle? parse(Object? raw) {
    for (final style in values) {
      if (style.name == raw) return style;
    }
    return null;
  }
}

/// What a package puts behind the app's pages.
enum BackgroundStyle {
  /// The theme's own surface color, which is also what the app draws with
  /// before any package is selected.
  none,

  /// A gradient derived from the color scheme.
  gradient,

  /// An image the package carries.
  image;

  /// The style a manifest or a stored setting names, or null when it names
  /// something this build does not know.
  static BackgroundStyle? parse(Object? raw) {
    for (final style in values) {
      if (style.name == raw) return style;
    }
    return null;
  }
}

/// The brightness a manifest table key names, or null when it names something
/// else.
///
/// `[components.light]` and `[components.dark]` are keyed this way, and so is
/// `colors.palette`, so a key is read back through [Brightness] rather than
/// compared against a literal — `light` and `dark` are its own `name`s.
Brightness? brightnessByName(Object? key) {
  for (final brightness in Brightness.values) {
    if (brightness.name == key) return brightness;
  }
  return null;
}

/// A symbol a package may carry an image or a color for, other than a tab's.
///
/// The key is a field rather than the value's own name, unlike the enums above:
/// the spelling is namespaced and dotted, so it is not an identifier. The set a
/// manifest may use is derived from [values], so a symbol here is one the parser
/// accepts and a widget can look up without either repeating the spelling.
enum ThemeNavIcon {
  more('nav.more'),
  settings('nav.settings'),
  tune('nav.tune'),
  privacy('nav.privacy'),
  agent('nav.agent'),
  tabs('nav.tabs'),
  server('nav.server'),
  sort('nav.sort'),
  terminal('nav.terminal'),
  folder('nav.folder'),
  cloud('nav.cloud'),
  snippet('nav.snippet'),
  inbox('nav.inbox'),
  key('nav.key'),
  info('nav.info'),
  download('nav.download'),
  desktop('nav.desktop');

  const ThemeNavIcon(this.iconKey);

  /// What a manifest's `icons.images` and `icons.colors` are keyed by, and what
  /// a widget asks the active package for.
  ///
  /// Not `key`: a value is named `key` too, and a case's name is a static member
  /// of the enum.
  final String iconKey;
}

/// The key a tab's symbol is stored under.
///
/// Derived from [AppTab] rather than listed, so a tab added to the bar cannot
/// arrive without its two icons being keys a package may use — every tab a
/// release ships needs an entry in a manifest for its icons to be drawn, and a
/// list of the same names kept here is a second place that has to be extended.
String tabIconKey(AppTab tab, {required bool selected}) =>
    'tab.${tab.name}${selected ? '.selected' : ''}';

