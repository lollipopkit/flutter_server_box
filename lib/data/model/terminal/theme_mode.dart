/// How the SSH terminal selects its light/dark palette.
enum TerminalThemeMode {
  followApp,
  light,
  dark;

  static TerminalThemeMode? fromStored(Object? raw) => switch (raw) {
    final String name => _byName(name),
    // TODO(migration): drop legacy 0/1/2 decoding once no older build writes ints.
    final int idx when idx >= 0 && idx < values.length => values[idx],
    _ => null,
  };

  static TerminalThemeMode? _byName(String name) {
    for (final v in values) {
      if (v.name == name) return v;
    }
    return null;
  }
}
