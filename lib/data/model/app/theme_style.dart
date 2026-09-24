import 'dart:ui' show Brightness;

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
