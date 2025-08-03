import 'package:circle_chart/circle_chart.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

final class PercentCircle extends StatelessWidget {
  final double percent;

  const PercentCircle({super.key, required this.percent});

  @override
  Widget build(BuildContext context) {
    final percent = switch (this.percent) {
      <= 0.01 => 0.01,
      >= 99.9 => 99.9,
      _ => this.percent,
    };
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleChart(
          progressColor: UIs.primaryColor,
          progressNumber: percent,
          maxNumber: 100,
          width: 57,
          height: 57,
          animationDuration: const Duration(milliseconds: 777),
        ),
        Text(
          '${percent.toStringAsFixed(1)}%',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.7),
        ),
      ],
    );
  }
}
