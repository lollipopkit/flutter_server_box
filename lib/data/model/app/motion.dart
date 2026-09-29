/// How much the app moves, as chosen in its own settings.
///
/// Stored by name.
enum MotionPref {
  /// What the device's own accessibility setting says.
  system,

  /// Less motion whatever the device says: nothing travels across the screen,
  /// and what would have is a short fade.
  reduce,

  /// Full motion whatever the device says.
  full;

  /// The preference a stored setting names, or null for one this build does
  /// not know.
  static MotionPref? parse(Object? raw) {
    for (final pref in values) {
      if (pref.name == raw) return pref;
    }
    return null;
  }

  /// Whether motion is reduced, given what the device asks for.
  bool reduces({required bool system}) => switch (this) {
    MotionPref.system => system,
    MotionPref.reduce => true,
    MotionPref.full => false,
  };
}
