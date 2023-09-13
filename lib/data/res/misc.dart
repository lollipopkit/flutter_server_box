import 'dart:convert';

import 'package:flutter/services.dart';

class Miscs {
  const Miscs._();

  /// RegExp for number
  static final numReg = RegExp(r'\s{1,}');

  /// RegExp for password request
  static final pwdRequestWithUserReg = RegExp(r'\[sudo\] password for (.+):');

  /// Private Key max allowed size is 20kb
  static const privateKeyMaxSize = 20 * 1024;

// Editor max allowed size is 1mb
  static const editorMaxSize = 1024 * 1024;

  /// Max debug log lines
  static const maxDebugLogLines = 100;

  /// Method Channels
  static const pkgName = 'tech.lolli.toolbox';
  static const bgRunChannel = MethodChannel('$pkgName/app_retain');
  static const homeWidgetChannel = MethodChannel('$pkgName/home_widget');

  static const jsonEncoder = JsonEncoder.withIndent('  ');
}
