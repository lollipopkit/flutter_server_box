import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';

/// One field of an object-valued property, with a property's own interface.
///
/// A setting group stored as an object is one row and reads as one value —
/// which is the point — but the app does not want it that way. Forty-odd call
/// sites read a single field, and the settings UI binds per field:
/// `StoreSwitch` takes a `StorePropDefault<bool>`, a text tile takes a
/// `StorePropDefault<String>`, and a `listenable()` on one field must not fire
/// when a different one changes. Rewriting all of that to fetch the object,
/// `copyWith` and put it back would put the same three lines at every call
/// site and lose the type each one wants.
///
/// So the object is the row and this is the field: [get] reads through, [set]
/// replaces one field and writes the object back, and [listenable] is the
/// parent's, filtered so a listener only hears its own field change.
///
/// [key] is the parent's key with the field appended. Nothing looks a row up
/// by it — every read and write goes through [parent] — and it exists so that
/// a failed write names something a person can find.
final class FieldProp<T extends Object, F extends Object>
    extends StorePropDefault<F> {
  FieldProp(
    this.parent,
    String field, {
    required F Function(T) read,
    required T Function(T, F) write,
  }) : _read = read,
       _write = write,
       super('${parent.key}.$field', read(parent.defaultValue));

  final StorePropDefault<T> parent;
  final F Function(T) _read;
  final T Function(T, F) _write;

  @override
  KvStore get store => parent.store;

  @override
  F get() => _read(parent.get());

  @override
  Future<void> set(F value) => parent.set(_write(parent.get(), value));

  /// Removing one field of an object is setting it back to its default: there
  /// is no row of its own to delete, and deleting the parent would take every
  /// other field with it.
  @override
  Future<void> remove() => set(defaultValue);

  @override
  ValueListenable<F> listenable() => _FieldListenable(this);

  /// The three names `SqliteProp` keeps for backward compatibility. Every call
  /// site in the app uses them, so a field has to read like any other property
  /// or grouping a setting would mean touching all of them.
  F fetch() => get();

  void put(F value) => set(value);

  void delete() => remove();
}

/// The parent's listenable, reporting this field and only when it changes.
///
/// The parent notifies on every write to the object, so a switch bound to one
/// field would rebuild whenever any other field was touched. Holding the last
/// value and comparing is what keeps that to the field the listener asked for.
class _FieldListenable<T extends Object, F extends Object>
    extends ValueListenable<F> {
  _FieldListenable(this.prop) : _parent = prop.parent.listenable();

  final FieldProp<T, F> prop;
  final ValueListenable<T> _parent;
  final _listeners = <VoidCallback, VoidCallback>{};

  @override
  F get value => prop.get();

  @override
  void addListener(VoidCallback listener) {
    var last = prop.get();
    void onParent() {
      final now = prop.get();
      if (now == last) return;
      last = now;
      listener();
    }

    _listeners[listener] = onParent;
    _parent.addListener(onParent);
  }

  @override
  void removeListener(VoidCallback listener) {
    final wrapped = _listeners.remove(listener);
    if (wrapped != null) _parent.removeListener(wrapped);
  }
}
