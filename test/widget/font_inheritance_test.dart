import 'package:fl_chart/fl_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/chart.dart';
import 'package:server_box/view/page/setting/seq/srv_func_seq.dart';

import '../helpers/test_db.dart';

const _fallback = ['Test CJK'];

Widget _app(Widget child) => MaterialApp(
  theme: ThemeData(fontFamily: 'Test UI', fontFamilyFallback: _fallback),
  locale: const Locale('zh'),
  localizationsDelegates: const [
    LibLocalizations.delegate,
    ...AppLocalizations.localizationsDelegates,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Builder(builder: (context) {
    context.setLibL10n();
    app_locale.l10n = AppLocalizations.of(context)!;
    return Scaffold(body: child);
  }),
);

void main() {
  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('font_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  testWidgets('server action labels inherit the tile typography', (tester) async {
    await tester.pumpWidget(_app(const ServerFuncBtnsOrderPage(embedded: true)));
    await tester.pumpAndSettle();
    final labels = find.byWidgetPredicate((widget) => widget is RichText &&
        widget.text.toPlainText().contains(libL10n.terminal));
    expect(labels, findsOneWidget);
    final style = tester.renderObject<RenderParagraph>(labels).text.style!;
    expect(style.fontFamily, 'Test UI');
    expect(style.fontFamilyFallback, _fallback);
  });

  testWidgets('chart tooltips retain the same fonts as their labels', (tester) async {
    await tester.pumpWidget(_app(MetricChart(MetricChartSpec(
      series: const [HistorySeries('温度', Colors.blue, [20, 21])],
      format: (value) => '$value°C',
    ))));
    await tester.pumpAndSettle();
    final data = tester.widget<LineChart>(find.byType(LineChart)).data;
    final bar = data.lineBarsData.single;
    final items = data.lineTouchData.touchTooltipData.getTooltipItems([
      LineBarSpot(bar, 0, bar.spots.first),
    ]);
    final tooltip = items.single!;
    expect(tooltip.text, contains('温度'));
    expect(tooltip.textStyle.fontFamily, 'Test UI');
    expect(tooltip.textStyle.fontFamilyFallback, _fallback);
    expect(tooltip.textStyle.fontSize, 11);
    expect(tooltip.textStyle.color, Colors.white);
  });

  testWidgets('Markdown prose and code retain the shared font fallback', (tester) async {
    await tester.pumpWidget(_app(const SimpleMarkdown(data: '正文\n\n```sh\n命令\n```')));
    await tester.pumpAndSettle();
    for (final text in ['正文', '命令']) {
      final rich = find.byWidgetPredicate((widget) => widget is RichText &&
          widget.text.toPlainText().contains(text));
      expect(rich, findsOneWidget);
      final style = tester.renderObject<RenderParagraph>(rich).text.style!;
      expect(style.fontFamilyFallback, _fallback);
    }
  });
}
