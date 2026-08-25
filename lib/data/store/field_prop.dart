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

  /// One per property, not one per call.
  ///
  /// The house idiom is `Stores.setting.x.listenable().addListener(f)` in
  /// `initState` and the same expression with `removeListener` in `dispose` —
  /// two calls, and for a `SqliteProp` they pair up because its listenable
  /// delegates to a map the *store* owns. `_FieldListenable` keeps its
  /// wrappers itself, so a fresh one per call meant the removal looked in an
  /// empty map and returned silently: the wrapper stayed registered on the
  /// parent for the life of the process, holding a disposed `State` and
  /// calling into it. The prop is `late final` on the store, so caching here
  /// is per key.
  @override
  ValueListenable<F> listenable() => _listenable ??= _FieldListenable(this);
  _FieldListenable<T, F>? _listenable;

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

  /// A list per callback, not one wrapper. `ValueListenable` lets the same
  /// callback be added more than once and removed once per addition; keying a
  /// single wrapper by it dropped the earlier one from this map while it was
  /// still registered on the parent, so it could never be removed and held
  /// this and the callback alive for the rest of the process.
  final _wrappers = <VoidCallback, List<VoidCallback>>{};

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

    (_wrappers[listener] ??= []).add(onParent);
    _parent.addListener(onParent);
  }

  @override
  void removeListener(VoidCallback listener) {
    final wrappers = _wrappers[listener];
    if (wrappers == null || wrappers.isEmpty) return;
    _parent.removeListener(wrappers.removeLast());
    if (wrappers.isEmpty) _wrappers.remove(listener);
  }
}
