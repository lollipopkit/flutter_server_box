/// One plugin's readings, however they were collected.
///
/// The app and a monitor agent can both run a status plugin, and what comes
/// back is the same shape either way — `sbm_plugin::status::StatusResult`. It
/// arrives over the FFI from one and as JSON over HTTP from the other, so this
/// is where the two meet: `PluginStatusCard` draws this and does not have to
/// know which of them produced it.
///
/// See PLUGINS.md 9.5.
library;

class PluginStatusReading {
  const PluginStatusReading({
    this.title = '',
    this.items = const [],
    this.note,
  });

  /// The card's heading. Empty falls back to the plugin's name.
  final String title;

  final List<PluginStatusItemReading> items;

  /// Under the readings, for what a row cannot say.
  final String? note;
}

class PluginStatusItemReading {
  const PluginStatusItemReading({
    required this.label,
    required this.value,
    this.percent,
    this.tone = 'normal',
  });

  final String label;
  final String value;

  /// 0..1, drawn as a bar beside the value.
  ///
  /// Absent where the reading is not a proportion, and never out of range: a
  /// value outside it is dropped rather than clamped, by whichever host
  /// parsed it.
  final double? percent;

  /// `normal`, `muted`, `success`, `warning` or `danger`.
  ///
  /// A name rather than a colour, so a plugin's row looks like the app's own
  /// in both themes and cannot ship an unreadable one.
  final String tone;
}
