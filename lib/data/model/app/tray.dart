import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';

/// What one server looks like in the status menu.
///
/// Described here and drawn natively — see `TrayService`. The three platforms
/// draw a menu row in three unrelated ways, and none of them takes a widget
/// from Flutter, so what crosses the channel is this: text that has already
/// been formatted, and a series that has already been normalised. Nothing on
/// the far side has to know what a percentage is or how to render one.
enum TrayLineState {
  /// Connected, and the machine answered.
  ok('●'),

  /// On its way: connecting, or a status still being read.
  working('◐'),

  /// Not connected, and nothing went wrong — a server nobody has opened yet,
  /// or one disconnected by hand.
  offline('○'),

  /// Tried and could not.
  failed('✕');

  const TrayLineState(this.glyph);

  /// Drawn before the name where a row is one line of text — Linux, and the
  /// compact layout. The rich layouts draw a dot themselves.
  final String glyph;
}

/// Which of the four a connection reads as.
TrayLineState trayStateOf(ServerConn conn) => switch (conn) {
  ServerConn.failed => TrayLineState.failed,
  ServerConn.disconnected => TrayLineState.offline,
  ServerConn.connecting || ServerConn.loading => TrayLineState.working,
  ServerConn.connected || ServerConn.finished => TrayLineState.ok,
};

/// A reading the menu can show, and the series a chart can be drawn from.
///
/// The set is what every source can answer for — SSH and a monitor agent both
/// report all six — so a metric never turns out to be missing on half the
/// servers in the list.
enum TrayMetric {
  cpu,
  mem,
  swap,
  net,
  disk,
  temp;

  /// The heading in the settings list and the label in a row.
  String get label => switch (this) {
    TrayMetric.cpu => 'CPU',
    TrayMetric.mem => 'MEM',
    TrayMetric.swap => 'SWAP',
    TrayMetric.net => 'NET',
    TrayMetric.disk => 'DISK',
    TrayMetric.temp => 'TEMP',
  };

  /// Whether a chart of it means anything.
  ///
  /// A percentage over time is a shape; a disk that is 41% full for a week is
  /// a flat line, and drawing it would spend the row's width saying nothing.
  bool get chartable => switch (this) {
    TrayMetric.cpu ||
    TrayMetric.mem ||
    TrayMetric.swap ||
    TrayMetric.net => true,
    TrayMetric.disk || TrayMetric.temp => false,
  };

  static TrayMetric? byName(String name) {
    for (final m in TrayMetric.values) {
      if (m.name == name) return m;
    }
    return null;
  }
}

/// What the user chose to see.
///
/// Carried with the model rather than read on the far side, so the native
/// menus hold no settings of their own: one push describes the whole menu,
/// including its shape.
class TrayConfig {
  const TrayConfig({
    this.metrics = const [TrayMetric.cpu, TrayMetric.mem],
    this.chart = TrayMetric.cpu,
    this.compact = false,
  });

  /// In the order they are drawn. Empty leaves a row with its name alone,
  /// which is a legitimate choice: the dot still says whether it is up.
  final List<TrayMetric> metrics;

  /// Null draws no chart.
  final TrayMetric? chart;

  /// One line per server instead of two, and no chart. What the menu was
  /// before this, and what a list of twenty servers wants.
  final bool compact;

  bool get drawsChart => !compact && chart != null;

  Map<String, Object?> toJson() => {
    'metrics': [for (final m in metrics) m.label],
    'chart': drawsChart,
    'compact': compact,
  };

  @override
  bool operator ==(Object other) =>
      other is TrayConfig &&
      other.chart == chart &&
      other.compact == compact &&
      _sameMetrics(other.metrics);

  bool _sameMetrics(List<TrayMetric> other) {
    if (other.length != metrics.length) return false;
    for (var i = 0; i < metrics.length; i++) {
      if (other[i] != metrics[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(metrics), chart, compact);
}

/// One reading on a row.
///
/// The metric travels with the value, not just its label: macOS draws an SF
/// Symbol in place of the words, and choosing one by matching the string
/// `CPU` would break the moment that label is translated or renamed. The label
/// goes too, for the platforms that draw it.
class TrayReading {
  const TrayReading(this.metric, this.value);

  final TrayMetric metric;
  final String value;

  Map<String, Object?> toJson() => {
    'key': metric.name,
    'label': metric.label,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is TrayReading && other.metric == metric && other.value == value;

  @override
  int get hashCode => Object.hash(metric, value);
}

/// One row.
class TrayLine {
  const TrayLine({
    required this.id,
    required this.name,
    required this.state,
    this.readings = const [],
    this.chart = const [],
  });

  /// The server this row is about, so that clicking it can open that server.
  final String id;

  final String name;
  final TrayLineState state;

  /// Already formatted, in the order they are drawn.
  ///
  /// Formatted here because the far side would otherwise need this app's
  /// notion of what a byte count reads as, three times over.
  final List<TrayReading> readings;

  /// 0..1, oldest first, or empty for no chart. Normalised here for the same
  /// reason: a drawing routine should not have to know that CPU is a
  /// percentage and network is bytes per second.
  final List<double> chart;

  /// The single line a platform that cannot do better draws — Linux, and the
  /// compact layout everywhere.
  String get label {
    final detail = readings
        .map((r) => '${r.metric.label} ${r.value}')
        .join('  ');
    return detail.isEmpty
        ? '${state.glyph}  $name'
        : '${state.glyph}  $name    $detail';
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'state': state.name,
    'label': label,
    'readings': [for (final r in readings) r.toJson()],
    'chart': chart,
  };

  @override
  bool operator ==(Object other) =>
      other is TrayLine &&
      other.id == id &&
      other.name == name &&
      other.state == state &&
      _sameReadings(other.readings) &&
      _sameChart(other.chart);

  bool _sameReadings(List<TrayReading> other) {
    if (other.length != readings.length) return false;
    for (var i = 0; i < readings.length; i++) {
      if (other[i] != readings[i]) return false;
    }
    return true;
  }

  bool _sameChart(List<double> other) {
    if (other.length != chart.length) return false;
    for (var i = 0; i < chart.length; i++) {
      if (other[i] != chart[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    state,
    Object.hashAll(readings),
    Object.hashAll(chart),
  );

  @override
  String toString() => 'TrayLine($label)';
}

/// Everything the menu shows, as one value.
///
/// One value so that an unchanged menu is not pushed again. A menu is replaced
/// whole on all three platforms, so a push while it is open closes it — and at
/// the refresh rate that would make it unusable.
class TrayModel {
  const TrayModel({required this.lines, this.config = const TrayConfig()});

  final List<TrayLine> lines;
  final TrayConfig config;

  Map<String, Object?> toJson() => {
    'config': config.toJson(),
    'lines': [for (final l in lines) l.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is TrayModel &&
      other.config == config &&
      other.lines.length == lines.length &&
      _same(other.lines);

  bool _same(List<TrayLine> other) {
    for (var i = 0; i < lines.length; i++) {
      if (lines[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(config, Object.hashAll(lines));
}

/// The readings [metrics] asks for, formatted.
///
/// A metric with nothing behind it is left out rather than shown as zero: a
/// machine with no temperature sensor is not a machine at 0°C.
List<TrayReading> trayReadings({
  required ServerStatus status,
  required List<TrayMetric> metrics,
}) {
  final out = <TrayReading>[];
  for (final metric in metrics) {
    final value = _read(status, metric);
    if (value != null) out.add(TrayReading(metric, value));
  }
  return out;
}

String? _read(ServerStatus status, TrayMetric metric) {
  switch (metric) {
    case TrayMetric.cpu:
      final used = status.cpu.usedPercent();
      return used == null ? null : '${used.round()}%';
    case TrayMetric.mem:
      final total = status.mem.total;
      if (total == 0) return null;
      return '${(status.mem.usedPercent * 100).round()}%';
    case TrayMetric.swap:
      final total = status.swap.total;
      if (total == 0) return null;
      return '${(status.swap.usedPercent * 100).round()}%';
    case TrayMetric.net:
      final vals = status.netSpeed.cachedVals;
      if (vals.speedIn == NetSpeed.noReading) return null;
      return '↓${vals.speedIn}  ↑${vals.speedOut}';
    case TrayMetric.disk:
      final usage = status.diskUsage;
      if (usage == null) return null;
      // Already 0..100 — unlike the memory ones, which are fractions.
      return '${usage.usedPercent.round()}%';
    case TrayMetric.temp:
      final temp = status.temps.first;
      return temp == null ? null : '${temp.round()}°C';
  }
}

/// The chart series, newest last and scaled to 0..1.
///
/// Empty when there is not enough of it: two points are a line segment, not a
/// trend, and a chart drawn from them says more than it knows.
List<double> trayChart({
  required ServerStatus status,
  required TrayMetric? metric,
  int count = 40,
}) {
  if (metric == null || !metric.chartable || count <= 0) return const [];
  final history = status.history;
  final List<double?> series = switch (metric) {
    TrayMetric.cpu => history.cpu,
    TrayMetric.mem => history.mem,
    TrayMetric.swap => history.swap,
    TrayMetric.net => _networkTotals(history.netRx, history.netTx),
    TrayMetric.disk || TrayMetric.temp => const [],
  };

  final samples = <double>[];
  for (final value in series.skip(
    series.length > count ? series.length - count : 0,
  )) {
    if (value != null && value.isFinite) samples.add(value);
  }
  if (samples.length < 3) return const [];

  if (metric == TrayMetric.net) {
    var peak = 0.0;
    for (final sample in samples) {
      if (sample.isFinite && sample > peak) peak = sample;
    }
    if (peak <= 0) return [for (final _ in samples) 0.0];
    return [for (final sample in samples) (sample / peak).clamp(0.0, 1.0)];
  }

  // Percentages against a fixed 0..100, not against their own range: a machine
  // idling between 1% and 3% would otherwise draw the same alarming shape as
  // one swinging between 10% and 90%.
  return [for (final s in samples) (s / 100).clamp(0.0, 1.0)];
}

/// One network series for a row: total traffic at each aligned sampling point.
/// A missing direction is zero only when the other direction was measured; if
/// neither was measured the point stays missing and is omitted from the chart.
List<double?> _networkTotals(List<double?> rx, List<double?> tx) {
  final length = rx.length < tx.length ? rx.length : tx.length;
  return [
    for (var i = 0; i < length; i++)
      if (rx[i] == null && tx[i] == null) null else (rx[i] ?? 0) + (tx[i] ?? 0),
  ];
}
