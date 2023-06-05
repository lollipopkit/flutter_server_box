import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ValueBuilder<T> extends ValueListenableBuilder<T> {
  final ValueListenable<T> listenable;
  final Widget Function() build;

  ValueBuilder({
    super.key,
    required this.listenable,
    required this.build,
  }) : super(
          valueListenable: listenable,
          builder: (_, __, ___) => build(),
        );
}
