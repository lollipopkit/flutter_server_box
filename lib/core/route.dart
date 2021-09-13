import 'package:flutter/material.dart';
import 'package:toolbox/core/analysis.dart';

class AppRoute {
  final Widget page;
  final String title;

  AppRoute(this.page, this.title);

  void go(BuildContext context) {
    Analysis.recordView(title);
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}
