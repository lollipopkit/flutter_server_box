import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class PersistentStore<E> {
  late Box<E> box;

  Future<PersistentStore<E>> init({String boxName = 'defaultBox'}) async {
    box = await Hive.openBox(boxName);
    return this;
  }

  StoreProperty<T> property<T>(String key, {T? defaultValue}) {
    return StoreProperty<T>(box, key, defaultValue);
  }
}

class StoreProperty<T> {
  StoreProperty(this._box, this._key, this.defaultValue);

  final Box _box;
  final String _key;
  T? defaultValue;

  ValueListenable<T> listenable() {
    return PropertyListenable<T>(_box, _key, defaultValue);
  }

  T? fetch() {
    return _box.get(_key, defaultValue: defaultValue);
  }

  Future<void> put(T value) {
    return _box.put(_key, value);
  }

  Future<void> delete() {
    return _box.delete(_key);
  }
}

class PropertyListenable<T> extends ValueListenable<T> {
  PropertyListenable(this.box, this.key, this.defaultValue);

  final Box box;
  final String key;
  T? defaultValue;

  final List<VoidCallback> _listeners = [];
  StreamSubscription? _subscription;

  @override
  void addListener(VoidCallback listener) {
    _subscription ??= box.watch().listen((event) {
      if (key == event.key) {
        for (var listener in _listeners) {
          listener();
        }
      }
    });

    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);

    if (_listeners.isEmpty) {
      _subscription?.cancel();
      _subscription = null;
    }
  }

  @override
  T get value => box.get(key, defaultValue: defaultValue);
}
