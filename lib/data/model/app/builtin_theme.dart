/// Stable package IDs and manifest names for bundled themes.
/// Theme resources are loaded separately, on demand.
///
/// Only what the app needs without a network: the default, and AMOLED, which
/// a legacy theme mode migrates to. Every other official theme is in the theme
/// store (`store/themes/`); a few of those also ship with the app, installed
/// once as ordinary packages — see `ThemePackages.seedBundled`.
enum BuiltinTheme {
  defaultTheme('default', 'Default'),
  amoled('amoled', 'AMOLED');

  const BuiltinTheme(this.id, this.label);

  final String id;
  final String label;

  static BuiltinTheme? fromId(String id) {
    for (final theme in values) {
      if (theme.id == id) return theme;
    }
    return null;
  }
}
