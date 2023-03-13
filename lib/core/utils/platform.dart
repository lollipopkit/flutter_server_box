import 'dart:io';

import 'package:flutter/foundation.dart';

enum PlatformType {
  android,
  ios,
  linux,
  macos,
  windows,
  web,
}

final _p = () {
  if (kIsWeb) {
    return PlatformType.web;
  }
  if (Platform.isAndroid) {
    return PlatformType.android;
  }
  if (Platform.isIOS) {
    return PlatformType.ios;
  }
  if (Platform.isLinux) {
    return PlatformType.linux;
  }
  if (Platform.isMacOS) {
    return PlatformType.macos;
  }
  if (Platform.isWindows) {
    return PlatformType.windows;
  }
  return PlatformType.web;
}();

PlatformType get platform => _p;

bool get isAndroid => _p == PlatformType.android;
bool get isIOS => _p == PlatformType.ios;
bool get isLinux => _p == PlatformType.linux;
bool get isMacOS => _p == PlatformType.macos;
bool get isWindows => _p == PlatformType.windows;
bool get isWeb => _p == PlatformType.web;

