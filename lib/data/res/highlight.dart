import 'package:highlight/languages/accesslog.dart';
import 'package:highlight/languages/awk.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/cmake.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:highlight/languages/css.dart';
import 'package:highlight/languages/dart.dart';
import 'package:highlight/languages/diff.dart';
import 'package:highlight/languages/go.dart';
import 'package:highlight/languages/htmlbars.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/java.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/kotlin.dart';
import 'package:highlight/languages/lisp.dart';
import 'package:highlight/languages/lua.dart';
import 'package:highlight/languages/nix.dart';
import 'package:highlight/languages/objectivec.dart';
import 'package:highlight/languages/perl.dart';
import 'package:highlight/languages/php.dart';
import 'package:highlight/languages/plaintext.dart';
import 'package:highlight/languages/powershell.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/ruby.dart';
import 'package:highlight/languages/rust.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/swift.dart';
import 'package:highlight/languages/tex.dart';
import 'package:highlight/languages/typescript.dart';
import 'package:highlight/languages/vim.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/yaml.dart';

abstract final class Highlights {
  /// - KEY: fileNameSuffix
  /// - VAL: highlight
  static final all = {
    'dart': dart,
    'go': go,
    'rust': rust,
    'lua': lua,
    'sh': bash,
    'py': python,
    'js': javascript,
    'ts': typescript,
    'java': java,
    'kt': kotlin,
    'swift': swift,
    'c': cpp,
    'oc': objectivec,
    'ruby': ruby,
    'perl': perl,
    'php': php,
    'nix': nix,
    'lisp': lisp,
    'sql': sql,
    'powershell': powershell,
    'log': accesslog,
    'ini': ini,
    'cmake': cmake,
    'awk': awk,
    'json': json,
    'yaml': yaml,
    'xml': xml,
    'cpp': cpp,
    'diff': diff,
    'css': css,
    'html': htmlbars,
    'tex': tex,
    'vim': vim,
    'plaintext': plaintext,
  };

  static String? getCode(String? fileName) {
    if (fileName == null) return null;
    return fileName.split('.').last;
  }
}
