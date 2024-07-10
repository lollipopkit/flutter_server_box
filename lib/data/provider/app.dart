import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

class AppProvider extends ChangeNotifier {
  BuildContext? ctx;

  bool isWearOS = false;

  Future<void> init() async {
    await _initIsWearOS();
  }

  Future<void> _initIsWearOS() async {
    if (!isAndroid) {
      isWearOS = false;
      return;
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    const feat = 'android.hardware.type.watch';
    final hasFeat = androidInfo.systemFeatures.contains(feat);
    if (hasFeat) {
      isWearOS = true;
      return;
    }
  }
}
