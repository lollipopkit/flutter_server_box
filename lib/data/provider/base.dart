import 'dart:async';

abstract class Provider<T> {
  const Provider();

  FutureOr<void> _init() {
    all.add(this);
    return load();
  }

  /// (Re)Load data from store / network / etc.
  FutureOr<void> load();

  static final all = <Provider>[];

  static Future<void> init() {
    if (all.isNotEmpty) return Future.value();

    // [FutureOr<void>] isn't returnable by [Future.wait], so add [await]
    return Future.wait(all.map((e) async => await e._init()));
  }

  static Future<void> reload() {
    return Future.wait(all.map((e) async => await e.load()));
  }
}
