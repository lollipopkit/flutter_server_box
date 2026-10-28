import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:server_box/core/utils/misc.dart';

/// This app's LKC Cloud client: the `serverbox` public client at the IdP.
abstract final class Lkc {
  /// Registered with the IdP; AppAuth's Android receiver takes it too
  /// (`appAuthRedirectScheme` in `android/app/build.gradle`).
  static const redirectUrl = 'serverbox://auth/callback';

  /// The APNs topic homebase pushes to.
  static const _apnsTopic = 'com.lollipopkit.toolbox';

  static final client = LkcClient(
    oidc: LkcOidc(clientId: 'serverbox', redirectUrl: redirectUrl),
  );

  static Future<void> init() async {
    client.user.addListener(_onUser);
    try {
      await client.init();
    } catch (e, s) {
      Loggers.app.warning('LKC Cloud init', e, s);
    }
  }

  /// The user this launch registered push for.
  static String? _pushFor;

  /// Signed in, at launch or just now: register for push. Once per user and
  /// launch, as the APNs token may change between launches.
  static void _onUser() {
    final user = client.user.value;
    if (user == null) {
      _pushFor = null;
      return;
    }
    if (_pushFor == user.id) return;
    _pushFor = user.id;
    unawaited(_registerPush());
  }

  static Future<void> _registerPush() async {
    if (!isIOS) return;
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;
      await client.registerDevice(
        token: token,
        appId: _apnsTopic,
        // Debug and profile builds are signed for APNs' development environment.
        sandbox: !kReleaseMode,
      );
    } catch (e, s) {
      Loggers.app.warning('LKC Cloud push registration', e, s);
    }
  }
}
