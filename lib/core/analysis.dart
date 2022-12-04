import 'dart:async';
import 'dart:io';

import 'package:countly_flutter/countly_config.dart';
import 'package:countly_flutter/countly_flutter.dart';
import 'package:logging/logging.dart';
import 'package:toolbox/core/build_mode.dart';

class Analysis {
  static const _url = 'https://countly.xuty.cc';
  static const _key = '80372a2a66424b32d0ac8991bfa1ef058bd36b1f';

  static bool _enabled = false;

  static Future<void> init() async {
    if (!BuildMode.isRelease) {
      return;
    }
    if (Platform.isAndroid || Platform.isIOS) {
      _enabled = true;
      final config = CountlyConfig(_url, _key)
          .setLoggingEnabled(false)
          .enableCrashReporting();
      await Countly.initWithConfig(config);
      await Countly.start();
      await Countly.giveAllConsent();
    } else {
      Logger('COUNTLY')
          .info('Unsupported platform ${Platform.operatingSystem}');
    }
  }

  static void recordView(String view) {
    if (_enabled) {
      Countly.recordView(view);
    }
  }

  static void recordException(Object exception, [bool fatal = false]) {
    if (_enabled) {
      Countly.logException(exception.toString(), !fatal, null);
    }
  }
}
