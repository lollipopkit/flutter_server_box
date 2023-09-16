import 'package:flutter/material.dart';

class FutureWidget<T> extends StatelessWidget {
  final Future<T> future;
  final Widget loading;
  final Widget Function(Object? error, StackTrace? trace) error;
  final Widget Function(T data) success;
  final Widget noData;
  final Widget Function(AsyncSnapshot<Object?> snapshot)? active;

  const FutureWidget({
    super.key,
    required this.future,
    required this.loading,
    required this.error,
    required this.success,
    required this.noData,
    this.active,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
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
            if (snapshot.hasData) {
              return success(snapshot.data as T);
            }
            return noData;
        }
      },
    );
  }
}
