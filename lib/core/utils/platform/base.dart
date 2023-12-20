import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:toolbox/core/extension/stringx.dart';

enum OS {
  android,
  ios,
  linux,
  macos,
  windows,
  web,
  fuchsia,
  unknown;

  static final type = () {
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

  @override
  String toString() => switch (this) {
        OS.macos => 'macOS',
        OS.ios => 'iOS',
        final val => val.name.upperFirst,
      };

  /// Whether has platform specific settings.
  static final hasSpecSetting = switch (type) {
    OS.android || OS.ios => true,
    _ => false,
  };
}

final isAndroid = OS.type == OS.android;
final isIOS = OS.type == OS.ios;
final isLinux = OS.type == OS.linux;
final isMacOS = OS.type == OS.macos;
final isWindows = OS.type == OS.windows;
final isWeb = OS.type == OS.web;
final isMobile = OS.type == OS.ios || OS.type == OS.android;
final isDesktop =
    OS.type == OS.linux || OS.type == OS.macos || OS.type == OS.windows;
