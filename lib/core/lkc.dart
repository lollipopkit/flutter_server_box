import 'package:fl_lib/fl_lib.dart';

/// This app's LKC Cloud client: the `serverbox` public client at the IdP.
abstract final class Lkc {
  /// Registered with the IdP; AppAuth's Android receiver takes it too
  /// (`appAuthRedirectScheme` in `android/app/build.gradle`).
  static const redirectUrl = 'serverbox://auth/callback';

  static final client = LkcClient(
    oidc: LkcOidc(clientId: 'serverbox', redirectUrl: redirectUrl),
  );

  static Future<void> init() async {
    try {
      await client.init();
    } catch (e, s) {
      Loggers.app.warning('LKC Cloud init', e, s);
    }
  }
}
