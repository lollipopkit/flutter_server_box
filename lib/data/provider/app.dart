import 'package:flutter/material.dart';

class AppProvider extends ChangeNotifier {
  int? _newestBuild;
  int? get newestBuild => _newestBuild;
  set newestBuild(int? build) {
    _newestBuild = build;
    notifyListeners();
  }

  bool moveBg = true;
}
