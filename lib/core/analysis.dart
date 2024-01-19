import 'dart:async';

import 'package:countly_flutter/countly_flutter.dart';
import 'package:toolbox/core/build_mode.dart';
import 'package:toolbox/core/utils/platform/base.dart';

class Analysis {
  static const _url = 'https://countly.lolli.tech';
  static const _key = '0772e65c696709f879d87db77ae1a811259e3eb9';

  static bool enabled = false;

  static Future<void> init() async {
    if (enabled) return;
    if (!BuildMode.isRelease) {
      return;
    }
    if (isAndroid || isIOS) {
      enabled = true;
      final config = CountlyConfig(_url, _key)
          .setLoggingEnabled(false)
          .enableCrashReporting();
      await Countly.initWithConfig(config);
      await Countly.giveAllConsent();
    }
  }

  static void recordView(String view) {
    if (enabled) {
      Countly.instance.views.startView(view);
    }
  }

  static void recordException(Object exception, [bool fatal = false]) {
    if (enabled) {
      Countly.logException(exception.toString(), !fatal, null);
    }
  }
}
