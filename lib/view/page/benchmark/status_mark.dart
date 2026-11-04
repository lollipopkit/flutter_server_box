import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/benchmark/benchmark_run.dart';
import 'package:server_box/data/res/chart_palette.dart';

/// How a run's state is drawn: a glyph, its colour, and the word for it.
///
/// One place for the history row and the result's summary, which used to pick
/// their own `Colors.*` each. The finished states take [StatePalette]'s fixed
/// hues, which keep their meaning under any seed. A run still going is neither
/// a success nor a warning, so it takes the theme colour, the way an "on" icon
/// does. The glyphs differ in shape as well, and the word goes beside them
/// where there is room, so no state rests on its colour alone.
extension BenchmarkStatusMark on BenchmarkStatus {
  (IconData, Color, String) mark(ColorScheme scheme) => switch (this) {
    BenchmarkStatus.completed => (
      Icons.check_circle,
      StatePalette.running,
      libL10n.success,
    ),
    BenchmarkStatus.failed => (
      Icons.error_outline,
      StatePalette.failed,
      libL10n.fail,
    ),
    BenchmarkStatus.cancelled => (
      Icons.cancel_outlined,
      StatePalette.warn,
      libL10n.cancelled,
    ),
    BenchmarkStatus.running => (
      Icons.timelapse,
      scheme.primary,
      l10n.benchmarkRunning,
    ),
  };
}
