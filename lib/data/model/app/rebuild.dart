import 'package:flutter/foundation.dart';

class RebuildNode implements Listenable {
  final List<VoidCallback> _listeners = [];

  RebuildNode();

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void rebuild() {
    for (var listener in _listeners) {
      listener();
    }
  }
}
