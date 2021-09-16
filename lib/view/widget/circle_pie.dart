import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class DonutPieChart extends StatelessWidget {
  final List<charts.Series<dynamic, num>> seriesList;
  final bool animate;

  const DonutPieChart(this.seriesList, {Key? key, this.animate = false})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return charts.PieChart(seriesList,
        animate: animate,
        layoutConfig: charts.LayoutConfig(
            leftMarginSpec: charts.MarginSpec.fixedPixel(1),
            topMarginSpec: charts.MarginSpec.fixedPixel(1),
            rightMarginSpec: charts.MarginSpec.fixedPixel(1),
            bottomMarginSpec: charts.MarginSpec.fixedPixel(17)),
        defaultRenderer: charts.ArcRendererConfig<num>(
          arcWidth: 6,
          arcRatio: 0.2,
        ));
  }
}

class IndexPercent {
  final int id;
  final int percent;

  IndexPercent(this.id, this.percent);
}
