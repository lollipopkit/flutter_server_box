import 'package:flutter/material.dart';
import 'package:toolbox/core/analysis.dart';

class AppRoute {
  final Widget page;
  final String title;

  AppRoute(this.page, this.title);

  Future<T?> go<T>(BuildContext context) {
    Analysis.recordView(title);
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
