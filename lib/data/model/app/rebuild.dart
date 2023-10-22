import 'package:flutter/foundation.dart';

// ignore: prefer_void_to_null
class RebuildNode implements ValueListenable<Null> {
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

  @override
  Null get value => null;
}
