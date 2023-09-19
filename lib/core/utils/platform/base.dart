import 'dart:io';

import 'package:flutter/foundation.dart';

enum OS {
  android,
  ios,
  linux,
  macos,
  windows,
  web,
  fuchsia,
  unknown;

  static final _os = () {
    if (kIsWeb) {
      return OS.web;
    }
    if (Platform.isAndroid) {
      return OS.android;
    }
    if (Platform.isIOS) {
      return OS.ios;
    }
    if (Platform.isLinux) {
      return OS.linux;
    }
    if (Platform.isMacOS) {
      return OS.macos;
    }
    if (Platform.isWindows) {
      return OS.windows;
    }
    if (Platform.isFuchsia) {
      return OS.fuchsia;
    }
    return OS.unknown;
  }();

  static OS get type => _os;

  @override
  String toString() {
    switch (this) {
      case OS.android:
        return 'Android';
      case OS.ios:
        return 'iOS';
      case OS.linux:
        return 'Linux';
      case OS.macos:
        return 'macOS';
      case OS.windows:
        return 'Windows';
      case OS.web:
        return 'Web';
      case OS.fuchsia:
        return 'Fuchsia';
      case OS.unknown:
        return 'Unknown';
    }
  }

  /// Whether has platform specific settings.
  static bool get hasSettings {
    switch (type) {
      case OS.android:
      case OS.ios:
        return true;
      default:
        return false;
    }
  }
}

bool get isAndroid => OS.type == OS.android;
bool get isIOS => OS.type == OS.ios;
bool get isLinux => OS.type == OS.linux;
bool get isMacOS => OS.type == OS.macos;
bool get isWindows => OS.type == OS.windows;
bool get isWeb => OS.type == OS.web;
bool get isMobile => OS.type == OS.ios || OS.type == OS.android;
bool get isDesktop =>
    OS.type == OS.linux || OS.type == OS.macos || OS.type == OS.windows;
