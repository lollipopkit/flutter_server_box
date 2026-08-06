import 'package:server_box/data/res/build_data.dart';

extension BuildDataX on BuildData {
  static const versionStr = 'v1.0.${BuildData.build}';
}

/// Version constants for the OHOS (HarmonyOS) release.
abstract final class OhosBuild {
  static const appName = 'ServerBox for HarmonyOS';
  static const version = '1.0.0.1';
}
