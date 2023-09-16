import 'dart:io';

import 'package:toolbox/core/utils/platform/base.dart';

final _pathSep = Platform.pathSeparator;
String get pathSeparator => _pathSep;

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
String joinPath(String path1, String path2) {
  if (isWindows) {
    return path1 + (path1.endsWith('\\') ? '' : '\\') + path2;
  }
  return path1 + (path1.endsWith('/') ? '' : '/') + path2;
}
