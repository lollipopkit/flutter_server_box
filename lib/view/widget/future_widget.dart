import 'package:flutter/material.dart';
import 'package:toolbox/data/res/ui.dart';

class FutureWidget<T> extends StatelessWidget {
  final Future<T> future;
  final Widget loading;
  final Widget Function(Object? error, StackTrace? trace) error;
  final Widget Function(T? data) success;
  final Widget Function(AsyncSnapshot<Object?> snapshot)? active;

  const FutureWidget({
    super.key,
    required this.future,
    this.loading = UIs.placeholder,
    required this.error,
    required this.success,
    this.active,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return error(snapshot.error, snapshot.stackTrace);
        }
        switch (snapshot.connectionState) {
          case ConnectionState.none:
          case ConnectionState.waiting:
            return loading;
          case ConnectionState.active:
            if (active != null) {
              return active!(snapshot);
            }
            return loading;
          case ConnectionState.done:
            return success(snapshot.data);
        }
      },
    );
  }
}
