import 'package:flutter/material.dart';


extension ContextX on BuildContext {
  void pop<T>([T? result]) {
  Navigator.of(this).pop(T);
}
}
