/// The bounds of the numeric preferences that have no list of choices: what
/// the settings page and the app's MCP server both accept.
abstract final class SettingRange {
  /// `SettingStore.textFactor`, a multiple of the system's text size.
  static const textFactor = (min: 0.5, max: 3.0);

  /// `SettingStore.termFontSize` and `editorFontSize`.
  static const fontSize = (min: 6.0, max: 64.0);

  /// `SettingStore.timeout`, in seconds.
  static const timeout = (min: 1, max: 120);

  static bool contains(({num min, num max}) range, num value) =>
      value.isFinite && value >= range.min && value <= range.max;
}
