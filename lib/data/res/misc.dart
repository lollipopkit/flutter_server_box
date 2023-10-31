import 'dart:convert';

class Miscs {
  const Miscs._();

  /// RegExp for number
  static final numReg = RegExp(r'\s{1,}');

  static final blankReg = RegExp(r'\s+');

  /// RegExp for password request
  static final pwdRequestWithUserReg = RegExp(r'\[sudo\] password for (.+):');

  /// Private Key max allowed size is 20kb
  static const privateKeyMaxSize = 20 * 1024;

  /// Editor max allowed size is 1mb
  static const editorMaxSize = 1024 * 1024;

  /// Max debug log lines
  static const maxDebugLogLines = 100;

  static const pkgName = 'tech.lolli.toolbox';

  static const jsonEncoder = JsonEncoder.withIndent('  ');
}
