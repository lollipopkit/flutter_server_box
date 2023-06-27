import 'package:flutter/services.dart';

/// RegExp for number
final numReg = RegExp(r'\s{1,}');

/// Private Key max allowed size is 20kb
const privateKeyMaxSize = 20 * 1024;

// Editor max allowed size is 1mb
const editorMaxSize = 1024 * 1024;

/// Max debug log lines
const maxDebugLogLines = 100;

/// Method Channels
const pkgName = 'tech.lolli.toolbox';
const bgRunChannel = MethodChannel('$pkgName/app_retain');
