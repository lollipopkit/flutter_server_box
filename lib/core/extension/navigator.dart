import 'package:flutter/material.dart';

extension ContextX on BuildContext {
  void pop<T extends Object?>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }

  bool get canPop => Navigator.of(this).canPop();
}
