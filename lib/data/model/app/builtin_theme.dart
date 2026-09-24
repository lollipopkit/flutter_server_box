/// Stable package IDs and picker labels for bundled themes.
/// Theme resources are loaded separately, on demand.
enum BuiltinTheme {
  defaultTheme('default', 'Default'),
  amoled('amoled', 'AMOLED'),
  midnight('midnight', 'Midnight'),
  oneDarkPro('one-dark-pro', 'One Dark Pro'),
  githubDark('github-dark', 'GitHub Dark'),
  dracula('dracula', 'Dracula');

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
