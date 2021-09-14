import 'dart:math';
// EXCLUDE_FROM_GALLERY_DOCS_END
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:flutter/material.dart';

class DonutPieChart extends StatelessWidget {
  final List<charts.Series<dynamic, num>> seriesList;
  final bool animate;

  const DonutPieChart(this.seriesList, {Key? key, this.animate = true}) : super(key: key);

  factory DonutPieChart.withRandomData() {
    return DonutPieChart(_createRandomData());
  }

  /// Create random data.
  static List<charts.Series<IndexPercent, int>> _createRandomData() {
    final random = Random();

    final data = [
      IndexPercent(0, random.nextInt(100)),
      IndexPercent(1, random.nextInt(100)),
      IndexPercent(2, random.nextInt(100)),
      IndexPercent(3, random.nextInt(100)),
    ];

    return [
      charts.Series<IndexPercent, int>(
        id: 'Sales',
        domainFn: (IndexPercent sales, _) => sales.id,
        measureFn: (IndexPercent sales, _) => sales.percent,
        data: data,
      )
    ];
  }
  // EXCLUDE_FROM_GALLERY_DOCS_END

  @override
  Widget build(BuildContext context) {
    return charts.PieChart(seriesList,
        animate: animate,
        layoutConfig: charts.LayoutConfig(
          leftMarginSpec: charts.MarginSpec.fixedPixel(1), 
          topMarginSpec: charts.MarginSpec.fixedPixel(1), 
          rightMarginSpec: charts.MarginSpec.fixedPixel(1),
          bottomMarginSpec: charts.MarginSpec.fixedPixel(17)
        ),
        // Configure the width of the pie slices to 60px. The remaining space in
        // the chart will be left as a hole in the center.
        defaultRenderer: charts.ArcRendererConfig<num>(
          arcWidth: 6,
          minHoleWidthForCenterContent: 60,
          arcRatio: 0.2,
        )
      );
  }
}

/// Sample linear data type.
class IndexPercent {
  final int id;
  final int percent;

  IndexPercent(this.id, this.percent);
}