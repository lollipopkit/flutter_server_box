/// See: https://github.com/flutter/flutter/issues/11392
///
enum _BuildMode {
  release,
  debug,
  profile,
}

final _buildMode = (() {
  if (const bool.fromEnvironment('dart.vm.product')) {
    return _BuildMode.release;
  }
  var result = _BuildMode.profile;
  assert(() {
    result = _BuildMode.debug;
    return true;
  }());
  return result;
}());

class BuildMode {
  static bool isDebug = (_buildMode == _BuildMode.debug);
  static bool isProfile = (_buildMode == _BuildMode.profile);
  static bool isRelease = (_buildMode == _BuildMode.release);
}
