import 'package:flutter/material.dart';

class AppProvider extends ChangeNotifier {
  int? _newestBuild;
  int? get newestBuild => _newestBuild;

  bool moveBg = true;

  void setNewestBuild(int build) {
    _newestBuild = build;
    notifyListeners();
  }
}
