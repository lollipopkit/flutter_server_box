import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:plain_notification_token/plain_notification_token.dart';
import 'package:server_box/core/chan.dart';

/// This app's LK Cloud client: the `serverbox` public client at the IdP.
abstract final class Lkc {
  /// Registered with the IdP; AppAuth's Android receiver takes it too
  /// (`appAuthRedirectScheme` in `android/app/build.gradle`).
  static const redirectUrl = 'serverbox://auth/callback';

  /// The APNs topic homebase pushes to.
  static const _apnsTopic = 'com.lollipopkit.toolbox';

  /// Whether the account shows in settings and the client runs at launch.
  // TODO: rm once the LK Cloud account ships in ServerBox.
  static const enabled = false;

  static final client = LkcClient(
    oidc: LkcOidc(clientId: 'serverbox', redirectUrl: redirectUrl),
  );

  static Future<void> init() async {
    client.user.addListener(_onUser);
    if (isIOS) ApnsToken().onTokenRefresh.listen(_onApnsToken);
    try {
      await client.init();
    } catch (e, s) {
      Loggers.app.warning('LK Cloud init', e, s);
    }
  }

  /// The user and token this launch registered for push.
  static String? _pushFor;
  static String? _pushToken;

  /// The APNs token, once iOS has handed one over.
  static String? _apnsToken;

  /// Signed in, at launch or just now: register once iOS has the token. The
  /// permission is asked on signing in, as the account is what the
  /// notifications are for.
  static void _onUser() {
    if (!isIOS) return;
    if (client.user.value == null) {
      _pushFor = null;
      return;
    }
    // A token says nothing of it: the plugin registers at launch either way.
    // iOS asks once; later it answers with what the user chose.
    ApnsToken().requestPermission();
    if (_apnsToken != null) {
      unawaited(_registerPush());
      return;
    }
    // The plugin keeps the token, which may have come before this side
    // listened.
    unawaited(
      ApnsToken().getToken().then(
        (token) {
          if (token != null && token.isNotEmpty) _onApnsToken(token);
        },
        onError: (Object e, StackTrace s) =>
            Loggers.app.warning('APNs token', e, s),
      ),
    );
  }

  /// A token from iOS: the first of this launch, or one that changed.
  static void _onApnsToken(String token) {
    _apnsToken = token;
    if (client.user.value != null) unawaited(_registerPush());
  }

  static Future<void> _registerPush() async {
    final user = client.user.value;
    final token = _apnsToken;
    if (user == null || token == null || token.isEmpty) return;
    if (_pushFor == user.id && _pushToken == token) return;
    try {
      await client.registerDevice(
        token: token,
        appId: _apnsTopic,
        // From the profile the build was signed with; the build mode guesses.
        sandbox: await MethodChans.apnsSandbox() ?? !kReleaseMode,
      );
      // Only once it took: a failed one is tried again on the next sign-in
      // or token.
      _pushFor = user.id;
      _pushToken = token;
    } catch (e, s) {
      Loggers.app.warning('LK Cloud push registration', e, s);
    }
  }
}
