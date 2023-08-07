import 'dart:io';

import 'package:flutter/foundation.dart';

enum PlatformType {
  android,
  ios,
  linux,
  macos,
  windows,
  web,
  fuchsia,
  unknown;
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
  if (Platform.isFuchsia) {
    return PlatformType.fuchsia;
  }
  return PlatformType.unknown;
}();

final _pathSep = () {
  if (Platform.isWindows) {
    return '\\';
  }
  return '/';
}();

PlatformType get platform => _p;
String get pathSeparator => _pathSep;

bool get isAndroid => _p == PlatformType.android;
bool get isIOS => _p == PlatformType.ios;
bool get isLinux => _p == PlatformType.linux;
bool get isMacOS => _p == PlatformType.macos;
bool get isWindows => _p == PlatformType.windows;
bool get isWeb => _p == PlatformType.web;
bool get isMobile => _p == PlatformType.ios || _p == PlatformType.android;
bool get isDesktop =>
    _p == PlatformType.linux ||
    _p == PlatformType.macos ||
    _p == PlatformType.windows;

/// Available only on desktop,
/// return null on mobile
String? getHomeDir() {
  final envVars = Platform.environment;
  if (isMacOS || isLinux) {
    return envVars['HOME'];
  } else if (isWindows) {
    return envVars['UserProfile'];
  }
  return null;
}

/// Join two paths with platform specific separator
String pathJoin(String path1, String path2) {
  if (isWindows) {
    return path1 + (path1.endsWith('\\') ? '' : '\\') + path2;
  }
  return path1 + (path1.endsWith('/') ? '' : '/') + path2;
}
