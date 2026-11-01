/// What a localized message's placeholders are filled with for [startOf].
const l10nHole = '\u0000';

/// What [said] says before its first placeholder, filled with [l10nHole]: a
/// sentence with a time in it is found by its start, not the time.
RegExp startOf(String said) {
  final at = said.indexOf(l10nHole);
  if (at <= 0) {
    throw ArgumentError.value(said, 'said', 'has no text before a placeholder');
  }
  return RegExp('^${RegExp.escape(said.substring(0, at))}');
}
