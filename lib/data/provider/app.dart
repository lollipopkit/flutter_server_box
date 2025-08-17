import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app.g.dart';
part 'app.freezed.dart';

@freezed
abstract class AppState with _$AppState {
  const factory AppState() = _AppState;
}

@Riverpod(keepAlive: true)
class AppStates extends _$AppStates {
  static BuildContext? ctx;

  @override
  AppState build() {
    return const AppState();
  }
}
