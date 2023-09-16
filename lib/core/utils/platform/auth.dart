import 'dart:io';

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:toolbox/core/utils/platform/base.dart';
import 'package:local_auth/error_codes.dart' as errs;

class BioAuth {
  const BioAuth._();

  static final _auth = LocalAuthentication();

  static bool get isPlatformSupported => isAndroid || isIOS || isWindows;

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

  static Future<AuthResult> auth([String? msg]) async {
    if (!await isAvail) return AuthResult.notAvail;
    try {
      final reuslt = await _auth.authenticate(
        localizedReason: msg ?? 'Auth required',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
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
