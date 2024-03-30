import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_android/local_auth_android.dart';
// ignore: depend_on_referenced_packages
import 'package:local_auth_ios/types/auth_messages_ios.dart';
import 'package:toolbox/core/extension/context/locale.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:local_auth/error_codes.dart' as errs;
import 'package:toolbox/data/res/store.dart';

abstract final class BioAuth {
  static final _auth = LocalAuthentication();

  static final isPlatformSupported = isAndroid || isIOS || isWindows;

  static bool _isAuthing = false;

  static Future<bool> get isAvail async {
    if (!isPlatformSupported) return false;
    if (!await _auth.canCheckBiometrics) {
      return false;
    }
    final biometrics = await _auth.getAvailableBiometrics();

    /// [biometrics] on Android and Windows is returned with error
    /// Handle it specially
    if (isAndroid | isWindows) return biometrics.isNotEmpty;
    return biometrics.contains(BiometricType.face) ||
        biometrics.contains(BiometricType.fingerprint);
  }

  static Future<void> go([int count = 0]) async {
    if (Stores.setting.useBioAuth.fetch()) {
      if (!_isAuthing) {
        _isAuthing = true;
        final val = await goWithResult();
        switch (val) {
          case AuthResult.success:
            break;
          case AuthResult.fail:
          case AuthResult.cancel:
            go(count + 1);
            break;
          case AuthResult.notAvail:
            Stores.setting.useBioAuth.put(false);
            break;
        }
        _isAuthing = false;
      }
    }
  }

  static Future<AuthResult> goWithResult() async {
    if (!await isAvail) return AuthResult.notAvail;
    try {
      await _auth.stopAuthentication();
      final reuslt = await _auth.authenticate(
          localizedReason: l10n.authRequired,
          options: const AuthenticationOptions(
            biometricOnly: true,
            stickyAuth: true,
          ),
          authMessages: [
            AndroidAuthMessages(
              biometricHint: l10n.bioAuth,
              biometricNotRecognized: l10n.failed,
              biometricRequiredTitle: l10n.authRequired,
              biometricSuccess: l10n.success,
              cancelButton: l10n.cancel,
            ),
            IOSAuthMessages(
              lockOut: l10n.authRequired,
              cancelButton: l10n.ok,
            ),
          ]);
      if (reuslt) {
        return AuthResult.success;
      }
      return AuthResult.fail;
    } on PlatformException catch (e) {
      switch (e.code) {
        case errs.notEnrolled:
          return AuthResult.notAvail;
        case errs.lockedOut:
        case errs.permanentlyLockedOut:
          exit(0);
      }
      return AuthResult.cancel;
    }
  }
}

enum AuthResult {
  success,
  // Not match
  fail,
  // User cancel
  cancel,
  // Device doesn't support biometrics
  notAvail,
}
