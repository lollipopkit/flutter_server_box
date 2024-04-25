import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

final class ValBuilder<T> extends ValueListenableBuilder<T> {
  ValBuilder({
    super.key,
    required ValueListenable<T> listenable,
    required Widget Function(T) builder,
  }) : super(
          valueListenable: listenable,
          builder: (_, val, __) => builder(val),
        );
}

final class ValChildBuilder<T> extends ValueListenableBuilder<T> {
  ValChildBuilder({
    super.key,
    required ValueListenable<T> listenable,
    required Widget Function(T, Widget?) builder,
    super.child,
  }) : super(
          valueListenable: listenable,
          builder: (_, val, child) => builder(val, child),
        );
}

final class ListenBuilder extends ListenableBuilder {
  ListenBuilder({
    super.key,
    required super.listenable,
    required Widget Function() builder,
  }) : super(
          builder: (_, __) => builder(),
        );
}
