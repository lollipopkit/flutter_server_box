import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/provider/server/metric.dart';
import 'package:server_box/data/provider/server/reading_fmt.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/view/page/server/card/title.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/server/metric_row.dart';

/// The app's dark theme as last built, for burn-in protection to draw in
/// whatever brightness the app is in.
abstract final class ServerFullScreenTheme {
  static ThemeData? dark;

  /// [child] on black in the dark theme when [on]; as it is otherwise, with
  /// the same widgets around it either way.
  static Widget burnIn(
    BuildContext context, {
    required bool on,
    required Widget child,
  }) {
    final current = Theme.of(context);
    final theme = on ? _dark(current).toAmoled : current;
    return Theme(
      data: theme,
      child: ColoredBox(
        color: on ? Colors.black : Colors.transparent,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: on ? theme.colorScheme.onSurface : null),
          child: IconTheme.merge(
            data: IconThemeData(color: on ? theme.colorScheme.onSurface : null),
            child: child,
          ),
        ),
      ),
    );
  }

  static ThemeData _dark(ThemeData current) {
    if (dark case final dark?) return dark;
    if (current.brightness == Brightness.dark) return current;
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: current.colorScheme.primary,
        brightness: Brightness.dark,
      ),
    );
  }
}

/// One machine across the screen: the reading being watched, large, beside
/// every reading it reports.
class ServerFullScreenOne extends StatelessWidget {
  const ServerFullScreenOne({
    super.key,
    required this.srv,
    required this.promoted,
    required this.onPromote,
    required this.onOpen,
  });

  final ServerState srv;
  final ServerMetricKind? promoted;
  final ValueChanged<ServerMetricKind> onPromote;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final all = serverCardReadings(srv).all;
    final focus = all.firstWhereOrNull((m) => m.kind == promoted) ?? all.first;
    final stale = serverCardStaleSince(srv) != null;
    return LayoutBuilder(
      builder: (context, cons) {
        final focusCard = _focus(context, focus, stale: stale);
        final rows = _rows(context, all, focus.kind);
        if (cons.maxWidth > cons.maxHeight) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 135, child: focusCard),
              Expanded(flex: 100, child: rows),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: focusCard),
            Flexible(flex: 2, child: rows),
          ],
        );
      },
    );
  }

  Widget _focus(BuildContext context, ServerMetric m, {required bool stale}) {
    final series = [
      HistorySeries(m.label, stale ? Colors.grey : ChartPalette.accent, m.samples),
    ];
    final window = watchedWindow(
      m.times,
      series,
      until: stale ? DateTime.now().millisecondsSinceEpoch : null,
    );
    final span = window == null || window.to <= window.from
        ? null
        : Duration(milliseconds: window.to - window.from).toAgoStr;
    return _surface(
      context,
      padding: const EdgeInsets.fromLTRB(17, 13, 17, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpen,
            child: ServerCardTitle(srv: srv, openness: 0),
          ),
          UIs.height13,
          Row(
            children: [
              Icon(m.icon, size: 18, color: Theme.of(context).colorScheme.primary),
              UIs.width7,
              Text(
                m.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          UIs.height7,
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                m.value,
                style: const TextStyle(fontSize: 27, fontFeatures: kTabularFigures),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  m.bigNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ),
            ],
          ),
          UIs.height13,
          Expanded(
            child: LayoutBuilder(
              // A tap here is for the controls, like anywhere else that is
              // not a control.
              builder: (_, cons) => IgnorePointer(
                child: RepaintBoundary(
                  child: MetricChart(
                    MetricChartSpec(
                      series: series,
                      format: m.format,
                      times: m.times,
                      window: window,
                      binaryScale: m.binary,
                      height: cons.maxHeight,
                      fill: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          UIs.height7,
          Row(
            children: [
              Expanded(
                child: Text(
                  m.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: UIs.text11Grey,
                ),
              ),
              if (span != null) Text(span, style: UIs.text11Grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _rows(
    BuildContext context,
    List<ServerMetric> all,
    ServerMetricKind focus,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return _surface(
      context,
      padding: const EdgeInsets.all(7),
      child: Center(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final m in all)
              Material(
                color: m.kind == focus
                    ? scheme.secondaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onPromote(m.kind),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: MetricRow(
                        openness: 0,
                        icon: m.icon,
                        label: m.label,
                        color: ChartPalette.accent,
                        value: m.value,
                        note: m.note,
                        percent: m.percent,
                        over: m.over,
                        selected: m.kind == focus,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _surface(
    BuildContext context, {
    required EdgeInsets padding,
    required Widget child,
  }) {
    return FadingCard(
      outline: 1,
      color: cardColorOf(context),
      margin: const EdgeInsets.all(2),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The controls over the full screen, shown by a tap anywhere.
class ServerFullScreenBar extends StatelessWidget {
  const ServerFullScreenBar({
    super.key,
    required this.leading,
    required this.actions,
  });

  final Widget leading;
  final List<Widget> actions;

  /// Below the top inset.
  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.scaffoldBackgroundColor.withValues(alpha: 0.92),
      shape: Border(
        bottom: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              UIs.width13,
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: leading),
              ),
              ...actions,
              UIs.width7,
            ],
          ),
        ),
      ),
    );
  }
}

/// One of [ServerFullScreenBar]'s buttons.
class ServerFullScreenAction extends StatelessWidget {
  const ServerFullScreenAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, size: 21),
    onPressed: onTap,
  );
}

/// What a column count makes of the width: one per 330 points, 1 to 6.
int serverFullScreenColumns(double width) =>
    (width / 330).floor().clamp(1, 6).toInt();
