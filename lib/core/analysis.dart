import 'dart:async';

import 'package:countly_flutter/countly_flutter.dart';

class Analysis {
  static const _url = 'https://countly.xuty.cc';
  static const _key = '80372a2a66424b32d0ac8991bfa1ef058bd36b1f';

  static Future<void> init(bool debug) async {
    await Countly.setLoggingEnabled(debug);
    await Countly.init(_url, _key);
    await Countly.start();
    await Countly.enableCrashReporting();
    await Countly.giveAllConsent();
  }

  static void recordView(String view) {
    Countly.recordView(view);
  }

  static void recordException(Object exception, [bool fatal = false]) {
    Countly.logException(exception.toString(), !fatal, null);
  }
}
